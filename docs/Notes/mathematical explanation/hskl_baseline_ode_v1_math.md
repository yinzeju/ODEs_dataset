# Step 1：数学说明  
## 前置任务：HSKL_Baseline 专用 ODEs 数据集设计

## 1. Task understanding

本次前置任务的目标是在 **ODEs_dataset** 项目内创建一个专门服务正式 **HSKL-Base / HSKL_Baseline** 测试的数据集。它不是泛化版 ODE benchmark，而是为了后续 HSKL 学习器验证而冻结的一组动力系统、参数族、split、观测模式、窗口协议与噪声协议。

建议数据集名称固定为：

$$

\boxed{
\texttt{hskl\_baseline\_ode\_v1}
}

$$

对应 benchmark version 可记为：

$$

\boxed{
\texttt{benchmark\_version = "hskl\_baseline\_ode\_v1"}
}

$$

这与 HSKL Baseline 指南中的数据对象约束一致：HSKL 工程后续只消费 `benchmark_version`、`system_id`、`difficulty_level`、`split_id`、`observation_mode`、`parameter_regime`、`window_profile`、`noise_level` 等数据对象声明，而不在 HSKL 工程里生成 ODE 数据。fileciteturn2file2

本数据集需要服务 HSKL-Base 的三大数学底座：

$$

\boxed{
\text{Koopman 线性推进}
+
\text{Hardy 可实现}
+
\text{轨线级重构}.
}

$$

HSKL-Base 的目标是学习复值谱核心 $\boldsymbol{\varphi}_{\theta}:\mathcal Z\to\mathbb C^N$，并使其同时满足谱推进、Hardy admissibility 与轨线级重构要求。fileciteturn2file0

因此，ODEs_dataset 侧应输出完整轨线对象，而不是已经打碎的随机窗口样本。

---

## 2. Mathematical objects and dimensions

### 2.1 动力系统族

对每个系统对象 $q$，定义连续时间 ODE：

$$

\dot{\mathbf x}
=
\mathbf f_q(\mathbf x;\boldsymbol{\mu}),
\qquad
\mathbf x(t)\in\mathbb R^{d_x(q)},
\qquad
\boldsymbol{\mu}\in\Pi_q.

$$

采样间隔为 $\tau_q>0$，离散流映射为：

$$

\mathbf x_{m+1}
=
\mathbf F_q^{\tau_q}(\mathbf x_m;\boldsymbol{\mu}),
\qquad
m=0,\dots,M.

$$

每条轨线记为：

$$

\mathbf X^{(r)}
=
\left(
\mathbf x_0^{(r)},
\mathbf x_1^{(r)},
\dots,
\mathbf x_M^{(r)}
\right)
\in
\mathbb R^{d_x\times(M+1)}.

$$

其中：

$$

r=1,\dots,R.

$$

### 2.2 观测链

HSKL 输入不是必须等于真实状态，而是：

$$

\mathbf x
\xmapsto{U}
\mathbf u
\xmapsto{S}
\mathbf s
\xmapsto{Z}
\mathbf z.

$$

在本数据集中可统一写成：

$$

\mathbf z_m
=
\mathcal O_o(\mathbf x_m)
\in\mathbb R^{d_z(o)}.

$$

默认目标观测取：

$$

\mathbf y_m
=
\mathbf z_m
\in\mathbb R^{d_y},
\qquad
d_y=d_z,

$$

用于后续实线性 KMD 轨线级重构：

$$

\widehat{\mathbf y}_{s+\ell,\mathbb R}
=
\mathbf b+
\operatorname{Re}
\left(
\mathbf M_{\mathrm{rec}}
\mathbf\Lambda^\ell
\boldsymbol{\varphi}_{\theta}(\mathbf z_s)
\right).

$$

HSKL 指南明确：实值目标不要求复值谱核心本身为实数，也不要求通道必须显式共轭成对；实值性只在最终读出层 enforce。fileciteturn3file14

### 2.3 数据张量

对每个 system object、parameter regime、split、observation mode、noise level，数据集应数学上包含：

$$

\mathcal X
\in
\mathbb R^{d_x\times(M+1)\times R},

$$

$$

\mathcal Z
\in
\mathbb R^{d_z\times(M+1)\times R},

$$

$$

\mathcal Y
\in
\mathbb R^{d_y\times(M+1)\times R}.

$$

如果包含参数标签，则同时保存：

$$

\boldsymbol{\mu}^{(r)}\in\Pi_q,
\qquad
r=1,\dots,R.

$$

### 2.4 HSKL 窗口条件

后续 HSKL 会从轨线中构造：

- one-step pairs；
- trajectory reconstruction windows；
- Hardy windows；
- rollout evaluation windows；
- statistics windows。

Hardy 部分必须支持：

$$

s=1,\dots,S,
\qquad
S=M-L_{\mathrm H}+1,

$$

$$

\mathcal F^{(\rho,L_{\mathrm H})}
\in
\mathbb C^{L_{\mathrm H}\times N\times S},

$$

其中轴约定必须是：

$$

\boxed{
\text{axis 1: Hardy 系数阶 } \ell=0,\dots,L_{\mathrm H}-1,
}

$$

$$

\boxed{
\text{axis 2: 谱通道 } j=1,\dots,N,
}

$$

$$

\boxed{
\text{axis 3: 窗口起点 } s.
}

$$

该 $L\times N\times S$ 布局已经被 HSKL Hardy 前置验证固定，应在正式 HSKL 数据协议中继承。fileciteturn2file0

---

## 3. Core formulas / numerical procedures

## 3.1 数据集总命名与对象层级

建议冻结为：

$$

\boxed{
\texttt{hskl\_baseline\_ode\_v1}
}

$$

内部组织分三层。

### A. HSKL internal sanity layer

用于先验证谱推进、Hardy 约束、窗口协议和读出协议是否正确。

$$

\boxed{
\mathcal S_{\mathrm{unit}}
=
\{
\texttt{linear\_diagonal},
\texttt{linear\_rotation\_contraction},
\texttt{linear\_jordan\_nonnormal}
\}.
}

$$

其中 `linear_jordan_nonnormal` 只作为对角谱模型边界压力测试，不作为 HSKL-Base 必须成功的硬指标；因为 HSKL-Base 当前采用对角谱模型。

### B. HSKL core benchmark layer

用于正式 HSKL-Base 主测试。

$$

\boxed{
\mathcal S_{\mathrm{core}}
=
\{
\texttt{damped\_linear\_oscillator},
\texttt{van\_der\_pol},
\texttt{duffing},
\texttt{lotka\_volterra},
\texttt{fitzhugh\_nagumo}
\}.
}

$$

这组系统覆盖：

- 解析点谱；
- 弱耗散振荡；
- 稳定极限环；
- 多稳态 / 势阱结构；
- 非线性耦合；
- 快慢激发结构。

### C. HSKL chaotic / high-dimensional stress layer

用于 stress，不作为第一轮所有配置必须通过的主结论。

$$

\boxed{
\mathcal S_{\mathrm{stress}}
=
\{
\texttt{lorenz63},
\texttt{rossler},
\texttt{lorenz96}
\}.
}

$$

它们用于检查：

- 短期预测；
- 长期统计保持；
- Gram 退化；
- near-boundary Hardy 风险；
- 高维系统中的谱核心容量。

这与 HSKL Tasks Guide 中“内部单元测试层、v1-core 主基准层、挑战扩展层”的组织原则一致。fileciteturn2file1

---

## 3.2 推荐 system object 与参数配置

### 3.2.1 `linear_diagonal`

连续系统：

$$

\dot{\mathbf x}
=
\mathbf A\mathbf x,
\qquad
\mathbf A=\operatorname{diag}(\gamma_1,\dots,\gamma_{d_x}).

$$

推荐维度：

$$

d_x\in\{4,8,16\}.

$$

参数 regime：

$$

\texttt{stable}:
\quad
\gamma_j\in[-1.0,-0.1],

$$

$$

\texttt{mixed\_decay}:
\quad
\gamma_j\in[-2.0,-0.02],

$$

$$

\texttt{near\_boundary}:
\quad
e^{\gamma_j\tau}
\approx
\frac{r_j}{\rho},
\qquad
r_j\in\{0.95,0.98,0.995\}.

$$

作用：验证对角谱恢复、衰减模态、Hardy near-boundary 风险。

---

### 3.2.2 `linear_rotation_contraction`

二维 block：

$$

\frac{d}{dt}
\begin{bmatrix}
x_{2k-1}\\
x_{2k}
\end{bmatrix}
=
\begin{bmatrix}
\sigma_k & -\omega_k\\
\omega_k & \sigma_k
\end{bmatrix}
\begin{bmatrix}
x_{2k-1}\\
x_{2k}
\end{bmatrix}.

$$

推荐维度：

$$

d_x\in\{4,8,16\}.

$$

参数 regime：

$$

\texttt{low\_frequency}:
\quad
\sigma=-0.1,\quad
\omega\in[0.5,1.0],

$$

$$

\texttt{medium\_frequency}:
\quad
\sigma=-0.1,\quad
\omega\in[1.0,3.0],

$$

$$

\texttt{weakly\_damped}:
\quad
\sigma\in[-0.03,-0.01],
\quad
\omega\in[0.5,2.0].

$$

作用：验证复值谱核心是否能表达旋转–收缩，而不是只学实值衰减。

---

### 3.2.3 `linear_jordan_nonnormal`

连续系统：

$$

\dot{\mathbf x}
=
(\gamma \mathbf I+\eta \mathbf N)\mathbf x,

$$

其中 $\mathbf N$ 是严格上三角 nilpotent 结构。

参数 regime：

$$

\texttt{weak\_nonnormal}:
\quad
\eta=0.5,

$$

$$

\texttt{strong\_nonnormal}:
\quad
\eta=2.0,

$$

$$

\texttt{jordan\_stress}:
\quad
\eta=5.0.

$$

作用：暴露对角谱 HSKL-Base 对非正规 transient 的表达边界。该系统失败不应立刻解释为代码错误。

---

### 3.2.4 `damped_linear_oscillator`

二维形式：

$$

\dot q=p,

$$

$$

\dot p
=
-2\beta p-\omega^2 q.

$$

参数 regime：

$$

\texttt{undamped}:
\quad
\beta=0,
\quad
\omega\in\{1.0,2.0\},

$$

$$

\texttt{weak\_damping}:
\quad
\beta=0.02,
\quad
\omega\in\{1.0,2.0\},

$$

$$

\texttt{moderate\_damping}:
\quad
\beta=0.10,
\quad
\omega\in\{1.0,2.0\}.

$$

作用：解析谱、近酉谱、弱耗散谱的最基础 rollout 测试。

---

### 3.2.5 `van_der_pol`

$$

\dot x=v,

$$

$$

\dot v
=
\mu(1-x^2)v-x.

$$

参数 regime：

$$

\texttt{near\_linear}:
\quad
\mu=0.2,

$$

$$

\texttt{limit\_cycle}:
\quad
\mu=1.0,

$$

$$

\texttt{relaxation}:
\quad
\mu=3.0.

$$

作用：稳定极限环、相位漂移、非混沌非线性谱学习。

---

### 3.2.6 `duffing`

采用自治 Duffing：

$$

\dot x=v,

$$

$$

\dot v
=
-\delta v-\alpha x-\beta x^3.

$$

推荐固定：

$$

\delta=0.05,
\qquad
\beta=1.

$$

参数 regime：

$$

\texttt{single\_well}:
\quad
\alpha=1,

$$

$$

\texttt{double\_well}:
\quad
\alpha=-1,

$$

$$

\texttt{transition}:
\quad
\alpha\in\{-0.1,0,0.1\}.

$$

作用：检查多稳态、势阱结构、局部结构与全局切换下的轨线级重构。

---

### 3.2.7 `lotka_volterra`

$$

\dot x
=
a x-bxy,

$$

$$

\dot y
=
-cy+dxy.

$$

默认参数：

$$

(a,b,c,d)=(1.5,1.0,3.0,1.0).

$$

参数 regime：

$$

\texttt{standard}:
\quad
(a,b,c,d)=(1.5,1.0,3.0,1.0),

$$

$$

\texttt{mild\_interaction}:
\quad
b,d \text{ 较小},

$$

$$

\texttt{strong\_interaction}:
\quad
b,d \text{ 较大}.

$$

作用：非线性耦合、轨道族泛化、近守恒几何结构。

---

### 3.2.8 `fitzhugh_nagumo`

$$

\dot v
=
v-\frac{v^3}{3}-w+I,

$$

$$

\dot w
=
\epsilon(v+a-bw).

$$

推荐固定：

$$

a=0.7,
\qquad
b=0.8,
\qquad
\epsilon=0.08.

$$

参数 regime：

$$

\texttt{excitable}:
\quad
I=0.5,

$$

$$

\texttt{oscillatory}:
\quad
I=0.8.

$$

作用：快慢结构、阈值激发、spike–recovery dynamics。

---

### 3.2.9 `lorenz63`

$$

\dot x=\sigma(y-x),

$$

$$

\dot y=x(\rho_L-z)-y,

$$

$$

\dot z=xy-\beta z.

$$

标准参数：

$$

\sigma=10,
\qquad
\rho_L=28,
\qquad
\beta=\frac83.

$$

作用：低维耗散混沌，验证短期可预报与长期统计保持。

---

### 3.2.10 `rossler`

$$

\dot x=-y-z,

$$

$$

\dot y=x+a y,

$$

$$

\dot z=b+z(x-c).

$$

标准参数：

$$

a=0.2,
\qquad
b=0.2,
\qquad
c=5.7.

$$

作用：不同 chaotic geometry 下的 rollout 与谱稳定性测试。

---

### 3.2.11 `lorenz96`

$$

\dot x_i
=
(x_{i+1}-x_{i-2})x_{i-1}
-
x_i
+
F,
\qquad
i=1,\dots,d_x,

$$

周期边界：

$$

x_{i+d_x}=x_i.

$$

推荐：

$$

d_x=40.

$$

参数 regime：

$$

\texttt{forcing\_low}:
\quad
F=6,

$$

$$

\texttt{forcing\_standard}:
\quad
F=8,

$$

$$

\texttt{forcing\_high}:
\quad
F=10.

$$

作用：高维混沌、平移结构、长期统计性质与高通道 HSKL stress。

---

## 3.3 difficulty profile

建议冻结三档。

### small

用于 smoke 与接口验证：

$$

R_{\mathrm{train}}=16,
\qquad
R_{\mathrm{val}}=4,
\qquad
R_{\mathrm{test}}=4,

$$

$$

M=256.

$$

窗口建议：

$$

L_{\mathrm H}=16,
\qquad
L_{\mathrm{rec}}=16,
\qquad
L_{\mathrm{roll}}=32.

$$

### medium

用于正式 baseline：

$$

R_{\mathrm{train}}=128,
\qquad
R_{\mathrm{val}}=32,
\qquad
R_{\mathrm{test}}=32,

$$

$$

M=1024.

$$

窗口建议：

$$

L_{\mathrm H}\in\{16,32,64\},

$$

$$

L_{\mathrm{rec}}\in\{16,32,64\},

$$

$$

L_{\mathrm{roll}}\in\{64,128\}.

$$

### large / stress

用于 chaotic 与 high-dimensional stress：

$$

R_{\mathrm{train}}=256,
\qquad
R_{\mathrm{val}}=64,
\qquad
R_{\mathrm{test}}=64,

$$

$$

M\in\{2048,4096\}.

$$

窗口建议：

$$

L_{\mathrm H}\in\{64,128\},

$$

$$

L_{\mathrm{rec}}\in\{64,128\},

$$

$$

L_{\mathrm{roll}}\in\{128,256,512\}.

$$

这些窗口必须满足：

$$

M+1
>
\max
\{
L_{\mathrm H},
L_{\mathrm{rec}},
L_{\mathrm{roll}}
\}.

$$

---

## 3.4 split protocol

必须按轨线编号切分，而不是按窗口随机切分。

### Split-I：initial-condition generalization

参数固定：

$$

\boldsymbol{\mu}_{\mathrm{train}}
=
\boldsymbol{\mu}_{\mathrm{val}}
=
\boldsymbol{\mu}_{\mathrm{test}},

$$

但初值集合不交：

$$

\mathcal X_{0,\mathrm{train}}
\cap
\mathcal X_{0,\mathrm{val}}
\cap
\mathcal X_{0,\mathrm{test}}
=
\varnothing.

$$

### Split-P：parameter generalization

参数集不交：

$$

\Pi_{\mathrm{train}}
\cap
\Pi_{\mathrm{test}}
=
\varnothing.

$$

例如：

$$

\mu_{\mathrm{train}}
\neq
\mu_{\mathrm{test}}

$$

用于 Van der Pol；

$$

F_{\mathrm{train}}
\neq
F_{\mathrm{test}}

$$

用于 Lorenz96。

### Split-O：observation generalization

动力系统与参数固定，但观测算子变化：

$$

\mathcal O_{\mathrm{train}}
\neq
\mathcal O_{\mathrm{test}}.

$$

为避免输入维度不兼容，建议 Split-O 只在相同 $d_z$ 的观测族内部比较，例如不同线性传感矩阵：

$$

\mathbf z=\mathbf C\mathbf x,
\qquad
\mathbf C_{\mathrm{train}}
\neq
\mathbf C_{\mathrm{test}},
\qquad
\mathbf C_{\mathrm{train}},\mathbf C_{\mathrm{test}}
\in\mathbb R^{d_z\times d_x}.

$$

---

## 3.5 observation modes

建议本数据集冻结三种 observation mode。

### `full_state`

$$

\mathbf z=\mathbf x,
\qquad
d_z=d_x.

$$

这是 HSKL-Base 的默认正式测试模式。

### `partial_linear_sensor`

$$

\mathbf z=\mathbf C\mathbf x,
\qquad
\mathbf C\in\mathbb R^{d_z\times d_x},
\qquad
d_z<d_x.

$$

要求 $\mathbf C$ 固定 seed 生成，并记录在 metadata 中。

### `nonlinear_observation`

$$

\mathbf z
=
\begin{bmatrix}
\mathbf C\mathbf x\\
\sin(\mathbf B\mathbf x)\\
\mathbf q(\mathbf x)
\end{bmatrix},

$$

其中 $\mathbf q(\mathbf x)$ 可为低阶二次观测。该模式只作为 observation stress，不作为第一轮主成功标准。

---

## 3.6 noise levels

噪声建议定义为相对轨线尺度的标准化噪声：

$$

\widetilde{\mathbf z}_m
=
\mathbf z_m
+
\sigma_z
\mathbf D_z
\boldsymbol{\epsilon}_m,
\qquad
\boldsymbol{\epsilon}_m\sim\mathcal N(\mathbf 0,\mathbf I),

$$

其中 $\mathbf D_z$ 是按训练轨线统计得到的坐标尺度对角矩阵。

冻结四档：

$$

\texttt{clean}:
\quad
\sigma_z=0,

$$

$$

\texttt{low}:
\quad
\sigma_z=10^{-3},

$$

$$

\texttt{medium}:
\quad
\sigma_z=10^{-2},

$$

$$

\texttt{stress}:
\quad
\sigma_z=5\times10^{-2}.

$$

第一轮正式 HSKL 建议只把 `clean` 与 `low` 作为主结果；`medium` 与 `stress` 用于鲁棒性分析。

---

## 3.7 sampling and burn-in

每个系统应声明：

$$

\tau_q,
\qquad
T_{\mathrm{burn},q},
\qquad
M,
\qquad
R.

$$

对稳定系统，可取短 burn-in 或无 burn-in；对极限环与混沌系统，应先 burn-in 再保存吸引子轨线：

$$

\mathbf x_0
\mapsto
\mathbf x(T_{\mathrm{burn}})
\mapsto
\{
\mathbf x_m
\}_{m=0}^{M}.

$$

推荐原则：

- 线性系统：$T_{\mathrm{burn}}=0$；
- Van der Pol / FitzHugh–Nagumo：保留短 burn-in，使轨线覆盖吸引子；
- Lorenz63 / Rössler / Lorenz96：必须 burn-in 后保存吸引子轨线；
- Lotka–Volterra：保留多轨道族，不应全部 burn-in 到同一局部区域。

---

## 4. Algorithmic logic

本数据集的数学生成逻辑如下。

1. 选择 system object：

$$

q\in
\mathcal S_{\mathrm{unit}}
\cup
\mathcal S_{\mathrm{core}}
\cup
\mathcal S_{\mathrm{stress}}.

$$

2. 选择参数 regime：

$$

\boldsymbol{\mu}\in\Pi_q^{(a)}.

$$

3. 选择 difficulty profile：

$$

d\in
\{\texttt{small},\texttt{medium},\texttt{large}\}.

$$

4. 采样轨线级初值集合：

$$

\mathcal X_{0,\mathrm{train}},
\quad
\mathcal X_{0,\mathrm{val}},
\quad
\mathcal X_{0,\mathrm{test}}.

$$

5. 对每条轨线积分：

$$

\dot{\mathbf x}=\mathbf f_q(\mathbf x;\boldsymbol{\mu}),

$$

并按 $\tau_q$ 保存：

$$

\mathbf x_0,\dots,\mathbf x_M.

$$

6. 应用观测算子：

$$

\mathbf z_m
=
\mathcal O_o(\mathbf x_m).

$$

7. 应用噪声协议：

$$

\widetilde{\mathbf z}_m
=
\mathbf z_m+
\sigma_z\mathbf D_z\boldsymbol{\epsilon}_m.

$$

8. 保存目标观测：

$$

\mathbf y_m=\mathbf z_m
\quad
\text{或}
\quad
\mathbf y_m=\widetilde{\mathbf z}_m,

$$

建议第一版采用：

$$

\boxed{
\mathbf y_m=\mathbf z_m,
\qquad
\text{input }=\widetilde{\mathbf z}_m
}

$$

这样可以同时测试 HSKL 的去噪式重构能力；若只做普通重构，则取 input 与 target 同为 clean 或同为 noisy。

9. 轨线级切分后，窗口由后续 HSKL 工程构造，数据集本身保留完整轨线，避免 train / test window leakage。

---

## 5. Key assumptions

1. 数据集生成侧只负责 ODE 轨线、观测、噪声、split 与 metadata，不负责 HSKL 模型训练。

2. HSKL 工程后续只通过 data object identity 绑定数据，不应把 ODE 生成逻辑写入 HSKL 工程；这与 3.3 指南的数据工程 / 学习工程分离原则一致。fileciteturn2file2

3. 第一版默认全状态观测：

$$

\mathbf z=\mathbf x.

$$

`partial_linear_sensor` 与 `nonlinear_observation` 作为后续 Split-O / stress 使用。

4. 第一版主结果优先使用：

$$

\texttt{Split-I},
\qquad
\texttt{clean / low noise},
\qquad
\texttt{small / medium}.

$$

5. Chaotic systems 不以长期逐点重合作为成功标准，而以短期预测与长期统计保持为评估对象。

6. `linear_jordan_nonnormal` 是边界诊断系统，不是当前对角谱 HSKL-Base 的必须成功对象。

7. 所有窗口相关对象必须以完整轨线为输入，禁止先随机打散窗口再划分 train / val / test。

---

## 6. Numerical risks

### 6.1 split leakage

如果先切窗口再随机划分，会导致相邻窗口同时出现在 train 和 test 中，长期 rollout 指标会虚高。必须先按轨线切分，再在各 split 内构造窗口。

### 6.2 near-boundary Hardy risk

当：

$$

|\alpha_j|
=
|\rho\lambda_j|
\approx 1,

$$

tail certificate 会变大：

$$

\mathcal E_{\mathrm{tail}}^{(\rho,L)}
\sim
\frac{|\alpha_j|^{2L}}{1-|\alpha_j|^2}.

$$

这类配置应保留，但必须标记为 near-boundary stress，而不是普通失败。

### 6.3 nonnormal transient risk

`linear_jordan_nonnormal` 可能出现短期能量放大，即使所有谱半径稳定。对角谱 HSKL-Base 可能不能很好表达 Jordan-like transient，因此失败应解释为模型假设边界。

### 6.4 scale mismatch

不同系统的状态尺度差异很大，尤其 Lotka–Volterra、Lorenz63、Lorenz96。噪声必须按坐标尺度归一化，否则同一 $\sigma_z$ 对不同系统含义不同。

### 6.5 chaotic evaluation risk

Lorenz63、Rössler、Lorenz96 的 long rollout 不应要求逐点长期一致。应使用：

- short-horizon prediction error；
- attractor statistics；
- coordinate mean / variance；
- autocorrelation；
- energy-like statistics；
- spectrum / Gram diagnostics。

### 6.6 observation dimension mismatch

Split-O 若从 full-state 切到 partial sensor，可能改变 $d_z$，导致同一模型无法直接评估。第一版 Split-O 应优先采用同维度观测算子变化。

### 6.7 stiffness / multi-timescale risk

FitzHugh–Nagumo 的快慢结构与 Van der Pol 的 relaxation regime 可能引入时间尺度差异。采样间隔 $\tau_q$ 过大会造成 spike 或 relaxation segment 解析不足。

### 6.8 window insufficiency

如果：

$$

M
\le
\max
\{
L_{\mathrm H},
L_{\mathrm{rec}},
L_{\mathrm{roll}}
\},

$$

则无法构造完整 HSKL 窗口。数据集 profile 必须保证足够长的轨线。

### 6.9 noisy target ambiguity

若 input 和 target 都是 noisy，则测试的是 noisy reconstruction；若 input noisy、target clean，则测试带去噪意味的重构。两种协议必须在 metadata 中明确区分。

---

## 7. Preliminary package direction

这里只给高层方向，不进入 Julia API。

1. **DifferentialEquations.jl / OrdinaryDiffEq.jl**  
   用于 ODE 数值积分。正式实现前必须查官方文档确认 solver、保存间隔、容差与 ensemble trajectory 的推荐写法。

2. **SciMLBase.jl**  
   可能用于统一 problem / solution 对象协议。需要查文档确认当前稳定接口。

3. **Random / Distributions.jl**  
   用于初值采样、参数采样、噪声采样。正式实现前应固定 seed 与采样分布协议。

4. **LinearAlgebra.jl**  
   用于线性系统矩阵、block diagonal 结构、谱诊断。

5. **JLD2.jl / HDF5.jl / Arrow.jl**  
   用于保存轨线张量与 metadata。需要在实现前确认 ODEs_dataset 当前采用的主存储格式，不能在本任务中凭记忆指定 API。

6. **DataFrames.jl / CSV.jl**  
   可用于 metadata table、system registry、split registry 的人类可读导出。实现前确认是否与 ODEs_dataset 当前工程风格一致。

---

## 8. Wait for confirmation

请确认或修改以上数学说明，尤其是：

$$

\boxed{
\texttt{dataset name = hskl\_baseline\_ode\_v1}
}

$$

以及三层系统集合：

$$

\mathcal S_{\mathrm{unit}},
\qquad
\mathcal S_{\mathrm{core}},
\qquad
\mathcal S_{\mathrm{stress}}.

$$

你确认后，我再进入 Step 2，给出这个 ODEs_dataset 前置任务的详细任务计划 / 实现蓝图。