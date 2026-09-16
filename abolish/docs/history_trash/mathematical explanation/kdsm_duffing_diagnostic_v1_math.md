# KDSM 诊断激发平台：Duffing 振子测试数据生成数学说明

## 0. 项目定位

本数据集项目记为：

**`kdsm_duffing_diagnostic_v1`**

其目标是生成一组围绕 Duffing 振子的受控 ODE 数据对象，用于下游 KDSM，即 Koopman Diagonal Spectrum Module，执行诊断激发实验。

本数据集项目不负责训练 KDSM，也不负责判断某个干预是否有效。它只负责生成如下对象：

$$

\mathfrak T_q^{\mathrm{Duff}}
\longmapsto
(
\mathcal X_{\mathrm{aug}},
\mathcal X_{\mathrm{phys}},
\mathcal U_{\mathrm{forc}},
\mathcal A_{\mathrm{forc}},
\mathcal Z,
\mathcal Y,
\mathbf t,
\mathrm{metadata}
).

$$

其中，$\mathfrak T_q^{\mathrm{Duff}}$ 是 KDSM 下游任务尺度对象。KDSM 项目侧已经把任务尺度统一写为  
$$

\mathfrak T_q=(\mathcal S_q,d_q,M_q,\mathbf y_q,H_q,\sigma_q),

$$
并要求后续实验从任务尺度映射到诊断向量、诊断模式和干预规则。

本数据集的作用是为这条链条提供可控输入：

$$

\boxed{
\text{Duffing 参数族}
\longmapsto
\text{可控轨线张量}
\longmapsto
\text{KDSM 诊断激发对象}.
}

$$

模块化 HSKL 的数值实验原则是：人工系统用于校准诊断—干预规则，真实系统用于寻找可诊断尺度边界；第一阶段应构造能够稳定激发某类诊断模式的数据。fileciteturn10file2 本数据集正是这一原则在 KDSM-Duffing 场景下的实现。

---

# 1. 基本动力系统

## 1.1 物理 Duffing 状态

物理状态记为

$$

\mathbf x_{\mathrm{phys}}
=
\begin{bmatrix}
q\\
p
\end{bmatrix}
\in \mathcal X_{\mathrm{phys}}\subseteq\mathbb R^2,

$$

其中 $q$ 是位移，$p=\dot q$ 是速度。

基础 Duffing 方程写为

$$

\dot q=p,

$$

$$

\dot p
=
-\delta p-\alpha q-\beta q^3+\gamma a(t).

$$

为了使下游 KDSM 能够把受迫系统写成自治系统，本文不直接使用外部时间函数 $a(t)$，而是让强迫项由一个外部自治系统生成。

---

## 1.2 外部自治强迫系统

引入外部强迫状态

$$

\mathbf u\in\mathcal U_{\mathrm{forc}}\subseteq\mathbb R^{d_u},

$$

并令

$$

\dot{\mathbf u}
=
\mathbf h_{\boldsymbol{\nu}}(\mathbf u),
\qquad
a
=
A_{\boldsymbol{\nu}}(\mathbf u).

$$

这里 $\boldsymbol{\nu}$ 是强迫系统参数，$A_{\boldsymbol{\nu}}$ 是从强迫状态到标量强迫信号的读出函数。

于是总自治状态为

$$

\mathbf x
=
\begin{bmatrix}
q\\
p\\
\mathbf u
\end{bmatrix}
\in
\mathcal X
:=
\mathcal X_{\mathrm{phys}}\times\mathcal U_{\mathrm{forc}}.

$$

增广自治 Duffing 系统定义为

$$

\boxed{
\begin{aligned}
\dot q&=p,\\
\dot p&=-\delta p-\alpha q-\beta q^3+\gamma A_{\boldsymbol{\nu}}(\mathbf u),\\
\dot{\mathbf u}&=\mathbf h_{\boldsymbol{\nu}}(\mathbf u).
\end{aligned}
}

$$

记参数组为

$$

\boldsymbol{\mu}
:=
(\alpha,\beta,\delta,\gamma,\boldsymbol{\nu}).

$$

因此总向量场写为

$$

\dot{\mathbf x}
=
\mathbf f_{\mathrm{Duff}}(\mathbf x;\boldsymbol{\mu}).

$$

这与项目记号中 ODE 系统 $\dot{\mathbf x}=\mathbf f(\mathbf x)$、流映射 $\mathbf F^\tau$ 和采样轨线 $\mathbf x_{m+1}=\mathbf F^\tau(\mathbf x_m)$ 的约定一致。fileciteturn10file0

---

# 2. 外部强迫生成器固定名称

本数据集固定四类强迫生成器。

## 2.1 `force_none`

无强迫：

$$

d_u=0,
\qquad
A_{\boldsymbol{\nu}}(\mathbf u)\equiv 0.

$$

此时系统退化为自治无强迫 Duffing：

$$

\dot q=p,
\qquad
\dot p=-\delta p-\alpha q-\beta q^3.

$$

---

## 2.2 `force_harmonic_1`

单频自治谐振子强迫：

$$

\mathbf u=
\begin{bmatrix}
c\\
s
\end{bmatrix}
\in\mathbb R^2,

$$

$$

\dot c=-\omega s,
\qquad
\dot s=\omega c,

$$

$$

A_{\boldsymbol{\nu}}(\mathbf u)=c.

$$

若初值满足 $c(0)^2+s(0)^2=1$，则

$$

c(t)=\cos(\omega t+\phi_0),
\qquad
s(t)=\sin(\omega t+\phi_0).

$$

因此原本的 $\gamma\cos(\omega t+\phi_0)$ 被写成自治增广系统的读出。

---

## 2.3 `force_harmonic_2`

双频自治强迫：

$$

\mathbf u=
(c_1,s_1,c_2,s_2)^\top\in\mathbb R^4,

$$

$$

\dot c_1=-\omega_1 s_1,
\qquad
\dot s_1=\omega_1 c_1,

$$

$$

\dot c_2=-\omega_2 s_2,
\qquad
\dot s_2=\omega_2 c_2,

$$

$$

A_{\boldsymbol{\nu}}(\mathbf u)
=
c_1+\eta c_2.

$$

其中

$$

\boldsymbol{\nu}
=
(\omega_1,\omega_2,\eta).

$$

当 $\omega_1/\omega_2$ 非有理或近似非有理时，该强迫可用于生成准周期或多频任务。

---

## 2.4 `force_lorenz_readout`

可选混沌外部强迫，用于更强 stress-test：

$$

\mathbf u=(u_1,u_2,u_3)^\top,

$$

$$

\dot u_1=\sigma_{\mathrm L}(u_2-u_1),

$$

$$

\dot u_2=u_1(\rho_{\mathrm L}-u_3)-u_2,

$$

$$

\dot u_3=u_1u_2-b_{\mathrm L}u_3,

$$

并取有界读出

$$

A_{\boldsymbol{\nu}}(\mathbf u)
=
\tanh\left(\frac{u_1}{s_{\mathrm L}}\right).

$$

这一项不是第一批必须项。第一批 KDSM-Duffing 诊断平台建议优先使用 `force_none`、`force_harmonic_1` 和 `force_harmonic_2`。

---

# 3. 采样流与数据张量

给定积分时间步长 $\Delta t_{\mathrm{int}}$、采样间隔 $\tau$、采样点数 $M+1$、轨线数 $R$。对第 $r$ 条轨线，设初值为

$$

\mathbf x_0^{(r)}
=
(q_0^{(r)},p_0^{(r)},\mathbf u_0^{(r)}).

$$

令

$$

t_m=t_0+m\tau,
\qquad
m=0,\dots,M.

$$

由自治流映射得到

$$

\mathbf x_m^{(r)}
=
\mathbf F_{\mathrm{Duff}}^{m\tau}(\mathbf x_0^{(r)};\boldsymbol{\mu}).

$$

数据集保存增广状态张量：

$$

\boxed{
\mathcal X_{\mathrm{aug}}
\in
\mathbb R^{d_x\times(M+1)\times R},
\qquad
\mathcal X_{\mathrm{aug}}[:,m,r]
=
\mathbf x_m^{(r)}.
}

$$

其中

$$

d_x=2+d_u.

$$

物理状态张量为

$$

\boxed{
\mathcal X_{\mathrm{phys}}
\in
\mathbb R^{2\times(M+1)\times R},
\qquad
\mathcal X_{\mathrm{phys}}[:,m,r]
=
(q_m^{(r)},p_m^{(r)})^\top.
}

$$

强迫状态张量为

$$

\boxed{
\mathcal U_{\mathrm{forc}}
\in
\mathbb R^{d_u\times(M+1)\times R}.
}

$$

强迫信号张量为

$$

\boxed{
\mathcal A_{\mathrm{forc}}
\in
\mathbb R^{1\times(M+1)\times R},
\qquad
\mathcal A_{\mathrm{forc}}[1,m,r]
=
A_{\boldsymbol{\nu}}(\mathbf u_m^{(r)}).
}

$$

时间网格保存为

$$

\boxed{
\mathbf t=(t_0,t_1,\dots,t_M)^\top\in\mathbb R^{M+1}.
}

$$

---

# 4. 观测对象与目标对象

KDSM 下游访问的是观测链后的 $\mathbf z_m$，而不是必须直接访问物理状态。项目记号中也区分了物理状态、观测链、量化快照 $\mathbf z_m$ 和数据矩阵。fileciteturn10file0

本数据集固定以下观测与目标对象名称。

## 4.1 `obs_aug_full`

增广自治观测：

$$

\boxed{
\mathbf z_m^{\mathrm{aug}}
=
\mathbf O_{\mathrm{aug}}(\mathbf x_m)
=
(q_m,p_m,\mathbf u_m)^\top.
}

$$

对应张量名：

$$

\boxed{
\mathcal Z_{\mathrm{aug}}
\in
\mathbb R^{d_x\times(M+1)\times R}.
}

$$

这是 KDSM 的默认输入模式，因为它把外部强迫相位或强迫状态显式纳入自治状态。

---

## 4.2 `obs_phys_only`

物理观测：

$$

\boxed{
\mathbf z_m^{\mathrm{phys}}
=
\mathbf O_{\mathrm{phys}}(\mathbf x_m)
=
(q_m,p_m)^\top.
}

$$

对应张量名：

$$

\boxed{
\mathcal Z_{\mathrm{phys}}
\in
\mathbb R^{2\times(M+1)\times R}.
}

$$

这个对象主要作为负控制：在受迫系统中，如果只给 $(q,p)$ 而不给 $\mathbf u$，下游 KDSM 看到的是非自治投影，诊断结果不应与 `obs_aug_full` 混淆。

---

## 4.3 `target_phys`

物理目标观测：

$$

\boxed{
\mathbf y_{\mathrm{phys}}(\mathbf x)
=
(q,p)^\top.
}

$$

对应张量名：

$$

\boxed{
\mathcal Y_{\mathrm{phys}}
\in
\mathbb R^{2\times(M+1)\times R}.
}

$$

---

## 4.4 `target_aug_full`

增广目标观测：

$$

\boxed{
\mathbf y_{\mathrm{aug}}(\mathbf x)
=
(q,p,\mathbf u)^\top.
}

$$

对应张量名：

$$

\boxed{
\mathcal Y_{\mathrm{aug}}
\in
\mathbb R^{d_x\times(M+1)\times R}.
}

$$

该目标用于检查 KDSM 是否不仅能重构物理 Duffing 状态，也能承载外部自治强迫相位。

---

## 4.5 `target_poly9`

高维多项式目标观测：

$$

\boxed{
\mathbf y_{\mathrm{poly9}}(q,p)
=
(q,\ p,\ q^2,\ qp,\ p^2,\ q^3,\ q^2p,\ qp^2,\ p^3)^\top.
}

$$

对应张量名：

$$

\boxed{
\mathcal Y_{\mathrm{poly9}}
\in
\mathbb R^{9\times(M+1)\times R}.
}

$$

这个对象专门用于激发 KDSM 的 rank / reconstruction capacity 诊断。若下游 KDSM 使用 $N=4$，则实扩展特征矩阵 $\mathbf R_X\in\mathbb R^{2N\times M}$ 最多只有 $8$ 行，面对 $d_y=9$ 的目标时会出现硬容量压力。KDSM Phase 0 协议已经把实扩展矩阵 $\mathbf R_X=[\operatorname{Re}\mathbf\Phi_X;\operatorname{Im}\mathbf\Phi_X]$、点态读出与 rank 诊断固定为标准对象。fileciteturn10file1

---

## 4.6 `target_energy5`

能量与势能目标观测：

$$

\boxed{
\mathbf y_{\mathrm{energy5}}(q,p)
=
\left(
q,\ p,\ 
\frac12p^2,\ 
\frac{\alpha}{2}q^2+\frac{\beta}{4}q^4,\ 
\frac12p^2+\frac{\alpha}{2}q^2+\frac{\beta}{4}q^4
\right)^\top.
}

$$

对应张量名：

$$

\boxed{
\mathcal Y_{\mathrm{energy5}}
\in
\mathbb R^{5\times(M+1)\times R}.
}

$$

这个对象用于区分“状态重构可行”与“物理派生量表达可行”。

---

# 5. 噪声协议

噪声只加在观测张量和目标张量的指定版本上，不改变 ground-truth 轨线张量。

给定无噪声观测 $\mathbf z_m$，定义噪声观测

$$

\mathbf z_{m,\sigma}
=
\mathbf z_m
+
\sigma\,\mathbf D_z\,\boldsymbol{\epsilon}_m,
\qquad
\boldsymbol{\epsilon}_m\sim \mathcal N(\mathbf 0,\mathbf I).

$$

其中 $\mathbf D_z$ 是逐坐标尺度矩阵，例如取每个通道训练集标准差。噪声级别固定为

$$

\sigma\in
\{0,\ 10^{-4},\ 10^{-3},\ 10^{-2},\ 10^{-1}\}.

$$

固定名称：

$$

\texttt{noise\_clean}:\sigma=0,

$$

$$

\texttt{noise\_1em4}:\sigma=10^{-4},

$$

$$

\texttt{noise\_1em3}:\sigma=10^{-3},

$$

$$

\texttt{noise\_1em2}:\sigma=10^{-2},

$$

$$

\texttt{noise\_1em1}:\sigma=10^{-1}.

$$

---

# 6. Split 协议

所有对象采用 trajectory-level split before windowing。也就是说，先给每条完整轨线分配角色，再由下游 KDSM 构造 one-step pairs 和 rollout windows。

固定 split 名称：

$$

\boxed{
\texttt{split\_trajectory\_I}.
}

$$

固定角色张量：

$$

\boxed{
\mathrm{split\_roles}
\in
\{\mathrm{train},\mathrm{val},\mathrm{test}\}^{R}.
}

$$

这与 KDSM Phase 0 报告中的协议一致：trajectory-level splitting 先于 windowing，以避免通过跨轨线窗口产生 train/test leakage。fileciteturn9file10

---

# 7. Duffing 子任务对象

本数据集固定 10 个主任务对象，名称为 `D0` 到 `D9`。

每个对象都对应一个 ODEs_dataset object id：

$$

\boxed{
\texttt{kdsm\_duffing\_\_Dk\_<slug>}.
}

$$

其中 `Dk` 是子任务编号，`<slug>` 是诊断目的。

---

## D0：近线性阻尼健康区

### 固定名称

$$

\boxed{
\texttt{kdsm\_duffing\_\_D0\_near\_linear\_damped}.
}

$$

### 强迫类型

$$

\texttt{force\_none}.

$$

### 参数

$$

\alpha=1,
\qquad
\beta=0.02,
\qquad
\delta=0.08,
\qquad
\gamma=0.

$$

### 方程

$$

\dot q=p,

$$

$$

\dot p=-0.08p-q-0.02q^3.

$$

### 初值区域

$$

(q_0,p_0)\in[-0.5,0.5]\times[-0.5,0.5].

$$

### 默认观测与目标

$$

\texttt{obs\_phys\_only},
\qquad
\texttt{target\_phys}.

$$

### 诊断目的

该对象用于生成 KDSM 健康区基准。预期下游应看到低 Koopman 推进误差、低点态重构误差和合理相位结构。

---

## D1：单井 hardening 非线性

### 固定名称

$$

\boxed{
\texttt{kdsm\_duffing\_\_D1\_single\_well\_hardening}.
}

$$

### 强迫类型

$$

\texttt{force\_none}.

$$

### 参数

$$

\alpha=1,
\qquad
\beta=1,
\qquad
\delta=0.05,
\qquad
\gamma=0.

$$

### 方程

$$

\dot q=p,

$$

$$

\dot p=-0.05p-q-q^3.

$$

### 初值区域

$$

(q_0,p_0)\in[-1.5,1.5]\times[-1.0,1.0].

$$

### 默认观测与目标

$$

\texttt{obs\_phys\_only},
\qquad
\texttt{target\_phys}.

$$

### 诊断目的

该对象用于激发有限维对角谱核心的 Koopman 推进压力。随着振幅增大，频率随能量漂移，单一小维度对角谱核心更容易出现

$$

\varepsilon_{\mathrm K}\uparrow,
\qquad
\varepsilon_{\mathrm{rec}}^{\mathrm{pt}}\downarrow
\quad\text{或中等}.

$$

这对应 KDSM 的推进瓶颈模式。

---

## D2：幅值依赖频率漂移

### 固定名称

$$

\boxed{
\texttt{kdsm\_duffing\_\_D2\_amplitude\_frequency\_drift}.
}

$$

### 强迫类型

$$

\texttt{force\_none}.

$$

### 参数

$$

\alpha=1,
\qquad
\beta=1,
\qquad
\delta=0.01,
\qquad
\gamma=0.

$$

### 方程

$$

\dot q=p,

$$

$$

\dot p=-0.01p-q-q^3.

$$

### 初值区域

使用双壳层初值：

$$

\mathcal I_{\mathrm{low}}
=
[-0.4,0.4]\times[-0.4,0.4],

$$

$$

\mathcal I_{\mathrm{high}}
=
\left([-2.0,-1.2]\cup[1.2,2.0]\right)\times[-0.5,0.5].

$$

数据中保存 trajectory metadata：

$$

\mathrm{amplitude\_shell}
\in
\{\mathrm{low},\mathrm{high}\}.

$$

### 默认观测与目标

$$

\texttt{obs\_phys\_only},
\qquad
\texttt{target\_phys}.

$$

### 诊断目的

该对象用于测试同一 KDSM 配置能否同时处理低幅与高幅 Duffing 振荡。它主要激发相位漂移、谱分离和 decoded rollout 诊断。

---

## D3：双井局部采样

### 固定名称

主对象：

$$

\boxed{
\texttt{kdsm\_duffing\_\_D3\_double\_well\_local\_mixed}.
}

$$

同时建议保存两个子对象：

$$

\boxed{
\texttt{kdsm\_duffing\_\_D3a\_double\_well\_local\_left},
}

$$

$$

\boxed{
\texttt{kdsm\_duffing\_\_D3b\_double\_well\_local\_right}.
}

$$

### 强迫类型

$$

\texttt{force\_none}.

$$

### 参数

$$

\alpha=-1,
\qquad
\beta=1,
\qquad
\delta=0.05,
\qquad
\gamma=0.

$$

### 方程

$$

\dot q=p,

$$

$$

\dot p=-0.05p+q-q^3.

$$

势能为

$$

V(q)
=
-\frac12q^2+\frac14q^4.

$$

稳定井位在

$$

q_\star=\pm1.

$$

### 初值区域

左井：

$$

\mathcal I_{\mathrm{left}}
=
[-1.2,-0.8]\times[-0.2,0.2].

$$

右井：

$$

\mathcal I_{\mathrm{right}}
=
[0.8,1.2]\times[-0.2,0.2].

$$

混合对象使用

$$

\mathcal I_{\mathrm{mixed}}
=
\mathcal I_{\mathrm{left}}\cup\mathcal I_{\mathrm{right}}.

$$

### 默认观测与目标

$$

\texttt{obs\_phys\_only},
\qquad
\texttt{target\_phys}.

$$

### 诊断目的

该对象用于激发局部谱差异、Gram 几何和通道退化诊断。若左右井单独可学，但混合对象出现

$$

\lambda_{\min}(\mathbf G)\downarrow,
\qquad
\operatorname{cond}(\mathbf G)\uparrow,
\qquad
D_{\mathrm{spec}}\uparrow,

$$

则说明 KDSM 的谱核心通道几何或输出头协议需要干预。

---

## D4：双井跨井跃迁

### 固定名称

$$

\boxed{
\texttt{kdsm\_duffing\_\_D4\_double\_well\_cross\_well}.
}

$$

### 强迫类型

$$

\texttt{force\_harmonic\_1}.

$$

### 参数

Duffing 参数：

$$

\alpha=-1,
\qquad
\beta=1,
\qquad
\delta=0.02,
\qquad
\gamma=0.20.

$$

强迫参数：

$$

\omega=1.0.

$$

### 增广方程

$$

\dot q=p,

$$

$$

\dot p=-0.02p+q-q^3+0.20c,

$$

$$

\dot c=-\omega s,
\qquad
\dot s=\omega c,
\qquad
\omega=1.0.

$$

### 初值区域

$$

(q_0,p_0)\in[-0.5,0.5]\times[0.8,1.6],

$$

$$

(c_0,s_0)=(\cos\phi_0,\sin\phi_0),
\qquad
\phi_0\sim\mathrm{Unif}(0,2\pi).

$$

### 默认观测与目标

默认输入：

$$

\texttt{obs\_aug\_full}.

$$

默认目标：

$$

\texttt{target\_phys}.

$$

负控制输入：

$$

\texttt{obs\_phys\_only}.

$$

### 诊断目的

该对象用于激发跨井非局部动力学和对角谱结构边界。若 `obs_aug_full` 明显优于 `obs_phys_only`，说明自治增广是必要的；若 `obs_aug_full` 仍无法压低推进残差，则说明当前小维度对角谱核心可能接近结构边界。

---

## D5：周期受迫稳定响应

### 固定名称

$$

\boxed{
\texttt{kdsm\_duffing\_\_D5\_periodic\_forced\_stable}.
}

$$

### 强迫类型

$$

\texttt{force\_harmonic\_1}.

$$

### 参数

Duffing 参数：

$$

\alpha=1,
\qquad
\beta=1,
\qquad
\delta=0.20,
\qquad
\gamma=0.30.

$$

强迫参数：

$$

\omega=1.0.

$$

### 增广方程

$$

\dot q=p,

$$

$$

\dot p=-0.20p-q-q^3+0.30c,

$$

$$

\dot c=-s,
\qquad
\dot s=c.

$$

### 初值区域

$$

(q_0,p_0)\in[-1,1]\times[-1,1],

$$

$$

(c_0,s_0)=(\cos\phi_0,\sin\phi_0),
\qquad
\phi_0\sim\mathrm{Unif}(0,2\pi).

$$

### 默认观测与目标

$$

\texttt{obs\_aug\_full},
\qquad
\texttt{target\_phys}.

$$

同时保存负控制：

$$

\texttt{obs\_phys\_only},
\qquad
\texttt{target\_phys}.

$$

### 诊断目的

该对象是相位诊断主对象。KDSM 若使用 learned diagonal spectrum，应能在增广自治状态中识别旋转相位。若出现

$$

D_{\mathrm{phase}}\uparrow,
\qquad
\operatorname{Im}\lambda_j\approx0,

$$

则说明下游应测试共轭对谱头、Fourier / Laplace 输出头或相位范围参数化。KDSM Phase 0 协议已经把相位诊断、谱诊断、rollout 诊断和 Gram / rank 诊断列入标准诊断对象。fileciteturn10file1

---

## D6：双频受迫响应

### 固定名称

$$

\boxed{
\texttt{kdsm\_duffing\_\_D6\_two\_frequency\_forced}.
}

$$

### 强迫类型

$$

\texttt{force\_harmonic\_2}.

$$

### 参数

Duffing 参数：

$$

\alpha=1,
\qquad
\beta=1,
\qquad
\delta=0.10,
\qquad
\gamma=0.30.

$$

强迫参数：

$$

\omega_1=1.0,
\qquad
\omega_2=1.618,
\qquad
\eta=0.5.

$$

### 增广方程

$$

\dot q=p,

$$

$$

\dot p=-0.10p-q-q^3+0.30(c_1+0.5c_2),

$$

$$

\dot c_1=-\omega_1s_1,
\qquad
\dot s_1=\omega_1c_1,

$$

$$

\dot c_2=-\omega_2s_2,
\qquad
\dot s_2=\omega_2c_2.

$$

### 默认观测与目标

$$

\texttt{obs\_aug\_full},
\qquad
\texttt{target\_phys}.

$$

### 诊断目的

该对象用于激发多频谱分离、相位容量和 Gram 几何诊断。预期下游 KDSM 会比 D5 更容易出现

$$

D_{\mathrm{phase}}\uparrow,
\qquad
D_{\mathrm{spec}}\uparrow,
\qquad
\operatorname{cond}(\mathbf G)\uparrow.

$$

若 $N=4$ 失败但 $N=8$ 改善，则说明主要瓶颈是谱容量；若增大 $N$ 仍失败，则可能接近对角结构边界。

---

## D7：经典混沌 Duffing 区

### 固定名称

$$

\boxed{
\texttt{kdsm\_duffing\_\_D7\_chaotic\_forced}.
}

$$

### 强迫类型

$$

\texttt{force\_harmonic\_1}.

$$

### 参数

Duffing 参数：

$$

\alpha=-1,
\qquad
\beta=1,
\qquad
\delta=0.20,
\qquad
\gamma=0.30.

$$

强迫参数：

$$

\omega=1.20.

$$

### 增广方程

$$

\dot q=p,

$$

$$

\dot p=-0.20p+q-q^3+0.30c,

$$

$$

\dot c=-1.20s,
\qquad
\dot s=1.20c.

$$

### 初值区域

$$

(q_0,p_0)\in[-1.5,1.5]\times[-1.5,1.5],

$$

$$

(c_0,s_0)=(\cos\phi_0,\sin\phi_0),
\qquad
\phi_0\sim\mathrm{Unif}(0,2\pi).

$$

### 默认观测与目标

$$

\texttt{obs\_aug\_full},
\qquad
\texttt{target\_phys}.

$$

### 诊断目的

该对象用于能力边界分类，而不是用于要求长时逐点预测成功。KDSM Phase 0 已明确指出，在混沌系统中，长时 decoded rollout 失相可能是合理现象，不应只用长时 rollout 误差判死刑。fileciteturn9file16

因此 D7 的下游解释应重点比较：

$$

\varepsilon_{\mathrm K},
\qquad
\varepsilon_{\mathrm{rec}}^{\mathrm{pt}},
\qquad
D_{\mathrm{phase}},
\qquad
D_{\mathrm{spec}},
\qquad
\mathcal E_{\mathrm{roll}}^{(h)}
\text{ 的短期与中期趋势}.

$$

---

## D8：高维目标观测容量测试

### 固定名称

$$

\boxed{
\texttt{kdsm\_duffing\_\_D8\_highdim\_target\_poly9}.
}

$$

### 基础动力学

建议复用 D5 的动力学：

$$

\texttt{kdsm\_duffing\_\_D5\_periodic\_forced\_stable}

$$

的轨线生成协议。

### 默认观测与目标

输入：

$$

\texttt{obs\_aug\_full}.

$$

目标：

$$

\texttt{target\_poly9}.

$$

即

$$

\mathbf y_{\mathrm{poly9}}(q,p)
=
(q,\ p,\ q^2,\ qp,\ p^2,\ q^3,\ q^2p,\ qp^2,\ p^3)^\top.

$$

### 诊断目的

该对象专门激发 rank / reconstruction capacity 诊断。若下游 KDSM 使用 $N=4$，则实扩展读出上限为 $2N=8$，而 $d_y=9$，因此该任务应稳定触发 capacity pressure：

$$

\operatorname{rank}(\mathbf R_X)<d_y
\quad
\text{或}
\quad
\varepsilon_{\mathrm{rec},\mathbb R}^{\mathrm{pt}}\uparrow.

$$

这类对象用于验证下游干预是否应优先增大 $N$ 或降低目标观测维度，而不是盲目调整 loss weight。

---

## D9：噪声扫描

### 固定名称

主对象前缀：

$$

\boxed{
\texttt{kdsm\_duffing\_\_D9\_noise\_scan}.
}

$$

具体对象按噪声级别命名：

$$

\texttt{kdsm\_duffing\_\_D9\_noise\_scan\_\_noise\_clean},

$$

$$

\texttt{kdsm\_duffing\_\_D9\_noise\_scan\_\_noise\_1em4},

$$

$$

\texttt{kdsm\_duffing\_\_D9\_noise\_scan\_\_noise\_1em3},

$$

$$

\texttt{kdsm\_duffing\_\_D9\_noise\_scan\_\_noise\_1em2},

$$

$$

\texttt{kdsm\_duffing\_\_D9\_noise\_scan\_\_noise\_1em1}.

$$

### 基础动力学

建议复用 D5 的动力学。

### 噪声协议

$$

\sigma\in
\{0,10^{-4},10^{-3},10^{-2},10^{-1}\}.

$$

### 默认观测与目标

$$

\texttt{obs\_aug\_full},
\qquad
\texttt{target\_phys}.

$$

噪声加在 $\mathcal Z_{\mathrm{aug}}$ 上，ground-truth $\mathcal X_{\mathrm{aug}}$ 与 $\mathcal Y_{\mathrm{phys}}$ 保持无噪声版本，同时可保存 noisy target 版本用于监督噪声测试。

### 诊断目的

该对象用于构造 $\sigma_q$ continuation，检查 KDSM 诊断量随观测噪声变化的稳定性。

---

# 8. 固定数据对象名称总表

| 编号 | object id | 主用途 |
|---|---|---|
| D0 | `kdsm_duffing__D0_near_linear_damped` | 健康区基准 |
| D1 | `kdsm_duffing__D1_single_well_hardening` | Koopman 推进压力 |
| D2 | `kdsm_duffing__D2_amplitude_frequency_drift` | 幅值依赖相位漂移 |
| D3a | `kdsm_duffing__D3a_double_well_local_left` | 左井局部谱 |
| D3b | `kdsm_duffing__D3b_double_well_local_right` | 右井局部谱 |
| D3 | `kdsm_duffing__D3_double_well_local_mixed` | Gram / 局部谱混合 |
| D4 | `kdsm_duffing__D4_double_well_cross_well` | 跨井与对角边界 |
| D5 | `kdsm_duffing__D5_periodic_forced_stable` | 周期相位诊断 |
| D6 | `kdsm_duffing__D6_two_frequency_forced` | 多频谱分离 |
| D7 | `kdsm_duffing__D7_chaotic_forced` | 混沌边界分类 |
| D8 | `kdsm_duffing__D8_highdim_target_poly9` | rank / reconstruction capacity |
| D9 | `kdsm_duffing__D9_noise_scan__noise_<level>` | 噪声鲁棒性 |

---

# 9. 每个数据对象必须保存的字段

每个 processed object 至少保存以下字段。

## 9.1 轨线张量

$$

\boxed{
\texttt{state\_aug}
\leftrightarrow
\mathcal X_{\mathrm{aug}}
}

$$

$$

\boxed{
\texttt{state\_phys}
\leftrightarrow
\mathcal X_{\mathrm{phys}}
}

$$

$$

\boxed{
\texttt{forcing\_state}
\leftrightarrow
\mathcal U_{\mathrm{forc}}
}

$$

$$

\boxed{
\texttt{forcing\_signal}
\leftrightarrow
\mathcal A_{\mathrm{forc}}
}

$$

$$

\boxed{
\texttt{time\_grid}
\leftrightarrow
\mathbf t
}

$$

---

## 9.2 观测张量

$$

\boxed{
\texttt{observation\_aug}
\leftrightarrow
\mathcal Z_{\mathrm{aug}}
}

$$

$$

\boxed{
\texttt{observation\_phys}
\leftrightarrow
\mathcal Z_{\mathrm{phys}}
}

$$

若加入噪声，则额外保存：

$$

\boxed{
\texttt{observation\_aug\_noisy}
\leftrightarrow
\mathcal Z_{\mathrm{aug},\sigma}
}

$$

$$

\boxed{
\texttt{observation\_phys\_noisy}
\leftrightarrow
\mathcal Z_{\mathrm{phys},\sigma}
}

$$

---

## 9.3 目标张量

$$

\boxed{
\texttt{target\_phys}
\leftrightarrow
\mathcal Y_{\mathrm{phys}}
}

$$

$$

\boxed{
\texttt{target\_aug}
\leftrightarrow
\mathcal Y_{\mathrm{aug}}
}

$$

$$

\boxed{
\texttt{target\_poly9}
\leftrightarrow
\mathcal Y_{\mathrm{poly9}}
}

$$

$$

\boxed{
\texttt{target\_energy5}
\leftrightarrow
\mathcal Y_{\mathrm{energy5}}
}

$$

---

## 9.4 Split 与 metadata

$$

\boxed{
\texttt{split\_roles}
\in
\{\mathrm{train},\mathrm{val},\mathrm{test}\}^{R}.
}

$$

每个对象的 metadata 至少包含：

$$

\texttt{release\_id}
=
\texttt{kdsm\_duffing\_diagnostic\_v1},

$$

$$

\texttt{object\_id},
\quad
\texttt{regime\_id},
\quad
\texttt{forcing\_id},
\quad
\texttt{obs\_modes},
\quad
\texttt{target\_modes},

$$

$$

\texttt{duffing\_params}
=
(\alpha,\beta,\delta,\gamma),

$$

$$

\texttt{forcing\_params}
=
\boldsymbol{\nu},

$$

$$

\texttt{tau},
\quad
\texttt{M},
\quad
\texttt{R},
\quad
\texttt{noise\_level},
\quad
\texttt{split\_protocol}.

$$

还应保存目标诊断标签：

$$

\texttt{intended\_diagnostics}
\subset
\{
\texttt{healthy},
\texttt{phase},
\texttt{spec},
\texttt{gram},
\texttt{rank},
\texttt{rec},
\texttt{rollout},
\texttt{diag\_boundary},
\texttt{noise}
\}.

$$

---

# 10. 推荐默认数值规格

第一版数据集建议统一使用：

$$

R=64
\quad
\text{条轨线},

$$

$$

M+1=2049
\quad
\text{个采样点},

$$

$$

\tau=0.05
\quad
\text{或}
\quad
\tau=0.1.

$$

split 使用：

$$

R_{\mathrm{train}}=48,
\qquad
R_{\mathrm{val}}=8,
\qquad
R_{\mathrm{test}}=8.

$$

如果为了快速 CI / protocol check，可以额外生成 bounded 版本：

$$

R=10,
\qquad
M+1=129,
\qquad
R_{\mathrm{train}}/R_{\mathrm{val}}/R_{\mathrm{test}}=6/2/2.

$$

这与之前 KDSM Phase 0.1 的 bounded all-object ODE release 互操作测试风格一致：保留完整诊断链，但降低执行成本。fileciteturn9file18

---

# 11. 下游 KDSM 的推荐读取方式

虽然本说明属于 ODEs_dataset 项目，但为了避免数据语义混乱，应在 metadata 中明确推荐下游读取模式。

## 11.1 默认 KDSM 输入

对于受迫对象 D4–D7，默认推荐：

$$

\mathbf z_m
=
\mathbf z_m^{\mathrm{aug}}
=
(q_m,p_m,\mathbf u_m)^\top.

$$

即使用 `observation_aug`。

这是因为下游 KDSM 当前学习的是自治离散流上的近似 Koopman 特征坐标。若受迫系统不给出 $\mathbf u_m$，则 $(q_m,p_m)$ 侧本身不封闭，容易把非自治投影误判为对角谱失败。

---

## 11.2 默认 KDSM 目标

第一轮推荐：

$$

\mathbf y_m
=
\mathbf y_{\mathrm{phys}}(\mathbf x_m)
=
(q_m,p_m)^\top.

$$

即使用 `target_phys`。

这能先检查谱核心是否承载物理 Duffing 状态。后续再用 `target_aug`、`target_poly9` 和 `target_energy5` 激发 reconstruction / rank / capacity 诊断。

---

## 11.3 负控制

对于 D4–D7，同时提供：

$$

\mathbf z_m=\mathbf z_m^{\mathrm{phys}}=(q_m,p_m)^\top.

$$

该输入对应 `observation_phys`。它是非自治投影负控制，不应与 `observation_aug` 的结果混为一谈。

---

# 12. 总结

这份数据集说明的核心是：

$$

\boxed{
\text{用同一个 Duffing 系统族，通过参数、外部自治强迫、观测目标和噪声扫描，生成 KDSM 诊断激发数据。}
}

$$

其中：

- D0 提供健康区；
- D1–D2 激发 Koopman 推进和相位漂移；
- D3 激发 Gram / 局部谱诊断；
- D4 激发跨井与对角结构边界；
- D5 激发周期相位诊断；
- D6 激发多频谱分离；
- D7 激发混沌边界分类；
- D8 激发 rank / reconstruction capacity；
- D9 激发噪声鲁棒性。

强迫项统一写成外部自治系统读出：

$$

\dot{\mathbf u}=\mathbf h_{\boldsymbol{\nu}}(\mathbf u),
\qquad
a=A_{\boldsymbol{\nu}}(\mathbf u),

$$

并把总系统写成自治增广形式：

$$

\boxed{
\begin{aligned}
\dot q&=p,\\
\dot p&=-\delta p-\alpha q-\beta q^3+\gamma A_{\boldsymbol{\nu}}(\mathbf u),\\
\dot{\mathbf u}&=\mathbf h_{\boldsymbol{\nu}}(\mathbf u).
\end{aligned}
}

$$

这样，ODEs_dataset 生成的数据既保持 Duffing 族的一致可比性，又能为 KDSM 提供自治 Koopman 学习所需的完整状态信息。