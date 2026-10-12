# SPDX-License-Identifier: GPL-3.0-only
struct WingMesh
    nodes::Matrix{Float64}
    triangles::Matrix{Int}
    domains::Vector{Int}
    fixed_nodes::Vector{Int}
    source_sha256::String
end

"""Read Gmsh ASCII MSH 2.x; ignore duplicate BC/load copies of physical triangles."""
function read_mesh(path)
    lines = readlines(path)
    section(name) = something(findfirst(==(name), lines), 0)
    f = section("\$MeshFormat")
    f > 0 || error("Missing MSH format")
    format = split(lines[f+1])
    startswith(format[1], "2.") && format[2] == "0" || error("ASCII MSH 2.x required")
    p = section("\$Nodes"); p > 0 || error("Missing nodes")
    coordinates = Dict{Int,NTuple{3,Float64}}()
    for line in lines[p+2:p+1+parse(Int, lines[p+1])]
        a = split(line)
        id = parse(Int, a[1])
        haskey(coordinates, id) && error("Repeated node id")
        coordinates[id] = Tuple(parse.(Float64, a[2:4]))
    end
    p = section("\$Elements"); p > 0 || error("Missing elements")
    elements = Dict{NTuple{3,Int},Tuple{NTuple{3,Int},Int}}()
    fixed = Set{Int}()
    for line in lines[p+2:p+1+parse(Int, lines[p+1])]
        a = parse.(Int, split(line))
        kind, ntags = a[2:3]
        ntags >= 1 || continue
        physical = a[4]
        ids = a[4+ntags:end]
        if 101 <= physical <= 200
            union!(fixed, ids)
        end
        if 1 <= physical <= 100
            kind == 2 && length(ids) == 3 || error("Only linear triangular structural faces are supported")
            key = Tuple(sort(ids))
            if haskey(elements, key)
                elements[key][2] == physical || error("Overlapping structural physical groups")
            else
                elements[key] = (Tuple(ids), physical)
            end
        end
    end
    isempty(elements) && error("No structural triangles")
    used = sort!(unique!(collect(Iterators.flatten(keys(elements)))))
    mapping = Dict(id => i for (i,id) in enumerate(used))
    nodes = reduce(vcat, [reshape(collect(coordinates[id]), 1, 3) for id in used])
    triangles = Matrix{Int}(undef, length(elements), 3)
    domains = Vector{Int}(undef, length(elements))
    for (e,key) in enumerate(sort!(collect(keys(elements))))
        ids, domains[e] = elements[key]
        triangles[e,:] = [mapping[id] for id in ids]
    end
    fixed_nodes = sort!([mapping[id] for id in fixed if haskey(mapping,id)])
    isempty(fixed_nodes) && error("Missing physical root constraint")
    maximum(abs, nodes[fixed_nodes,3]) < 1e-8 || error("Root group is not at z=0")
    Set(domains) == Set([1,2,3]) || error("Skin, longitudinal stiffeners and rib groups required")
    all(isfinite,nodes) || error("Nonfinite coordinates")
    # Every structural component must connect to the clamped root.
    adjacency = [Int[] for _ in used]
    for tri in eachrow(triangles), i in tri, j in tri
        i != j && push!(adjacency[i],j)
    end
    seen = falses(length(used)); queue = copy(fixed_nodes); seen[queue] .= true
    cursor = 1
    while cursor <= length(queue)
        i = queue[cursor]; cursor += 1
        for j in adjacency[i]
            if !seen[j]; seen[j]=true; push!(queue,j); end
        end
    end
    all(seen) || error("Disconnected mesh component")
    return WingMesh(nodes,triangles,domains,fixed_nodes,filehash(path))
end

function source_root()
    manifest = JSON.parsefile(joinpath(ROOT,"configs","references","naca_sources.json"))
    manifest["commit"] == UPSTREAM_COMMIT || error("Unexpected upstream commit")
    root = joinpath(ROOT,manifest["cache_root"])
    for row in manifest["files"]
        file = joinpath(root,row["path"])
        isfile(file) || error("Missing source $file; run the source preparation command first")
        filehash(file) == row["sha256"] || error("Source hash mismatch: $file")
    end
    return root
end

function generate_mesh(folder, parameters, gmsh)
    mkpath(folder)
    root = joinpath(source_root(),"ext","YetAnotherFEcode","examples","Mechanical","3D","NACAWing")
    wing = read(joinpath(root,"WING.geo"),String)
    airfoil = read(joinpath(root,"AIRFOIL.geo"),String)
    wing = replace(wing, r"La\s*=\s*6\s*;" => "La=$(parameters["La"]);")
    airfoil = replace(airfoil, r"a1\s*=\s*5\s*;" => "a1=$(parameters["a1"]);")
    airfoil = replace(airfoil, r"a2\s*=\s*10\s*;" => "a2=$(parameters["a2"]);")
    # SF is deliberately not applied: the pinned source declares but never uses it.
    write(joinpath(folder,"WING.geo"), wing)
    write(joinpath(folder,"AIRFOIL.geo"),airfoil)
    geo = joinpath(folder,"WING.geo"); msh = joinpath(folder,"Wing.msh")
    logpath = joinpath(folder,"gmsh.log")
    open(logpath,"w") do io
        run(pipeline(`$gmsh $geo -2 -order 1 -format msh2 -o $msh -nt 1`, stdout=io,stderr=io))
    end
    return read_mesh(msh)
end

"""Piecewise-linear geometric map for all six nodal coordinates; used only in QUAL."""
function interpolation(source::WingMesh, destination::Matrix{Float64})
    ii=Int[]; jj=Int[]; vv=Float64[]; distances=zeros(size(destination,1))
    for s in axes(destination,1)
        p=destination[s,:]; best=Inf; besttri=zeros(Int,3); bestweights=zeros(3)
        for tri in eachrow(source.triangles)
            a,b,c=(source.nodes[i,:] for i in tri)
            ab=b-a; ac=c-a; v=p-a
            gram=[dot(ab,ab) dot(ab,ac);dot(ab,ac) dot(ac,ac)]
            uv=gram\[dot(ab,v),dot(ac,v)]
            candidates=Vector{Vector{Float64}}()
            if uv[1]>=0 && uv[2]>=0 && sum(uv)<=1
                push!(candidates,[1-sum(uv),uv[1],uv[2]])
            end
            for (i,j) in ((1,2),(2,3),(3,1))
                vertices=(a,b,c); edge=vertices[j]-vertices[i]
                t=clamp(dot(p-vertices[i],edge)/dot(edge,edge),0.,1.)
                w=zeros(3);w[i]=1-t;w[j]=t;push!(candidates,w)
            end
            for w in candidates
                distance=norm(w[1]*a+w[2]*b+w[3]*c-p)
                if distance<best
                    best=distance;besttri.=tri;bestweights.=w
                end
            end
        end
        distances[s]=best
        for j in 1:3,d in 1:6
            push!(ii,6(s-1)+d);push!(jj,6(besttri[j]-1)+d);push!(vv,bestweights[j])
        end
    end
    return sparse(ii,jj,vv,6size(destination,1),6size(source.nodes,1)),distances
end
