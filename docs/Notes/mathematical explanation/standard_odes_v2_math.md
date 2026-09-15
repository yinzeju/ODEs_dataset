---
title: TestSub-1. lowdim_nonlinear_v1_math
aliases:
  - TestSub-1
  - TestSub1
  - Standard_ODEs_v2
  - Autonomous ODE Canonical and Conditional Data Protocol
  - 自治 ODE 标准工况与隐条件辨识数据协议
status: active
type: mathematical-protocol
parent:
  - "[[Koopman Learning Project Guide]]"
related:
  - "[[Notation-Core Convention]]"
  - "[[Notation-Standard Convention]]"
  - "[[SKDM-Backbone-Guidance]]"
  - "[[SKDM-K3-Multi-step Predictive SKDM]]"
  - "[[SKDM-K3.4.2-SSM Hidden-Parameter Koopman Operator Manifold]]"
  - "[[SKDM-K3.4.3-From Conditional EDMD to Hidden-Parameter SKDM]]"
  - "[[SKDM-MAG0-Koopman Learning Measure and Projection Geometry]]"
  - "[[SKDM-MAG1-Empirical Batch Moment Package Contract]]"
  - "[[SKDM-K3.3-HDMD Pre-identification Base]]"
  - "[[SKDM-SP2-Polar SpecEnv]]"
  - "[[KSR-R1-Streaming Sparse Prediction-Optimal KMD Readout Refit]]"
  - "[[TestSub-2. One-Dimensional PDE Data Protocol]]"
  - "[[TestSub-3. controlled_lowdim_v1]]"
updated: 2026-09-15
---

# TestSub-1：自治 ODE 标准工况与参数化工况族
## 全状态轨线、初值分布、可辨识条件、数值生成与参考文献

> [!abstract] 协议定位
> `Standard_ODEs_v2` 将 ODE 资源分成两个独立层级：固定工况基准 `CAN` 与参数化工况族 `COND`。保留三个线性检查对象、两档 Duffing、非线性摆、Lorenz63 和 Rössler，加入 autonomous Van der Pol、Axås–Haller 两自由度非线性弹簧振子和 32 自由度 FPUT–β 链。
>
> 每个对象分别声明完整方程、固定参数、可变工况、初值分布、观测方式、时间网格、数值资格和数据划分。工况改变向量场；初值、轨道能量、相位、噪声强度和采样间隔分别登记，不混入同一个工况标签。
>
> 本文是数据协议，不是 K3、条件辨识器或 SSM 算法。文献给出的物理模型与本文设计的多初值人口、条件区间、split 和计算预算明确分开。数值参数是待生成数据执行的规范，不表示这些新数据已经通过数值验收。

# 0. 对象清单、来源与研究边界

## 0.1 十个方程族与十一个固定工况配置

| 方程族 | 固定配置 ID | 状态维数 $d_x$ | 固定工况基准 | 首版条件研究 |
|---|---|---:|---|---|
| 实对角线性系统 | `linear_diagonal` | 4 | 指定实增长／衰减率 | 固定检查对象 |
| 旋转收缩系统 | `linear_rotation_contraction_2d` | 2 | 指定复共轭线性谱 | 固定检查对象 |
| 阻尼线性振子 | `damped_linear_oscillator` | 2 | $\gamma=0.05,\ \omega_0=1$ | $\omega_0$；后续可加入 $\gamma$ |
| 自治硬化 Duffing | `duffing_chi40_medium` | 2 | $\alpha=1,\delta=0.08,\beta=10,\ A_{\mathrm{IC}}=2$ | $\beta$，固定初值分布 |
| 同一 Duffing 方程族 | `duffing_chi320_strong` | 2 | $\alpha=1,\delta=0.08,\beta=20,\ A_{\mathrm{IC}}=4$ | 不以两个固定配置直接拼出条件族 |
| 非线性摆 | `nonlinear_pendulum_lusch2018` | 2 | $\omega_0=1$，无阻尼、无外力 | $\omega_0$ |
| 自治 Van der Pol | `vanderpol_autonomous_mu03` | 2 | $\mu=0.3$ | $\mu$ |
| Axås–Haller 弹簧振子 | `axas_haller_2023_2dof` | 4 | $m=k=1,c=0.03,\alpha_2=-2,\beta_3=1$ | $\beta_3$ |
| FPUT–β 固端链 | `fput_beta_32dof` | 64 | $n_{\mathrm{dof}}=32,\beta=1$ | $\beta$，固定质量、拓扑和初值分布 |
| Lorenz63 | `lorenz63_standard` | 3 | $(\sigma,\rho,\beta)=(10,28,8/3)$ | $\rho$，后续资格化扩展 |
| Rössler | `rossler_standard` | 3 | $(a,b,c)=(0.2,0.2,5.7)$ | $c$，后续资格化扩展 |

两档 Duffing 是同一方程族的两个固定配置。因此本文包含 **10 个方程族、11 个 CAN 配置**，不是 11 种互不相关的物理方程。每个 clean 配置可派生 5 dB、15 dB 观测视图；噪声视图不增加动力系统数量。

## 0.2 三类来源身份

本文用以下规则解释参考文献。

**文献模型。** Van der Pol 的 $\mu=0.3$ 采用 Mauroy–Mezić 的自治算例；两自由度振子采用 Axås–Haller 2023 第 4.1 节及官方脚本的力学定义；FPUT 采用固定边界的 β 模型，并以 Marchetti 2025 及其公开轨线为现代复现锚点。[^vdp] [^ah] [^ah-code] [^fput]

**项目固定配置。** 两档 Duffing 的具体参数和初值尺度、线性系统数值参数、已有轨线预算与摆的短轨采样口径来自项目现有 TestSub-1。它们有明确方程，但不被表述为外部社区唯一标准数据集。摆的 `lusch2018` 表示物理模型与研究问题的文献来源，不表示本文的 8192 条轨线、拒绝采样边界和求解器逐项复制原论文。[^lusch] [^duffing]

**本文新增实验设计。** 条件区间、统一参数网格、多初值分布、安全采样集、留出规则、噪声标定和新对象的训练规模均为本协议定义；它们不是引文中的原始训练人口，也不是已验证的最优设置。

## 0.3 不进入本协议的对象

本文只处理轨线内参数固定、无外部控制的有限维自治 ODE。显式 forcing、受控摆、受迫 Duffing 与信号源增广属于 [[TestSub-3. controlled_lowdim_v1]]。PDE 空间离散数据仍按 TestSub-2 等协议组织。机器人、可变拓扑机械系统和 GNN 任务不纳入本版。

FPUT 虽具有一维近邻连接，其质量块数是物理自由度数，不解释为 PDE 网格分辨率。本文不要求某个 backbone；首轮可以直接使用完整状态向量比较 MLP 与 KAN 字典。

# 1. 数学对象与记号

## 1.1 系统族、完整状态与流

用 $\mathfrak s$ 表示方程族，避免与预测起点 $s$ 混淆。对固定方程族，设

$$
\mathbf x\in\mathcal X_{\mathfrak s}\subseteq\mathbb R^{d_x},
\qquad
\boldsymbol\kappa\in\Theta_{\kappa,\mathfrak s},
\qquad
\dot{\mathbf x}=\mathbf f_{\mathfrak s,\boldsymbol\kappa}(\mathbf x).
$$

假设向量场在所用区域局部 Lipschitz，并且所有正式轨线在声明的生成区间内存在、唯一且有限。存在局部适用域的力学模型需单独证明或验收轨线不会离开该区域，不由“多项式 ODE”推出全局有界性。

流映射及采样动力学为

$$
\mathbf F_{\mathfrak s,\boldsymbol\kappa}^{t},
\qquad
\mathbf x_{m+1}^{(\nu)}
=\mathbf F_{\mathfrak s,\boldsymbol\kappa^{(\nu)}}^{\tau}
(\mathbf x_m^{(\nu)}),
\qquad
\boldsymbol\kappa_m^{(\nu)}\equiv\boldsymbol\kappa^{(\nu)}.
$$

$\nu$ 为轨线索引，$m$ 为快照索引，$s$ 为预测截止／起点，$h$ 为预测步数，$n$ 为字典或谱分量索引。$n_{\mathrm{dof}}$ 表示机械自由度数；不使用 K3 的谱维数 $N$ 表示质量块数。

本版统一以 $M$ 表示一条记录的**快照数**，以

$$
M_{\mathrm{tr}}:=M-1
$$

表示一步转移数。时间索引为 $m=0,\ldots,M-1$；artifact 中分别保存 `snapshot_count` 和 `transition_count`。

## 1.2 完整参数记录与可变工况坐标

每条轨线保存完整物理配置 $\boldsymbol\kappa$，包括固定系数。条件研究再通过冻结的字段选择适配器给出

$$
\mathbf u_\kappa=\mathscr M_\kappa(\boldsymbol\kappa)
\in\mathbb R^{d_\kappa}.
$$

例如 Duffing 的完整配置包含 $(\alpha,\delta,\beta)$，首版可变坐标只取 $\mathbf u_\kappa=[\beta]$。固定系数不是缺失字段，也不作为零方差分量直接进行标准化。

参数适配器、字段顺序、单位和数值精度在生成前固定。方程族 ID、质量块数、边界类型、观测定义和时间单位属于模型解释；改变这些对象通常产生新的方程族／配置版本，而不是同一标量条件轴上的插值。

## 1.3 物理条件、初值与不变量

本协议的物理工况轴索引向量场变化：

$$
\boldsymbol\kappa\longmapsto
\mathbf f_{\mathfrak s,\boldsymbol\kappa}
\longmapsto
\mathbf F_{\mathfrak s,\boldsymbol\kappa}^{\tau}.
$$

初值 $\mathbf x_0$、初始能量、模态激发比例和相位决定同一系统内的轨道，不自动成为可变物理系数。初值分布参数单独放入 $\Pi_{\mathrm{IC}}$；噪声、采样和求解器参数分别放入 $\Pi_{\mathrm{noise}}$、$\Pi_{\mathrm{time}}$、$\Pi_{\mathrm{solver}}$。

这一约定针对**物理参数族**。将同一 Hamiltonian 系统限制到不同能量面，也可以构造另一类条件化研究，但那是 invariant-component／orbit-conditioned 任务，不与本版 `COND` 的物理工况辨识混合计分。[^mag0]

# 2. CAN 与 COND 的独立身份

## 2.1 固定工况基准 CAN

每个 CAN 配置固定

$$
\boldsymbol\kappa^{(\nu)}=\boldsymbol\kappa^\star,
\qquad
\mathbf x_0^{(\nu)}\sim\rho_0^{\mathrm{CAN}}.
$$

不同算法读取相同的完整轨线、观测视图和冻结数据划分。此层主要检验固定系统上的新初值预测、数值谱检查和观测噪声鲁棒性。

不同 CAN 配置不因此共享同一个训练后模型或 normalizer。尤其，两档 Duffing 同时改变 $\beta$ 与初值尺度，其比较是两种非线性暴露场景，而不是受控的单参数消融。

## 2.2 参数化工况族 COND

在一个固定方程族内选定有限条件集合

$$
\mathcal C=\{1,\ldots,C\},
\qquad
\boldsymbol\kappa_c\in\Theta_{\kappa,\mathfrak s},
\qquad
\mathcal R_c=\{\nu:\boldsymbol\kappa^{(\nu)}=\boldsymbol\kappa_c\}.
$$

每个条件包含多条初值不同的独立轨线。首版主测试使用同一个原坐标初值分布：

$$
\boxed{
\rho_{0\mid\boldsymbol\kappa_c}^{\mathrm{COND}}
=\rho_0^{\mathrm{COND}},\qquad c\in\mathcal C.
}
$$

在理论生成模型中，这对应

$$
\operatorname{Law}(K_\kappa,X_0)
=\pi_\kappa\otimes\rho_0^{\mathrm{COND}},
\qquad
\pi_\kappa=\sum_{c=1}^{C}\pi_c\delta_{\boldsymbol\kappa_c}.
$$

这里 $K_\kappa$ 与 $X_0$ 是随机工况、随机初态；下标完整的 $\pi_\kappa$ 是工况质量，不是 Koopman 谱。

这一独立性发生在初始抽样阶段，不要求后续 $\mathbf x_m$ 与工况独立。不同动力学自然产生不同占据分布，历史辨识器可以利用这种真实动力学信息。不能把所有状态幅值差异一概视为泄漏。

## 2.3 固定物理时间与固定坐标

同一 COND 族共用 $\tau$、时间单位、通道顺序和原坐标定义。不按每个条件重新选择采样间隔，不把每条轨线重采样为“每周期相同帧数”，也不利用真实条件把速度或时间归一化为条件无关系统。

例如摆的 $\omega_0$ 辨识必须在同一个时间单位下进行。使用条件相关的 $t'=\omega_0t$ 和 $p'=p/\omega_0$ 会改变辨识任务，且部署时需要未知参数。

## 2.4 对条件 Koopman 的解释边界

固定条件下，对合法可观测函数 $g$ 定义

$$
(\mathcal K_{\boldsymbol\kappa}^{\tau}g)(\mathbf x)
:=g\bigl(\mathbf F_{\boldsymbol\kappa}^{\tau}(\mathbf x)\bigr).
$$

若 $g$ 可微，生成元为

$$
\mathcal L_{\boldsymbol\kappa}g
=Dg[\mathbf f_{\boldsymbol\kappa}].
$$

本协议不预设不同条件一定具有不同的点谱，也不从相同线性化谱推出相同的非线性 Koopman 算子。Duffing、Axås–Haller 和 FPUT 的非线性系数变化可以保持原点线性化不变；条件依赖可能主要体现在谱函数与读出，而不一定体现为每个 $\lambda_n$ 都变化。有限维对角谱与线性读出的适用性由下游模型验证。[^k3] [^hp]

# 3. 观测、轨线布局与公共初值基元

## 3.1 全状态 clean 观测

采用项目观测链

$$
\mathbf x_m\xmapsto{U}\mathbf u_m
\xmapsto{S}\mathbf s_m
\xmapsto{Z}\mathbf z_m.
$$

本文的理想 clean 绑定为恒等物理观测与恒等有限维采样：

$$
\mathbf z_m^{\mathrm{clean}}=\mathbf x_m,
\qquad
\mathbf y_m^{\mathrm{clean}}=\mathbf x_m,
\qquad d_z=d_y=d_x.
$$

存储量化与数值积分带来的有限精度误差单独记录，不把磁盘 Float32 数值称为精确连续解。完整位置与速度／动量同时保存；不把只含位移的一帧观测默认为闭合状态。

## 3.2 摆的角度表示

本版无外力、无阻尼的摆只采样单个 libration 势阱。clean 状态采用该势阱内连续角度及角速度，因而保留 $d_x=d_z=2$。

不在每个时间步执行不连续的 angle wrap。若另行加入完整旋转轨道，必须另设周期观测适配器与评价度量，例如 $(\cos q,\sin q,p)$；该三通道配置不与当前两通道 CAN 数据静默混用。

## 3.3 轨线布局

数学列快照矩阵与磁盘张量分别为

$$
\mathbf X^{(\nu)}
=[\mathbf x_0^{(\nu)}\ \cdots\ \mathbf x_{M-1}^{(\nu)}]
\in\mathbb R^{d_x\times M},
$$

$$
\mathcal A^{\mathrm{state}}\in\mathbb R^{R\times M\times d_x}.
$$

固定磁盘轴顺序为 `trajectory × time × state_component`。转置、向量化和模型端适配必须可逆并有测试；条件记录按轨线索引保存，不按快照重新生成。

## 3.4 公共二维环形抽样

对无量纲的两个状态坐标，定义面积均匀的环形分布 $\operatorname{Ann}(a_{\min},a_{\max})$：

$$
U_r\sim\operatorname{Unif}[0,1],\quad
\Phi\sim\operatorname{Unif}[0,2\pi),\quad
A=\sqrt{a_{\min}^2+U_r(a_{\max}^2-a_{\min}^2)},
$$

$$
\mathbf x_0=A[\cos\Phi,\sin\Phi]^\top.
$$

半径与相位独立。若坐标保留物理单位，先声明固定的、跨条件相同的参考尺度矩阵，再从该无量纲分布映回物理坐标；不能直接把不同量纲的坐标平方相加作为物理能量。

下文 CAN 线性对象缺少完整初值法则的部分，由本协议明确补全。补全是本项目实验设计，不追溯归属于外部文献。

# 4. 三个线性检查对象

## 4.1 实对角线性系统

$$
\mathbf f(\mathbf x)=\mathbf A\mathbf x,
\qquad
\mathbf A=\operatorname{diag}(-1,-0.3,0.1,0.5),
\qquad \mathcal X=\mathbb R^4.
$$

CAN 初态取 $\rho_0=\operatorname{Unif}([-1,1]^4)$。精确传播为

$$
\mathbf x_m=e^{m\tau\mathbf A}\mathbf x_0.
$$

完整参数记录为四个连续时间线性率 $(a_1,a_2,a_3,a_4)$；本版将其条件域取为上述固定向量组成的单点集，不启用额外参数扫描。坐标可观测函数 $g_j(\mathbf x)=x_j$ 的谱满足

$$
\gamma_j=a_j,\qquad\lambda_j=e^{a_j\tau}.
$$

这些是坐标函数对应的精确谱值，不是对全部函数空间 Koopman 谱的穷尽。

## 4.2 旋转收缩系统

$$
\mathbf A=
\begin{bmatrix}-\gamma&-\omega\\\omega&-\gamma\end{bmatrix},
\qquad \gamma=0.15,\quad\omega=2\pi,
\qquad\dot{\mathbf x}=\mathbf A\mathbf x.
$$

CAN 初态取 $\operatorname{Ann}(0.5,1)$。完整参数记录为 $(\gamma,\omega)$，本版条件域为单点。精确传播为

$$
\mathbf F^\tau(\mathbf x)
=e^{-\gamma\tau}
\begin{bmatrix}
\cos(\omega\tau)&-\sin(\omega\tau)\\
\sin(\omega\tau)&\cos(\omega\tau)
\end{bmatrix}\mathbf x.
$$

线性连续率与离散特征值为 $\gamma_\pm=-\gamma\pm\mathrm i\omega$、$\lambda_\pm=e^{\tau\gamma_\pm}$。此处裸符号 $\gamma$ 是阻尼系数，带下标的 $\gamma_\pm$ 是连续时间特征率。

## 4.3 阻尼线性振子

采用单位质量状态 $\mathbf x=[q,p]^\top$；$p=\dot q$ 在此也等于动量：

$$
\dot q=p,\qquad
\dot p=-2\gamma p-\omega_0^2q,
\qquad
\mathbf A=\begin{bmatrix}0&1\\-\omega_0^2&-2\gamma\end{bmatrix}.
$$

CAN 固定 $\gamma=0.05,\omega_0=1$，初态取 $\operatorname{Ann}(0.5,1)$。首版 COND 固定 $\gamma=0.05$，取 $\omega_0\in[0.8,1.2]$，初值分布不变。

在 $0<\gamma<\omega_0$ 下，

$$
\gamma_\pm=-\gamma\pm\mathrm i\sqrt{\omega_0^2-\gamma^2},
\qquad
\lambda_\pm=e^{\tau\gamma_\pm}.
$$

令 $E=\tfrac12p^2+\tfrac12\omega_0^2q^2$，直接微分得到

$$
\frac{\mathrm dE}{\mathrm dt}
=p(-2\gamma p-\omega_0^2q)+\omega_0^2qp
=-2\gamma p^2.
$$

可选二维工况扩展为 $(\gamma,\omega_0)\in[0.025,0.075]\times[0.8,1.2]$，始终欠阻尼；该扩展另设数据版本，不自动增加首轮条件实验数量。

# 5. 自治硬化 Duffing：工况与初值尺度分离

## 5.1 方程与参数身份

$$
\mathbf x=[q,p]^\top\in\mathbb R^2,
\qquad
\dot q=p,\qquad
\dot p=-\delta p-\alpha q-\beta q^3.
$$

完整参数为 $(\alpha,\delta,\beta)$，本版固定 $\alpha=1,\delta=0.08$。无 forcing 项；不保留一个数值为零但语义不明的“forcing 参数”作为条件轴。硬化情形取 $\beta>0$。方程的力学背景见 Duffing 专著；下面两个具体配置是项目基准。[^duffing]

## 5.2 两个 CAN 配置

| 配置 | $\beta$ | 初值分布 | 暴露强度指标 |
|---|---:|---|---:|
| `duffing_chi40_medium` | 10 | $\operatorname{Ann}(1.5,2)$ | $\chi_{\mathrm{nl}}=40$ |
| `duffing_chi320_strong` | 20 | $\operatorname{Ann}(3,4)$ | $\chi_{\mathrm{nl}}=320$ |

初值尺度统一写为 $A_{\mathrm{IC}}$，旧配置键 `Q` 只作为 $A_{\mathrm{IC}}$ 的读取别名。定义

$$
\chi_{\mathrm{nl}}:=\frac{\beta A_{\mathrm{IC}}^2}{\alpha}.
$$

$\chi_{\mathrm{nl}}$ 是在指定暴露尺度上比较非线性恢复力与线性恢复力的指标，不是独立于初值分布的物理系数。artifact 分别保存 `beta`、`ic_amplitude_scale` 和 `nonlinearity_exposure_index`。

## 5.3 COND 配置

首版取

$$
\boxed{
\mathbf u_\kappa=[\beta],\qquad
\beta\in[5,25],\qquad
\rho_0^{\mathrm{COND}}=\operatorname{Ann}(1.5,2).
}
$$

每个 $\beta$ 使用相同初值法则，不随 $\beta$ 放大或缩小初始半径。原点 Jacobian 为

$$
D\mathbf f_\beta(\mathbf0)
=\begin{bmatrix}0&1\\-1&-0.08\end{bmatrix},
$$

与 $\beta$ 无关，而

$$
\partial_\beta\mathbf f_\beta(q,p)
=[0,-q^3]^\top.
$$

因此该条件轴专门检验有限振幅下的非线性规律辨识。小幅后期片段可能对 $\beta$ 很不敏感，不以低幅拟合好坏代替完整条件辨识资格。

## 5.4 能量与数值资格

$$
E_\beta(q,p)
=\frac12p^2+\frac12\alpha q^2+\frac14\beta q^4,
\qquad
\frac{\mathrm dE_\beta}{\mathrm dt}=-\delta p^2\le0.
$$

在 $\alpha>0,\beta>0$ 下，能量对状态强制增长，其子水平集有界。CAN 与 COND 都保存初始能量，但不把 $E_\beta(\mathbf x_0)$作为条件输入或标签。改变 $\beta$ 时，即使原坐标初态相同，真实总能量也可以不同；这是系统定义的结果，不通过条件相关重缩放消除。

# 6. 非线性摆：保守轨道与频率工况

## 6.1 方程与可辨识参数组合

$$
\mathbf x=[q,p]^\top,
\qquad
\dot q=p,\qquad
\dot p=-\omega_0^2\sin q,
\qquad\omega_0^2=g/\ell.
$$

$q$ 为相对下垂平衡的角度，$p$ 为角速度。仅由这两个状态及已知时间轴，方程直接识别的是 $g/\ell$，而不是独立的 $g$ 与 $\ell$。本版采用 $\omega_0>0$ 作为条件坐标，避免把结构不可辨识的参数分量同时列为独立标签。

## 6.2 CAN：Lusch 相关的短轨配置

固定 $\omega_0=1$，定义

$$
H(q,p)=\frac12p^2-\cos q.
$$

从矩形 $[-3.1,3.1]\times[-2,2]$ 均匀提议并拒绝不满足 $H(q,p)<0.99$ 的初态。保留项目的 $\tau=0.02$、$t\in[0,1]$ 与 51 帧短轨结构。

该配置属于无阻尼 Hamiltonian 摆；Lusch 等人的论文提供其 Koopman 学习研究背景。这里的具体有限样本数与采样人口按本协议生成，不声称与原论文数据逐条相同。[^lusch]

## 6.3 COND：共同原坐标初值支撑

固定

$$
\omega_0\in[\omega_{\min},\omega_{\max}]=[0.8,1.2].
$$

定义移位机械能和分离轨能量：

$$
E_{\omega_0}(q,p)
=\frac12p^2+\omega_0^2(1-\cos q),
\qquad E_{\mathrm{sep}}(\omega_0)=2\omega_0^2.
$$

本协议的主条件人口为：从 $[-3.1,3.1]\times[-1.6,1.6]$ 均匀提议，只保留

$$
\frac{p^2}{4\omega_{\min}^2}
+\frac{1-\cos q}{2}<0.95.
$$

接受规则只使用预声明的全族下界 $\omega_{\min}$，不读取当前工况。因为

$$
\frac{E_{\omega_0}(q,p)}{2\omega_0^2}
=\frac{p^2}{4\omega_0^2}+\frac{1-\cos q}{2}
\le
\frac{p^2}{4\omega_{\min}^2}+\frac{1-\cos q}{2},
$$

同一初值分布对全族都位于同一 libration 势阱内，并留有共同的分离轨裕度。

**能量配平的口径。** 固定相对能量 $E/E_{\mathrm{sep}}$ 的分布有助于匹配不同工况的相对轨道区域，但通常使原坐标角速度分布随 $\omega_0$ 缩放。因此“相对能量配平”不等于“初值与工况独立”。它只能作为独立的 `energy_matched` 辅助人口，不替代上述主条件测试。

## 6.4 守恒与频率解释

$$
\frac{\mathrm dE_{\omega_0}}{\mathrm dt}
=p(-\omega_0^2\sin q)+\omega_0^2\sin q\,p=0,
\qquad
\partial_{\omega_0}\mathbf f=[0,-2\omega_0\sin q]^\top.
$$

不同能量轨道具有不同振动周期，但在固定 $\omega_0$ 时仍属于同一物理系统。CAN 的 1 个时间单位短轨不作为“已经覆盖整周期”的保证；条件辨识和长时相位诊断使用单独的较长 COND 记录。

# 7. Autonomous Van der Pol

## 7.1 文献模型与固定工况

采用

$$
\mathbf x=[q,p]^\top\in\mathbb R^2,
\qquad
\dot q=p,\qquad
\dot p=\mu(1-q^2)p-q.
$$

CAN 取 $\mu^\star=0.3$，对应 Mauroy–Mezić 2012 第 III.B 节的自治 Van der Pol 算例。其原论文研究等时相线与 Koopman 特征函数；本文借用方程和该参数，不复制原论文的等时相线计算网格。[^vdp]

## 7.2 初值与条件轴

CAN 与首版 COND 均采用跨条件相同的混合人口

$$
\rho_0
=\frac12\operatorname{Ann}(0.5,1.5)
+\frac12\operatorname{Ann}(2.5,3.5).
$$

两个半径层用于提供不同振幅的启动轨线，不作为未知条件的代理标签，也不声称环形边界等于真实极限环。

首版工况为

$$
\mathbf u_\kappa=[\mu],\qquad\mu\in[0.1,0.9].
$$

整段轨线从启动时刻保存，不执行统一 burn-in 后再删除全部暂态。更大的 $\mu$ 与强松弛振荡属于单独扩展，需要重新资格化时间步与历史长度；不把奇异摄动形式的参数直接当作这里的 $\mu$。[^vdp-sp]

## 7.3 诊断恒等式

对 $E_0=\tfrac12(q^2+p^2)$，

$$
\frac{\mathrm dE_0}{\mathrm dt}
=\mu(1-q^2)p^2.
$$

它不是单调衰减能量。数值生成检查有限性、积分收敛及暂态／周期段覆盖，不以机械耗散系统的单调能量门禁验收 Van der Pol。

$$
\partial_\mu\mathbf f=[0,(1-q^2)p]^\top,
\qquad
D\mathbf f_\mu(\mathbf0)
=\begin{bmatrix}0&1\\-1&\mu\end{bmatrix}.
$$

该工况轴同时改变原点线性化与非线性阻尼，与“线性化完全相同”的 Duffing 条件轴区分。极限环附近的相位和横向衰减可作为谱诊断对象，但不把相位本身作为 $\mu$ 标签。

# 8. Axås–Haller 2023 两自由度非线性弹簧振子

## 8.1 官方模型及状态顺序

令

$$
\mathbf q=[q_1,q_2]^\top,\qquad
\mathbf p=[p_1,p_2]^\top=\dot{\mathbf q},\qquad
\mathbf x=[q_1,q_2,p_1,p_2]^\top\in\mathbb R^4.
$$

取

$$
\mathbf L_{\mathrm{mech}}
=\begin{bmatrix}2&-1\\-1&2\end{bmatrix},\quad
\mathbf M_{\mathrm{mech}}=\mathbf I_2,\quad
\mathbf K_{\mathrm{mech}}=\mathbf L_{\mathrm{mech}},\quad
\mathbf C_{\mathrm{mech}}=c\mathbf L_{\mathrm{mech}}.
$$

两个质量都与地面连接，质量之间也有连接；三个连接均带线性阻尼。左接地弹簧带二次恢复力，质量间弹簧带三次恢复力。完整方程为

$$
\dot{\mathbf q}=\mathbf p,
$$

$$
\dot{\mathbf p}
=-\mathbf C_{\mathrm{mech}}\mathbf p
-\mathbf K_{\mathrm{mech}}\mathbf q
-\begin{bmatrix}
\alpha_2q_1^2+\beta_3(q_1-q_2)^3\\
-\beta_3(q_1-q_2)^3
\end{bmatrix}.
$$

CAN 参数为

$$
\boxed{m=k=1,\quad c=0.03,\quad\alpha_2=-2,\quad\beta_3=1.}
$$

展开后的加速度为

$$
\begin{aligned}
\dot p_1&=-0.06p_1+0.03p_2-2q_1+q_2+2q_1^2-\beta_3(q_1-q_2)^3,\\
\dot p_2&= 0.03p_1-0.06p_2+q_1-2q_2+\beta_3(q_1-q_2)^3.
\end{aligned}
$$

力项符号与官方 `fastSSM/examples/oscillator/oscillator.m` 中的 `F = A*x - FF(x)` 一致；二次恢复力系数 $-2$ 对应第一条加速度中的 $+2q_1^2$，不能反号。[^ah] [^ah-code]

## 8.2 文献复现与本协议数据人口

原论文用位于慢二维 SSM 上的一条训练轨线。核对的官方脚本采用 `getSSMIC(...)` 构造初态、`ode45` 积分、$\Delta t=0.1$，终止时间为 250。本文保留模型及 $\tau=0.1$，但正式 SKDM 数据采用下面的四维多初值人口，并保存完整状态。二者是同一物理方程下的不同采样实验。

本协议不要求数据生成依赖 SSMTool；文献轨线可作为独立 replay 资源，不替代多初值的 CAN／COND 资源。

## 8.3 首版条件轴

固定 $m,k,c,\alpha_2$，取

$$
\mathbf u_\kappa=[\beta_3],\qquad\beta_3\in[0.5,1.5].
$$

原点线性化为

$$
\mathbf A_\star
=\begin{bmatrix}
\mathbf0&\mathbf I_2\\
-\mathbf L_{\mathrm{mech}}&-c\mathbf L_{\mathrm{mech}}
\end{bmatrix},
$$

不依赖 $\beta_3$。若 $\ell_j\in\{1,3\}$ 是 $\mathbf L_{\mathrm{mech}}$ 的特征值，其线性连续率为

$$
\gamma_{j,\pm}
=-\frac{c\ell_j}{2}
\pm\mathrm i\sqrt{\ell_j-\left(\frac{c\ell_j}{2}\right)^2}.
$$

这些仅用于线性化检查。条件敏感方向为

$$
\partial_{\beta_3}\mathbf f
=[0,0,-(q_1-q_2)^3,(q_1-q_2)^3]^\top.
$$

因此辨识该参数需要相对位移的有效激发，不能只使用两质量几乎同步运动的低幅片段。

## 8.4 能量与共同安全初值集

势能和总能量为

$$
V_{\beta_3}(\mathbf q)
=\frac12\mathbf q^\top\mathbf L_{\mathrm{mech}}\mathbf q
-\frac23q_1^3+\frac{\beta_3}{4}(q_1-q_2)^4,
$$

$$
E_{\beta_3}(\mathbf q,\mathbf p)
=\frac12\|\mathbf p\|_2^2+V_{\beta_3}(\mathbf q).
$$

由于恢复力等于 $\nabla_{\mathbf q}V_{\beta_3}$，

$$
\frac{\mathrm dE_{\beta_3}}{\mathrm dt}
=-\mathbf p^\top\mathbf C_{\mathrm{mech}}\mathbf p\le0.
$$

**局部适用范围由本协议单独规定。** 二次软化恢复力产生三次势能，不能仅凭能量耗散宣称任意初值都被全局约束。为构造全条件共享且可核对的安全人口，取 $R_q=1/2$。利用 $\lambda_{\min}(\mathbf L_{\mathrm{mech}})=1$ 与 $\beta_3\ge0$，在 $\|\mathbf q\|_2=R_q$ 上有

$$
V_{\beta_3}(\mathbf q)
\ge\frac12R_q^2-\frac23R_q^3
=\frac1{24}.
$$

令 $\beta_{3,\max}=1.5$。从四维无量纲球 $\|\mathbf x\|_2<1/2$ 均匀提议，保留满足

$$
\boxed{
\|\mathbf q\|_2<\frac12,
\qquad
\frac1{240}\le E_{\beta_{3,\max}}(\mathbf q,\mathbf p)\le\frac1{30}.
}
$$

的样本，作为 CAN 与 COND 的共同初值分布。接受规则与当前 $\beta_3$ 无关。因为 $E_{\beta_3}(\mathbf x_0)\le E_{\beta_{3,\max}}(\mathbf x_0)<1/24$ 且总能量不增，精确轨线不可能第一次穿越 $\|\mathbf q\|_2=1/2$。在该球内，

$$
V_{\beta_3}(\mathbf q)
\ge\left(\frac12-\frac23R_q\right)\|\mathbf q\|_2^2
=\frac16\|\mathbf q\|_2^2,
$$

故速度也由能量约束。该安全集是本文的保守构造，不是原论文的 SSM 采样范围；它保证有界生成，但不保证所有窗口都有足够的参数辨识信号。

# 9. FPUT–β：32 自由度保守非线性弹簧链

## 9.1 模型与固定边界

取 $n_{\mathrm{dof}}=32$，单位质量、单位线性刚度。状态与边界为

$$
\mathbf x=[\mathbf q^\top,\mathbf p^\top]^\top\in\mathbb R^{64},
\qquad q_0=q_{n_{\mathrm{dof}}+1}=0.
$$

端点不是额外动态自由度。Hamiltonian 为

$$
H_\beta(\mathbf q,\mathbf p)
=\frac12\sum_{i=1}^{n_{\mathrm{dof}}}p_i^2
+\frac12\sum_{i=0}^{n_{\mathrm{dof}}}(q_{i+1}-q_i)^2
+\frac\beta4\sum_{i=0}^{n_{\mathrm{dof}}}(q_{i+1}-q_i)^4.
$$

因此

$$
\boxed{
\begin{aligned}
\dot q_i&=p_i,\\
\dot p_i&=q_{i+1}-2q_i+q_{i-1}
+\beta\bigl[(q_{i+1}-q_i)^3-(q_i-q_{i-1})^3\bigr],
\quad i=1,\ldots,n_{\mathrm{dof}}.
\end{aligned}}
$$

该定义采用固定端点的 β 型近邻链，不加入阻尼、外力或额外接地非线性。现代可复现参考为 Marchetti 2025。[^fput]

## 9.2 CAN、COND 与文献 replay

CAN 固定 $\beta^\star=1$；这是本文从参考研究的参数范围内选择的固定工作点，不是 FPUT 唯一的标准参数。首版 COND 固定

$$
\mathbf u_\kappa=[\beta],\qquad\beta\in[0.5,1.5].
$$

参考论文的 $n_{\mathrm{dof}}=32$、单模态幅值 $A=10$、velocity-Verlet 步长 0.05 及长轨数据用于独立的 `literature_replay` 配置。公开 Zenodo 记录列出第一模态初值、$\beta\in[0.1,1.5]$ 与 $\beta\in[1.6,3.0]$ 两组数据。[^fput-data1] [^fput-data2]

本文的多初值 CAN／COND 不把单条公开长轨切成若干段后称为独立初值轨线，也不声称下文较短记录覆盖了完整 FPUT recurrence 时间尺度。

## 9.3 全模态激发的共同多初值人口

为了避免 64 维状态始终只来自一个特殊单模态轨道，主人口采用固定线性模态基

$$
(\mathbf V_{\mathrm{lin}})_{ij}
=\sqrt{\frac{2}{n_{\mathrm{dof}}+1}}
\sin\frac{ij\pi}{n_{\mathrm{dof}}+1},
\qquad
\omega_j=2\sin\frac{j\pi}{2(n_{\mathrm{dof}}+1)}.
$$

$\mathbf V_{\mathrm{lin}}^\top\mathbf V_{\mathrm{lin}}=\mathbf I$。抽取独立标准正态数 $A_j,B_j$，以及

$$
\log E_{\mathrm{lin},0}\sim
\operatorname{Unif}[\log(0.5),\log(2)].
$$

定义

$$
Q_j^{\mathrm{raw}}=\frac{A_j}{j\omega_j},
\qquad P_j^{\mathrm{raw}}=\frac{B_j}{j},
$$

$$
a_{\mathrm{scale}}
=\sqrt{\frac{2E_{\mathrm{lin},0}}
{\sum_{j=1}^{n_{\mathrm{dof}}}
[\omega_j^2(Q_j^{\mathrm{raw}})^2+(P_j^{\mathrm{raw}})^2]}}.
$$

以

$$
\mathbf q_0=a_{\mathrm{scale}}\mathbf V_{\mathrm{lin}}\mathbf Q^{\mathrm{raw}},
\qquad
\mathbf p_0=a_{\mathrm{scale}}\mathbf V_{\mathrm{lin}}\mathbf P^{\mathrm{raw}}
$$

生成状态。分母为零是连续抽样中的零概率事件，实现遇到时按固定规则重抽。各模态都有非零随机激发，低模态获得更大的典型权重；整个法则不依赖 $\beta$。

由构造得到初始**线性能量**恰为 $E_{\mathrm{lin},0}$，但真实 $H_\beta(\mathbf x_0)$包含四次势能，通常不同于 $E_{\mathrm{lin},0}$。二者分别保存；不利用真实 $\beta$ 再将总能量归一化为相同值。

该多初值法则为本文设计，不是对参考论文单模态初值的复写。

## 9.4 守恒、模态能量与参数敏感性

$$
\frac{\mathrm dH_\beta}{\mathrm dt}=0.
$$

固定端点使线性刚度正定，$\beta\ge0$ 时四次势能非负，因而有限能量子水平集有界。原点线性率为 $\gamma_{j,\pm}=\pm\mathrm i\omega_j$，与 $\beta$ 无关；这不是完整非线性 Koopman 谱的公式。

令 $\mathbf Q=\mathbf V_{\mathrm{lin}}^\top\mathbf q$、$\mathbf P=\mathbf V_{\mathrm{lin}}^\top\mathbf p$，定义线性模态能量

$$
E_j^{(2)}=\frac12(P_j^2+\omega_j^2Q_j^2).
$$

严格有

$$
H_\beta=\sum_{j=1}^{n_{\mathrm{dof}}}E_j^{(2)}
+\frac\beta4\sum_{i=0}^{n_{\mathrm{dof}}}(q_{i+1}-q_i)^4,
$$

不把线性模态能量之和当作非线性总能量。条件敏感项为

$$
\partial_\beta\dot p_i
=(q_{i+1}-q_i)^3-(q_i-q_{i-1})^3.
$$

正式诊断同时保留总能量、各线性模态能量和相对位移幅值。改变 $n_{\mathrm{dof}}$ 产生独立规模配置，不作为同一固定维数 COND 的工况轴。

# 10. Lorenz63 与 Rössler

## 10.1 Lorenz63

$$
\begin{aligned}
\dot x_1&=\sigma(x_2-x_1),\\
\dot x_2&=x_1(\rho-x_3)-x_2,\\
\dot x_3&=x_1x_2-\beta x_3.
\end{aligned}
$$

CAN 固定 $(\sigma,\rho,\beta)=(10,28,8/3)$。本文将 pre-burn 初态规范为盒

$$
[-12,12]\times[-12,12]\times[8,32]
$$

上的均匀分布，以固定随机种子独立生成，随后 burn-in $T_{\mathrm{burn}}=10$。这是对已有初值盒范围的明确人口绑定，不保留“随机／网格／低差异序列任选”的未定接口。方程来源为 Lorenz 1963。[^lorenz]

$$
\nabla\cdot\mathbf f=-\sigma-1-\beta=-41/3.
$$

完整参数均保留。后续条件轴候选为 $\rho\in[26,30]$，固定其他系数；该区间是项目预声明候选，不构成区间内所有动力学都已验证为同一混沌吸引子或同一光滑模型图册的结论。

## 10.2 Rössler

$$
\begin{aligned}
\dot x_1&=-x_2-x_3,\\
\dot x_2&=x_1+a x_2,\\
\dot x_3&=b+x_3(x_1-c).
\end{aligned}
$$

CAN 固定 $(a,b,c)=(0.2,0.2,5.7)$。pre-burn 初态规范为

$$
[-8,8]\times[-8,8]\times[0.5,8]
$$

上的均匀分布，burn-in $T_{\mathrm{burn}}=50$。向量场来源为 Rössler 1976；本配置参数、初值盒和采样预算由项目明确固定，不声称每项都来自原始短文。[^rossler]

$$
\nabla\cdot\mathbf f=x_1+a-c=x_1-5.5.
$$

后续工况轴候选为 $c\in[5.5,5.9]$，固定 $a,b$。有限性、轨线支撑及动力学区域必须资格化后才启用该条件族。

## 10.3 混沌数据的解释

burn-in 后保存的起始状态是 pre-burn 分布的动力学推前，不再等于初始提议盒上的均匀分布。不同工况使用同一 pre-burn 法则，并不保证 burn-in 后分布相同。

CAN 用独立初态生成独立轨线；短期检查逐点误差与相位，长期检查占据统计、相关函数与吸引子覆盖。生成器仍须检查局部误差与收敛，不以“混沌敏感”免除数值资格。

这两个候选条件族不进入首轮隐参数辨识总分。启用时保留相同时间／观测协议，并单列分岔、周期窗口和跨吸引子变化的风险；不得用验证或测试误差反向筛掉不利工况。

# 11. 首版条件区间与统一参数网格

## 11.1 启用范围

以下区间及其初值法则均为本项目首版设计。

| 条件族 ID | 可变工况坐标 $\mathbf u_\kappa$ | 区间 | 固定系数 | 初值法则 | 状态 |
|---|---|---|---|---|---|
| `damped_linear_cond_w0` | $[\omega_0]$ | $[0.8,1.2]$ | $\gamma=0.05$ | $\operatorname{Ann}(0.5,1)$ | 启用 |
| `duffing_cond_beta` | $[\beta]$ | $[5,25]$ | $\alpha=1,\delta=0.08$ | $\operatorname{Ann}(1.5,2)$ | 启用 |
| `pendulum_cond_w0` | $[\omega_0]$ | $[0.8,1.2]$ | 无阻尼、无外力 | 第 6.3 节共同安全支撑 | 启用 |
| `vanderpol_cond_mu` | $[\mu]$ | $[0.1,0.9]$ | 恢复力系数为 1 | 第 7.2 节混合环形人口 | 启用 |
| `axas_haller_cond_beta3` | $[\beta_3]$ | $[0.5,1.5]$ | $m=k=1,c=0.03,\alpha_2=-2$ | 第 8.4 节共同能量安全集 | 启用 |
| `fput32_cond_beta` | $[\beta]$ | $[0.5,1.5]$ | 32 质量块，固定端点 | 第 9.3 节多模态人口 | 启用 |
| `lorenz63_cond_rho` | $[\rho]$ | $[26,30]$ | $\sigma=10,\beta=8/3$ | 相同 pre-burn 盒 | 后续资格化 |
| `rossler_cond_c` | $[c]$ | $[5.5,5.9]$ | $a=b=0.2$ | 相同 pre-burn 盒 | 后续资格化 |

“启用”表示本版定义了可执行的数据生成配置，不表示已经通过数值和条件辨识实验。“后续资格化”不自动进入默认任务清单。

## 11.2 单参数工况的冻结网格

对区间 $[a_\kappa,b_\kappa]$，使用坐标

$$
\kappa(r)=a_\kappa+(b_\kappa-a_\kappa)r.
$$

固定三个不相交位置集

$$
\mathcal G_{\mathrm{tr}}=\{0,1/4,1/2,3/4,1\},
\quad
\mathcal G_{\mathrm{val}}=\{1/8,5/8\},
\quad
\mathcal G_{\mathrm{test}}=\{3/8,7/8\}.
$$

合并得到 9 个工况。`Split-C` 中，5 个工况用于训练、2 个用于验证、2 个用于测试。验证与测试均在训练区间内部，故该配置检验**未见工况插值**，不宣称外推能力。

例如 Duffing 训练 $\beta=5,10,15,20,25$，验证 $\beta=7.5,17.5$，测试 $\beta=12.5,22.5$。这只是上述统一映射的展开，不是根据预测误差选择的参数点。

每个参数用准确十进制／有理描述生成并保存其数值值和稳定 `condition_id`，不以浮点近似相等临时分组。

## 11.3 扩展条件轴

加入第二个系数时，先定义新的区间、采样设计和留出规则；不默认对所有参数进行高维笛卡尔积扫描。物理轴彼此可辨识性需要联合检查。

超出首版区间的 `extrapolation` 工况必须在生成前单独登记，且不能用于选取 normalizer、条件教师、模型维数或超参数。跨工况的坐标和时间规则继续保持固定。

# 12. 正式轨线资源与时间预算

## 12.1 CAN 生成表

以下前八个既有配置的采样与轨线预算保持原 TestSub-1 的数值口径；三个新增配置的预算是本协议设计。$T_{\mathrm{rec}}=(M-1)\tau$，不包含 burn-in。

| CAN ID | $\tau$ | 快照数 $M$ | $T_{\mathrm{rec}}$ | 轨线数 $R$ | Train / Val / Test | $T_{\mathrm{burn}}$ |
|---|---:|---:|---:|---:|---|---:|
| `linear_diagonal` | 0.01 | 1025 | 10.24 | 512 | 384 / 64 / 64 | 0 |
| `linear_rotation_contraction_2d` | 0.01 | 2049 | 20.48 | 512 | 384 / 64 / 64 | 0 |
| `damped_linear_oscillator` | 0.02 | 3001 | 60 | 512 | 384 / 64 / 64 | 0 |
| `duffing_chi40_medium` | 0.01 | 2049 | 20.48 | 512 | 384 / 64 / 64 | 0 |
| `duffing_chi320_strong` | 0.01 | 2049 | 20.48 | 512 | 384 / 64 / 64 | 0 |
| `nonlinear_pendulum_lusch2018` | 0.02 | 51 | 1 | 8192 | 6144 / 1024 / 1024 | 0 |
| `lorenz63_standard` | 0.01 | 4097 | 40.96 | 512 | 384 / 64 / 64 | 10 |
| `rossler_standard` | 0.02 | 4097 | 81.92 | 512 | 384 / 64 / 64 | 50 |
| `vanderpol_autonomous_mu03` | 0.02 | 5001 | 100 | 512 | 384 / 64 / 64 | 0 |
| `axas_haller_2023_2dof` | 0.1 | 1001 | 100 | 512 | 384 / 64 / 64 | 0 |
| `fput_beta_32dof` | 0.05 | 8193 | 409.6 | 512 | 384 / 64 / 64 | 0 |

原方程采用无量纲化定义的对象，表内时间是相应无量纲时间。Axås–Haller 的采样时间沿用文献标示；artifact 必须明确 `time_unit`，不能把所有对象的表内数值统一称为秒。

## 12.2 COND 生成表

同一条件族内所有工况共享下表的记录时长。CAN 与 COND 是不同实验资源，尤其摆不把 51 帧 CAN 短轨直接当作长期条件辨识数据。

| 条件族 | $\tau$ | $M$ | $T_{\mathrm{rec}}$ | burn-in |
|---|---:|---:|---:|---:|
| 阻尼线性振子 | 0.02 | 2001 | 40 | 0 |
| Duffing | 0.01 | 2049 | 20.48 | 0 |
| 非线性摆 | 0.02 | 2001 | 40 | 0 |
| Van der Pol | 0.02 | 3001 | 60 | 0 |
| Axås–Haller | 0.1 | 1001 | 100 | 0 |
| FPUT–β | 0.05 | 4097 | 204.8 | 0 |

默认生成规模分为两种独立 split 实验：

| 实验 | 低维五族：每工况轨线数 | FPUT：每工况轨线数 |
|---|---|---|
| `Split-I`：9 个工况均可见，组内分轨线 | 256 = 192 Train + 32 Val + 32 Test | 128 = 96 Train + 16 Val + 16 Test |
| `Split-C`：工况组整体留出 | 训练工况 256；验证工况 64；测试工况 64 | 训练工况 128；验证工况 32；测试工况 32 |

`Split-I` 与 `Split-C` 独立编译数据身份和拟合产物。不能把前者在全部 9 个工况上拟合的表示、normalizer 或教师直接带入后者。

## 12.3 时间分层与暂态保留

衰减型系统不做删除全部大幅暂态的 burn-in。正式记录覆盖初始非线性阶段与后期低幅阶段；评价至少按记录区间前半、后半分别报告。训练器是否改变时间质量，由其父风险合同单独声明，不由数据提供者依据模型误差重采样。

记录时长不是参数可辨识性的证明。若声明的历史物理时长过短或样本趋近共同平衡态，应在条件敏感性诊断中标记信息不足，不能把延长记录或增加重叠窗口当作自动增加独立信息。

# 13. Split、历史窗口与泄漏边界

## 13.1 两种泛化问题

`Split-I` 在每个固定工况内按完整轨线划分，评价**已见工况下的新初态泛化**。

`Split-C` 先按第 11.2 节划分完整工况组，再为各组生成独立初态，评价**未见工况且新初态的插值**。任何同一条件组的数据、衍生 SSM 描述或噪声统计不得跨入 Train。

CAN 的完整轨线 split 同样在窗口生成前冻结。一个母轨线的所有时间段、clean／noisy 视图、正反序列和重采样版本继承同一 split。

## 13.2 随机种子与可选匹配初态

生成器分别固定初值、噪声、split 的随机种子命名空间。通常每个条件独立抽样但遵循同一初值分布。

若为降低跨工况比较方差而复用一组相同初态，应显式保存 `ic_seed_group_id`；相同种子组在所有条件中继承相同 split。`Split-C` 的训练、验证、测试组仍使用不相交的初态种子池，不能把“相同初态换参数”冒充新初态泛化。

数值生成失败不得无记录地重抽。预先允许的拒绝采样仅由已定义的初值安全规则决定；积分失败、越界或资格失败必须留下记录，并在发布前解决或说明，而不是依据训练难度删除轨线。

## 13.3 合法历史与未来窗口

给定历史长度 $q_{\mathrm H}\ge1$ 和最大预测步数 $h_{\max}$，合法截止集合为

$$
\mathcal A^{\mathrm{win}}
=\{(\nu,s):q_{\mathrm H}-1\le s,\ s+h_{\max}\le M_\nu-1\}.
$$

历史与未来分别为

$$
\mathfrak z_s^{\mathrm{hist},(\nu)}
=(\mathbf z_{s-q_{\mathrm H}+1}^{(\nu)},\ldots,\mathbf z_s^{(\nu)}),
\qquad
\{\mathbf y_{s+h}^{(\nu)}\}_{h=1}^{h_{\max}}.
$$

单轨形式窗口数为

$$
\max\{0,M_\nu-q_{\mathrm H}-h_{\max}+1\}.
$$

$q_{\mathrm H}=1$ 时退化为 $M_\nu-h_{\max}$。窗口高度重叠，不等于独立样本数。不得跨轨线、跨工况拼接历史，也不得用预测值、未来值或重复末帧补足正式历史。

$q_{\mathrm H}$ 和训练 horizon 由下游任务规定；本文不把二维流体协议中的特定帧数强加给 ODE。正式记录同时报告历史物理时长 $(q_{\mathrm H}-1)\tau$ 与未来物理时长 $h\tau$。

# 14. 概率质量、噪声视图与 raw 坐标

## 14.1 条件平衡的声明测度

对 Train 条件集合 $\mathcal C_{\mathrm{tr}}$，固定 $\pi_c$、组内轨线质量 $\rho_{\nu\mid c}$ 与快照质量 $w_{m\mid\nu}$，使各层和为 1。状态经验测度为

$$
\widehat\nu_{\mathrm{snap}}^{\mathrm{tr}}
=\sum_{c\in\mathcal C_{\mathrm{tr}}}\pi_c
\sum_{\nu\in\mathcal R_{c,\mathrm{tr}}}\rho_{\nu\mid c}
\sum_{m=0}^{M_\nu-1}w_{m\mid\nu}\delta_{\mathbf x_m^{(\nu)}}.
$$

默认条件平衡、组内轨线平衡、完整记录均匀：

$$
\pi_c=1/|\mathcal C_{\mathrm{tr}}|,\quad
\rho_{\nu\mid c}=1/|\mathcal R_{c,\mathrm{tr}}|,\quad
w_{m\mid\nu}=1/M_\nu.
$$

CAN 取单条件的特例。该快照测度可供 noise reference 和下游标准化使用；它不自动替代 K3/MAG1 的合法 window-head source 测度。缓存去重不得改变原子质量。[^mag0] [^mag1]

## 14.2 观测噪声

对 clean Train 资源，按上述测度计算各分量未中心化信号功率

$$
P_j:=\mathbb E_{\widehat\nu_{\mathrm{snap}}^{\mathrm{tr}}}[x_j^2].
$$

对标称信噪比 $b_{\mathrm{SNR}}\in\{5,15\}$，定义

$$
\sigma_{\mathrm{noise},j}
=\sqrt{P_j}\,10^{-b_{\mathrm{SNR}}/20},
\qquad
\mathbf\Sigma_{\mathrm{noise}}
=\operatorname{diag}(\sigma_{\mathrm{noise},1}^2,\ldots,
\sigma_{\mathrm{noise},d_x}^2),
$$

$$
\boldsymbol\eta_m^{(\nu)}\sim
\mathcal N(\mathbf0,\mathbf\Sigma_{\mathrm{noise}}),
\qquad
\mathbf z_m^{\mathrm{obs},(\nu)}
=\mathbf x_m^{(\nu)}+\boldsymbol\eta_m^{(\nu)},
\qquad
\mathbf y_m^{(\nu)}=\mathbf x_m^{(\nu)}.
$$

噪声在给定冻结协方差下跨轨线、时间独立，并与 clean 生成过程独立。未激发的零功率分量单独标记，不通过任意 floor 把它悄悄改成另一个 SNR 口径。

**同一 COND 族使用一个由全部 Train 工况按声明质量拟合的共享噪声协方差。** 不按条件或轨线调整噪声，使每条轨线都恰好达到相同经验 SNR；否则噪声尺度本身可能编码条件。各工况实际 SNR 可不同，须报告；5/15 dB 是相对于共享 Train reference 的标称值。

一个物理时刻的噪声 realization 冻结后由所有窗口复用，不因窗口重新切分而重新抽噪声。动态噪声增强若使用，作为另一个训练协议登记。

## 14.3 clean 目标与信息权限

clean、5 dB、15 dB 是同一母轨线的不同观测视图。默认监督目标始终为 clean 状态；需要 noisy-to-noisy 任务时，另设目标视图及独立噪声约定，不改变这里的 clean-target 定义。

部署历史只包含所声明观测视图。clean 轨线、真实工况、精确向量场和未来状态可用于数据生成及离线审计，但不作为隐藏条件预测器的部署输入。含噪观测一般不满足单帧确定性闭合；确定性 Koopman 解释属于底层 clean 系统或已另行资格化的状态表示。

## 14.4 raw artifact 与外部标准化

保持 raw 数据政策：生成器保存原坐标状态、观测、目标和元数据，不在 raw artifact 中保存训练标准化后的状态。

```text
normalization_policy = none_raw_physical_coordinates
integration_dtype = Float64
storage_dtype = Float32
clean_target_policy = clean_full_state
```

保留 Float64 数值资格记录；有高精度复现需要时，另存 Float64 raw 视图并登记不同 storage identity。默认 target 和 clean observation 可以引用同一状态数据，避免重复保存。

下游若需要标准化，仅用当前 split 的 Train 资源计算

$$
\widetilde{\mathbf z}
=\mathbf D_{\sigma,\mathbf z}^{-1}(\mathbf z-\boldsymbol\mu_{\mathbf z}),
\qquad
\widetilde{\mathbf y}
=\mathbf D_{\sigma,\mathbf y}^{-1}(\mathbf y-\boldsymbol\mu_{\mathbf y}).
$$

normalizer 是独立、冻结、带 split identity 的模型侧产物。所有条件和部署窗口共用；不按工况、轨线、batch 重新中心化或缩放。工况适配器也只标准化真正变化的物理轴。此分层保留 raw 数据含义，不把状态标准化与 SNR 标定混为一谈。

# 15. 数值积分与资格证书

## 15.1 三个不同误差来源

必须分别记录连续解的数值积分误差、存储量化误差和人工观测噪声。`reltol`、`abstol` 是积分器的局部误差控制参数，不是整个轨线全局误差的自动保证。

线性系统从初态使用解析传播／矩阵指数生成，避免通过粗步进引入虚假的谱偏差。非线性对象在 Float64 中积分，在固定时间网格读取状态后才转换为目标存储精度。

## 15.2 非刚性对象的默认积分配置

以下为本协议的正式初始配置，需经第 15.4 节的收敛门禁验收。Dormand–Prince 5(4) 采用接受的五阶解并以嵌入误差控制步长。[^dp]

| 对象 | 方法 | `reltol` | `abstol` | 内部最大步长 |
|---|---|---:|---:|---:|
| 三个线性对象 | 解析传播／矩阵指数 | 不适用 | 不适用 | 不适用 |
| 两档 CAN Duffing 与 COND Duffing | DP5(4) | $10^{-11}$ | $10^{-13}$ | $0.0005$ |
| CAN／COND 非线性摆 | DP5(4) | $10^{-11}$ | $10^{-13}$ | $0.004$ |
| CAN／COND Van der Pol | DP5(4) | $10^{-11}$ | $10^{-13}$ | $0.004$ |
| CAN／COND Axås–Haller | DP5(4) | $10^{-11}$ | $10^{-13}$ | $0.02$ |
| CAN Lorenz63 | DP5(4) | $10^{-10}$ | $10^{-12}$ | $0.002$ |
| CAN Rössler | DP5(4) | $10^{-10}$ | $10^{-12}$ | $0.004$ |

本版明确将摆的数值绑定统一为高精度 DP5(4)，而不是把未指定内部细步长的 RK4 当作可复现接口。Axås–Haller 的正式多初值数据也不承诺逐步复制官方 `ode45` 的自适应步序；复现身份是相同方程、参数与明确的独立数值协议。

所有对象保存模型采样间隔与积分器内部步长的区别。等间隔输出可以来自求解器的高阶 dense output，但插值公式、求解器版本与容差必须登记并包含在收敛测试中。禁止以最近邻方式读取不等间隔内部时间点。

## 15.3 FPUT 的默认四阶辛积分

文献 replay 保留原文 velocity-Verlet 设定。本文的正式多初值高精度生成采用 Yoshida 四阶对称组合，以下定义给出可直接复现的数值映射。[^yoshida]

对 $H(\mathbf q,\mathbf p)=\tfrac12\|\mathbf p\|^2+V(\mathbf q)$，记 $\mathbf a(\mathbf q)=-\nabla V(\mathbf q)$。定义一个步长为 $\Delta$ 的 velocity-Verlet 映射 $\mathbf V_\Delta$：

$$
\begin{aligned}
\mathbf p^{1/2}&=\mathbf p+\frac\Delta2\mathbf a(\mathbf q),\\
\mathbf q^+&=\mathbf q+\Delta\mathbf p^{1/2},\\
\mathbf p^+&=\mathbf p^{1/2}+\frac\Delta2\mathbf a(\mathbf q^+).
\end{aligned}
$$

取

$$
w_1=\frac1{2-2^{1/3}},\qquad
w_0=-\frac{2^{1/3}}{2-2^{1/3}},
$$

$$
\mathbf\Phi_\Delta^{(4)}
=\mathbf V_{w_1\Delta}\circ
\mathbf V_{w_0\Delta}\circ
\mathbf V_{w_1\Delta}.
$$

负的中间子步是该自治 Hamiltonian 组合的组成部分，不是沿观测轨线进行非因果取样。初始采用

$$
K_{\mathrm{sub}}=8,\qquad
\Delta=\tau/K_{\mathrm{sub}}=0.00625.
$$

用独立于正式 Train／Val／Test 的数值探针初态比较 $K_{\mathrm{sub}}$ 与 $2K_{\mathrm{sub}}$；若门禁不通过，按预声明的倍增规则细化，并在整个对应方程族数据版本中固定最终子步数。固定采样间隔不随之改变。

辛性不等于真实 Hamiltonian 在离散点上精确守恒。有限精度、长时间积累和初态能量仍需要实际验收，不通过投影回能量面、裁剪状态或人为阻尼来隐藏生成误差。

## 15.4 数值门禁

先声明固定参考坐标尺度 $\mathbf D_{\mathrm{num}}\succ0$ 与能量尺度 $E_{\mathrm{num}}>0$；它们来自模型单位／初值设计，不由测试预测误差确定。初始数值阈值取

$$
\varepsilon_{\mathrm{num},x}=10^{-7},\qquad
\varepsilon_{\mathrm{num},E}=10^{-8}.
$$

这些是本文要求的资格阈值，不是对尚未生成轨线的测量结果。

**状态收敛。** 对非混沌、声明时段内可作逐点比较的数值探针，比较正式与加严方案在相同输出时刻的轨线：

$$
\max_m
\frac{\|\mathbf D_{\mathrm{num}}^{-1}
(\mathbf x_m^{\mathrm{base}}-\mathbf x_m^{\mathrm{fine}})\|_2}
{1+\|\mathbf D_{\mathrm{num}}^{-1}\mathbf x_m^{\mathrm{fine}}\|_2}
\le\varepsilon_{\mathrm{num},x}.
$$

加严方案将自适应容差缩小一个数量级、最大步长减半，或将辛积分子步数加倍。若长轨出现敏感性放大，不把整段逐点比较继续解释为唯一标准；改用预声明的局部重启收敛检查并报告采用的时间尺度。

**保守能量。** 对摆和 FPUT，记录

$$
\delta_E
=\max_m\frac{|E(\mathbf x_m)-E(\mathbf x_0)|}
{E_{\mathrm{num}}+|E(\mathbf x_0)|}.
$$

要求数值探针和正式资源的能量门禁满足声明阈值。Hamiltonian 使用各轨线真实参数计算，仅作为离线资格量。

**耗散能量平衡。** 对阻尼线性振子、Duffing 和 Axås–Haller，令耗散率分别为 $2\gamma p^2$、$\delta p^2$、$\mathbf p^\top\mathbf C_{\mathrm{mech}}\mathbf p$，检查

$$
E(t)-E(0)+\int_0^t\mathscr D(\mathbf x(u))\,\mathrm du\approx0.
$$

耗散积分由同精度积分器增广变量或经加严的求积计算，不用未验证的粗采样梯形公式冒充 $10^{-8}$ 级证书。另报告能量正增量最大值。

**Van der Pol 平衡。** 使用第 7.3 节带符号的能量变化率积分检查，不要求能量单调。

**混沌检查。** Lorenz63、Rössler 和可能处于敏感区域的 FPUT 使用相同起点的短段重启比较、局部一步一致性与长期统计收敛。不能要求不同容差生成的长混沌轨线无限期逐点重合，也不能只看长期统计而省略局部积分误差检查。

**几何／支撑检查。** 验证摆不越过声明势阱与分离轨裕度、Axås–Haller 不离开安全区域、FPUT 固定端点始终为零。数值越界不能通过重新 wrap、补零或裁剪动态状态修正。

## 15.5 存储、噪声与发布检查

所有资源必须通过有限值、维数、时间单调性、轨线身份、split 隔离和 clean-target 对齐检查。Float32 转换误差单独记录，不与 Float64 数值门禁合并。

噪声只需在足够样本下相对于共享 reference 达到统计一致的标称 SNR，不要求每条短轨的实测 SNR 恰为 5 或 15 dB；不得为通过 SNR 检查逐条再缩放。

发布证书至少记录最大／分位数数值误差、拒绝采样率、失败计数、所有最终求解器配置和独立探针身份。没有证书的数据可用于实现调试，但不能标记为正式 benchmark artifact。

# 16. 隐参数辨识所需的额外数据合同

## 16.1 条件标签不是隐坐标真值

数据层发布真实物理工况 $\boldsymbol\kappa$，不预先发布某个唯一的 $\boldsymbol\zeta$。后者由当前 K3.4.2 的训练期条件描述和冻结教师定义。当前项目绑定读取 [[SKDM-K3.4.2-SSM Hidden-Parameter Koopman Operator Manifold]] 中的数值 Fast-SSM 条件协议，而不是要求先训练另一套参考 K3。[^id]

同一条件下多条轨线用于分离物理规律与初始状态；历史辨识器读取

$$
\mathfrak z_s^{\mathrm{hist}}
\longmapsto\widehat{\boldsymbol\zeta}_s.
$$

部署时不读取工况标签、整条轨线统计量、未来窗口、真实能量参数或精确向量场。每个预测事件的条件估计在整个预测块内固定。

## 16.2 数据侧的参数激发审计

为区分“模型辨识失败”和“历史本来不含充分参数信息”，可以在 clean Train 或独立数值探针上执行方程已知的离线审计。本文各首版条件族都可写成

$$
\mathbf f_{\boldsymbol\kappa}(\mathbf x)
=\mathbf f_0(\mathbf x)
+\mathbf B_{\mathrm{dyn}}(\mathbf x)\mathbf a(\boldsymbol\kappa),
$$

其中 $\mathbf a(\boldsymbol\kappa)$ 是有效物理系数：

| 条件轴 | 有效系数 $\mathbf a(\boldsymbol\kappa)$ | 对应非零加速度系数 |
|---|---|---|
| 线性振子的 $\omega_0$ | $[\omega_0^2]$ | $-q$ |
| Duffing 的 $\beta$ | $[\beta]$ | $-q^3$ |
| 摆的 $\omega_0$ | $[\omega_0^2]$ | $-\sin q$ |
| Van der Pol 的 $\mu$ | $[\mu]$ | $(1-q^2)p$ |
| Axås–Haller 的 $\beta_3$ | $[\beta_3]$ | $[-(q_1-q_2)^3,(q_1-q_2)^3]^\top$ |
| FPUT 的 $\beta$ | $[\beta]$ | $[(q_{i+1}-q_i)^3-(q_i-q_{i-1})^3]_i$ |

在历史内部选定若干子区间 $I_\ell=[t_\ell^-,t_\ell^+]$，定义

$$
\mathbf d_\ell
=\mathbf x(t_\ell^+)-\mathbf x(t_\ell^-)
-\int_{I_\ell}\mathbf f_0(\mathbf x(t))\,\mathrm dt,
\qquad
\mathbf Z_\ell=\int_{I_\ell}\mathbf B_{\mathrm{dyn}}(\mathbf x(t))\,\mathrm dt.
$$

精确轨线满足 $\mathbf d_\ell=\mathbf Z_\ell\mathbf a(\boldsymbol\kappa)$。令

$$
\mathbf G_{\mathrm{id}}
=\sum_\ell\omega_\ell\mathbf Z_\ell^\top\mathbf Z_\ell,
\qquad\omega_\ell>0,\quad\sum_\ell\omega_\ell=1.
$$

在精确全状态历史、精确积分及正确方程结构下，$\mathbf G_{\mathrm{id}}\succ0$ 保证该线性系数回归的唯一性。它不是噪声下的自动辨识保证，也不是无条件的 Fisher 信息矩阵。参数回到 $\boldsymbol\kappa$ 还要求 $\mathbf a$ 在声明域上单射；例如 $\omega_0>0$ 才能从 $\omega_0^2$ 唯一取回本协议频率参数。

小特征值提示弱激发。只在完整周期上积分还可能发生系数抵消，因此区间模板预先固定为多个短子段，而不是只用一个整周期端点差。该审计不新增正式模型的方程输入，也不按测试误差删除低激发窗口。

## 16.3 不同初态下的条件一致性

条件评价至少区分：同一工况不同初态的一致性、同一轨线不同窗口的一致性、未见工况的条件插值，以及使用该条件后的真实未来预测风险。

只比较隐坐标与物理参数的逐分量数值误差通常不成立，因为 $\boldsymbol\zeta$ 具有教师与坐标规范。使用 Train 冻结教师生成验证／测试的参考代码；不得对留出轨线重新拟合 SSM，然后把所得代码称为独立真值。[^id]

物理参数回归可以作为另设的可解释性诊断，但其回归器、尺度和指标也只能在 Train 上拟合与冻结。它不替代条件 K3 的预测资格。

## 16.4 SSM 参考模型的适用性单独验收

数据族具有可变物理工况，不意味着所有对象都满足相同的慢吸引 SSM 假设。阻尼机械系统、极限环系统、保守摆／FPUT 与混沌系统的参考运动类型不同。

尤其保守摆和 FPUT 在原点的线性化含中心方向，不自动具有耗散系统中的慢吸引 SSM。使用 K3.4.2 的某个 SSM 候选描述时，必须分别检查其参考运动、适用域、低维充分性与历史辨识资格；不能仅凭数据是 ODE 就统一宣称已满足 SSM 存在性条件。本文不为通过该资格而擅自给保守系统增加阻尼。

## 16.5 与 K3.4.3 的接口

数据提供者只需暴露工况分组、合法历史、clean／noisy 观测与未来目标。条件 K3 仍采用共享字典与条件谱实现：

$$
\boldsymbol\varphi_{s\mid s}
=\mathbf W_{\mathrm{ext}}(\widehat{\boldsymbol\zeta}_s)
\boldsymbol\psi_{\boldsymbol\theta}(\widetilde{\mathbf z}_s),
$$

$$
\widehat{\widetilde{\mathbf y}}_{s,h}
=\mathbf B_{\mathrm K}(\widehat{\boldsymbol\zeta}_s)
\boldsymbol\chi_{\mathrm K}\!\left(
\mathbf\Lambda(\widehat{\boldsymbol\zeta}_s)^h
\boldsymbol\varphi_{s\mid s}\right).
$$

条件对象作用于 $\mathbf W_{\mathrm{ext}}$、$\mathbf\Lambda$ 与 $\mathbf B_{\mathrm K}$，不只作用于谱值。训练期与最终 refit 读出保持父协议身份分离；TestSub-1 不规定其损失、网络宽度、谱维数或优化器。[^hp] [^k3]

# 17. Artifact、命名与复现清单

## 17.1 最小必需字段

```yaml
protocol_id: Standard_ODEs_v2
family_id: <equation_family>
profile: CAN | COND | literature_replay
base_object_id: <fixed_configuration_or_conditional_family>
state_components: <ordered_names>
state_units: <ordered_units_or_nondimensional>
state_dim: <integer>
physical_parameters: <complete_fixed_and_variable_parameter_record>
condition_parameter_names: <ordered_active_fields>
condition_values: <trajectory_level_values>
condition_id: <stable_identity>
ic_law_id: <fully_specified_distribution>
ic_law_parameters: <including_shared_safety_bounds>
ic_seed: <seed>
ic_seed_group_id: <optional_matched_initial_state_identity>
preburn_initial_state: <state_or_reference>
record_initial_state: <state_or_reference>
burn_in_time: <number>
sampling_interval: <tau>
time_unit: <unit>
snapshot_count: <M>
transition_count: <M_minus_one>
record_duration: <M_minus_one_times_tau>
endpoint_policy: closed
layout: trajectory_time_state
solver: <exact_name_and_version>
solver_parameters: <tolerances_max_step_or_substeps>
integration_dtype: Float64
storage_dtype: Float32
normalization_policy: none_raw_physical_coordinates
observation_view: clean | noise_5db | noise_15db
noise_reference_split_id: <identity_or_not_applicable>
noise_covariance: <frozen_shared_matrix_or_reference>
noise_seed: <seed_or_not_applicable>
target_view: clean_full_state
split_protocol: Split-I | Split-C
split_id: <stable_identity>
trajectory_id: <stable_identity>
parent_trajectory_id: <shared_by_all_views>
source_references: <DOI_and_software_source_records>
qualification_artifact_id: <numerical_and_data_checks>
configuration_hash: <hash>
```

这是字段合同，不是已经生成的数据实例。生成 manifest 时必须填入具体值，不能保留占位符。

## 17.2 命名层级

```text
<family_id>__<CAN_or_COND>__<configuration_id>__<split_id>__<observation_view>
```

对象 ID 负责识别方程与配置；完整初值人口、参数网格和求解器设置仍由 manifest 和配置哈希决定。5/15 dB 只出现在 observation view 中，不改变物理方程 identity。

CAN 中保留已有基础 ID，方便任务映射；它们不意味着 raw artifact 的新版本可以覆盖旧数值文件。方程、初值分布、采样、noise reference 或 split 任何一项变化，都需要新的配置 identity。

## 17.3 发布要求

正式发布需同时具备：完整可执行方程、明确条件坐标、固定初值人口、独立轨线划分、精确时间网格、已登记求解器、训练专用噪声标定、数值资格证书和来源说明。代码来源需记录 commit 或文件 blob；文献数据需记录版本 DOI 和实际下载记录。

本版已核对 Axås–Haller 官方方程脚本；FPUT 的 Zenodo DOI 按原论文数据声明登记。本文没有下载或校验两组 FPUT 大型数据文件，故不发布其文件哈希或内容完整性证书。项目多初值数据由本协议本地生成，并独立验收。

# 18. 参考文献与来源说明

下面的 DOI 用于识别固定出版物；代码路径和公开数据记录用于复现。正文中的多初值人口、条件区间及 split 为本协议设计，除明确说明外，不归于这些文献。

[^duffing]: Kovačić, I., & Brennan, M. J. (Eds.). **The Duffing Equation: Nonlinear Oscillators and their Behaviour**. Wiley, 2011. DOI: [10.1002/9780470977859](https://doi.org/10.1002/9780470977859). 用途：Duffing 恢复力、无外力／受迫形式与力学解释。本文的 $(\alpha,\delta,\beta,A_{\mathrm{IC}})$ 配置由项目规定。

[^lusch]: Lusch, B., Kutz, J. N., & Brunton, S. L. **Deep learning for universal linear embeddings of nonlinear dynamics**. *Nature Communications*, **9**, 4950, 2018. DOI: [10.1038/s41467-018-07210-0](https://doi.org/10.1038/s41467-018-07210-0). [作者代码仓库](https://github.com/BethanyL/DeepKoopman). 用途：非线性摆与有限维 Koopman 学习的研究来源；不作为本文具体轨线规模和拒绝采样人口的逐项出处。

[^vdp]: Mauroy, A., & Mezić, I. **On the use of Fourier averages to compute the global isochrons of (quasi)periodic dynamics**. *Chaos*, **22**(3), 033112, 2012. DOI: [10.1063/1.4736859](https://doi.org/10.1063/1.4736859). [作者机构全文记录](https://orbi.uliege.be/handle/2268/165073). 第 III.B 节明确使用自治 Van der Pol 和 $\mu=0.3$；本文的初值混合分布、时长和条件区间另行定义。

[^vdp-sp]: Katayama, N., & Susuki, Y. **Koopman analysis of the singularly perturbed van der Pol oscillator**. *Chaos*, **34**(9), 093133, 2024. DOI: [10.1063/5.0216779](https://doi.org/10.1063/5.0216779). [arXiv:2405.07635](https://arxiv.org/abs/2405.07635). 用途：Van der Pol 快慢时间尺度与 Koopman 谱解释的补充来源；本文未采用其奇异摄动坐标或将其参数直接映射为本版 $\mu$。

[^ah]: Axås, J., & Haller, G. **Model reduction for nonlinearizable dynamics via delay-embedded spectral submanifolds**. *Nonlinear Dynamics*, **111**, 22079–22099, 2023. DOI: [10.1007/s11071-023-08705-2](https://doi.org/10.1007/s11071-023-08705-2). 第 4.1 节提供两质量块、二次接地软化、三次质量间硬化与 $\Delta t=0.1$ 的算例。本文采用该物理模型，不继承单条 SSM 训练轨线人口。

[^ah-code]: Haller Group, **SSMLearn / fastSSM**, 官方脚本 [`fastSSM/examples/oscillator/oscillator.m`](https://github.com/haller-group/SSMLearn/blob/main/fastSSM/examples/oscillator/oscillator.m). 核对日期：2026-09-15；核对文件 blob SHA：`dc4c064a0aa168bf72871350a5b7bf687320cd80`。该文件明确给出质量／刚度／阻尼矩阵、`FF`、`F = A*x - FF(x)`、`getSSMIC` 初态与 `ode45` 生成流程。blob SHA 识别文件内容，不替代运行整个仓库时应冻结的仓库 commit 和依赖版本。

[^fput]: Marchetti, G. **Intrinsic dimensionality of Fermi–Pasta–Ulam–Tsingou high-dimensional trajectories through manifold learning: A linear approach**. *Chaos*, **35**(10), 103118, 2025. DOI: [10.1063/5.0293702](https://doi.org/10.1063/5.0293702). [arXiv:2411.02058v3](https://arxiv.org/abs/2411.02058v3). 用途：固定端点、32 自由度 FPUT–β 模型及现代长轨数据来源。正式引用采用 2025 期刊版，2024 是预印本初次提交年份。

[^fput-data1]: Marchetti, G. **Dataset of entire trajectories of Fermi–Pasta–Ulam–Tsingou model β ($N=32,k=1,A=10,\beta\in[0.1,1.5]$)**. Zenodo, 2025. DOI: [10.5281/zenodo.15856651](https://doi.org/10.5281/zenodo.15856651). 该题名中的 $N$ 为原作者质量块数，本协议统一记为 $n_{\mathrm{dof}}$。这里只登记论文引用的数据来源，不把其中单条长轨拆分为本协议的独立初值人口。

[^fput-data2]: Marchetti, G. **Dataset of entire trajectories of Fermi–Pasta–Ulam–Tsingou model β ($N=32,k=1,A=10,\beta\in[1.6,3.0]$)**. Zenodo, 2025. DOI: [10.5281/zenodo.15873646](https://doi.org/10.5281/zenodo.15873646). 用途：较强非线性文献 replay 的外部资源；不自动纳入本版 $[0.5,1.5]$ COND 主区间。

[^lorenz]: Lorenz, E. N. **Deterministic Nonperiodic Flow**. *Journal of the Atmospheric Sciences*, **20**(2), 130–141, 1963. DOI: `10.1175/1520-0469(1963)020<0130:DNF>2.0.CO;2`. [出版社页面](https://journals.ametsoc.org/view/journals/atsc/20/2/1520-0469_1963_020_0130_dnf_2_0_co_2.xml). 用途：Lorenz63 方程与经典参数来源；本文 pre-burn 初值盒、轨线预算和条件候选范围另行声明。

[^rossler]: Rössler, O. E. **An equation for continuous chaos**. *Physics Letters A*, **57**(5), 397–398, 1976. DOI: [10.1016/0375-9601(76)90101-8](https://doi.org/10.1016/0375-9601%2876%2990101-8). 用途：Rössler 方程来源。本文采用项目固定的 $(0.2,0.2,5.7)$ 配置，初值盒和时间预算由本协议定义。

[^dp]: Dormand, J. R., & Prince, P. J. **A family of embedded Runge–Kutta formulae**. *Journal of Computational and Applied Mathematics*, **6**(1), 19–26, 1980. DOI: [10.1016/0771-050X(80)90013-3](https://doi.org/10.1016/0771-050X%2880%2990013-3). 用途：DP5(4) 嵌入式积分器来源；容差和最大步长为本文数值配置。

[^yoshida]: Yoshida, H. **Construction of higher order symplectic integrators**. *Physics Letters A*, **150**(5–7), 262–268, 1990. DOI: [10.1016/0375-9601(90)90092-3](https://doi.org/10.1016/0375-9601%2890%2990092-3). 用途：对称低阶辛映射的高阶组合。本文给出所用四阶组合系数，子步数由独立数值资格确定。

[^k3]: 项目协议 [[SKDM-K3-Multi-step Predictive SKDM]]。用途：单快照字典、谱坐标、多步风险与训练期／部署期读出接口；不作为物理 ODE 参数来源。

[^hp]: 项目协议 [[SKDM-K3.4.3-From Conditional EDMD to Hidden-Parameter SKDM]]。用途：共享字典上的条件谱抽取、谱值、KMD 读出及 conditional R1 接口。

[^id]: 项目协议 [[SKDM-K3.4.2-SSM Hidden-Parameter Koopman Operator Manifold]]，2026-09-15 版，正文题名为“快速数值 SSM 隐条件辨识”。用途：工况分组、冻结教师、因果历史条件 provider 与数据权限；TestSub-1 不复制其数值拟合算法。

[^mag0]: 项目协议 [[SKDM-MAG0-Koopman Learning Measure and Projection Geometry]]。用途：状态测度、占据测度与条件动力学的解释边界。

[^mag1]: 项目协议 [[SKDM-MAG1-Empirical Batch Moment Package Contract]]。用途：结构学习 source／pair 测度、概率质量及去重计算边界。
