---
title: KSF-D1-低维受控系统数据生成协议
aliases:
  - 低维受控系统 5x3 数据生成协议
  - Controlled Low-Dimensional Systems Data Generation
  - KSF-D1
status: active
type: data-generation-protocol
updated: 2026-07-27
related:
  - KSF-F2-Controlled Koopman Diagonal-Spectrum Structure Learning
  - KSF-F3-Multi-step Predictive Controlled Koopman Diagonal-Spectrum Core Learning
  - KDSM-K2-Koopman Diagonal-Spectrum Structure Learning
  - KDSM-K3-Multi-step Predictive KDSM
  - 4.1 EDMDc，强迫项
---

# KSF-D1：低维受控系统数据生成协议
## 五类动力学底座、三类控制语义与统一噪声注入接口

# 0. 名称、目标与协议边界

本文定义面向 Koopman learning、EDMDc、KDSMc 与未来双线性受控模型的低维受控系统数据生成协议，记为

$$
\boxed{
\mathsf{KSF\text{-}D1}
:=
\text{Controlled Low-Dimensional Systems Data Generation}.
}
$$

中文名称为

$$
\boxed{
\text{低维受控系统数据生成协议}.
}
$$

本文构造五类低维动力学底座：

$$
\boxed{
\begin{aligned}
\mathsf{LIN}&:\quad \text{线性阻尼振子},\\
\mathsf{DUF}&:\quad \text{一般 Duffing 振子},\\
\mathsf{VDP}&:\quad \text{Van der Pol 振子},\\
\mathsf{PEN}&:\quad \text{受控单摆},\\
\mathsf{DUF\text{-}HF}&:\quad \text{高频强硬化 Duffing 振子}.
\end{aligned}
}
$$

每个底座分别构造三类严格区分的数据对象：

$$
\boxed{
\begin{aligned}
\mathsf{AUG}&:\quad \text{外部信号源状态的扩展自治系统},\\
\mathsf{ADD}&:\quad \text{显式加性受控系统},\\
\mathsf{BIL}&:\quad \text{显式双线性受控系统}.
\end{aligned}
}
$$

因此，本文共定义

$$
\boxed{
5\times3=15
}
$$

个规范数据对象。

本文的核心目标不是把同一物理轨线同时解释为自治、加性和双线性三种模型，而是建立

$$
\boxed{
\text{一个动力学底座}
\quad\Longrightarrow\quad
\text{三个数学身份互斥的数据分支}.
}
$$

本文同时定义可选噪声注入接口。噪声不构成新的动力学分支，不使用独立的强度等级命名，也不写入数据集代号。对任一数据对象，噪声只作为 clean trajectory 上的附加 observation view：

$$
\boxed{
\mathcal D_{\mathrm{clean}}
\xrightarrow{\ \mathcal N_{\Pi_{\mathrm{noise}}}\ }
\mathcal D_{\mathrm{obs}}.
}
$$

本文不规定：

$$
\boxed{
\text{KDSMc 的网络规模、损失权重、谱参数化、优化器或训练轮数}.
}
$$

本文只规定：

$$
\boxed{
\text{动力学方程、控制语义、信号源、轨线生成、数据字段、噪声接口与划分规则}.
}
$$

---

## 0.1 三类分支不是同层控制律

加性与双线性描述控制输入如何作用于物理状态：

$$
\boxed{
\dot{\mathbf x}
=
\mathbf f_0(\mathbf x)
+
\mathbf b_c c(t)
}
$$

或

$$
\boxed{
\dot{\mathbf x}
=
\mathbf f_0(\mathbf x)
+
c(t)\mathbf N_c\mathbf x.
}
$$

扩展自治描述外部信号源是否被纳入完整状态。设

$$
\dot{\mathbf q}
=
\mathbf S\mathbf q,
\qquad
c(t)
=
C(\mathbf q(t)),
$$

则扩展状态

$$
\mathbf x_{\mathrm{aug}}
:=
\begin{bmatrix}
\mathbf x\\
\mathbf q
\end{bmatrix}
$$

满足自治方程。

理论上，加性控制与双线性控制均可通过增广外部源状态构造成自治系统。为避免在同一 benchmark 分支中再次混合两种控制机制，本文固定：

$$
\boxed{
\mathsf{AUG}
\text{ 分支一律采用加性外部作用的信号源自治增广}.
}
$$

因此三类数据对象的规范含义为：

$$
\boxed{
\begin{aligned}
\mathsf{AUG}:&\quad
\dot{\mathbf x}=\mathbf f_0(\mathbf x)+\mathbf b_c C(\mathbf q),
\quad
\dot{\mathbf q}=\mathbf S\mathbf q;
\\
\mathsf{ADD}:&\quad
\dot{\mathbf x}=\mathbf f_0(\mathbf x)+\mathbf b_c c(t);
\\
\mathsf{BIL}:&\quad
\dot{\mathbf x}=\mathbf f_0(\mathbf x)+c(t)\mathbf N_c\mathbf x
\quad
\text{或其指定的等价状态--控制乘积}.
\end{aligned}
}
$$

---

## 0.2 与模型主线的固定映射

三个分支对应不同的模型能力边界：

| 数据分支 | learner 信息集 | 规范模型 | 是否属于当前 F2/F3 正式能力范围 |
|---|---|---|---|
| `augaut` | 当前增广状态 $[\mathbf z_m;\mathbf q_m]$ | 自治 K2/K3 | 不属于 F2/F3；应使用自治模型 |
| `addc` | 当前物理观测 $\mathbf z_m$ 与已知 forcing feature $\mathbf v_m$ | F2/F3 | 是 |
| `bilinc` | 当前物理观测与状态--控制交互 | 未来双线性 KDSMc/MPc | 否；当前 F2/F3 只能作为结构失配基线 |

因此，15 个数据对象不得被混合成单一平均分数。正式报告至少分为：

$$
\boxed{
\text{自治增广能力}
\quad+
\text{加性受控能力}
\quad+
\text{双线性受控能力}.
}
$$

---

# 1. 统一时间、轨线与数据对象

## 1.1 连续时间、采样时间与底座特定时间包

不同动力学底座可以具有不同的特征时间尺度、最高 forcing 频率与数值刚性。因此，本文不再要求五类底座共享唯一的采样间隔与轨线时长，而是为第 $r$ 个底座定义冻结时间包

$$
\boxed{
\Pi_{\mathrm{time}}^{(r)}
=
\left(
\tau_r,
T_r,
\Delta t_{\max,r},
\Pi_{\mathrm{endpoint}}^{(r)},
\Pi_{\mathrm{resample}}^{(r)},
\Pi_{\mathrm{solver}}^{(r)}
\right).
}
$$

其中

$$
\tau_r>0
$$

是 learner 模型网格的采样间隔，

$$
T_r>0
$$

是单条轨线的物理积分时长，

$$
\Delta t_{\max,r}>0
$$

是连续时间求解器的内部最大步长。

定义第 $r$ 个底座的模型采样时刻

$$
\boxed{
t_m^{(r)}:=m\tau_r,
\qquad
m=0,\ldots,M_{\mathrm{state}}^{(r)}-1.
}
$$

允许两种冻结端点策略。

### 闭区间端点策略

若

```text
endpoint_policy = "closed"
```

则保存 $t=T_r$ 端点，并取

$$
M_{\mathrm{state}}^{(r)}
=
1+\frac{T_r}{\tau_r}.
$$

### 半开区间端点策略

若

```text
endpoint_policy = "half_open"
```

则保存时间区间 $[0,T_r)$，不重复保存 $t=T_r$ 端点，并取

$$
M_{\mathrm{state}}^{(r)}
=
\frac{T_r}{\tau_r}.
$$

无论采用哪一种端点策略，一步转移数量均为

$$
\boxed{
M_{\mathrm{tr}}^{(r)}
:=
M_{\mathrm{state}}^{(r)}-1.
}
$$

第 $\nu$ 条轨线的 clean physical state 记为

$$
\boxed{
\mathbf x_m^{(\nu,r)}
:=
\mathbf x^{(\nu,r)}\!\left(t_m^{(r)}\right).
}
$$

连续系统的内部积分必须解析读取当前 forcing，而不能用最近邻索引读取预生成的粗时间数组。并要求

$$
0<\Delta t_{\max,r}
\le
\frac{\tau_r}{K_{\mathrm{sub},r}},
\qquad
K_{\mathrm{sub},r}\ge1,
$$

其中 $K_{\mathrm{sub},r}$ 由具体底座的状态尺度、最高 forcing 频率与收敛性审计共同确定。

数据生成配置必须保存：

$$
\boxed{
\tau_r,
\quad
T_r,
\quad
M_{\mathrm{state}}^{(r)},
\quad
M_{\mathrm{tr}}^{(r)},
\quad
\Delta t_{\max,r},
\quad
\Pi_{\mathrm{endpoint}}^{(r)},
\quad
\Pi_{\mathrm{resample}}^{(r)},
\quad
\text{solver},
\quad
\texttt{rtol},
\quad
\texttt{atol}.
}
$$

前四个底座可以继续使用共享的低频 canonical 时间包。高频强硬化 Duffing 使用独立时间包：

$$
\boxed{
\tau_{\mathrm{DUF\text{-}HF}}
=0.002\,\mathrm{s},
\qquad
T_{\mathrm{DUF\text{-}HF}}
=4\,\mathrm{s},
\qquad
\Pi_{\mathrm{endpoint}}^{(\mathrm{DUF\text{-}HF})}
=\mathrm{half\text{-}open}.
}
$$

因此其 canonical 模型网格包含

$$
\boxed{
M_{\mathrm{state}}^{(\mathrm{DUF\text{-}HF})}=2000
}
$$

个时间点。
---

## 1.2 物理状态、learner 观测与预测目标

设第 $r$ 个底座的物理状态空间为

$$
\mathcal X_r
\subseteq
\mathbb R^{d_x(r)\times1}.
$$

定义 clean learner observation map

$$
\boxed{
Z_r:
\mathcal X_r
\to
\mathcal Z_r,
\qquad
\mathbf z_m^{(\nu)}
:=
Z_r\!\left(\mathbf x_m^{(\nu)}\right).
}
$$

除单摆外，默认取恒等观测：

$$
\boxed{
\mathbf z=\mathbf x.
}
$$

单摆采用周期嵌入观测：

$$
\boxed{
Z_{\mathrm{PEN}}
\left(
\begin{bmatrix}
\theta\\
\omega
\end{bmatrix}
\right)
:=
\begin{bmatrix}
\cos\theta\\
\sin\theta\\
\omega
\end{bmatrix}.
}
$$

默认物理预测目标取 clean learner observation：

$$
\boxed{
\mathbf y_m^{(\nu)}
:=
\mathbf z_m^{(\nu)}.
}
$$

单摆同时保存 raw angle：

$$
\theta_m^{(\nu)},
$$

但 raw angle 不作为 canonical learner target，以避免 $-\pi$ 与 $\pi$ 处的人为跳变。

---

## 1.3 轨线级数据划分

轨线集合按完整 trajectory 划分：

$$
\boxed{
\mathcal R
=
\mathcal R_{\mathrm{train}}
\sqcup
\mathcal R_{\mathrm{val}}
\sqcup
\mathcal R_{\mathrm{test}}.
}
$$

不允许把同一轨线中的 snapshots、one-step pairs 或 rollout windows 随机分配到不同 split。

训练集用于：

$$
\boxed{
\text{标准化统计量、模型训练、noise reference scale 与最终 refit}.
}
$$

验证集用于：

$$
\boxed{
\text{配置选择、checkpoint 选择与稳定性检查}.
}
$$

测试集只用于：

$$
\boxed{
\text{冻结方案后的最终一次性评估}.
}
$$

---

# 2. 外部信号源的统一接口与两类实现

## 2.1 有限维自治信号源

为使 `augaut`、`addc` 与 `bilinc` 三个分支可以使用匹配的外部信号 realization，本文统一要求 source state 服从有限维自治动力学。前四个底座默认使用线性输出的多模态 harmonic exosystem；高频强硬化 Duffing 使用二维相位源与非线性周期读出。

设使用 $J_q$ 个振荡模态，定义

$$
\boxed{
\mathbf q
=
\begin{bmatrix}
\mathbf q_1\\
\vdots\\
\mathbf q_{J_q}
\end{bmatrix}
\in
\mathbb R^{2J_q\times1},
\qquad
\mathbf q_j
=
\begin{bmatrix}
q_{j,c}\\
q_{j,s}
\end{bmatrix}.
}
$$

每个模态满足

$$
\boxed{
\dot{\mathbf q}_j
=
\mathbf S_j\mathbf q_j,
\qquad
\mathbf S_j
:=
\begin{bmatrix}
0&-\omega_j\\
\omega_j&0
\end{bmatrix},
\qquad
\omega_j>0.
}
$$

定义 block-diagonal source matrix：

$$
\boxed{
\mathbf S
:=
\operatorname{blockdiag}
\left(
\mathbf S_1,\ldots,\mathbf S_{J_q}
\right).
}
$$

于是

$$
\boxed{
\dot{\mathbf q}
=
\mathbf S\mathbf q,
\qquad
\mathbf q(t)
=
e^{\mathbf S t}\mathbf q_0.
}
$$

定义标量物理 forcing：

$$
\boxed{
c(t)
:=
C(\mathbf q(t))
=
\mathbf c_q^\top\mathbf q(t),
}
$$

其中

$$
\mathbf c_q
\in
\mathbb R^{2J_q\times1}
$$

由配置给定。

第 $\nu$ 条轨线的 source initial state 写为

$$
\boxed{
\mathbf q_0^{(\nu)}.
}
$$

不同轨线允许使用不同的幅值与相位；这些差异全部编码在

$$
\mathbf q_0^{(\nu)}
$$

中，而

$$
\mathbf S,
\qquad
\mathbf c_q
$$

在一个数据集版本内保持固定。

---

## 2.2 source initial state 的极坐标采样

对第 $j$ 个 source mode，定义

$$
\boxed{
\mathbf q_{j,0}^{(\nu)}
=
\rho_j^{(\nu)}
\begin{bmatrix}
\cos\phi_j^{(\nu)}\\
\sin\phi_j^{(\nu)}
\end{bmatrix},
}
$$

其中

$$
\rho_j^{(\nu)}
\in
[\rho_{j,\min},\rho_{j,\max}],
\qquad
\phi_j^{(\nu)}
\in
[0,2\pi).
$$

所有随机种子必须保存。禁止逐轨线重新缩放 forcing 使其峰值完全相同，因为这会破坏 source initial state 与 forcing amplitude 之间的真实对应关系。

若需要固定全局最大 forcing 幅值，可在整个 source bank 构造完成后使用一个全局常数

$$
\kappa_c>0
$$

进行统一缩放：

$$
\boxed{
\mathbf c_q
\leftarrow
\kappa_c\mathbf c_q.
}
$$

不允许对不同轨线使用不同的 $\kappa_c$。

---

## 2.3 与一步转移严格对齐的 forcing 字段

对区间

$$
[t_m,t_{m+1}),
$$

保存以下字段。

### 左端点 forcing

$$
\boxed{
c_m^{\mathrm L}
:=
c(t_m).
}
$$

### 中点 forcing

$$
\boxed{
c_m^{\mathrm M}
:=
c\!\left(t_m+\frac{\tau_r}{2}\right).
}
$$

### 精确区间平均 forcing

$$
\boxed{
\overline c_m
:=
\frac1{\tau_r}
\int_{t_m}^{t_{m+1}}
c(t)\,\mathrm dt.
}
$$

对默认线性输出 harmonic exosystem，若

$$
c(t)=\mathbf c_q^\top\mathbf q(t),
\qquad
\dot{\mathbf q}=\mathbf S\mathbf q,
$$

则

$$
\boxed{
\overline c_m
=
\mathbf c_q^\top
\mathbf A_{\mathrm{avg}}^{\tau_r}
\mathbf q_m,
}
$$

其中

$$
\boxed{
\mathbf A_{\mathrm{avg}}^{\tau_r}
:=
\frac1{\tau_r}
\int_0^{\tau_r}
e^{\mathbf S s}\,\mathrm ds.
}
$$

当 $\mathbf S$ 可逆时，亦可写为

$$
\boxed{
\mathbf A_{\mathrm{avg}}^{\tau_r}
=
\frac1{\tau_r}
\mathbf S^{-1}
\left(e^{\mathbf S\tau_r}-\mathbf I\right).
}
$$

对非线性周期读出

$$
c(t)=C(\mathbf q(t)),
$$

区间平均必须由读出函数的解析积分或经过收敛验证的高精度积分计算。高频强硬化 Duffing 的 multisine 为有限 Fourier 和，其区间平均具有逐模态闭式表达，不允许用粗采样算术平均替代。

所有 explicit-control 数据对象必须把用于一步转移的控制字段与状态时间网格严格对齐。
---

## 2.4 explicit-control 分支的 forcing feature

对 `addc` 与 `bilinc`，learner state 不包含 $\mathbf q_m$。外部 forcing feature 统一记为

$$
\boxed{
\mathbf v_m
\in
\mathbb R^{d_v\times1}.
}
$$

本文允许两种冻结配置。

### 最小标量 forcing feature

$$
\boxed{
\mathbf v_m^{\mathrm{scalar}}
:=
\begin{bmatrix}
\overline c_m
\end{bmatrix},
\qquad
d_v=1.
}
$$

该模式对应最小加性 KDSMc 接口。

### 完整 source-coordinate forcing feature

$$
\boxed{
\mathbf v_m^{\mathrm{source}}
:=
\mathbf q_m,
\qquad
d_v=2J_q.
}
$$

该模式使当前 forcing feature 与未来 schedule 由已知 source dynamics 完整确定，适合研究更充分的 forcing descriptor。

两种模式必须作为不同的显式配置保存：

```text
forcing_feature_mode = "scalar_interval_average"
```

或

```text
forcing_feature_mode = "source_state"
```

不得在训练、验证与测试阶段动态切换。

不论采用哪一种 forcing feature，数据包都必须保存

$$
\mathbf q_m,
\qquad
c_m^{\mathrm L},
\qquad
c_m^{\mathrm M},
\qquad
\overline c_m,
$$

以便审计、重新构造 schedule 与后续模型升级。

---

## 2.5 二维相位源与相位锁定 multisine 读出

高频强硬化 Duffing 不使用 $J_q$ 个显式 Fourier 振荡器作为 learner source state，而采用二维相位源

$$
\boxed{
\mathbf q
=
\begin{bmatrix}
q_c\\
q_s
\end{bmatrix}
=
\begin{bmatrix}
\cos\vartheta\\
\sin\vartheta
\end{bmatrix}
\in\mathbb R^{2\times1}.
}
$$

其自治动力学为

$$
\boxed{
\dot{\mathbf q}
=
\mathbf S_0\mathbf q,
\qquad
\mathbf S_0
:=
\begin{bmatrix}
0&-\omega_{\mathrm b}\\
\omega_{\mathrm b}&0
\end{bmatrix}.
}
$$

设

$$
\vartheta(t)
=
\omega_{\mathrm b}t+\vartheta_0.
$$

允许 source output 为固定的非线性周期读出

$$
\boxed{
c_{\mathrm{HF}}(t)
=
C_{\mathrm{HF}}\!\left(\mathbf q(t)\right),
}
$$

其中 $C_{\mathrm{HF}}$ 由冻结 Fourier realization 定义。理论上，$C_{\mathrm{HF}}$ 是单位圆上的确定性函数；实现时应使用连续绝对相位计算 Fourier 和，不应通过最近邻索引读取离散 forcing 数组。

该 source 模式记为

```text
source.mode = "phase_locked_multisine_exosystem"
source.output_mode = "nonlinear_periodic_readout"
```

它仍满足：当前 source state 唯一决定全部未来 forcing schedule。因此，`augaut` 可以把 $\mathbf q$ 纳入完整自治状态；`addc` 与 `bilinc` 可以把 $\mathbf q_m$ 作为独立 forcing feature，但不得拼入物理 state encoder。

---

# 3. 三类数据分支的统一语义

## 3.1 `augaut`：扩展自治分支

设底座 vector field 为

$$
\mathbf f_{0,r}:
\mathcal X_r
\to
\mathbb R^{d_x(r)\times1}.
$$

定义加性作用方向

$$
\mathbf b_{c,r}
\in
\mathbb R^{d_x(r)\times1}.
$$

扩展自治系统为

$$
\boxed{
\frac{\mathrm d}{\mathrm dt}
\begin{bmatrix}
\mathbf x\\
\mathbf q
\end{bmatrix}
=
\begin{bmatrix}
\mathbf f_{0,r}(\mathbf x)
+
\mathbf b_{c,r}\mathbf c_q^\top\mathbf q
\\[1mm]
\mathbf S\mathbf q
\end{bmatrix}.
}
$$

其 learner observation 为

$$
\boxed{
\mathbf z_{\mathrm{aug}}
:=
\begin{bmatrix}
Z_r(\mathbf x)\\
\mathbf q
\end{bmatrix}.
}
$$

`augaut` 分支不存在独立 forcing input：

$$
\boxed{
\mathbf v_m
\text{ 不进入 learner interface}.
}
$$

虽然数据包为了审计仍保存

$$
c(t)=\mathbf c_q^\top\mathbf q(t),
$$

但该字段不得与 $\mathbf q_m$ 同时作为模型输入。

`augaut` 分支的 canonical one-step data 为

$$
\boxed{
\mathcal D_{\mathrm{AUG}}^{\mathrm{pair}}
=
\left\{
\left(
\mathbf z_{\mathrm{aug},m}^{(\nu)},
\mathbf z_{\mathrm{aug},m+1}^{(\nu)}
\right)
\right\}.
}
$$

---

## 3.2 `addc`：加性受控分支

显式加性系统为

$$
\boxed{
\dot{\mathbf x}
=
\mathbf f_{0,r}(\mathbf x)
+
\mathbf b_{c,r}c(t).
}
$$

它满足 vector-field-level 加性判据：

$$
\boxed{
\frac{\partial}{\partial c}
\left[
\mathbf f_{0,r}(\mathbf x)
+
\mathbf b_{c,r}c
\right]
=
\mathbf b_{c,r},
}
$$

即控制方向不依赖当前状态。

learner state 为

$$
\boxed{
\mathbf z_m
=
Z_r(\mathbf x_m),
}
$$

forcing feature 为冻结配置下的

$$
\boxed{
\mathbf v_m
=
\mathbf v_m^{\mathrm{scalar}}
\quad\text{或}\quad
\mathbf v_m^{\mathrm{source}}.
}
$$

canonical one-step controlled pair 为

$$
\boxed{
\mathcal D_{\mathrm{ADD}}^{\mathrm{pair}}
=
\left\{
\left(
\mathbf z_m^{(\nu)},
\mathbf v_m^{(\nu)},
\mathbf z_{m+1}^{(\nu)}
\right)
\right\}.
}
$$

canonical multi-step window 为

$$
\boxed{
\mathfrak W_{\mathrm{ADD}}^{(\nu,s)}
=
\left(
\mathbf z_s^{(\nu)},
\left\{
\mathbf v_{s+\ell}^{(\nu)}
\right\}_{\ell=0}^{h_{\max}-1},
\left\{
\mathbf y_{s+h}^{(\nu)}
\right\}_{h\in\mathcal H_{\mathrm{roll}}}
\right).
}
$$

---

## 3.3 `bilinc`：双线性受控分支

双线性分支必须包含明确的状态--控制乘积。统一写为

$$
\boxed{
\dot{\mathbf x}
=
\mathbf f_{0,r}(\mathbf x)
+
c(t)\mathbf g_{\mathrm{bil},r}(\mathbf x).
}
$$

当

$$
\mathbf g_{\mathrm{bil},r}(\mathbf x)
=
\mathbf N_{c,r}\mathbf x,
$$

得到严格矩阵双线性形式：

$$
\boxed{
\dot{\mathbf x}
=
\mathbf f_{0,r}(\mathbf x)
+
c(t)\mathbf N_{c,r}\mathbf x.
}
$$

其控制灵敏度为

$$
\boxed{
\frac{\partial}{\partial c}
\left[
\mathbf f_{0,r}(\mathbf x)
+
c\mathbf g_{\mathrm{bil},r}(\mathbf x)
\right]
=
\mathbf g_{\mathrm{bil},r}(\mathbf x),
}
$$

显式依赖状态。

`bilinc` 分支的数据字段与 `addc` 相同：

$$
\boxed{
\left(
\mathbf z_m,
\mathbf v_m,
\mathbf z_{m+1}
\right),
}
$$

但其物理生成方程不同，不能由数据字段名称判断为加性系统。

数据 metadata 必须保存：

```text
control_role = "bilinear"
bilinear_channel = "..."
```

当前加性 F2/F3 可以在该分支上运行，但结果只能解释为 additive-model structural-mismatch baseline。

---

# 4. 线性阻尼振子三分支

## 4.1 物理底座

定义物理状态

$$
\boxed{
\mathbf x
=
\begin{bmatrix}
x\\
p
\end{bmatrix},
\qquad
p:=\dot x.
}
$$

线性阻尼振子底座为

$$
\boxed{
\begin{aligned}
\dot x
&=
p,
\\
\dot p
&=
-2\zeta\omega_0p
-\omega_0^2x,
\end{aligned}
}
$$

其中

$$
\omega_0>0,
\qquad
\zeta\ge0.
$$

加性作用方向取

$$
\boxed{
\mathbf b_{c,\mathrm{LIN}}
=
\begin{bmatrix}
0\\
b_c
\end{bmatrix}.
}
$$

---

## 4.2 `linosc_augaut`

$$
\boxed{
\begin{aligned}
\dot x
&=
p,
\\
\dot p
&=
-2\zeta\omega_0p
-\omega_0^2x
+b_c\mathbf c_q^\top\mathbf q,
\\
\dot{\mathbf q}
&=
\mathbf S\mathbf q.
\end{aligned}
}
$$

learner state：

$$
\boxed{
\mathbf z_{\mathrm{aug}}
=
\begin{bmatrix}
x\\p\\\mathbf q
\end{bmatrix}.
}
$$

---

## 4.3 `linosc_addc`

$$
\boxed{
\begin{aligned}
\dot x
&=
p,
\\
\dot p
&=
-2\zeta\omega_0p
-\omega_0^2x
+b_cc(t).
\end{aligned}
}
$$

learner state 与 forcing feature：

$$
\boxed{
\mathbf z
=
\begin{bmatrix}
x\\p
\end{bmatrix},
\qquad
\mathbf v_m
=
\mathbf v_m^{\mathrm{scalar}}
\text{ 或 }
\mathbf v_m^{\mathrm{source}}.
}
$$

该对象是受控实现正确性的首要基线。

---

## 4.4 `linosc_bilinc`

采用线性刚度调制：

$$
\boxed{
\begin{aligned}
\dot x
&=
p,
\\
\dot p
&=
-2\zeta\omega_0p
-\left(
\omega_0^2+\alpha_c c(t)
\right)x.
\end{aligned}
}
$$

展开为

$$
\boxed{
\dot p
=
-2\zeta\omega_0p
-\omega_0^2x
-\alpha_c c(t)x.
}
$$

其 canonical 双线性通道为

$$
\boxed{
\mathbf g_{\mathrm{bil},\mathrm{LIN}}(\mathbf x)
=
\begin{bmatrix}
0\\
-\alpha_c x
\end{bmatrix}.
}
$$

---

# 5. Duffing 振子三分支

## 5.1 物理底座

定义

$$
\boxed{
\mathbf x
=
\begin{bmatrix}
x\\p
\end{bmatrix},
\qquad
p:=\dot x.
}
$$

Duffing 底座为

$$
\boxed{
\begin{aligned}
\dot x
&=
p,
\\
\dot p
&=
-dp-kx-k_cx^3,
\end{aligned}
}
$$

其中

$$
d\ge0,
\qquad
k\in\mathbb R,
\qquad
k_c\in\mathbb R.
$$

若使用带质量形式

$$
m\ddot x+d\dot x+kx+k_cx^3=f_{\mathrm{ext}},
$$

则必须在配置中保存 $m>0$，并将右端全部除以 $m$ 后进入状态方程。

---

## 5.2 `duffing_augaut`

$$
\boxed{
\begin{aligned}
\dot x
&=
p,
\\
\dot p
&=
-dp-kx-k_cx^3
+b_c\mathbf c_q^\top\mathbf q,
\\
\dot{\mathbf q}
&=
\mathbf S\mathbf q.
\end{aligned}
}
$$

learner state：

$$
\boxed{
\mathbf z_{\mathrm{aug}}
=
\begin{bmatrix}
x\\p\\\mathbf q
\end{bmatrix}.
}
$$

显式 forcing 字段只用于审计，不进入 learner。

---

## 5.3 `duffing_addc`

$$
\boxed{
\begin{aligned}
\dot x
&=
p,
\\
\dot p
&=
-dp-kx-k_cx^3
+b_cc(t).
\end{aligned}
}
$$

该对象是当前 F2/F3 的正式 Duffing 主基准。

---

## 5.4 `duffing_bilinc`

采用线性刚度调制：

$$
\boxed{
\begin{aligned}
\dot x
&=
p,
\\
\dot p
&=
-dp
-\left(
k+\alpha_c c(t)
\right)x
-k_cx^3.
\end{aligned}
}
$$

展开为

$$
\boxed{
\dot p
=
-dp-kx-k_cx^3
-\alpha_c c(t)x.
}
$$

canonical 双线性通道为

$$
\boxed{
\mathbf g_{\mathrm{bil},\mathrm{DUF}}(\mathbf x)
=
\begin{bmatrix}
0\\
-\alpha_c x
\end{bmatrix}.
}
$$

第一版不采用 $c(t)x^3$，以避免控制调制与高阶状态交互同时改变。

---

# 6. Van der Pol 振子三分支

## 6.1 物理底座

定义

$$
\boxed{
\mathbf x
=
\begin{bmatrix}
x\\p
\end{bmatrix},
\qquad
p:=\dot x.
}
$$

Van der Pol 底座为

$$
\boxed{
\begin{aligned}
\dot x
&=
p,
\\
\dot p
&=
\mu(1-x^2)p
-\omega_0^2x,
\end{aligned}
}
$$

其中

$$
\mu>0,
\qquad
\omega_0>0.
$$

---

## 6.2 `vdp_augaut`

$$
\boxed{
\begin{aligned}
\dot x
&=
p,
\\
\dot p
&=
\mu(1-x^2)p
-\omega_0^2x
+b_c\mathbf c_q^\top\mathbf q,
\\
\dot{\mathbf q}
&=
\mathbf S\mathbf q.
\end{aligned}
}
$$

learner state：

$$
\boxed{
\mathbf z_{\mathrm{aug}}
=
\begin{bmatrix}
x\\p\\\mathbf q
\end{bmatrix}.
}
$$

---

## 6.3 `vdp_addc`

$$
\boxed{
\begin{aligned}
\dot x
&=
p,
\\
\dot p
&=
\mu(1-x^2)p
-\omega_0^2x
+b_cc(t).
\end{aligned}
}
$$

该对象用于检验非线性耗散与极限环条件下的加性受控建模。

---

## 6.4 `vdp_bilinc`

采用阻尼调制：

$$
\boxed{
\begin{aligned}
\dot x
&=
p,
\\
\dot p
&=
\left[
\mu(1-x^2)
-\alpha_c c(t)
\right]p
-\omega_0^2x.
\end{aligned}
}
$$

展开为

$$
\boxed{
\dot p
=
\mu(1-x^2)p
-\omega_0^2x
-\alpha_c c(t)p.
}
$$

canonical 双线性通道为

$$
\boxed{
\mathbf g_{\mathrm{bil},\mathrm{VDP}}(\mathbf x)
=
\begin{bmatrix}
0\\
-\alpha_c p
\end{bmatrix}.
}
$$

第一版不采用

$$
[\mu+\alpha_c c(t)](1-x^2)p,
$$

因为该形式同时包含 $c(t)p$ 与 $c(t)x^2p$，不再是最小双线性诊断对象。

---

# 7. 单摆三分支

## 7.1 物理底座与周期观测

定义物理状态

$$
\boxed{
\mathbf x
=
\begin{bmatrix}
\theta\\
\omega
\end{bmatrix},
\qquad
\omega:=\dot\theta.
}
$$

单摆底座为

$$
\boxed{
\begin{aligned}
\dot\theta
&=
\omega,
\\
\dot\omega
&=
-d\omega
-\omega_p^2\sin\theta,
\end{aligned}
}
$$

其中

$$
\omega_p^2
:=
\frac{g}{\ell},
\qquad
d\ge0,
\qquad
\ell>0.
$$

canonical learner observation 为

$$
\boxed{
\mathbf z
=
\begin{bmatrix}
\cos\theta\\
\sin\theta\\
\omega
\end{bmatrix}.
}
$$

必须保存几何一致性诊断：

$$
\boxed{
\varepsilon_{S^1,m}
:=
\left|
\cos^2\theta_m
+
\sin^2\theta_m
-1
\right|.
}
$$

clean 数据中该误差应仅由浮点误差产生。

---

## 7.2 `pendulum_augaut`

$$
\boxed{
\begin{aligned}
\dot\theta
&=
\omega,
\\
\dot\omega
&=
-d\omega
-\omega_p^2\sin\theta
+b_c\mathbf c_q^\top\mathbf q,
\\
\dot{\mathbf q}
&=
\mathbf S\mathbf q.
\end{aligned}
}
$$

learner state：

$$
\boxed{
\mathbf z_{\mathrm{aug}}
=
\begin{bmatrix}
\cos\theta\\
\sin\theta\\
\omega\\
\mathbf q
\end{bmatrix}.
}
$$

---

## 7.3 `pendulum_addc`

采用加性外部力矩：

$$
\boxed{
\begin{aligned}
\dot\theta
&=
\omega,
\\
\dot\omega
&=
-d\omega
-\omega_p^2\sin\theta
+b_cc(t).
\end{aligned}
}
$$

该对象用于检验周期状态嵌入和跨势垒加性控制。

---

## 7.4 `pendulum_bilinc`

采用阻尼调制：

$$
\boxed{
\begin{aligned}
\dot\theta
&=
\omega,
\\
\dot\omega
&=
-\left[
d+\alpha_c c(t)
\right]\omega
-\omega_p^2\sin\theta.
\end{aligned}
}
$$

展开为

$$
\boxed{
\dot\omega
=
-d\omega
-\omega_p^2\sin\theta
-\alpha_c c(t)\omega.
}
$$

canonical 双线性通道为

$$
\boxed{
\mathbf g_{\mathrm{bil},\mathrm{PEN}}(\mathbf x)
=
\begin{bmatrix}
0\\
-\alpha_c\omega
\end{bmatrix}.
}
$$

第一版不使用

$$
c(t)\sin\theta
$$

形式，以保持原始物理状态中的最小状态--控制乘积。

---

# 8. 高频强硬化 Duffing 振子三分支

## 8.1 对象身份与物理底座

定义第五类底座

$$
\boxed{
\mathsf{DUF\text{-}HF}
:=
\text{High-Frequency Strong-Hardening Duffing Oscillator}.
}
$$

该对象不替代第 5 节的一般 Duffing，而是作为独立的高频、强硬化、短时间高采样率 benchmark。定义物理状态

$$
\boxed{
\mathbf x
=
\begin{bmatrix}
x\\p
\end{bmatrix},
\qquad
p:=\dot x.
}
$$

其带质量形式为

$$
\boxed{
m\ddot x
+d\dot x
+kx
+k_cx^3
=
f_{\mathrm{ext}}.
}
$$

canonical 物理参数冻结为

$$
\boxed{
m=1,
\qquad
d=40,
\qquad
k=3\times10^3,
\qquad
k_c=5\times10^8.
}
$$

对应无控制 vector field 为

$$
\boxed{
\mathbf f_{0,\mathrm{DUF\text{-}HF}}(\mathbf x)
=
\begin{bmatrix}
p\\[1ex]
\dfrac{-dp-kx-k_cx^3}{m}
\end{bmatrix}.
}
$$

由于 $k>0$ 且 $k_c>0$，该底座属于单稳态强硬化 Duffing。其目的不是提供多稳态势阱，而是提供高恢复力尺度、强三次非线性与宽频外部激励共同作用下的受控预测对象。

---

## 8.2 固定 realization 的高频稀疏 multisine

设置公共基频

$$
\boxed{
f_{\mathrm b}=0.5\,\mathrm{Hz},
\qquad
\omega_{\mathrm b}=2\pi f_{\mathrm b}.
}
$$

使用 $J_{\mathrm{HF}}=16$ 个正频率分量：

$$
\boxed{
\mathcal F_{\mathrm{HF}}
=
\{
5,\,7.5,\,9,\,12,\,16,\,17.5,\,20,\,25,\,
30,\,35,\,40,\,50,\,60,\,65,\,70,\,80
\}\,\mathrm{Hz}.
}
$$

对每个 $f_j\in\mathcal F_{\mathrm{HF}}$，定义整数谐波指标

$$
\boxed{
k_j:=\frac{f_j}{f_{\mathrm b}}\in\mathbb N.
}
$$

在数据 artifact 生成开始前只采样一次固定 Fourier 相位：

$$
\boxed{
\phi_j
\sim
\operatorname{Unif}(0,2\pi),
\qquad
j=1,\ldots,J_{\mathrm{HF}}.
}
$$

所有轨线和三个 role 分支共享同一组 $\{\phi_j\}_{j=1}^{J_{\mathrm{HF}}}$。定义谐波权重及其 Euclidean 归一化：

$$
\boxed{
a_j
:=
\begin{cases}
2,
&
f_j\in\{9,17.5\}\,\mathrm{Hz},
\\
1,
&
\text{其他频率},
\end{cases}
\qquad
\widetilde a_j
:=
\frac{a_j}
{\left(\sum_{\ell=1}^{J_{\mathrm{HF}}}a_\ell^2\right)^{1/2}}.
}
$$

其中 $9\,\mathrm{Hz}$ 邻近小振幅直接共振频率

$$
f_{\mathrm n}
=
\frac{1}{2\pi}\sqrt{\frac{k}{m}}
\approx
8.72\,\mathrm{Hz},
$$

而 $17.5\,\mathrm{Hz}$ 邻近主要参数激励频率 $2f_{\mathrm n}\approx17.44\,\mathrm{Hz}$。因此这两个分量同时服务 AUG/ADD 的直接加性激励和 BIL 的刚度调制。定义加权原始模板

$$
\boxed{
U_{\mathrm{raw}}(\vartheta)
:=
\sum_{j=1}^{J_{\mathrm{HF}}}
\widetilde a_j
\cos(k_j\vartheta+\phi_j).
}
$$

定义全局归一化系数

$$
\boxed{
\kappa_{\mathrm{HF}}
:=
\left[
\max_{\vartheta\in[0,2\pi)}
\left|U_{\mathrm{raw}}(\vartheta)\right|
\right]^{-1}.
}
$$

由此得到单位峰值 source signal

$$
\boxed{
c_{\mathrm{HF}}(\vartheta)
:=
\kappa_{\mathrm{HF}}U_{\mathrm{raw}}(\vartheta),
\qquad
\max_{\vartheta\in[0,2\pi)}
|c_{\mathrm{HF}}(\vartheta)|=1.
}
$$

在单位圆 source state 上定义冻结读出

$$
\boxed{
C_{\mathrm{HF}}(\mathbf q)
:=
c_{\mathrm{HF}}\!\left(
\operatorname{atan2}(q_s,q_c)
\right).
}
$$

该表达用于定义自治 vector field；数值积分器内部应直接使用连续绝对相位 $\vartheta(t)=\omega_{\mathrm b}t+\vartheta_0$ 计算 Fourier 和，以避免 $\operatorname{atan2}$ 分支切换造成数值不连续。

加性物理外力幅值冻结为

$$
\boxed{
A_{\mathrm{HF}}=20,
}
$$

因此加性 forcing 为

$$
\boxed{
u_{\mathrm{HF}}(t)
:=
A_{\mathrm{HF}}
c_{\mathrm{HF}}\!\left(\vartheta(t)\right).
}
$$

不同轨线只改变初始相位

$$
\vartheta_0^{(\nu)}
\sim
\operatorname{Unif}(0,2\pi),
$$

不允许逐轨线重新归一化 multisine 峰值。

对模型区间 $[t_m,t_{m+1})$，单位峰值 source 的精确平均为

$$
\boxed{
\overline c_{\mathrm{HF},m}
=
\frac{\kappa_{\mathrm{HF}}}
{\tau_{\mathrm{HF}}}
\sum_{j=1}^{J_{\mathrm{HF}}}
\widetilde a_j
\frac{
\sin\!\left(k_j(\vartheta_m+\omega_{\mathrm b}\tau_{\mathrm{HF}})+\phi_j\right)
-
\sin(k_j\vartheta_m+\phi_j)
}{k_j\omega_{\mathrm b}}.
}
$$

相应加性外力平均为

$$
\boxed{
\overline u_{\mathrm{HF},m}
=
A_{\mathrm{HF}}\overline c_{\mathrm{HF},m}.
}
$$

---

## 8.3 高频对象的轨线、时间网格与初值

高分辨率仿真输出网格冻结为

$$
\boxed{
f_{\mathrm{sim}}=2000\,\mathrm{Hz},
\qquad
\Delta t_{\mathrm{sim}}=5\times10^{-4}\,\mathrm{s}.
}
$$

每条轨线的物理积分时长为

$$
\boxed{
T_{\mathrm{traj}}=4\,\mathrm{s},
\qquad
T_{\mathrm{drop}}=0.
}
$$

高分辨率保存时刻为

$$
\boxed{
t_n=n\Delta t_{\mathrm{sim}},
\qquad
n=0,\ldots,7999,
}
$$

不重复保存 $t=4\,\mathrm{s}$ 端点。连续时间求解器采用高阶自适应积分与解析 forcing evaluation，canonical 容差为

```text
rtol = 1.0e-10
atol = 1.0e-12
max_internal_step = 5.0e-4
```

并应以更细内部步长执行小规模收敛审计。

模型网格冻结为

$$
\boxed{
f_{\mathrm{model}}=500\,\mathrm{Hz},
\qquad
\tau_{\mathrm{HF}}=0.002\,\mathrm{s}.
}
$$

高分辨率状态、source 与 forcing 必须使用同一抗混叠滤波器，并按 $4{:}1$ 降采样。canonical 保存网格采用半开区间：

$$
\boxed{
t_m=m\tau_{\mathrm{HF}},
\qquad
m=0,\ldots,1999.
}
$$

因此每条轨线保存 $2000$ 个状态点和 $1999$ 个一步转移。

轨线数量冻结为

$$
\boxed{
|\mathcal R_{\mathrm{train}}|=512,
\qquad
|\mathcal R_{\mathrm{val}}|=128,
\qquad
|\mathcal R_{\mathrm{test}}|=128.
}
$$

对每条轨线独立采样

$$
\boxed{
x_0^{(\nu)}
\sim
\operatorname{Unif}\!\left(-5\times10^{-3},5\times10^{-3}\right),
}
$$

$$
\boxed{
p_0^{(\nu)}
\sim
\operatorname{Unif}(-0.3,0.3),
}
$$

$$
\boxed{
\vartheta_0^{(\nu)}
\sim
\operatorname{Unif}(0,2\pi).
}
$$

三个 role 分支必须复用同一 physical initial bank、phase initial bank、split manifest 与 Fourier realization。

---

## 8.4 `duffing_hf_augaut`

定义二维相位状态

$$
\mathbf q
=
\begin{bmatrix}
q_c\\q_s
\end{bmatrix}
=
\begin{bmatrix}
\cos\vartheta\\\sin\vartheta
\end{bmatrix}.
$$

扩展自治系统为

$$
\boxed{
\begin{aligned}
\dot x
&=p,
\\
m\dot p
&=
A_{\mathrm{HF}}C_{\mathrm{HF}}(\mathbf q)
-dp-kx-k_cx^3,
\\
\dot{\mathbf q}
&=
\mathbf S_0\mathbf q.
\end{aligned}
}
$$

canonical learner state 为

$$
\boxed{
\mathbf z_{\mathrm{aug}}
=
\begin{bmatrix}
x\\p\\q_c\\q_s
\end{bmatrix}
\in\mathbb R^{4\times1}.
}
$$

显式外力 $u_{\mathrm{HF}}(t)$ 只保存为 audit 字段，不作为额外 learner input，也不与 source state 重复拼接。

`duffing_hf_augaut` 不定义新的物理 forcing realization。它与 `duffing_hf_addc` 共享相同的

$$
\boxed{
\left(x_0^{(\nu)},p_0^{(\nu)},\vartheta_0^{(\nu)}\right),
\qquad
u_{\mathrm{HF}}^{(\nu)}(t),
}
$$

以及同一数值积分结果；二者只在 learner 信息结构上不同。

---

## 8.5 `duffing_hf_addc`

显式加性受控系统为

$$
\boxed{
\begin{aligned}
\dot x
&=p,
\\
m\dot p
&=
u_{\mathrm{HF}}(t)
-dp-kx-k_cx^3.
\end{aligned}
}
$$

learner state 为

$$
\boxed{
\mathbf z
=
\begin{bmatrix}
x\\p
\end{bmatrix}.
}
$$

canonical forcing feature 取物理外力的精确区间平均：

$$
\boxed{
\mathbf v_m^{\mathrm{HF,ADD}}
=
\begin{bmatrix}
\overline u_{\mathrm{HF},m}
\end{bmatrix}.
}
$$

亦允许冻结配置

```text
forcing_feature_mode = "source_state"
```

并使用 $\mathbf q_m$ 作为独立 forcing feature。该对象属于当前 F2/F3 的正式能力范围。

因此，在 matched key 相同的条件下，

$$
\boxed{
\mathbf X_{\mathrm{DUF\text{-}HF,AUG}}
=
\mathbf X_{\mathrm{DUF\text{-}HF,ADD}}
}
$$

应在求解器与写盘精度范围内严格成立。这一相等关系是协议要求，不是数据退化；AUG 与 ADD 分别表示同一加性物理母轨线的自治增广视图和显式输入视图。

---

## 8.6 `duffing_hf_bilinc`

双线性分支采用允许瞬时线性曲率变号的强高频刚度调制。v3 正式 profile 冻结无量纲调制深度

$$
\boxed{
\rho_k=12.
}
$$

系统为

$$
\boxed{
\begin{aligned}
\dot x
&=p,
\\
m\dot p
&=
-dp
-k\left[1-\rho_kc_{\mathrm{HF}}(t)\right]x
-k_cx^3.
\end{aligned}
}
$$

展开后得到

$$
\boxed{
m\dot p
=
-dp-kx-k_cx^3
+\rho_k k c_{\mathrm{HF}}(t)x.
}
$$

因此该分支没有加性外力，且 canonical 双线性通道为

$$
\boxed{
\mathbf g_{\mathrm{bil},\mathrm{DUF\text{-}HF}}(\mathbf x)
=
\begin{bmatrix}
0\\[1ex]
\dfrac{\rho_k k}{m}x
\end{bmatrix}.
}
$$

其控制灵敏度为

$$
\boxed{
\frac{\partial}{\partial c}
\begin{bmatrix}
p\\
\left[-dp-k(1-\rho_kc)x-k_cx^3\right]/m
\end{bmatrix}
=
\begin{bmatrix}
0\\
\rho_k kx/m
\end{bmatrix}.
}
$$

该灵敏度显式依赖状态，故此分支仍是纯双线性系统，而不是加性与双线性的混合系统。

定义瞬时有效线性刚度

$$
\boxed{
k_{\mathrm{eff}}(t)
:=
k\left[1-\rho_kc_{\mathrm{HF}}(t)\right].
}
$$

由 $|c_{\mathrm{HF}}(t)|\le1$ 得到理论界

$$
\boxed{
k(1-\rho_k)
\le
k_{\mathrm{eff}}(t)
\le
k(1+\rho_k).
}
$$

对 $\rho_k=12$ 与 $k=3000$，该界为

$$
\boxed{
-3.3\times10^4
\le
k_{\mathrm{eff}}(t)
\le
3.9\times10^4.
}
$$

当 $c_{\mathrm{HF}}(t)>1/\rho_k$ 时，$k_{\mathrm{eff}}(t)<0$，原点成为瞬时不稳定平衡点。对应的瞬时势能为

$$
\boxed{
V(x,t)
=
\frac12k\left[1-\rho_kc_{\mathrm{HF}}(t)\right]x^2
+
\frac14k_cx^4.
}
$$

由于 $k_c>0$，

$$
V(x,t)\longrightarrow+\infty
\qquad
\text{当}
\qquad
|x|\longrightarrow\infty,
$$

所以瞬时负线性曲率不会把系统变成无界倒置线性振子。当 $\rho_kc_{\mathrm{HF}}(t)>1$ 时，瞬时非零势阱中心为

$$
\boxed{
x_\pm(t)
=
\pm
\sqrt{
\frac{k\left[\rho_kc_{\mathrm{HF}}(t)-1\right]}{k_c}
}.
}
$$

为说明能量通道，定义未调制 Duffing 能量

$$
\boxed{
E_0(x,p)
=
\frac12mp^2
+
\frac12kx^2
+
\frac14k_cx^4.
}
$$

沿 BIL 轨线有

$$
\boxed{
\frac{\mathrm dE_0}{\mathrm dt}
=
-dp^2
+
\rho_k k c_{\mathrm{HF}}(t)x(t)p(t).
}
$$

第一项是阻尼耗散，第二项是双线性调制对未调制能量的瞬时做功；后续物理验收要求二者在轨线集合上处于同一量级。

canonical forcing feature 使用单位峰值 source 的区间平均：

$$
\boxed{
\mathbf v_m^{\mathrm{HF,BIL}}
=
\begin{bmatrix}
\overline c_{\mathrm{HF},m}
\end{bmatrix}.
}
$$

metadata 必须保存：

```text
control_role = "bilinear"
bilinear_channel = "relative_linear_stiffness_modulation_x"
```

当前加性 F2/F3 在该对象上的结果只能解释为 structural-mismatch baseline。

---

## 8.7 BIL 参数冻结与物理验收

### 8.7.1 参数只能由 training-side physical pilot 冻结

草稿建议首先扫描

$$
\rho_k\in\{1.25,1.5,2,2.5\}.
$$

这组候选在 64 条 training-side pilot 轨线上均未通过持续性验收，因此工程扫描扩展到更强调制区间。v2 曾选择 $\rho_k=10$，但其首尾指标无法排除中段局部塌缩。v3 改为扫描

$$
\boxed{
\rho_k\in\{10,12,14,16,18,20\},
}
$$

并冻结通过以下全部物理门槛的最小候选。该选择不得使用下游 KDSMc、KDSM 或其他学习模型的测试误差。

### 8.7.2 首尾持续性

所有持续性诊断均在冻结的 raw stored coordinates 上计算。令

$$
\mathbf D_{\mathrm{diag}}
:=
\mathbf I_2,
\qquad
r^{(\nu)}(t)
:=
\left\|
\mathbf D_{\mathrm{diag}}
\begin{bmatrix}
x^{(\nu)}(t)\\
p^{(\nu)}(t)
\end{bmatrix}
\right\|_2.
$$

这里 $\mathbf D_{\mathrm{diag}}=\mathbf I_2$ 表示实现使用数据文件中的数值坐标，不把 $r$ 解释为机械能；所有候选共享同一坐标尺度，后续只比较无量纲比值。

对第 $\nu$ 条 BIL 轨线，定义

$$
R_{\mathrm{head}}^{(\nu)}
:=
\left[
\frac{1}{1\,\mathrm{s}}
\int_0^{1\,\mathrm{s}}
r^{(\nu)}(t)^2
\,\mathrm dt
\right]^{1/2},
$$

$$
R_{\mathrm{tail}}^{(\nu)}
:=
\left[
\frac{1}{1\,\mathrm{s}}
\int_{3\,\mathrm{s}}^{4\,\mathrm{s}}
r^{(\nu)}(t)^2
\,\mathrm dt
\right]^{1/2},
$$

以及

$$
\boxed{
\Gamma_{\mathrm{persist}}^{(\nu)}
:=
\frac{R_{\mathrm{tail}}^{(\nu)}}
{R_{\mathrm{head}}^{(\nu)}+\varepsilon}.
}
$$

至少 $50\%$ 的 pilot 轨线必须满足

$$
\boxed{
0.2
\le
\Gamma_{\mathrm{persist}}^{(\nu)}
\le
5,
}
$$

且 $\operatorname{median}_{\nu}\Gamma_{\mathrm{persist}}^{(\nu)}$ 也必须位于同一区间。

### 8.7.3 连续滑动窗持续性

首尾持续性不能识别中间时段的近零平台。令窗长 $T_{\mathrm w}=0.5\,\mathrm{s}$、窗起点步长 $\Delta T_{\mathrm w}=0.1\,\mathrm{s}$，并令

$$
\mathcal W_\ell
:=
[t_\ell,t_\ell+T_{\mathrm w}),
\qquad
t_{\ell+1}-t_\ell
=
\Delta T_{\mathrm w}.
$$

定义

$$
R_{\mathrm w,\ell}^{(\nu)}
:=
\left[
\frac{1}{T_{\mathrm w}}
\int_{\mathcal W_\ell}
r^{(\nu)}(t)^2
\,\mathrm dt
\right]^{1/2},
$$

$$
\boxed{
\Gamma_{\mathrm{win}}^{(\nu)}
:=
\frac{
\min_\ell R_{\mathrm w,\ell}^{(\nu)}
}{
\operatorname{median}_\ell R_{\mathrm w,\ell}^{(\nu)}
+\varepsilon
}.
}
$$

至少 $75\%$ 的 pilot 轨线必须满足

$$
\boxed{
\Gamma_{\mathrm{win}}^{(\nu)}
\ge
0.1.
}
$$

### 8.7.4 做功、耗散、分支差异与高频尾能量

定义双线性做功和阻尼耗散

$$
\boxed{
W_{\mathrm{bil}}^{(\nu)}
:=
\int_0^{T_{\mathrm{traj}}}
\rho_k k
c_{\mathrm{HF}}^{(\nu)}(t)
x^{(\nu)}(t)
p^{(\nu)}(t)
\,\mathrm dt,
}
$$

$$
\boxed{
D_{\mathrm{damp}}^{(\nu)}
:=
\int_0^{T_{\mathrm{traj}}}
d\,p^{(\nu)}(t)^2
\,\mathrm dt.
}
$$

要求

$$
\boxed{
0.1
\le
\operatorname{median}_{\nu}
\frac{|W_{\mathrm{bil}}^{(\nu)}|}
{D_{\mathrm{damp}}^{(\nu)}+\varepsilon}
\le
10.
}
$$

同时定义 BIL 与 ADD 全体状态张量的相对差异

$$
\boxed{
\Delta_{\mathrm{BIL,ADD}}
:=
\frac{
\|\mathcal X_{\mathrm{BIL}}-\mathcal X_{\mathrm{ADD}}\|_{\mathrm F}
}{
\|\mathcal X_{\mathrm{ADD}}\|_{\mathrm F}+\varepsilon
},
\qquad
\Delta_{\mathrm{BIL,ADD}}
\ge
0.1.
}
$$

对每条轨线尾段速度 $p(t)$ 计算离散 Fourier 功率谱，记 $P_\nu(f)$ 为去除零频后的谱功率。定义

$$
\boxed{
\Gamma_{\mathrm{HF}}^{(\nu)}
:=
\frac{
\sum_{f>20\,\mathrm{Hz}}P_\nu(f)
}{
\sum_{f>0}P_\nu(f)+\varepsilon
}.
}
$$

要求

$$
\boxed{
\operatorname{median}_{\nu}\Gamma_{\mathrm{HF}}^{(\nu)}
\ge
10^{-4}.
}
$$

所有状态必须有限并满足 $\|\mathcal X_{\mathrm{BIL}}\|_\infty\le10$，且正式数据必须同时出现 $k_{\mathrm{eff}}(t)<0$ 与 $k_{\mathrm{eff}}(t)>0$。

### 8.7.5 v3 冻结结果

在 64 条 training-side pilot 上，$\rho_k=10$ 的连续窗通过率为 $0.421875$，未达到 $0.75$；$\rho_k=12$ 的连续窗通过率为 $0.96875$，并通过其余全部门槛。因此按“通过全部物理门槛的最小候选”规则冻结

$$
\boxed{
\rho_k=12.
}
$$

对 768 条正式 v3 轨线，关键审计结果为

$$
\boxed{
\begin{aligned}
\text{首尾持续性通过率}
&=0.9986979167,
\\
\text{连续窗通过率}
&=0.9765625,
\\
\operatorname{median}\Gamma_{\mathrm{win}}
&=0.5705570396,
\\
\operatorname{median}
\frac{|W_{\mathrm{bil}}|}{D_{\mathrm{damp}}+\varepsilon}
&=0.9964579034,
\\
\operatorname{median}\Gamma_{\mathrm{HF}}
&=0.3562749842,
\\
\Delta_{\mathrm{BIL,ADD}}
&=2.5045867300.
\end{aligned}
}
$$

正式 realization 的实际有效刚度范围为

$$
\boxed{
-32999.9965
\le
k_{\mathrm{eff}}(t)
\le
35636.6828,
}
$$

负刚度样本比例为 $0.383779296875$，全体状态最大绝对值为 $1.0229542633<10$。

---

## 8.8 Clean 与 10 dB observation view

高频强硬化 Duffing 的 clean trajectory 是唯一动力学母对象。若启用与旧 `duffing_aug_snr10` 对齐的 observation view，则固定

$$
\boxed{
\mathrm{SNR}=10\,\mathrm{dB},
}
$$

并只在 $500\,\mathrm{Hz}$ 模型网格上对物理观测通道 $x,p$ 添加独立 Gaussian noise。source state、forcing realization 与 clean target 保持无噪。

噪声方差只由 clean training split 的逐通道物理功率确定：

$$
\boxed{
\sigma_{\eta_x}^2
=0.1P_x^{\mathrm{train}},
\qquad
\sigma_{\eta_p}^2
=0.1P_p^{\mathrm{train}}.
}
$$

该 view 通过 metadata 记录：

```text
noise.enabled = true
noise.snr_db = 10
noise.apply_to = ["x", "p"]
noise.target_mode = "clean_target"
```

它不产生新的数据对象代号；`duffing_hf_augaut`、`duffing_hf_addc` 与 `duffing_hf_bilinc` 的数学身份保持不变。

---

# 9. 15 个规范数据对象与代号

本文固定以下数据集代号：

| 底座 | 扩展自治 | 加性受控 | 双线性受控 |
|---|---|---|---|
| 线性阻尼振子 | `linosc_augaut` | `linosc_addc` | `linosc_bilinc` |
| 一般 Duffing 振子 | `duffing_augaut` | `duffing_addc` | `duffing_bilinc` |
| Van der Pol 振子 | `vdp_augaut` | `vdp_addc` | `vdp_bilinc` |
| 单摆 | `pendulum_augaut` | `pendulum_addc` | `pendulum_bilinc` |
| 高频强硬化 Duffing | `duffing_hf_augaut` | `duffing_hf_addc` | `duffing_hf_bilinc` |

噪声配置不得修改数据集主代号。例如：

```text
vdp_addc
```

在启用噪声后仍记为

```text
vdp_addc
```

噪声状态只写入 metadata 与 observation view：

```text
noise.enabled = true
```

而不是生成

```text
vdp_addc_snrXX
```

之类的新数据身份。

---

# 10. 初值、forcing 与反事实配对设计

## 10.1 初始物理状态 bank

对每个底座 $r$，定义初值集合

$$
\boxed{
\mathcal I_{x,r}
:=
\left\{
\mathbf x_{0,a}^{(r)}
\right\}_{a=1}^{N_{x,0}^{(r)}}.
}
$$

初值范围由底座配置包

$$
\Pi_{x_0}^{(r)}
$$

确定。

初值采样必须覆盖目标工作区间，并避免只在单条吸引轨线附近取样。

---

## 10.2 source initial state bank

定义 source initial state 集合

$$
\boxed{
\mathcal I_q
:=
\left\{
\mathbf q_{0,b}
\right\}_{b=1}^{N_{q,0}}.
}
$$

同一底座的三个 role 分支必须复用同一个 source bank，以支持 branch-matched 比较。不同底座允许使用不同的 source family 与时间尺度。特别地，高频强硬化 Duffing 使用独立的 phase initial bank 与固定 Fourier realization，不与前四个低频底座强制共享 source bank。

---

## 10.3 部分笛卡尔积设计

完整初值资源为

$$
\mathcal I_{x,r}
\times
\mathcal I_q.
$$

不要求生成完整笛卡尔积，但每个 split 内必须满足：

1. 至少存在同一 physical initial state 对应多个不同 source initial states；
2. 至少存在同一 source initial state 对应多个不同 physical initial states。

记 pairing set 为

$$
\boxed{
\mathcal P_r
\subseteq
\mathcal I_{x,r}
\times
\mathcal I_q.
}
$$

该设计提供两类反事实资源：

$$
\boxed{
\text{同初值、异 forcing};
}
$$

$$
\boxed{
\text{同 forcing、异初值}.
}
$$

它用于减少状态与 forcing 的统计共线，并提高齐次传播与控制作用的可分离性。

---

## 10.4 split 的 bank-level 隔离

定义

$$
\mathcal I_{x,r}
=
\mathcal I_{x,r}^{\mathrm{train}}
\sqcup
\mathcal I_{x,r}^{\mathrm{val}}
\sqcup
\mathcal I_{x,r}^{\mathrm{test}},
$$

$$
\mathcal I_q
=
\mathcal I_q^{\mathrm{train}}
\sqcup
\mathcal I_q^{\mathrm{val}}
\sqcup
\mathcal I_q^{\mathrm{test}}.
$$

推荐 validation 与 test 同时使用未出现在 training 中的 physical initial states 与 source initial states。

若研究目标只要求新初值泛化或新 forcing 泛化，也可以分别构造：

$$
\boxed{
\texttt{new\_state},
\qquad
\texttt{new\_forcing},
\qquad
\texttt{new\_state\_and\_forcing}
}
$$

三个测试子集，但这些子集仍必须来自完整 trajectory 划分。

---

## 10.5 三分支 matched trajectory key

对每个底座 $r$ 和 pairing

$$
(a,b)
\in
\mathcal P_r,
$$

定义共同 matched key：

```text
matched_key = (base_system, physical_initial_id, source_initial_id)
```

同一 matched key 下，`augaut`、`addc` 与 `bilinc` 使用相同：

$$
\boxed{
\mathbf x_0,
\qquad
\mathbf q_0,
\qquad
\mathbf S,
\qquad
C,
\qquad
\Pi_{\mathrm{time}}^{(r)}.
}
$$

其中 `augaut` 与 `addc` 具有相同物理 forcing realization，因而可直接比较自治增广与显式加性输入两种信息接口。

`bilinc` 使用同一 $c(t)$，但控制作用机制不同，因此其轨线不应与 `addc` 逐点相同。

---

# 11. 噪声注入接口

## 11.1 噪声不是动力学分支

所有 clean trajectories 必须先完整生成并冻结，然后再构造 observation noise view：

$$
\boxed{
\mathcal D_{\mathrm{clean}}
\xrightarrow{\ \mathcal N_{\Pi_{\mathrm{noise}}}\ }
\mathcal D_{\mathrm{obs}}.
}
$$

噪声不得反馈进入 ODE 积分器。本文讨论的是测量噪声，而不是 process noise 或随机动力系统。

若未来需要 process noise，必须另建随机动力学协议，不能复用本文的 observation noise 字段冒充过程扰动。

---

## 11.2 通用噪声算子

设 clean learner observation 为

$$
\mathbf z_m
\in
\mathbb R^{d_z\times1}.
$$

定义随机变量

$$
\boldsymbol{\varepsilon}_m
\in
\mathbb R^{d_z\times1},
\qquad
\mathbb E[\boldsymbol{\varepsilon}_m]
=
\mathbf0,
\qquad
\mathbb E[
\boldsymbol{\varepsilon}_m
\boldsymbol{\varepsilon}_m^\top
]
=
\mathbf I_{d_z}.
$$

通用加性 observation noise 接口为

$$
\boxed{
\mathbf z_m^{\delta}
=
\mathbf z_m
+
\mathbf M_{\mathrm{noise}}
\mathbf D_{\mathrm{noise}}
\boldsymbol{\varepsilon}_m.
}
$$

其中：

$$
\mathbf M_{\mathrm{noise}}
=
\operatorname{diag}(m_1,\ldots,m_{d_z}),
\qquad
m_j\in\{0,1\},
$$

为通道 mask；

$$
\mathbf D_{\mathrm{noise}}
=
\operatorname{diag}(s_{\delta,1},\ldots,s_{\delta,d_z}),
\qquad
s_{\delta,j}\ge0,
$$

为外部配置给定的 noise scale。

本文不规定固定的

$$
s_{\delta,j}
$$

数值，也不定义低、中、高噪声等级。

---

## 11.3 噪声参数包

定义

$$
\boxed{
\Pi_{\mathrm{noise}}
:=
\left(
\Pi_{\mathrm{enable}},
\Pi_{\mathrm{model}},
\mathbf M_{\mathrm{noise}},
\mathbf D_{\mathrm{noise}},
\Pi_{\mathrm{reference}},
\Pi_{\mathrm{temporal}},
\Pi_{\mathrm{seed}},
\Pi_{\mathrm{target}}
\right).
}
$$

配置字段至少包括：

```text
[noise]
enabled = false
model = "additive_gaussian"
apply_to = ["learner_state"]
channel_mask = "all"
scale_mode = "external"
scale_values = []
reference = "clean_training_split"
temporal_correlation = "iid"
seed = 0
target_mode = "clean_target"
control_noise = false
source_state_noise = false
```

其中：

- `enabled=false` 表示只保存 clean view；
- `scale_mode="external"` 表示噪声尺度由实验配置提供；
- `reference="clean_training_split"` 只在使用相对尺度时读取 clean training statistics；
- `target_mode="clean_target"` 表示 noisy-input/clean-target；
- `control_noise=false` 表示显式 forcing schedule 保持 clean；
- `source_state_noise=false` 表示 `augaut` 中的 source state 默认保持 clean。

---

## 11.4 推荐 canonical 噪声语义

本文推荐的 canonical robustness view 为：

$$
\boxed{
\text{noisy learner-state input}
\quad+
\text{clean physical target}
\quad+
\text{clean forcing/source state}.
}
$$

对 `addc` 与 `bilinc`：

$$
\boxed{
\left(
\mathbf z_m^{\delta},
\mathbf v_m
\right)
\longmapsto
\mathbf y_{m+1}.
}
$$

对 `augaut`：

$$
\boxed{
\begin{bmatrix}
Z_r(\mathbf x_m)^{\delta}\\
\mathbf q_m
\end{bmatrix}
\longmapsto
\begin{bmatrix}
Z_r(\mathbf x_{m+1})\\
\mathbf q_{m+1}
\end{bmatrix}.
}
$$

若未来需要 source-state measurement noise，可显式启用：

```text
source_state_noise = true
```

但必须单独报告，不能与 canonical robustness view 混合。

---

## 11.5 单摆噪声与单位圆几何

对单摆，若噪声直接加在

$$
\left(
\cos\theta,
\sin\theta
\right)
$$

通道上，则 noisy observation 一般不再满足单位圆约束。

本文允许两种明确配置。

### embedded-channel noise

$$
\boxed{
\begin{bmatrix}
\cos\theta\\
\sin\theta
\end{bmatrix}^{\delta}
=
\begin{bmatrix}
\cos\theta\\
\sin\theta
\end{bmatrix}
+
\boldsymbol{\varepsilon}_{S^1}.
}
$$

该模式模拟两个嵌入通道的独立测量误差，不做单位圆投影。

### raw-angle noise

先构造

$$
\theta^{\delta}
=
\theta+\varepsilon_{\theta},
$$

再计算

$$
\boxed{
\mathbf z^{\delta}
=
\begin{bmatrix}
\cos\theta^{\delta}\\
\sin\theta^{\delta}\\
\omega^{\delta}
\end{bmatrix}.
}
$$

该模式保持单位圆几何。

配置必须显式记录：

```text
pendulum_noise_coordinate = "embedded_channels"
```

或

```text
pendulum_noise_coordinate = "raw_angle"
```

不得在同一正式实验中混用。

---

# 12. 数据存储接口

## 12.1 共同字段

每个数据对象至少保存：

```text
time_state                 [R, M_state]
time_transition            [R, M_tr]
state_physical_clean        [R, M_state, d_x]
state_observation_clean     [R, M_state, d_z]
target_clean                [R, M_state, d_y]
source_state_clean          [R, M_state, d_q]
control_left_clean          [R, M_tr, 1]
control_mid_clean           [R, M_tr, 1]
control_interval_average    [R, M_tr, 1]
control_feature_clean       [R, M_tr, d_v]
trajectory_id               [R]
physical_initial_id         [R]
source_initial_id           [R]
matched_key                 [R]
split_id                    [R]
```

若启用噪声，额外保存：

```text
state_observation_observed  [R, M_state, d_z]
target_observed             [R, M_state, d_y]   # 仅在显式启用 noisy-target 时存在
noise_seed                  [R]
noise_metadata              [1]
```

---

## 12.2 `augaut` learner view

`augaut` 的 canonical learner arrays 为：

```text
learner_state_clean = concat(state_observation_clean, source_state_clean)
learner_target_clean = learner_state_clean
forcing_exposed_to_learner = false
```

若启用 canonical noise：

```text
learner_state_observed = concat(state_observation_observed, source_state_clean)
learner_target = learner_target_clean
```

显式 forcing 字段仍保存，但必须标记：

```text
control_role = "audit_only"
```

---

## 12.3 `addc` 与 `bilinc` learner view

```text
learner_state_clean = state_observation_clean
learner_target_clean = target_clean
forcing_feature = control_feature_clean
forcing_exposed_to_learner = true
source_state_exposed_to_encoder = false
```

即使

```text
forcing_feature_mode = "source_state"
```

也必须把 $\mathbf q_m$ 作为独立 forcing feature，而不是拼入 state encoder。

---

## 12.4 单摆附加字段

```text
angle_raw_clean             [R, M_state, 1]
angular_velocity_clean      [R, M_state, 1]
unit_circle_residual_clean  [R, M_state, 1]
```

若使用 raw-angle noise：

```text
angle_raw_observed          [R, M_state, 1]
```


## 12.5 高频强硬化 Duffing 附加字段

高频强硬化 Duffing 额外保存：

```text
forcing_phase_clean         [R, M_state, 2]   # cos(theta), sin(theta)
source_signal_unit_peak     [R, M_state, 1]   # c_HF(t)
forcing_additive_physical   [R, M_state, 1]   # A_HF c_HF(t)
forcing_frequency_hz        [16]
forcing_harmonic_indices    [16]
forcing_harmonic_weights    [16]
forcing_normalized_weights  [16]
forcing_fourier_phases      [16]
forcing_normalization       [1]
```

并保存

```text
fs_sim = 2000
fs_model = 500
resample_ratio = 4
endpoint_policy = "half_open"
artifact_version = "v3"
base_parameter_version = "duffing_hf_base-v3"
source_parameter_version = "duffing_hf_source-v2"
```

metadata 还必须保存 BIL candidate pilot、验收门槛、正式物理诊断与有效刚度符号切换结果。若启用 10 dB view，额外保存训练集物理功率、逐通道 noise variance 与 empirical SNR 审计结果。

---

# 13. 数据生成算法

## 13.1 输入配置包

统一输入为

$$
\boxed{
\Pi_{\mathrm{D1}}
=
\left(
\Pi_{\mathrm{base}},
\Pi_{\mathrm{role}},
\Pi_{\mathrm{source}},
\Pi_{x_0},
\Pi_{q_0},
\Pi_{\mathrm{pair}},
\Pi_{\mathrm{time}},
\Pi_{\mathrm{solver}},
\Pi_{\mathrm{split}},
\Pi_{\mathrm{noise}}
\right).
}
$$

其中：

$$
\Pi_{\mathrm{base}}
\in
\{
\mathrm{LIN},
\mathrm{DUF},
\mathrm{VDP},
\mathrm{PEN},
\mathrm{DUF\text{-}HF}
\},
$$

$$
\Pi_{\mathrm{role}}
\in
\{
\mathrm{AUG},
\mathrm{ADD},
\mathrm{BIL}
\}.
$$

---

## 13.2 生成步骤

对每个底座与分支，执行：

1. 冻结底座参数包 $\Pi_{\mathrm{base}}$；
2. 冻结 source dynamics、output map $C$、source bank 与 source realization；
3. 构造 physical initial state bank；
4. 构造 pairing set $\mathcal P_r$；
5. 按 matched key 生成 source trajectory $\mathbf q^{(\nu)}(t)$；
6. 根据 role 选择 `augaut`、`addc` 或 `bilinc` vector field；
7. 使用高精度求解器积分 clean physical trajectory；
8. 按 $\Pi_{\mathrm{time}}^{(r)}$ 采样或抗混叠重采样 physical state 与 source state；
9. 依据 source output mode 解析计算 $c_m^{\mathrm L}$、$c_m^{\mathrm M}$ 与 $\overline c_m$；
10. 构造 clean learner observation 与 target；
11. 执行轨线合法性与结构语义检查；
12. 冻结 train/validation/test split；
13. 如启用噪声，在 clean data 上构造 observed view；
14. 写入完整 metadata、随机种子、参数与软件版本。

---

# 14. 结构语义校验

每个数据对象在写盘前必须通过以下自动测试。

## 14.1 role exclusivity

### `augaut`

必须满足：

```text
forcing_exposed_to_learner = false
source_state_in_learner_state = true
```

### `addc`

必须满足：

```text
forcing_exposed_to_learner = true
source_state_in_encoder = false
control_role = "additive"
```

### `bilinc`

必须满足：

```text
forcing_exposed_to_learner = true
source_state_in_encoder = false
control_role = "bilinear"
```

---

## 14.2 零 forcing 退化

当

$$
c(t)\equiv0,
$$

`addc` 与 `bilinc` 必须退化为同一个底座自治系统：

$$
\boxed{
\dot{\mathbf x}
=
\mathbf f_{0,r}(\mathbf x).
}
$$

在同一 $\mathbf x_0$ 下，二者的 zero-control clean trajectories 应在数值积分容差内一致。

---

## 14.3 加性控制灵敏度

对 `addc`，数值有限差分应验证：

$$
\frac{
\mathbf f(\mathbf x,c+\epsilon)
-
\mathbf f(\mathbf x,c)
}{\epsilon}
\approx
\mathbf b_c,
$$

且该结果不依赖 $\mathbf x$。

---

## 14.4 双线性控制灵敏度

对 `bilinc`，应验证：

$$
\frac{
\mathbf f(\mathbf x,c+\epsilon)
-
\mathbf f(\mathbf x,c)
}{\epsilon}
\approx
\mathbf g_{\mathrm{bil}}(\mathbf x),
$$

并且在测试状态集上

$$
\mathbf g_{\mathrm{bil}}(\mathbf x)
$$

不是常向量。

---

## 14.5 source consistency

所有 source mode 必须验证：

$$
\boxed{
\mathbf q_{m+1}
\approx
e^{\mathbf S\tau_r}\mathbf q_m.
}
$$

对线性输出 harmonic exosystem，验证

$$
\boxed{
c_m^{\mathrm L}
=
\mathbf c_q^\top\mathbf q_m.
}
$$

对 phase-locked multisine，验证

$$
\boxed{
(q_{c,m})^2+(q_{s,m})^2
\approx1,
}
$$

以及

$$
\boxed{
c_{\mathrm{HF},m}^{\mathrm L}
=
C_{\mathrm{HF}}(\mathbf q_m).
}
$$

两类 source 均必须验证解析区间平均与高精度数值积分结果一致。

---

## 14.6 单摆几何

clean pendulum data 必须满足：

$$
\max_{\nu,m}
\varepsilon_{S^1,m}^{(\nu)}
\le
\varepsilon_{S^1}^{\mathrm{tol}}.
$$

---

## 14.7 高频 Duffing 的频率、重采样与 role 检查

高频强硬化 Duffing 必须额外验证：

1. 固定 Fourier realization、频率集合与谐波权重在三个 role 分支中完全一致；
2. $\max|c_{\mathrm{HF}}|=1$ 且 $\max|u_{\mathrm{HF}}|=20$；
3. 模型采样率为 $500\,\mathrm{Hz}$，最高 forcing 频率 $80\,\mathrm{Hz}$ 低于 Nyquist 频率；
4. 高分辨率到模型网格的抗混叠滤波器配置在全部轨线与通道中一致；
5. `duffing_hf_augaut` 与 `duffing_hf_addc` 在相同 matched key 下的 clean physical trajectory 在数值容差内一致；
6. `duffing_hf_bilinc` 的瞬时有效线性刚度同时取正值与负值；
7. BIL 的有限差分控制灵敏度与 $[0,\rho_k kx/m]^\top$ 一致，且随 $x$ 改变；
8. BIL 通过第 8.7 节定义的首尾持续性、连续滑动窗、做功--耗散、BIL--ADD 差异、高频尾能量、有限性与状态上界门槛；
9. 若启用 noise10 view，噪声只作用于 $x,p$，并且 empirical SNR 接近 $10\,\mathrm{dB}$。

---

# 15. 数值合法性与轨线拒绝规则

若发生以下任一情况，轨线生成失败：

1. ODE solver 返回失败状态；
2. 出现 NaN 或 Inf；
3. 状态超出配置允许的 physical domain；
4. forcing 超出全局配置的安全幅值；
5. source norm 违反理论守恒范围；
6. 单摆嵌入的 clean unit-circle residual 超过容差；
7. matched key 或 split metadata 缺失；
8. control role 与 learner interface 不一致。

失败轨线不得静默删除后继续使用原编号。必须记录：

```text
rejected = true
rejection_reason = "..."
```

并使用新的 trajectory id 重新生成。

---

# 16. 参数包与版本管理

## 16.1 底座参数包

每个底座的参数必须独立保存：

### Linear oscillator

$$
\boxed{
\Pi_{\mathrm{LIN}}
=
\left(
\omega_0,
\zeta,
b_c,
\alpha_c
\right).
}
$$

### Duffing

$$
\boxed{
\Pi_{\mathrm{DUF}}
=
\left(
m,
d,
k,
k_c,
b_c,
\alpha_c
\right).
}
$$

### Van der Pol

$$
\boxed{
\Pi_{\mathrm{VDP}}
=
\left(
\mu,
\omega_0,
b_c,
\alpha_c
\right).
}
$$

### Pendulum

$$
\boxed{
\Pi_{\mathrm{PEN}}
=
\left(
d,
g,
\ell,
b_c,
\alpha_c
\right).
}
$$

### High-frequency strong-hardening Duffing

$$
\boxed{
\Pi_{\mathrm{DUF\text{-}HF}}
=
\left(
m,
d,
k,
k_c,
A_{\mathrm{HF}},
\rho_k,
f_{\mathrm b},
\mathcal F_{\mathrm{HF}},
\{\phi_j\}_{j=1}^{J_{\mathrm{HF}}},
\kappa_{\mathrm{HF}}
\right).
}
$$

canonical 数值为

$$
\boxed{
m=1,
\quad d=40,
\quad k=3\times10^3,
\quad k_c=5\times10^8,
\quad A_{\mathrm{HF}}=20,
\quad \rho_k=12.
}
$$

同一个底座的三个 role 分支必须共享 $m,d,k,k_c$、初值 bank、source realization 与时间包。AUG/ADD 使用 $A_{\mathrm{HF}}c_{\mathrm{HF}}(t)$ 的同一加性物理母轨线；BIL 不使用 $A_{\mathrm{HF}}$ 加性通道，而使用 $\rho_k$ 指定的纯刚度调制。

---

## 16.2 source 参数包

定义统一 source 配置接口

$$
\boxed{
\Pi_{\mathrm{source}}^{(r)}
=
\left(
\Pi_{\mathrm{source\ dynamics}}^{(r)},
C_r,
\Pi_{q_0}^{(r)},
\Pi_{\mathrm{source\ realization}}^{(r)}
\right).
}
$$

默认 harmonic exosystem 保存

$$
\left(
J_q,
\{\omega_j\}_{j=1}^{J_q},
\mathbf c_q,
\{\rho_{j,\min},\rho_{j,\max}\}_{j=1}^{J_q},
\Pi_{\phi},
\Pi_{q_0\text{-seed}}
\right).
$$

phase-locked multisine 额外保存

$$
\left(
f_{\mathrm b},
\mathcal F_{\mathrm{HF}},
\{k_j\}_{j=1}^{J_{\mathrm{HF}}},
\{a_j\}_{j=1}^{J_{\mathrm{HF}}},
\{\widetilde a_j\}_{j=1}^{J_{\mathrm{HF}}},
\{\phi_j\}_{j=1}^{J_{\mathrm{HF}}},
\kappa_{\mathrm{HF}},
\Pi_{\vartheta_0\text{-seed}}
\right).
$$

---

## 16.3 一般对象参数版本化与高频 Duffing 的冻结 profile

对前四个底座，本文主要定义结构和配置字段，不把某组具体物理参数提升为所有实验的唯一规范值。高频强硬化 Duffing 是由旧 `duffing_aug_snr10` 迁入并经过 BIL 物理持续性修订的固定 benchmark profile，因此其物理参数、加权频率集合、采样间隔、轨线时长、split 数量与验收门槛在本协议中冻结。

每一批数据必须绑定一个版本化参数文件：

```text
base_parameter_version = "..."
source_parameter_version = "..."
time_parameter_version = "..."
noise_parameter_version = "..."
```

参数值改变时，必须生成新的数据 artifact version，但无需改变 15 个数学对象的主代号。高频 Duffing 若改变其冻结 profile，应显式升级 `base_parameter_version`、`source_parameter_version` 或 `time_parameter_version`。

当前正式版本固定为

```text
artifact_version = "v3"
base_parameter_version = "duffing_hf_base-v3"
source_parameter_version = "duffing_hf_source-v2"
time_parameter_version = "duffing_hf_time-v1"
noise_parameter_version = "duffing_hf_noise-v1"
```

其中 source v2 表示加入 $17.5\,\mathrm{Hz}$ 并对 $9\,\mathrm{Hz}$ 与 $17.5\,\mathrm{Hz}$ 加权；base v3 表示 BIL 深度 $\rho_k=12$ 与连续滑动窗验收共同冻结。

---

# 17. 推荐目录结构

```text
controlled_lowdim/
├── shared/
│   ├── source_config.yaml
│   ├── split_manifest.json
│   ├── physical_initial_banks.npz
│   ├── source_initial_bank.npz
│   └── generation_environment.json
├── linosc/
│   ├── linosc_augaut/
│   ├── linosc_addc/
│   └── linosc_bilinc/
├── duffing/
│   ├── duffing_augaut/
│   ├── duffing_addc/
│   └── duffing_bilinc/
├── vdp/
│   ├── vdp_augaut/
│   ├── vdp_addc/
│   └── vdp_bilinc/
├── pendulum/
│   ├── pendulum_augaut/
│   ├── pendulum_addc/
│   └── pendulum_bilinc/
└── duffing_hf/
    ├── shared_fourier_realization.json
    ├── duffing_hf_augaut/
    ├── duffing_hf_addc/
    └── duffing_hf_bilinc/
```

每个数据对象目录建议包含：

```text
clean.npz
observed.npz              # 仅在 noise.enabled=true 时存在
metadata.json
parameters.yaml
trajectory_manifest.csv
generation_report.md
```

---

# 18. 面向 K2/K3、F2/F3 与双线性模型的导出接口

## 18.1 K2/K3 导出

只允许从 `augaut` 导出：

$$
\boxed{
\left\{
\mathbf z_{\mathrm{aug},m}^{(\nu)}
\right\}_{m=0}^{M_{\mathrm{state}}-1}.
}
$$

不导出显式 forcing channel。

---

## 18.2 F2 导出

只允许从 `addc` 导出正式训练资源：

$$
\boxed{
\left\{
\left(
\mathbf z_m^{(\nu)},
\mathbf v_m^{(\nu)},
\mathbf z_{m+1}^{(\nu)}
\right)
\right\}.
}
$$

`bilinc` 可导出同结构字段，但 metadata 必须阻止其被误标为 F2 正式适配对象。

---

## 18.3 F3 导出

从 `addc` 导出 trajectory windows：

$$
\boxed{
\left(
\mathbf z_s^{(\nu)},
\{\mathbf v_{s+\ell}^{(\nu)}\}_{\ell=0}^{h_{\max}-1},
\{\mathbf y_{s+h}^{(\nu)}\}_{h\in\mathcal H_{\mathrm{roll}}}
\right).
}
$$

未来 forcing schedule 必须来自保存的 clean source trajectory，或先由

$$
\mathbf q_{m+1}
=
e^{\mathbf S\tau_r}\mathbf q_m
$$

推进 source state，再通过冻结 output map $C_r$ 解析生成。

---

## 18.4 双线性模型导出

从 `bilinc` 导出：

$$
\boxed{
\left(
\mathbf z_m,
\mathbf v_m,
\mathbf z_{m+1},
\Pi_{\mathrm{bilinear\ channel}}
\right).
}
$$

其中

$$
\Pi_{\mathrm{bilinear\ channel}}
$$

必须标明：

```text
linosc: stiffness_modulation_x
duffing: linear_stiffness_modulation_x
vdp: damping_modulation_p
pendulum: damping_modulation_omega
duffing_hf: relative_linear_stiffness_modulation_x
```

---

# 19. 诊断与生成报告

每个数据对象的 generation report 至少记录：

1. 轨线数量、长度、采样间隔与总物理时间；
2. physical initial state 与 source initial state 的覆盖范围；
3. forcing 的均值、标准差、峰值、频率支撑与区间平均统计；
4. state--forcing 相关系数与控制 feature Gram 条件数；
5. train/validation/test 的轨线数量；
6. 轨线拒绝数与原因；
7. clean state 的范围与能量统计；
8. 单摆的单位圆残差；
9. noise 是否启用、作用通道、尺度来源与 seed；
10. 每个底座三个 role 分支之间的 matched key 覆盖率；
11. zero-control 退化测试；
12. additivity/bilinearity finite-difference test。

对 forcing feature matrix

$$
\mathbf V
=
\begin{bmatrix}
\mathbf v_1&\cdots&\mathbf v_M
\end{bmatrix},
$$

至少记录经验 Gram：

$$
\boxed{
\mathbf G_{\mathrm v}
:=
\frac1M
\mathbf V\mathbf V^\top.
}
$$

若

$$
\operatorname{rank}(\mathbf G_{\mathrm v})<d_v,
$$

则必须在报告中标记 forcing excitation deficiency。

---

# 20. Canonical 配置模板

```toml
[dataset]
protocol = "KSF-D1"
base_system = "duffing"      # linosc | duffing | vdp | pendulum | duffing_hf
control_role = "additive"    # augmented_autonomous | additive | bilinear
artifact_version = "v1"

[time]
sample_interval = 0.01
trajectory_duration = 20.0
max_internal_step = 0.001
solver = "adaptive_high_order"
rtol = 1.0e-9
atol = 1.0e-11

[source]
mode = "finite_dimensional_harmonic_exosystem"
num_modes = 2
angular_frequencies = [1.0, 2.5]
output_vector = "configured"
initial_amplitude_range = "configured"
initial_phase_distribution = "uniform"
global_scale_only = true

[forcing]
feature_mode = "scalar_interval_average"  # or source_state
save_left_value = true
save_mid_value = true
save_interval_average = true
save_source_state = true
forcing_into_state_encoder = false

[initial_conditions]
physical_bank = "configured"
source_bank = "configured"
pairing = "partial_cartesian"
require_same_state_different_forcing = true
require_same_forcing_different_state = true

[split]
unit = "trajectory"
reuse_manifest_across_roles = true
new_state_test = true
new_forcing_test = true

[noise]
enabled = false
model = "additive_gaussian"
apply_to = ["learner_state"]
scale_mode = "external"
scale_values = []
reference = "clean_training_split"
temporal_correlation = "iid"
target_mode = "clean_target"
control_noise = false
source_state_noise = false
seed = 0

[storage]
save_clean = true
save_observed = true
save_raw_physical_state = true
save_metadata = true
save_generation_report = true
```

对 `augaut`，配置加载器必须自动强制：

```toml
forcing.forcing_into_state_encoder = false
forcing.feature_mode = "audit_only"
```

并将 source state 拼入 autonomous learner state。

对 `bilinc`，配置加载器必须要求：

```toml
bilinear.channel = "explicitly_configured"
```


高频强硬化 Duffing 使用以下冻结 override：

```toml
[dataset]
base_system = "duffing_hf"
artifact_version = "v3"
base_parameter_version = "duffing_hf_base-v3"
source_parameter_version = "duffing_hf_source-v2"
time_parameter_version = "duffing_hf_time-v1"
noise_parameter_version = "duffing_hf_noise-v1"

[time]
sample_interval = 0.002
trajectory_duration = 4.0
endpoint_policy = "half_open"
sim_sample_rate = 2000
model_sample_rate = 500
max_internal_step = 0.0005
resample_method = "zero_phase_windowed_sinc_fir_then_decimate_by_4"
anti_alias_taps = 129
anti_alias_cutoff_hz = 225.0
solver = "local_adaptive_dopri5"
rtol = 1.0e-10
atol = 1.0e-12

[source]
mode = "phase_locked_multisine_exosystem"
output_mode = "nonlinear_periodic_readout"
base_frequency_hz = 0.5
frequencies_hz = [5, 7.5, 9, 12, 16, 17.5, 20, 25,
                  30, 35, 40, 50, 60, 65, 70, 80]
harmonic_weights = [1, 1, 2, 1, 1, 2, 1, 1,
                    1, 1, 1, 1, 1, 1, 1, 1]
num_modes = 16
fourier_phase_realization = "fixed_global"
fourier_phase_seed = 2026061701
phase_initial_seed = 2026061702
unit_peak_normalization = true
additive_force_amplitude = 20.0

[base]
mass = 1.0
damping = 40.0
linear_stiffness = 3.0e3
cubic_stiffness = 5.0e8
bilinear_relative_stiffness_depth = 12.0
bilinear_stiffness_form = "k*(1-rho_k*c_hf)"
state_abs_limit = 10.0

[bilinear_pilot]
candidate_relative_stiffness_depths = [10, 12, 14, 16, 18, 20]
selection_rule = "smallest_candidate_passing_all_physical_gates"
selected_relative_stiffness_depth = 12.0
pilot_training_trajectories = 64
persistence_ratio_bounds = [0.2, 5.0]
minimum_passing_fraction = 0.5
work_damping_ratio_bounds = [0.1, 10.0]
minimum_bilinear_additive_relative_frobenius = 0.1
minimum_tail_high_frequency_energy_ratio = 1.0e-4
tail_high_frequency_cutoff_hz = 20.0
continuous_window_seconds = 0.5
continuous_window_stride_seconds = 0.1
minimum_window_relative_rms = 0.1
minimum_window_passing_fraction = 0.75

[initial_conditions]
position_range = [-5.0e-3, 5.0e-3]
velocity_range = [-0.3, 0.3]
phase_distribution = "uniform"

[split]
train_trajectories = 512
validation_trajectories = 128
test_trajectories = 128

[noise]
enabled = false
recommended_view = "snr10_physical_channels_only"
```

---

# 21. 最终规范

本文的 15 个对象构成以下测试矩阵：

$$
\boxed{
\begin{array}{c|ccc}
&\mathsf{AUG}&\mathsf{ADD}&\mathsf{BIL}\\
\hline
\mathsf{LIN}&
\texttt{linosc\_augaut}&
\texttt{linosc\_addc}&
\texttt{linosc\_bilinc}
\\
\mathsf{DUF}&
\texttt{duffing\_augaut}&
\texttt{duffing\_addc}&
\texttt{duffing\_bilinc}
\\
\mathsf{VDP}&
\texttt{vdp\_augaut}&
\texttt{vdp\_addc}&
\texttt{vdp\_bilinc}
\\
\mathsf{PEN}&
\texttt{pendulum\_augaut}&
\texttt{pendulum\_addc}&
\texttt{pendulum\_bilinc}
\\
\mathsf{DUF\text{-}HF}&
\texttt{duffing\_hf\_augaut}&
\texttt{duffing\_hf\_addc}&
\texttt{duffing\_hf\_bilinc}
\end{array}
}
$$

其固定语义为：

$$
\boxed{
\mathsf{AUG}
\Longrightarrow
\text{外部信号源状态已进入完整自治状态，禁止再暴露 forcing input};
}
$$

$$
\boxed{
\mathsf{ADD}
\Longrightarrow
\text{控制方向在物理 vector field 中与状态无关，服务当前 F2/F3};
}
$$

$$
\boxed{
\mathsf{BIL}
\Longrightarrow
\text{控制灵敏度显式依赖状态，服务未来双线性 KDSMc}.
}
$$

噪声的固定语义为：

$$
\boxed{
\text{噪声是 clean data 上的可选 observation operator，}
}
$$

$$
\boxed{
\text{不改变物理动力学、不产生新数据集代号；}
}
$$

$$
\boxed{
\text{高频强硬化 Duffing 可额外导出与旧数据对齐的 }10\,\mathrm{dB}\text{ observation view}.
}
$$

由此，模型性能差异可以分别归因于：

$$
\boxed{
\text{自治增广信息接口},
\qquad
\text{加性输入建模能力},
\qquad
\text{双线性状态--控制交互能力},
\qquad
\text{测量噪声鲁棒性},
\qquad
\text{高频强硬化动力学下的时间分辨率与受控预测能力}.
}
$$

五类底座分别承担：

$$
\boxed{
\begin{aligned}
\mathsf{LIN}:&\quad \text{线性实现与受控时间对齐基线};\\
\mathsf{DUF}:&\quad \text{一般非线性恢复力与 Duffing 结构};\\
\mathsf{VDP}:&\quad \text{非线性耗散与极限环结构};\\
\mathsf{PEN}:&\quad \text{周期状态空间与流形观测结构};\\
\mathsf{DUF\text{-}HF}:&\quad
\text{宽频强迫、强硬化恢复力、短时高采样率与高频控制作用}.
\end{aligned}
}
$$

因此，KSF-D1 为后续自治 Koopman、加性 KDSMc 与双线性受控 Koopman 模型提供一个语义隔离、数据匹配、跨时间尺度、可扩展且可审计的低维基准数据层。
