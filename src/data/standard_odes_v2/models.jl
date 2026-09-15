const MODES = [sqrt(2/33)*sin(i*j*pi/33) for i in 1:32, j in 1:32]
const FREQUENCIES = [2sin(j*pi/66) for j in 1:32]

struct Model{F,P}
    parameters::P
end
Model(f::String, p) = Model{Symbol(f),typeof(p)}(p)
family(::Model{F}) where F = F
parameters(s) = (; (Symbol(k)=>Float64(v) for (k,v) in s["parameters"])...)
model(s) = Model(s["family"], parameters(s))

function rhs!(du, u, m::Model{:linear_diagonal}, t)
    p=m.parameters
    du[1]=p.a1*u[1]; du[2]=p.a2*u[2]; du[3]=p.a3*u[3]; du[4]=p.a4*u[4]
end
function rhs!(du, u, m::Model{:rotation}, t)
    p=m.parameters
    du[1]=-p.gamma*u[1]-p.omega*u[2]; du[2]=p.omega*u[1]-p.gamma*u[2]
end
function rhs!(du, u, m::Model{:oscillator}, t)
    p=m.parameters
    du[1]=u[2]; du[2]=-2p.gamma*u[2]-p.omega0^2*u[1]
end
function rhs!(du, u, m::Model{:duffing}, t)
    p=m.parameters
    du[1]=u[2]; du[2]=-p.delta*u[2]-p.alpha*u[1]-p.beta*u[1]^3
end
function rhs!(du, u, m::Model{:pendulum}, t)
    du[1]=u[2]; du[2]=-m.parameters.omega0^2*sin(u[1])
end
function rhs!(du, u, m::Model{:vanderpol}, t)
    du[1]=u[2]; du[2]=m.parameters.mu*(1-u[1]^2)*u[2]-u[1]
end
function rhs!(du, u, m::Model{:axas_haller}, t)
    p=m.parameters; q1,q2,v1,v2=u[1],u[2],u[3],u[4]
    z=p.beta3*(q1-q2)^3
    du[1]=v1; du[2]=v2
    du[3]=-p.c*(2v1-v2)-2q1+q2-p.alpha2*q1^2-z
    du[4]=-p.c*(2v2-v1)+q1-2q2+z
end
function rhs!(du, u, m::Model{:lorenz}, t)
    p=m.parameters; x,y,z=u[1],u[2],u[3]
    du[1]=p.sigma*(y-x); du[2]=x*(p.rho-z)-y; du[3]=x*y-p.beta*z
end
function rhs!(du, u, m::Model{:rossler}, t)
    p=m.parameters; x,y,z=u[1],u[2],u[3]
    du[1]=-y-z; du[2]=x+p.a*y; du[3]=p.b+z*(x-p.c)
end
function acceleration!(a, q, beta)
    @inbounds for i in 1:32
        left=q[i]-(i==1 ? 0.0 : q[i-1])
        right=(i==32 ? 0.0 : q[i+1])-q[i]
        a[i]=right-left+beta*(right^3-left^3)
    end
end
function rhs!(du, u, m::Model{:fput}, t)
    @views du[1:32].=u[33:64]
    acceleration!(view(du,33:64),view(u,1:32),m.parameters.beta)
end
energy(u,m::Model)=0.0
energy(u,m::Model{:oscillator})=(u[2]^2+m.parameters.omega0^2*u[1]^2)/2
energy(u,m::Model{:duffing})=u[2]^2/2+m.parameters.alpha*u[1]^2/2+m.parameters.beta*u[1]^4/4
energy(u,m::Model{:pendulum})=u[2]^2/2+m.parameters.omega0^2*(1-cos(u[1]))
energy(u,m::Model{:vanderpol})=(u[1]^2+u[2]^2)/2
function energy(u,m::Model{:axas_haller})
    q1,q2,v1,v2=u[1],u[2],u[3],u[4]
    (v1^2+v2^2)/2+q1^2+q2^2-q1*q2+m.parameters.alpha2*q1^3/3+m.parameters.beta3*(q1-q2)^4/4
end
function energy(u,m::Model{:fput})
    e=sum(abs2,view(u,33:64))/2
    @inbounds for i in 0:32
        z=(i==32 ? 0.0 : u[i+1])-(i==0 ? 0.0 : u[i])
        e+=z*z/2+m.parameters.beta*z^4/4
    end
    e
end
energy_rate(u,m::Model)=0.0
energy_rate(u,m::Model{:oscillator})=-2m.parameters.gamma*u[2]^2
energy_rate(u,m::Model{:duffing})=-m.parameters.delta*u[2]^2
energy_rate(u,m::Model{:vanderpol})=m.parameters.mu*(1-u[1]^2)*u[2]^2
energy_rate(u,m::Model{:axas_haller})=-2m.parameters.c*(u[3]^2+u[4]^2-u[3]*u[4])
function augmented_rhs!(du,u,m,t)
    rhs!(du,u,m,t)
    du[end]=energy_rate(u,m)
end
function annulus(rng,a,b)
    r=sqrt(a*a+rand(rng)*(b*b-a*a)); phi=2pi*rand(rng)
    r.*[cos(phi),sin(phi)]
end
function initial_state(s,seed)
    rng=MersenneTwister(seed); law=s["ic"]; attempts=0
    while true
        attempts+=1
        attempts<=100000 || error("IC rejection limit")
        x = if law=="annulus"
            annulus(rng,s["radii"]...)
        elseif law=="mixed_annuli"
            rand(rng)<0.5 ? annulus(rng,0.5,1.5) : annulus(rng,2.5,3.5)
        elseif law=="uniform_box4"
            2rand(rng,4).-1
        elseif law=="lorenz_box"
            [-12+24rand(rng),-12+24rand(rng),8+24rand(rng)]
        elseif law=="rossler_box"
            [-8+16rand(rng),-8+16rand(rng),0.5+7.5rand(rng)]
        elseif law in ("pendulum_can","pendulum_cond")
            vmax=law=="pendulum_can" ? 2.0 : 1.6
            q=-3.1+6.2rand(rng); v=vmax*(2rand(rng)-1)
            ok=law=="pendulum_can" ? v*v/2-cos(q)<0.99 : v*v/(4*0.8^2)+(1-cos(q))/2<0.95
            ok || continue
            [q,v]
        elseif law=="axas_safe_ball"
            z=randn(rng,4); z .*= 0.5*rand(rng)^(1/4)/norm(z)
            e=energy(z,Model("axas_haller",(c=0.03,alpha2=-2.0,beta3=1.5)))
            1/240<=e<=1/30 || continue
            z
        elseif law=="fput_all_modes"
            a=randn(rng,32); b=randn(rng,32); j=collect(1:32)
            q=a./(j.*FREQUENCIES); v=b./j
            e=exp(log(0.5)+rand(rng)*log(4.0))
            denom=sum(abs2,FREQUENCIES.*q)+sum(abs2,v)
            denom>0 || continue
            sqrt(2e/denom).*vcat(MODES*q,MODES*v)
        else
            error("Unknown IC law $law")
        end
        return x,attempts
    end
end

function ic_description(s)
    law=s["ic"]
    law=="annulus" && return Dict("radii"=>s["radii"],"radial_density"=>"area_uniform")
    law=="mixed_annuli" && return Dict("weights"=>[0.5,0.5],"radii"=>[[0.5,1.5],[2.5,3.5]],"radial_density"=>"area_uniform")
    law=="uniform_box4" && return Dict("lower"=>fill(-1,4),"upper"=>fill(1,4))
    law=="lorenz_box" && return Dict("lower"=>[-12,-12,8],"upper"=>[12,12,32],"density"=>"uniform")
    law=="rossler_box" && return Dict("lower"=>[-8,-8,0.5],"upper"=>[8,8,8],"density"=>"uniform")
    law=="pendulum_can" && return Dict("proposal"=>[[-3.1,3.1],[-2,2]],"acceptance"=>"p^2/2-cos(q)<0.99")
    law=="pendulum_cond" && return Dict("proposal"=>[[-3.1,3.1],[-1.6,1.6]],"omega_min"=>0.8,"acceptance"=>"p^2/(4*0.8^2)+(1-cos(q))/2<0.95")
    law=="axas_safe_ball" && return Dict("uniform_ball_radius"=>0.5,"safety_beta3"=>1.5,"energy_bounds"=>[1/240,1/30],"q_norm_bound"=>0.5)
    Dict("mode_count"=>32,"gaussians"=>"independent_N(0,1)","q_mode_scale"=>"1/(j*omega_j)","p_mode_scale"=>"1/j","linear_energy_log_uniform"=>[0.5,2.0],"beta_rescaling"=>false)
end
