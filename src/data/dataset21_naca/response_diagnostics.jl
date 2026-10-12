# SPDX-License-Identifier: GPL-3.0-only
# Modal quantities are diagnostics of complete physical-state trajectories.
# They are never integration coordinates or learner labels.

function mechanical_features(path,m;mode_indices=collect(1:4))
    nm=length(mode_indices);projection=transpose(m.modes[:,mode_indices])*m.M
    omega=m.omega[mode_indices]
    physical_scale=[amplitude(m,m.modes[:,j]) for j in mode_indices]
    return HDF5.h5open(path,"r") do file
        times=read(file["t"]);frames=length(times);n=length(m.active)
        modal_q=zeros(nm,frames);modal_v=zeros(nm,frames);modal_energy=zeros(nm+1,frames)
        for first in 1:16:frames
            cols=first:min(first+15,frames);states=file["x"][:,cols]
            q=view(states,1:n,:);v=view(states,n+1:2n,:)
            modal_q[:,cols]=projection*q;modal_v[:,cols]=projection*v
            @views modal_energy[1:nm,cols].=(modal_v[:,cols].^2+
                omega.^2 .* modal_q[:,cols].^2)./2
            total=vec(sum(q.*(m.K*q)+v.*(m.M*v);dims=1))./2
            remainder=total.-vec(sum(modal_energy[1:nm,cols];dims=1))
            minimum(remainder)>=-1e-7*max(maximum(total),eps()) || error("Negative unresolved modal energy")
            modal_energy[end,cols]=max.(remainder,0.)
        end
        envelopes=physical_scale.*sqrt.(modal_q.^2+(modal_v./omega).^2)
        energy=read(file["energy"])
        return (;times,modal_q,modal_v,modal_energy,envelopes,energy,omega)
    end
end

function centered_average(values,width)
    half=max(0,width÷2);prefix=hcat(zeros(size(values,1)),cumsum(values;dims=2))
    result=similar(values)
    for k in axes(values,2)
        first=max(1,k-half);last=min(size(values,2),k+half)
        @views result[:,k].=(prefix[:,last+1]-prefix[:,first])./(last-first+1)
    end
    return result
end

function phase_and_rate(q,v,omega,times)
    phase=atan.(-v./omega,q)
    for k in 2:length(phase)
        delta=mod(phase[k]-phase[k-1]+pi,2pi)-pi
        phase[k]=phase[k-1]+delta
    end
    radius=sqrt.(q.^2+(v./omega).^2)
    mask=radius.>=0.1maximum(radius)
    weights=radius[mask].^2
    sum(weights)>eps(Float64)^2 || return phase,NaN,mask
    t=times[mask];p=phase[mask]
    tmean=dot(weights,t)/sum(weights);pmean=dot(weights,p)/sum(weights)
    rate=dot(weights.*(t.-tmean),p.-pmean)/dot(weights,(t.-tmean).^2)
    return phase,rate,mask
end

function nonlinear_energy_features(nonlinear,linear,width)
    return centered_average((nonlinear.modal_energy-linear.modal_energy)./nonlinear.energy[1],width)
end

function response_convergence(coarse,coarse_linear,fine,fine_linear,m,fm,cfg)
    coarse.times==fine.times || error("Response diagnostic time grids differ")
    envelope_difference=coarse.envelopes-fine.envelopes
    envelope_error=maximum(norm(view(envelope_difference,:,k)) for k in eachindex(coarse.times))/
        max(maximum(norm(view(fine.envelopes,:,k)) for k in eachindex(fine.times)),eps())
    energy_error=maximum(abs,coarse.energy/coarse.energy[1]-fine.energy/fine.energy[1])
    # One period of the highest initialized linear mode removes carrier-scale
    # energy oscillations; use the SAME declared physical window on both grids.
    width=max(1,round(Int,2pi/(maximum(m.omega[1:4])*cfg["sampling"]["dt_seconds"])))
    feature_c=nonlinear_energy_features(coarse,coarse_linear,width)
    feature_f=nonlinear_energy_features(fine,fine_linear,width)
    feature_difference=feature_c-feature_f
    feature_error=maximum(norm(view(feature_difference,:,k)) for k in axes(feature_c,2))
    signal=maximum(norm(view(feature_c,:,k)) for k in axes(feature_c,2))
    phase_rows=Any[];phase_passed=true
    for j in 1:4
        active=max(maximum(coarse_linear.envelopes[j,:]),maximum(fine_linear.envelopes[j,:]))>
            0.01max(maximum(coarse_linear.envelopes),maximum(fine_linear.envelopes))
        active || continue
        pc,wc,mc=phase_and_rate(coarse.modal_q[j,:],coarse.modal_v[j,:],coarse.omega[j],coarse.times)
        pf,wf,mf=phase_and_rate(fine.modal_q[j,:],fine.modal_v[j,:],fine.omega[j],fine.times)
        relative=abs(wc/wf-1);mask=mc .& mf
        drift=maximum(abs,(pc.-pc[1]-pf.+pf[1])[mask])
        phase_passed &= isfinite(relative) && relative<=cfg["qualification"]["phase_rate_relative"]
        push!(phase_rows,Dict("mode"=>j,"coarse_rate_rad_s"=>wc,"fine_rate_rad_s"=>wf,
            "rate_relative"=>relative,"maximum_active_cumulative_phase_difference_rad"=>drift))
    end
    passed=envelope_error<=cfg["qualification"]["envelope_relative"] &&
        energy_error<=cfg["qualification"]["spatial_energy_absolute"] && phase_passed
    return Dict("passed"=>passed,"envelope_relative"=>envelope_error,
        "normalized_energy_absolute"=>energy_error,"phase"=>phase_rows,
        "nonlinear_energy_feature_error"=>feature_error,"nonlinear_energy_signal"=>signal,
        "energy_average_frames"=>2(width÷2)+1,
        "criterion_scope"=>"Frequency, phase rate, q-v phase-plane envelopes, energy decay and nonlinear modal-energy transfer of the fixed coarse FE model. Raw same-clock state and cumulative phase errors remain reported; no fine-grid pointwise-equivalence claim.")
end
