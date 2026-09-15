using Test, LinearAlgebra, JSON
const SOV2=StandardODEsV2
@testset "Standard ODE v2 mathematical and data contracts" begin
    cfg=JSON.parsefile(joinpath(SOV2.ROOT,"configs","releases","standard_odes_v2.json"))
    groups=SOV2.group_specs(cfg,:formal)
    @test length(groups)==119
    @test length(unique(s["resource_id"] for s in groups))==23
    @test length(filter(s->s["profile"]=="CAN",groups))==11
    @test isapprox(SOV2.MODES'*SOV2.MODES,I;atol=2e-14)
    @test sum(s["R"] for s in groups)==34432
    for s in cfg["CAN"]
        x,_=SOV2.initial_state(s,123456); m=SOV2.model(s); du=similar(x)
        SOV2.rhs!(du,x,m,0.0)
        @test all(isfinite,du)
        if s["family"] in ("oscillator","duffing","pendulum","vanderpol","axas_haller","fput")
            h=1e-6
            # Directional finite difference independently checks force/energy signs.
            derivative=(SOV2.energy(x+h*du,m)-SOV2.energy(x-h*du,m))/(2h)
            @test isapprox(derivative,SOV2.energy_rate(x,m);atol=1e-6,rtol=1e-6)
        end
        A,integral=SOV2.integrate(s,x;M=9,burn=0)
        @test A[:,1]≈x
        @test SOV2.diagnostics(s,A,integral)["energy_residual"]<1e-8
        if s["family"] in ("linear_diagonal","rotation","oscillator")
            n=s["d"]; F=zeros(n,n)
            for j in 1:n
                ej=zeros(n); ej[j]=1
                SOV2.rhs!(view(F,:,j),ej,m,0.0)
            end
            @test A[:,end]≈exp(F*(8s["tau"]))*x atol=1e-13
        end
    end
    for s in groups
        roles,seed=SOV2.split_roles(s,cfg)
        @test [count(==(r),roles) for r in ("train","val","test")]==s["counts"]
    end
    duffing=filter(s->s["id"]=="duffing_cond_beta" && s["split"]=="Split-C",groups)
    @test [s["parameters"]["beta"] for s in duffing if s["counts"][1]>0]==[5,10,15,20,25]
    pend=filter(s->s["id"]=="pendulum_cond_w0",groups)
    for seed in 1:100
        x,_=SOV2.initial_state(pend[1],seed)
        @test all(SOV2.initial_state(s,seed)[1]==x for s in pend)
        @test all(SOV2.energy(x,SOV2.model(s))/(2s["parameters"]["omega0"]^2)<0.95 for s in pend)
    end
    fput=only(filter(s->s["id"]=="fput_beta_32dof",groups))
    x,_=SOV2.initial_state(fput,7531); m=SOV2.model(fput)
    A,_=SOV2.symplectic_trajectory(m,x,0.05,2,8)
    reversed=vcat(A[1:32,end],-A[33:64,end])
    B,_=SOV2.symplectic_trajectory(m,reversed,0.05,2,8)
    @test B[:,end]≈vcat(x[1:32],-x[33:64]) atol=2e-14
    sentinel=reshape(Float32.(1:120),3,10,4)
    @test permutedims(permutedims(sentinel,(3,2,1)),(3,2,1))==sentinel
end
