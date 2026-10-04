# Allman flat-facet shell, following YetAnotherFEcode and the SSMLearn examples.
# Source identities and comparisons are frozen in the release provenance.
# Full six-DOF nodes are retained, including the drilling rotation.

function allman_bending(nodes, E, h, nu, area)
    x, y = nodes[:,1], nodes[:,2]
    x12, x23, x31 = x[1]-x[2], x[2]-x[3], x[3]-x[1]
    y21, y32, y13 = y[2]-y[1], y[3]-y[2], y[1]-y[3]
    ell = sqrt.([x12^2+y21^2, x23^2+y32^2, x31^2+y13^2])
    si, co = [x12,x23,x31]./ell, [y21,y32,y13]./ell
    D = E*h^3/(12*(1-nu^2))
    Db = D .* [1 nu 0; nu 1 0; 0 0 (1-nu)/2]
    H = zeros(7,7)
    # Exact degree-two triangle quadrature for the cubic bending stress basis.
    for bary in ((2/3,1/6,1/6),(1/6,2/3,1/6),(1/6,1/6,2/3))
        xx, yy = dot(x,bary), dot(y,bary)
        curvature = [2 0 0 6xx 2yy 0 0;
                     0 0 2 0 0 2xx 6yy;
                     0 2 0 0 4xx 4yy 0]
        H .+= (area/3) .* (curvature' * Db * curvature)
    end
    T = zeros(12,9)
    T[1,1]=T[2,4]=T[3,7]=1
    l1,l2,l3=ell; s1,s2,s3=si; c1,c2,c3=co
    T[4,1:6] = [l1/2,-l1^2*s1/12,l1^2*c1/12,l1/2,l1^2*s1/12,-l1^2*c1/12]
    T[5,4:9] = [l2/2,-l2^2*s2/12,l2^2*c2/12,l2/2,l2^2*s2/12,-l2^2*c2/12]
    T[6,[1,2,3,7,8,9]] = [l3/2,l3^2*s3/12,-l3^2*c3/12,l3/2,-l3^2*s3/12,l3^2*c3/12]
    T[7,[2,3,5,6]] = [-l1*c1/3,-l1*s1/3,-l1*c1/6,-l1*s1/6]
    T[8,[2,3,5,6]] = [-l1*c1/6,-l1*s1/6,-l1*c1/3,-l1*s1/3]
    T[9,[5,6,8,9]] = [-l2*c2/3,-l2*s2/3,-l2*c2/6,-l2*s2/6]
    T[10,[5,6,8,9]] = [-l2*c2/6,-l2*s2/6,-l2*c2/3,-l2*s2/3]
    T[11,[2,3,8,9]] = [-l3*c3/6,-l3*s3/6,-l3*c3/3,-l3*s3/3]
    T[12,[2,3,8,9]] = [-l3*c3/3,-l3*s3/3,-l3*c3/6,-l3*s3/6]
    S = 2 .* si .* co .- 2 .* si[[3,1,2]] .* co[[3,1,2]]
    C = co.^2 .- si.^2 .- (co[[3,1,2]].^2 .- si[[3,1,2]].^2)
    B = zeros(7,12)
    B[1,1:3] = D*(1-nu).*S
    B[2,1:3] = -D*(1-nu).*C
    B[3,1:3] = -B[1,1:3]
    B[4,1:3] = 3D*(1-nu).*x.*S
    B[5,1:3] = -D*(1-nu).*(-y.*S .+ 2x.*C)
    B[6,1:3] = -D*(1-nu).*(x.*S .+ 2y.*C)
    B[7,1:3] = -3D*(1-nu).*y.*S
    B[4,4:6] = -6D.*co.*(1 .+ (1-nu).*si.^2)
    B[5,4:6] = -2D.*si.*((2-nu).*si.^2 .+ (2nu-1).*co.^2)
    B[6,4:6] = -2D.*co.*((2-nu).*co.^2 .+ (2nu-1).*si.^2)
    B[7,4:6] = -6D.*si.*(1 .+ (1-nu).*co.^2)
    for (cols, permutation) in ((7:2:11,[1,2,3]),(8:2:12,[2,3,1]))
        xx, yy = x[permutation], y[permutation]
        B[1,cols] = -2D.*(co.^2 .+ nu.*si.^2)
        B[2,cols] = -2D*(1-nu).*si.*co
        B[3,cols] = -2D.*(nu.*co.^2 .+ si.^2)
        B[4,cols] = -6D.*xx.*(co.^2 .+ nu.*si.^2)
        B[5,cols] = -2D.*(yy.*(co.^2 .+ nu.*si.^2) .+ 2(1-nu).*xx.*si.*co)
        B[6,cols] = -2D.*(xx.*(nu.*co.^2 .+ si.^2) .+ 2(1-nu).*yy.*si.*co)
        B[7,cols] = -6D.*yy.*(nu.*co.^2 .+ si.^2)
    end
    BT=B*T
    K=BT'*(Symmetric(H)\BT)
    permutation=[1,3,2,4,6,5,7,9,8]
    K=K[permutation,permutation]
    signs=[1.,1.,-1.,1.,1.,-1.,1.,1.,-1.]
    K .*= signs*signs'
    return (K+K')/2
end

function allman_mass(nodes, rho, h, A)
    x1,x2,x3=nodes[:,1]; y1,y2,y3=nodes[:,2]
    x12,x23,x31=x1-x2,x2-x3,x3-x1
    y21,y32,y13=y2-y1,y3-y2,y1-y3
    X12,X23,X31=-x12/(4A),-x23/(4A),-x31/(4A)
    Y12,Y23,Y31=y21/(4A),y32/(4A),y13/(4A)
    Bu=zeros(3,9); Bv=zeros(3,9); Bw=zeros(3,9)
    for i in 1:3
        Bu[i,3i-2]=1; Bv[i,3i-1]=1; Bw[i,3i-2]=1
    end
    Bau=zeros(6,9); Bav=zeros(6,9); Baw=zeros(6,9)
    Bau[1,[3,6]]=[-y21,y21]/2; Bau[2,[6,9]]=[-y32,y32]/2
    Bau[3,[3,9]]=[y13,-y13]/2
    Bav[1,[3,6]]=[-x12,x12]/2; Bav[2,[6,9]]=[-x23,x23]/2
    Bav[3,[3,9]]=[x31,-x31]/2
    for (Ba,a,b,c) in ((Bau,y21,y32,y13),(Bav,x12,x23,x31))
        Ba[4,1:8]=[X23*a,Y23*a,a/2,X31*a,Y31*a,a/2,X12*a,Y12*a]
        Ba[5,[1,2,4,5,6,7,8,9]]=[X23*b,Y23*b,X31*b,Y31*b,b/2,X12*b,Y12*b,b/2]
        Ba[6,[1,2,3,4,5,7,8,9]]=[X23*c,Y23*c,c/2,X31*c,Y31*c,X12*c,Y12*c,c/2]
    end
    Baw[1,[2,3,5,6]]=[y21,x12,-y21,-x12]/2
    Baw[2,[5,6,8,9]]=[y32,x23,-y32,-x23]/2
    Baw[3,[2,3,8,9]]=[-y13,-x31,y13,x31]/2
    Baw[4,1:6]=[-2,-y21,-x12,2,-y21,-x12]/2
    Baw[5,4:9]=[-2,-y32,-x23,2,-y32,-x23]/2
    Baw[6,[1,2,3,7,8,9]]=[2,-y13,-x31,-2,-y13,-x31]/2
    NN=[1/6 1/12 1/12; 0 1/6 1/12; 0 0 1/6]
    NNa=rho*h*A.*[1/30 1/60 1/30 -1/180 0 -1/180;
                          1/30 1/30 1/60 1/180 -1/180 0;
                          1/60 1/30 1/30 0 1/180 -1/180]
    NaNa=rho*h*A.*[1/90 1/180 1/180 0 -1/1260 1/1260;
        0 1/90 1/180 1/1260 0 -1/1260; 0 0 1/90 -1/1260 1/1260 0;
        0 0 0 1/840 -1/2520 -1/2520; 0 0 0 0 1/840 -1/2520; 0 0 0 0 0 1/840]
    membrane_NN=(rho*h*A/2) .* (NN+NN')
    membrane_NaNa=(NaNa+NaNa')/2
    Mm=Bu'*membrane_NN*Bu + Bu'*NNa*Bau + Bau'*NNa'*Bu + Bau'*membrane_NaNa*Bau +
       Bv'*membrane_NN*Bv + Bv'*NNa*Bav + Bav'*NNa'*Bv + Bav'*membrane_NaNa*Bav
    bending_NN=rho*h*A.*(NN+tril(NN',-1))
    bending_NaNa=NaNa+tril(NaNa',-1)
    Mb=Bw'*bending_NN*Bw + Bw'*NNa*Baw + Baw'*NNa'*Bw + Baw'*bending_NaNa*Baw
    md=diag(Mm).*(rho*h*A/sum(diag(Mm)[[2,5,8]]))
    bd=diag(Mb).*(rho*h*A/sum(diag(Mb)[[1,4,7]]))
    return md,bd
end

function shell_element(nodes, E, nu, rho, h)
    e1=normalize(nodes[2,:]-nodes[1,:])
    e3=normalize(cross(e1,nodes[3,:]-nodes[1,:]))
    e2=cross(e3,e1)
    R=vcat(e1',e2',e3'); T=kron(Matrix{Float64}(I,6,6),R)
    localnodes=(nodes .- nodes[1,:]')*R'
    x=localnodes[:,1]; y=localnodes[:,2]
    x12,x23,x31=x[1]-x[2],x[2]-x[3],x[3]-x[1]
    y12,y23,y31=y[1]-y[2],y[2]-y[3],y[3]-y[1]
    x21,x32,x13=-x12,-x23,-x31; y21,y32,y13=-y12,-y23,-y31
    A=(y21*x13-x21*y13)/2
    A>0 || error("Nonpositive triangle orientation")
    Am=h*E/(1-nu^2).*[1 nu 0;nu 1 0;0 0 (1-nu)/2]
    mem=[1,2,6,7,8,12,13,14,18]; bend=[3,4,5,9,10,11,15,16,17]
    B=zeros(3,18)
    L=[y23 0 x32; 0 x32 y23;
       y23*(y13-y21)/6 x32*(x31-x12)/6 (x31*y13-x12*y21)/3;
       y31 0 x13; 0 x13 y31;
       y31*(y21-y32)/6 x13*(x12-x23)/6 (x12*y21-x23*y32)/3;
       y12 0 x21; 0 x21 y12;
       y12*(y32-y13)/6 x21*(x23-x31)/6 (x23*y32-x31*y13)/3]
    B[:,mem]=L'/(2A)
    Tqu=[x32 y32 4A x13 y13 0 x21 y21 0;
         x32 y32 0 x13 y13 4A x21 y21 0;
         x32 y32 0 x13 y13 0 x21 y21 4A]/(4A)
    LL21=x21^2+y21^2; LL32=x32^2+y32^2; LL13=x13^2+y13^2
    Te=[y23*y13*LL21 y31*y21*LL32 y12*y32*LL13;
        x23*x13*LL21 x31*x21*LL32 x12*x32*LL13;
        (y23*x31+x32*y13)*LL21 (y31*x12+x13*y21)*LL32 (y12*x23+x21*y32)*LL13]/(4A^2)
    b=[1/12,5/12,1/2,0,1/3,-1/3,-1/12,-1/2,-5/12]
    Q1=vcat(b[[1,2,3]]'/LL21,b[[4,5,6]]'/LL32,b[[7,8,9]]'/LL13)*(2A/3)
    Q2=vcat(b[[9,7,8]]'/LL21,b[[3,1,2]]'/LL32,b[[6,4,5]]'/LL13)*(2A/3)
    Q3=vcat(b[[5,6,4]]'/LL21,b[[8,9,7]]'/LL32,b[[2,3,1]]'/LL13)*(2A/3)
    Enat=Te'*Am*Te
    Kq=sum(Q'*Enat*Q for Q in ((Q1+Q2)/2,(Q2+Q3)/2,(Q3+Q1)/2))*(A/3)
    K=A.*(B'*Am*B)
    K[mem,mem] .+= Tqu'*Kq*Tqu
    K[bend,bend] .+= allman_bending(localnodes,E,h,nu,A)
    md,bd=allman_mass(localnodes,rho,h,A)
    M=zeros(18,18); M[mem,mem]=Diagonal(md); M[bend,bend]=Diagonal(bd)
    # Preserve the source's in-plane terms in the nonlinear shear strain too.
    G=zeros(6,18)
    for d in 1:3
        G[2d-1,[d,d+6,d+12]]=[y23,y31,y12]/(2A)
        G[2d,[d,d+6,d+12]]=[x32,x13,x21]/(2A)
    end
    return T'*M*T, T'*K*T, B*T, G*T, A.*Am
end
