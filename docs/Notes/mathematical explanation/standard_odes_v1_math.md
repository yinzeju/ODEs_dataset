# Standard_ODEs_v1 聚合数学说明

## 1. 数据集定位

`Standard_ODEs_v1` 是 `ODEs_dataset` 中面向后续常用学习与评测任务整理的一组标准 ODE 对象集合。它不是一个新的动力学家族，而是从项目内已经存在、已经有数学说明和工程对象的系统中抽取一组常用 clean 对象，并为每个对象定义两个统一的含噪观测版本。

本聚合版本包含 8 个 clean 基础对象：

| 序号 | 聚合对象 | 源对象或源说明 | 状态维数 | 类型 |
| ---: | --- | --- | ---: | --- |
| 1 | `linear_diagonal` | `linear_diagonal_math.md`; `configs/systems/unit_internal/linear_diagonal_small.json` | 4 | 线性实对角谱 |
| 2 | `linear_rotation_contraction_2d` | `linear_rotation_contraction_2d_math.md`; `configs/systems/unit_internal/linear_rotation_contraction_2d.json` | 2 | 线性复共轭谱 |
| 3 | `damped_linear_oscillator` | `linear_oscillator_math.md`; `configs/systems/linear_oscillator_v1_core_damped.json` | 2 | 线性阻尼振子 |
| 4 | `duffing_chi40_medium` | `duffing_nonlinearity_matrix_v1_math.md` 中的 `beta=10.0, Q=2.0` cell | 2 | 中等 Duffing 非线性 |
| 5 | `duffing_chi320_strong` | `duffing_nonlinearity_matrix_v1_math.md` 中的 `beta=20.0, Q=4.0` cell | 2 | 强 Duffing 非线性 |
| 6 | `lorenz63_standard` | `lorenz63_math.md`; `configs/systems/v1_core/lorenz63_standard.json` | 3 | 低维耗散混沌 |
| 7 | `rossler_standard` | `rossler_math.md`; `configs/systems/v1_core/rossler_standard.json` | 3 | 单卷曲耗散混沌 |
| 8 | `nonlinear_pendulum_lusch2018` | `lusch-aligned_nonlinear_pendulum_math.md`; `configs/systems/v1_plus/nonlinear_pendulum_lusch2018_medium.json` | 2 | Hamiltonian 非线性摆 |

`jordan_nonnormal_linear` 不纳入本聚合版本。

每个 clean 基础对象同时派生两个含噪观测版本：

$$
\mathrm{SNR}_{\mathrm{dB}}\in\{5,15\}.
$$

因此，`Standard_ODEs_v1` 的观测对象总数为

$$
8 \times (1+2)=24,
$$

其中 8 个为 clean 版本，16 个为 noisy 版本。

---

## 2. 统一数据与观测约定

每个基础系统生成连续或离散时间状态轨线：

$$
\mathbf x_m^{(r)}\in\mathbb R^{d_x},
\qquad
m=0,\dots,M,
\qquad
r=1,\dots,R.
$$

单条轨线按列快照写为

$$
\mathbf X^{(r)}
=
\begin{bmatrix}
\mathbf x_0^{(r)} & \mathbf x_1^{(r)} & \cdots & \mathbf x_M^{(r)}
\end{bmatrix}
\in\mathbb R^{d_x\times(M+1)}.
$$

项目内部分生成器可能保存为 `trajectory_by_time_by_channel` 或 `state_dim_by_time_by_trajectory`。本数学说明只固定数学含义：时间索引是同一条轨线上的有序采样，状态维度是物理坐标维度。

clean 观测采用全状态恒等观测：

$$
\mathbf z_m^{(r,\mathrm{clean})}
=
\mathbf x_m^{(r)}.
$$

噪声只加在观测上，不改变底层动力系统，也不改变 clean 物理状态轨线：

$$
\mathbf z_m^{(r,s)}
=
\mathbf x_m^{(r)}
+
\boldsymbol\eta_m^{(r,s)},
\qquad
s\in\{5\mathrm{db},15\mathrm{db}\}.
$$

默认监督目标保留 clean 物理状态：

$$
\mathbf y_m^{(r)}
=
\mathbf x_m^{(r)}.
$$

如果下游任务需要 noisy-to-noisy forecasting，可以由 noisy 观测序列自行构造；但本聚合数学定义的默认目标是 clean target，以便同时支持去噪、鲁棒预测和 clean-state 误差评估。

### 2.1 正式机器学习生成规格

`Standard_ODEs_v1` 不应直接复用部分早期对象的 smoke 或 medium-small 数据规模。正式聚合数据集应按机器学习训练资源重新生成或重新整理，保证每个对象都有足够多的轨线、one-step pair 和 rollout window。

正式生成规格如下：

| 聚合对象 | $\tau$ | $M$ | 快照数 $M+1$ | clean 轨线数 $R$ | Split-I train/val/test | train one-step pairs | 主要 rollout horizons |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- |
| `linear_diagonal` | 0.01 | 1024 | 1025 | 512 | 384/64/64 | 393216 | 1, 4, 8, 16, 32, 64 |
| `linear_rotation_contraction_2d` | 0.01 | 2048 | 2049 | 512 | 384/64/64 | 786432 | 1, 4, 8, 16, 32, 64, 128 |
| `damped_linear_oscillator` | 0.02 | 3000 | 3001 | 512 | 384/64/64 | 1152000 | 1, 4, 8, 16, 32, 64, 128 |
| `duffing_chi40_medium` | 0.01 | 2048 | 2049 | 512 | 384/64/64 | 786432 | 1, 4, 8, 16, 32, 64, 128 |
| `duffing_chi320_strong` | 0.01 | 2048 | 2049 | 512 | 384/64/64 | 786432 | 1, 4, 8, 16, 32, 64, 128 |
| `lorenz63_standard` | 0.01 | 4096 | 4097 | 512 | 384/64/64 | 1572864 | 1, 4, 8, 16, 32, 64 |
| `rossler_standard` | 0.02 | 4096 | 4097 | 512 | 384/64/64 | 1572864 | 1, 4, 8, 16, 32, 64 |
| `nonlinear_pendulum_lusch2018` | 0.02 | 50 | 51 | 8192 | 6144/1024/1024 | 307200 | 1, 5, 10, 25, 50 |

其中 $M$ 表示一步转移数量，单条轨线含 $M+1$ 个快照。对第 $s$ 个对象，clean 状态张量可写为

$$
\mathcal X_s
\in
\mathbb R^{R_s\times(M_s+1)\times d_s},
$$

clean 观测张量和 clean target 张量满足

$$
\mathcal Z_s^{\mathrm{clean}}
=
\mathcal X_s,
\qquad
\mathcal Y_s
=
\mathcal X_s.
$$

两个 noisy 版本分别保存为

$$
\mathcal Z_s^{5\mathrm{dB}},
\qquad
\mathcal Z_s^{15\mathrm{dB}},
$$

且

$$
\operatorname{size}
\left(
\mathcal Z_s^{5\mathrm{dB}}
\right)
=
\operatorname{size}
\left(
\mathcal Z_s^{15\mathrm{dB}}
\right)
=
\operatorname{size}
\left(
\mathcal X_s
\right).
$$

### 2.2 数据量汇总

按上述 formal profile，clean 基础对象合计包含

$$
9,821,696
$$

个状态快照向量。按状态维数展开后，clean 物理状态标量总数为

$$
24,888,320.
$$

若同时保存 clean、5 dB noisy 和 15 dB noisy 三个观测版本，观测标量总量约为

$$
3\times24,888,320
=
74,664,960.
$$

这还不包括 target 的重复存储、split metadata、window index 和诊断表。若 target 与 clean state 以引用或共享数据方式保存，可以避免额外复制；若为了下游读取方便单独保存 target，则总标量存储会进一步增加。

训练 one-step pair 数量合计为

$$
7,357,440.
$$

如果对每个 noisy 版本也生成独立 one-step 输入，训练输入 pair 规模为

$$
3\times7,357,440
=
22,072,320,
$$

其中三倍分别对应 clean、5 dB noisy 和 15 dB noisy 输入。默认 target 仍为 clean state。

### 2.3 机器学习任务对象

每个对象至少应支持以下任务：

| 任务 | 输入 | 目标 | 用途 |
| --- | --- | --- | --- |
| one-step clean forecasting | $\mathbf z_m^{\mathrm{clean}}$ | $\mathbf x_{m+1}$ | 基础动力学拟合与谱健康检查 |
| one-step noisy forecasting | $\mathbf z_m^{s}$ | $\mathbf x_{m+1}$ | 噪声鲁棒预测与去噪预测 |
| multi-step rollout | $\mathbf z_s$ | $\mathbf x_{s+1:s+H}$ | 短期与中期 rollout 评估 |
| reconstruction / denoising | $\mathbf z_m^{s}$ | $\mathbf x_m$ | 含噪观测到 clean state 的重构 |
| long-time statistics | 生成轨线统计量 | clean 轨线统计量 | Lorenz63/Rossler 等混沌系统的长期统计保持 |

对任意 horizon $H$，第 $r$ 条轨线可生成的 rollout window 数量为

$$
N_{\mathrm{win}}(M,H)
=
M-H+1.
$$

因此某个 split 中的 rollout window 数量为

$$
|\mathcal R_{\mathrm{split}}|(M-H+1).
$$

例如，对 $R_{\mathrm{train}}=384$、$M=2048$、$H=128$ 的对象，训练 rollout window 数量为

$$
384(2048-128+1)
=
737664.
$$

非线性摆保持 Lusch-aligned 的短时间窗 $t\in[0,1]$，因此通过增加轨线数量到 $R=8192$ 来保证机器学习样本量，而不是盲目延长单条轨线。该设计保留原始 continuous-spectrum pendulum 任务口径，同时提供超过三十万条训练 one-step pairs。

### 2.4 数值积分精度约定

`Standard_ODEs_v1` 的正式生成采用“高精度生成、Float32 保存”的策略。也就是说，动力系统积分和诊断先在 `Float64` 中完成，保存给 Flux 等神经网络训练使用的张量再转换为 `Float32`。

不同对象的积分策略为：

| 对象类型 | 积分或传播方式 | 精度理由 |
| --- | --- | --- |
| 线性对角、旋转收缩、阻尼振子 | 解析离散传播或矩阵指数传播 | 避免把 ODE 积分误差引入线性谱基准 |
| Duffing `chi=40` 和 `chi=320` | 本地自适应 Dormand-Prince 5(4) 积分器 | 中强非线性下需要严格控制局部误差和内部步长 |
| Lorenz63、Rossler | 本地自适应 Dormand-Prince 5(4) 积分器 | 混沌系统对局部数值误差敏感，正式数据不使用粗固定步积分 |
| 非线性摆 | 短时间窗固定步 RK4 | 当前 Lusch-aligned 轨线很短，核心风险由能量筛选和覆盖度控制 |

Duffing 对象的正式容差为

$$
\mathrm{reltol}=10^{-11},
\qquad
\mathrm{abstol}=10^{-13},
\qquad
\Delta t_{\max}=0.0005.
$$

Lorenz63 和 Rossler 的正式容差为

$$
\mathrm{reltol}=10^{-10},
\qquad
\mathrm{abstol}=10^{-12}.
$$

其中 Lorenz63 使用

$$
\Delta t_{\max}=0.002,
$$

Rossler 使用

$$
\Delta t_{\max}=0.004.
$$

这些设置的目标是让生成数据的数值误差小于后续 Float32 训练和 5 dB / 15 dB 观测噪声带来的学习误差，不把数据生成误差误认为模型误差。

---

## 3. 噪声模型

`Standard_ODEs_v1` 的 5 dB 和 15 dB 版本采用加性高斯观测噪声。对任一 clean 对象，设第 $j$ 个状态坐标在 clean 训练轨线上的信号功率为

$$
P_j
=
\frac{1}{|\mathcal R_{\mathrm{train}}|(M+1)}
\sum_{r\in\mathcal R_{\mathrm{train}}}
\sum_{m=0}^{M}
\left(x_{m,j}^{(r)}\right)^2.
$$

给定目标信噪比

$$
\mathrm{SNR}_{\mathrm{dB}}
=
10\log_{10}\frac{P_j}{\sigma_j^2},
$$

对应噪声标准差为

$$
\sigma_j(\mathrm{SNR}_{\mathrm{dB}})
=
\sqrt{\frac{P_j}{10^{\mathrm{SNR}_{\mathrm{dB}}/10}}}
=
\frac{\sqrt{P_j}}{10^{\mathrm{SNR}_{\mathrm{dB}}/20}}.
$$

因此

$$
\boldsymbol\eta_m^{(r,s)}
\sim
\mathcal N(\mathbf 0,\Sigma_s),
\qquad
\Sigma_s
=
\operatorname{diag}
\left(
\sigma_1(s)^2,\dots,\sigma_{d_x}(s)^2
\right).
$$

数值比例为

$$
\frac{\sigma_j(5\mathrm{dB})}{\sqrt{P_j}}
\approx
0.56234,
\qquad
\frac{\sigma_j(15\mathrm{dB})}{\sqrt{P_j}}
\approx
0.17783.
$$

所以 5 dB 是强噪声版本，15 dB 是中低噪声版本。噪声应使用固定随机种子，并在 metadata 中记录：

```text
noise_type = additive_gaussian_observation
snr_db = 5 or 15
noise_applied_to = observation_only
noise_scale_estimation_split = train
target_policy = clean_state
```

---

## 4. 三个线性对象

### 4.1 `linear_diagonal`

状态为

$$
\mathbf x(t)\in\mathbb R^4.
$$

连续系统为

$$
\dot{\mathbf x}
=
\Lambda\mathbf x,
\qquad
\Lambda
=
\operatorname{diag}(-1.0,-0.3,0.1,0.5).
$$

闭式解为

$$
\mathbf x(t)
=
e^{\Lambda t}\mathbf x_0.
$$

动力学参数沿用现有 `linear_diagonal` 对象；`Standard_ODEs_v1` 正式生成不采用早期 small 轨线规模，而采用 2.1 节的机器学习 formal profile：

$$
\tau=0.01,
\qquad
M=1024,
\qquad
R=512.
$$

离散一步传播矩阵为

$$
A_\tau
=
e^{\Lambda\tau}
=
\operatorname{diag}
\left(
e^{-1.0\tau},
e^{-0.3\tau},
e^{0.1\tau},
e^{0.5\tau}
\right).
$$

该对象用于检查实对角谱、稳定与不稳定模态、矩阵方向、one-step 传播和全状态观测协议。

### 4.2 `linear_rotation_contraction_2d`

状态为

$$
\mathbf x(t)
=
\begin{bmatrix}
x_1(t)\\
x_2(t)
\end{bmatrix}
\in\mathbb R^2.
$$

连续系统为

$$
\dot{\mathbf x}
=
A\mathbf x,
\qquad
A
=
\begin{bmatrix}
-\gamma & -\omega\\
\omega & -\gamma
\end{bmatrix}.
$$

动力参数沿用现有 `linear_rotation_contraction_2d` 配置：

$$
\gamma=0.15,
\qquad
\omega=2\pi.
$$

`Standard_ODEs_v1` 正式生成采用

$$
\tau=0.01,
\qquad
M=2048,
\qquad
R=512.
$$

闭式离散传播为

$$
\mathbf x_{m+1}
=
e^{-\gamma\tau}
\begin{bmatrix}
\cos(\omega\tau) & -\sin(\omega\tau)\\
\sin(\omega\tau) & \cos(\omega\tau)
\end{bmatrix}
\mathbf x_m.
$$

连续谱为

$$
\lambda_\pm
=
-\gamma\pm i\omega,
$$

离散谱为

$$
\rho_\pm
=
\exp\left((-\gamma\pm i\omega)\tau\right).
$$

该对象用于检查实值二维状态中的复共轭谱、相位传播和稳定旋转收缩。

### 4.3 `damped_linear_oscillator`

状态为

$$
\mathbf x(t)
=
\begin{bmatrix}
q(t)\\
p(t)
\end{bmatrix}
\in\mathbb R^2.
$$

连续系统为

$$
\dot q=p,
\qquad
\dot p=-2\gamma p-\omega_0^2 q.
$$

动力参数沿用现有 v1-core damped oscillator：

$$
\gamma=0.05,
\qquad
\omega_0=1.0.
$$

`Standard_ODEs_v1` 正式生成采用

$$
\tau=0.02,
\qquad
M=3000,
\qquad
R=512.
$$

矩阵形式为

$$
\dot{\mathbf x}
=
A\mathbf x,
\qquad
A
=
\begin{bmatrix}
0 & 1\\
-\omega_0^2 & -2\gamma
\end{bmatrix}.
$$

欠阻尼情形下，连续谱为

$$
\lambda_\pm
=
-\gamma
\pm
i\sqrt{\omega_0^2-\gamma^2},
$$

离散谱为

$$
\rho_\pm
=
\exp(\tau\lambda_\pm).
$$

机械能定义为

$$
E(q,p)
=
\frac12p^2+\frac12\omega_0^2q^2,
$$

并满足

$$
\frac{dE}{dt}
=
-2\gamma p^2
\le 0.
$$

该对象作为最常用的二维线性振子基准，连接线性谱恢复、阻尼 rollout 和能量耗散诊断。

---

## 5. 两个 Duffing 对象

两个 Duffing 对象都来自 `duffing_nonlinearity_matrix_v1`，统一使用 hardening Duffing 形式：

$$
\dot q=p,
\qquad
\dot p=-\delta p-\alpha q-\beta q^3.
$$

固定参数为

$$
\alpha=1.0,
\qquad
\delta=0.08,
\qquad
\gamma=0.0,
\qquad
\texttt{forcing\_type}=\texttt{force\_none}.
$$

有效非线性强度定义为

$$
\chi_{\mathrm{nl}}
=
\frac{\beta Q^2}{\alpha}
=
\beta Q^2.
$$

两个纳入对象为：

| 聚合对象 | Duffing matrix cell | 参数 | 非线性强度 |
| --- | --- | --- | ---: |
| `duffing_chi40_medium` | `D_beta_10000__Q_200` | $\beta=10.0,\ Q=2.0$ | $\chi_{\mathrm{nl}}=40$ |
| `duffing_chi320_strong` | `D_beta_20000__Q_400` | $\beta=20.0,\ Q=4.0$ | $\chi_{\mathrm{nl}}=320$ |

时间步沿用当前 Duffing matrix 配置，单个被选中 cell 的正式机器学习数据规模按 `Standard_ODEs_v1` 提升到更长轨线：

$$
\tau=0.01,
\qquad
M=2048,
\qquad
R_{\mathrm{train}}=384,
\qquad
R_{\mathrm{val}}=64,
\qquad
R_{\mathrm{test}}=64.
$$

总轨线数为

$$
R=512.
$$

初值按 $Q$ 控制的相平面环形区域采样。令

$$
q_0=a\cos\theta,
\qquad
p_0=a\sin\theta,
\qquad
\theta\sim\operatorname{Unif}[0,2\pi),
$$

其中

$$
a
=
\sqrt{
(0.75Q)^2
+
u\left(Q^2-(0.75Q)^2\right)
},
\qquad
u\sim\operatorname{Unif}[0,1].
$$

两个 Duffing 对象的能量为

$$
E(q,p)
=
\frac12p^2
+
\frac12\alpha q^2
+
\frac14\beta q^4.
$$

沿精确动力学有

$$
\frac{dE}{dt}
=
-\delta p^2
\le 0.
$$

当前配置文件中，极端求解器设置的触发阈值为

$$
\chi_{\mathrm{nl}}\ge 40.
$$

因此 `duffing_chi40_medium` 和 `duffing_chi320_strong` 都应使用 stricter solver 设置：

$$
\mathrm{reltol}=10^{-11},
\qquad
\mathrm{abstol}=10^{-13},
\qquad
\Delta t_{\max}=0.0005.
$$

这两个对象的用途是用同一 Duffing 方程和同一数据协议比较中等非线性与强非线性下的 rollout、相位、谱和 Gram 条件数退化。

---

## 6. Lorenz63 标准对象

`lorenz63_standard` 使用经典 Lorenz '63 系统：

$$
\begin{aligned}
\dot x &= \sigma(y-x),\\
\dot y &= x(\rho-z)-y,\\
\dot z &= xy-\beta z.
\end{aligned}
$$

标准参数为

$$
\sigma=10,
\qquad
\rho=28,
\qquad
\beta=\frac83.
$$

状态维数为

$$
d_x=3.
$$

动力参数沿用现有 Lorenz63 standard 对象；`Standard_ODEs_v1` 正式生成采用更大的初值轨线集合和 2 的幂长度轨线：

$$
\tau=0.01,
\qquad
T_{\mathrm{burn}}=10.0,
\qquad
M=4096,
\qquad
R=512.
$$

源对象使用 $4\times4\times3$ 手工网格作为初值口径。正式聚合版本应扩展为 $R=512$ 条 pre-burn-in 初值轨线，可在相同盒区域内使用分层 Latin-hypercube、低差异序列或分层随机采样，以保持双翼吸引子的覆盖：

$$
x_0\in\{-12,-4,4,12\},
\quad
y_0\in\{-12,-4,4,12\},
\quad
z_0\in\{8,20,32\}.
$$

轨线在 burn-in 后保存，以更集中地覆盖标准混沌吸引子。向量场散度为

$$
\nabla\cdot f
=
-\sigma-1-\beta
=
-\frac{41}{3}<0.
$$

该对象用于低维耗散混沌测试。短期 rollout 可以使用逐点误差；长期 rollout 不应只看逐点相位一致性，还应看吸引子几何、边际统计、协方差、自相关或双翼切换统计。

---

## 7. Rossler 标准对象

`rossler_standard` 使用经典 Rossler 系统：

$$
\begin{aligned}
\dot x &= -y-z,\\
\dot y &= x+ay,\\
\dot z &= b+z(x-c).
\end{aligned}
$$

标准参数为

$$
a=0.2,
\qquad
b=0.2,
\qquad
c=5.7.
$$

状态维数为

$$
d_x=3.
$$

动力参数沿用现有 Rossler standard 对象；`Standard_ODEs_v1` 正式生成采用更大的初值轨线集合和 2 的幂长度轨线：

$$
\tau=0.02,
\qquad
T_{\mathrm{burn}}=50.0,
\qquad
M=4096,
\qquad
R=512.
$$

源对象使用 $4\times4\times3$ 手工网格作为初值口径。正式聚合版本应扩展为 $R=512$ 条 pre-burn-in 初值轨线，可在相同盒区域内使用分层 Latin-hypercube、低差异序列或分层随机采样，以保持单卷曲吸引子的覆盖：

$$
x_0\in\{-8,-2,2,8\},
\quad
y_0\in\{-8,-2,2,8\},
\quad
z_0\in\{0.5,4,8\}.
$$

向量场散度为

$$
\nabla\cdot f
=
x+a-c
=
x-5.5.
$$

长期平均散度应主要体现耗散性，但点态散度不要求处处为负。该对象用于检验不同于 Lorenz 双翼结构的单卷曲 chaotic geometry。

---

## 8. 非线性摆对象

`nonlinear_pendulum_lusch2018` 使用 Lusch-aligned 的无阻尼、无外力、未线性化 Hamiltonian pendulum：

$$
\dot x_1=x_2,
\qquad
\dot x_2=-\sin(x_1).
$$

状态为

$$
\mathbf x
=
\begin{bmatrix}
x_1\\
x_2
\end{bmatrix}
=
\begin{bmatrix}
\theta\\
\dot\theta
\end{bmatrix}
\in\mathbb R^2.
$$

Hamiltonian 为

$$
H(\mathbf x)
=
\frac12x_2^2-\cos(x_1).
$$

连续精确动力学满足

$$
\frac{dH}{dt}=0.
$$

动力学与采样窗口沿用 Lusch-aligned medium 口径；`Standard_ODEs_v1` 正式生成通过增加初值数量保证机器学习样本量：

$$
\tau=0.02,
\qquad
t\in[0,1],
\qquad
M+1=51,
\qquad
R=8192.
$$

初值由 rejection sampling 得到：

$$
x_1^{\mathrm{raw}}\sim\operatorname{Unif}[-3.1,3.1],
\qquad
x_2^{\mathrm{raw}}\sim\operatorname{Unif}[-2,2],
$$

并保留满足

$$
H(\mathbf x_0)<0.99
$$

的样本。由于 separatrix 能量为

$$
H_{\mathrm{sep}}=1,
$$

该对象只保留 libration 区域，不包含完整 rotation 轨道。

该对象的核心价值是覆盖非线性摆不同能量层上的连续频率变化。接近 separatrix 时周期增大、频率降低，因此下游固定频率或固定线性 Koopman 近似可能在高能区域表现变差。

---

## 9. 版本命名建议

每个基础对象建议保留一个 clean id 和两个 noisy id：

```text
<base_object_id>__clean
<base_object_id>__noise_5db
<base_object_id>__noise_15db
```

例如：

```text
lorenz63_standard__clean
lorenz63_standard__noise_5db
lorenz63_standard__noise_15db
```

Duffing 对象示例：

```text
duffing_chi40_medium__clean
duffing_chi40_medium__noise_5db
duffing_chi40_medium__noise_15db

duffing_chi320_strong__clean
duffing_chi320_strong__noise_5db
duffing_chi320_strong__noise_15db
```

---

## 10. 关键验收指标

`Standard_ODEs_v1` 后续生成时，每个对象至少应检查：

| 检查项 | 数学含义 |
| --- | --- |
| finite check | 所有 clean 和 noisy 观测均无 `NaN`、`Inf` |
| shape check | clean/noisy 版本的轨线数、时间长度、状态维度一致 |
| split check | train/val/test 按轨线切分，不按窗口随机切分 |
| noise SNR check | 经验 SNR 接近 5 dB 或 15 dB |
| clean target check | noisy 版本的默认 target 仍对应 clean state |
| linear truth check | 线性对象的一步解析残差接近数值精度 |
| Duffing energy check | $E_M\le E_0+\epsilon_{\mathrm{num}}$ |
| Lorenz/Rossler attractor check | 坐标范围、统计量和吸引子覆盖合理 |
| pendulum energy check | Hamiltonian drift 小，且不越过 separatrix |

对混沌系统，长期 rollout 的逐点误差增长是动力学性质，不应单独作为失败判据。对含噪版本，应同时报告 clean-state error 和 noisy-observation error，避免把观测噪声误判为动力学生成错误。

---

## 11. 聚合对象清单

最终基础对象集合为

$$
\mathcal S_{\mathrm{clean}}
=
\{
\texttt{linear\_diagonal},
\texttt{linear\_rotation\_contraction\_2d},
\texttt{damped\_linear\_oscillator},
\texttt{duffing\_chi40\_medium},
\texttt{duffing\_chi320\_strong},
\texttt{lorenz63\_standard},
\texttt{rossler\_standard},
\texttt{nonlinear\_pendulum\_lusch2018}
\}.
$$

噪声版本集合为

$$
\mathcal S_{\mathrm{noisy}}
=
\left\{
(s,\nu):
s\in\mathcal S_{\mathrm{clean}},
\nu\in\{5\mathrm{db},15\mathrm{db}\}
\right\}.
$$

`Standard_ODEs_v1` 的完整观测对象集合为

$$
\mathcal S_{\mathrm{standard}}
=
\mathcal S_{\mathrm{clean}}
\cup
\mathcal S_{\mathrm{noisy}}.
$$

该聚合版本的设计意图是：用少量、常用、数学含义清晰的 ODE 对象覆盖实线性谱、复线性谱、阻尼振子、Duffing 非线性强度、低维混沌、单卷曲混沌和 Hamiltonian 连续频率结构，并在统一 SNR 协议下提供鲁棒性测试入口。
