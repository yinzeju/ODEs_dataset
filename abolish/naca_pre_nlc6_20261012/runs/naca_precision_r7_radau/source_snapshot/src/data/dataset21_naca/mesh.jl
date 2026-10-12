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
    if haskey(parameters,"span_layers")
        layers=Int.(parameters["span_layers"])
        length(layers)==24 && minimum(layers)>=1 || error("One positive layer count per physical rib interval is required")
        declaration="span_layers[] = {"*join(layers,",")*"};\n"
        wing=declaration*replace(wing,"Layers{La}"=>"Layers{span_layers[i-1]}")
    end
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

@inline difference3(a,b)=(a[1]-b[1],a[2]-b[2],a[3]-b[3])
@inline dot3(a,b)=a[1]*b[1]+a[2]*b[2]+a[3]*b[3]
@inline function mapped_distance2(p,a,b,c,w)
    x=w[1]*a[1]+w[2]*b[1]+w[3]*c[1]-p[1]
    y=w[1]*a[2]+w[2]*b[2]+w[3]*c[2]-p[2]
    z=w[1]*a[3]+w[2]*b[3]+w[3]*c[3]-p[3]
    return x*x+y*y+z*z
end

"""Exact closest-triangle interpolation with conservative bounding-box pruning."""
function interpolation(source::WingMesh, destination::Matrix{Float64})
    vertices=[ntuple(j->ntuple(d->source.nodes[source.triangles[e,j],d],3),3) for e in axes(source.triangles,1)]
    boxes=[(ntuple(d->min(a[d],b[d],c[d]),3),ntuple(d->max(a[d],b[d],c[d]),3)) for (a,b,c) in vertices]
    ii=Int[];jj=Int[];vv=Float64[];distances=zeros(size(destination,1))
    sizehint!(ii,18size(destination,1));sizehint!(jj,18size(destination,1));sizehint!(vv,18size(destination,1))
    for s in axes(destination,1)
        p=ntuple(d->destination[s,d],3)
        best=Inf;best_element=0;bestweights=(0.,0.,0.)
        for e in eachindex(vertices)
            lo,hi=boxes[e];lower_bound=0.
            @inbounds for d in 1:3
                distance=max(lo[d]-p[d],p[d]-hi[d],0.)
                lower_bound+=distance*distance
            end
            lower_bound>best+32eps(Float64)*max(1.,best) && continue
            a,b,c=vertices[e];ab=difference3(b,a);ac=difference3(c,a);v=difference3(p,a)
            aa=dot3(ab,ab);cc=dot3(ac,ac);cross=dot3(ab,ac)
            determinant=aa*cc-cross*cross
            determinant>0 || error("Degenerate interpolation triangle")
            av=dot3(ab,v);cv=dot3(ac,v)
            u=(cc*av-cross*cv)/determinant;w=(aa*cv-cross*av)/determinant
            if u>=0 && w>=0 && u+w<=1
                weights=(1-u-w,u,w);distance=mapped_distance2(p,a,b,c,weights)
                if distance<best;best=distance;best_element=e;bestweights=weights;end
            end
            for (i,j) in ((1,2),(2,3),(3,1))
                vi=vertices[e][i];vj=vertices[e][j];edge=difference3(vj,vi)
                t=clamp(dot3(difference3(p,vi),edge)/dot3(edge,edge),0.,1.)
                weights=ntuple(k->k==i ? 1-t : k==j ? t : 0.,3)
                distance=mapped_distance2(p,a,b,c,weights)
                if distance<best;best=distance;best_element=e;bestweights=weights;end
            end
        end
        best_element>0 || error("No interpolation triangle")
        distances[s]=sqrt(best)
        @inbounds for j in 1:3,d in 1:6
            push!(ii,6(s-1)+d);push!(jj,6(source.triangles[best_element,j]-1)+d);push!(vv,bestweights[j])
        end
    end
    return sparse(ii,jj,vv,6size(destination,1),6size(source.nodes,1)),distances
end
