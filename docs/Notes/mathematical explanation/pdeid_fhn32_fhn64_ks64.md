任务代号定为：

:::writing{variant="document" id="58317"}
# 高维 PDE 辨识数据生成任务：FHN32 / FHN64 / KS64

**任务代号**
$$

\boxed{
\texttt{pdeid\_fhn32\_fhn64\_ks64}
}

$$

## 0. 任务目标与边界

本任务生成三组自治、高维、完整状态可观测的 PDE 离散轨线数据：

$$

\boxed{
\mathsf{FHN32},
\qquad
\mathsf{FHN64},
\qquad
\mathsf{KS64}.
}

$$

其目的是建立一条由较强结构化非线性场动力学逐步过渡到时空混沌动力学的数据验证链：

$$

\boxed{
\text{FHN32}
\longrightarrow
\text{FHN64}
\longrightarrow
\text{KS64}.
}

$$

其中：

$$

\boxed{
\text{FHN32/FHN64}
}

$$

用于检验 MP-KDSM 在高维、空间相关、非线性传播场上的 Koopman 型直接多步预测能力；

$$

\boxed{
\text{KS64}
}

$$

用于检验模型面对高维自治时空混沌时的短中期预测、相位传播与长期统计一致性。

本任务只生成并验证数值数据，不扫描 MP-KDSM 的网络宽度、字典维数、损失权重或读出协议。三组数据均采用完整状态预测：

$$

\boxed{
\mathbf y_m^{(\nu)}
=
\mathbf z_m^{(\nu)}.
}

$$

因此，学习器面对的是离散化 PDE 在完整状态空间上的确定性一步映射：

$$

\boxed{
\mathbf z_{m+1}^{(\nu)}
=
\mathbf F_{\mathcal Z}^{\tau}
\left(
\mathbf z_m^{(\nu)}
\right),
\qquad
\mathbf z_m^{(\nu)}
\in
\mathcal Z.
}

$$

这与项目中基于固定采样间隔 $\tau$ 的离散动力学、完整轨线划分和 Koopman 学习数据对象保持一致。fileciteturn7file3

---

# 1. 统一 MP 数据接口

三组对象都输出均匀采样轨线：

$$

\mathcal D_{\mathrm{sys}}
=
\left\{
\left(
t_m,
\mathbf z_m^{(\nu)},
\mathbf y_m^{(\nu)}
\right)
:
\nu\in\mathcal R_{\mathrm{sys}},
\quad
m=0,\ldots,M
\right\},

$$

其中

$$

t_m=m\tau,
\qquad
\mathbf y_m^{(\nu)}
=
\mathbf z_m^{(\nu)}.

$$

轨线集合按完整 trajectory 划分：

$$

\boxed{
\mathcal R_{\mathrm{sys}}
=
\mathcal R_{\mathrm{train}}
\sqcup
\mathcal R_{\mathrm{val}}
\sqcup
\mathcal R_{\mathrm{test}}.
}

$$

固定取

$$

|\mathcal R_{\mathrm{train}}|=320,
\qquad
|\mathcal R_{\mathrm{val}}|=80,
\qquad
|\mathcal R_{\mathrm{test}}|=80.

$$

因此每个对象包含

$$

R=480

$$

条完整轨线。

所有对象统一采用：

$$

\boxed{
\tau=0.25,
\qquad
M=1024,
\qquad
T_{\mathrm{record}}=M\tau=256.
}

$$

MP 的默认 rollout horizon 集取为：

$$

\boxed{
\mathcal H_{\mathrm{roll}}
=
\{1,2,4,8,16,32,64\},
\qquad
h_{\max}=64.
}

$$

故最大直接预测物理时间为：

$$

\boxed{
T_{\mathrm{roll}}
=
h_{\max}\tau
=
16.
}

$$

每条轨线可提供的合法 window-anchor 数为：

$$

M-h_{\max}+1
=
961.

$$

训练集合的总合法 window 数为：

$$

320\times961
=
307{,}520.

$$

这与 MP 的训练语义一致：一个训练元素是 trajectory window，而不是孤立 one-step pair；每个 window 同时提供 head pair、真实 endpoint 与多步 rollout target。fileciteturn8file5

---

# 2. 三个对象的统一配置

| 对象 | 连续模型 | 空间点数 | 状态维数 | 空间区间 | 采样间隔 | 内部积分 | Warm-up |
|---|---:|---:|---:|---:|---:|---|---:|
| FHN32 | FitzHugh–Nagumo | $N_x=32$ | $d_z=d_y=64$ | $[0,32)$ | $\tau=0.25$ | 自适应刚性 ODE | $32$ |
| FHN64 | FitzHugh–Nagumo | $N_x=64$ | $d_z=d_y=128$ | $[0,32)$ | $\tau=0.25$ | 自适应刚性 ODE | $32$ |
| KS64 | Kuramoto–Sivashinsky | $N_x=64$ | $d_z=d_y=64$ | $[0,22)$ | $\tau=0.25$ | Fourier-ETDRK4 | $200$ |

FHN32 与 FHN64 具有相同的连续 PDE 参数、相同空间区间与相同初值分布，仅改变空间网格数：

$$

N_x:
32
\longrightarrow
64.

$$

因此二者构成的是一个“空间分辨率与环境状态维数”共同增加的受控阶梯，而不是纯粹固定离散系统上的维数扫描。每个 $N_x$ 对应其自身的离散流映射：

$$

\mathbf F_{\mathrm{FHN},N_x}^{\tau}.

$$

---

# 3. Julia 实现环境

本任务使用 Julia 实现，并冻结完整的 `Project.toml` 与 `Manifest.toml`。

## 3.1 FHN 依赖

FHN 使用：

```toml
OrdinaryDiffEq
SciMLBase
SparseArrays
LinearAlgebra
Random
Statistics
HDF5
TOML
```

FHN 半离散后是刚性 ODE。Julia 的 SciML / DifferentialEquations 体系以 `ODEProblem` 表示常微分方程初值问题，并提供包括 `Rodas5P` 在内的刚性 Rosenbrock 类求解器。citeturn953134search1turn953134search2

## 3.2 KS 依赖

KS 使用：

```toml
FFTW
LinearAlgebra
Random
Statistics
HDF5
TOML
```

KS 采用自实现 Fourier 伪谱 ETDRK4 推进器。`FFTW.jl` 提供 Julia 对 FFTW 快速 Fourier 变换库的绑定。citeturn953134search3turn953134search9

所有积分与数值证书在 `Float64` 下完成。HDF5 文件中的原始状态也保存为 `Float64`；模型训练阶段再由读取器转换为 `Float32` 或其他训练精度。

---

# 4. FHN32 / FHN64：反应扩散波传播数据

## 4.1 连续模型

在周期区间

$$

x\in[0,L_{\mathrm{FHN}}),
\qquad
L_{\mathrm{FHN}}=32,

$$

上定义 FitzHugh–Nagumo 反应扩散系统：

$$

\begin{aligned}
\partial_t u
&=
D_u\partial_{xx}u
+
u
-
\frac13u^3
-
v,
\\
\partial_t v
&=
D_v\partial_{xx}v
+
\varepsilon
\left(
u+a-bv
\right).
\end{aligned}

$$

固定参数取为：

$$

\boxed{
D_u=1,
\qquad
D_v=0,
\qquad
\varepsilon=0.08,
\qquad
a=0.7,
\qquad
b=0.8.
}

$$

该任务不引入外部驱动：

$$

I_{\mathrm{ext}}=0.

$$

## 4.2 周期空间离散

取周期网格：

$$

x_j=j\Delta x,
\qquad
\Delta x=\frac{L_{\mathrm{FHN}}}{N_x},
\qquad
j=0,\ldots,N_x-1.

$$

对任意网格场 $\mathbf q\in\mathbb R^{N_x\times1}$，定义周期二阶差分：

$$

\left(
\mathbf D_{xx}\mathbf q
\right)_j
=
\frac{
q_{j+1}
-
2q_j
+
q_{j-1}
}{
\Delta x^2
},

$$

其中下标按模 $N_x$ 取值。

令

$$

\mathbf u(t)
=
\begin{bmatrix}
u(x_0,t)\\
\vdots\\
u(x_{N_x-1},t)
\end{bmatrix},
\qquad
\mathbf v(t)
=
\begin{bmatrix}
v(x_0,t)\\
\vdots\\
v(x_{N_x-1},t)
\end{bmatrix}.

$$

半离散系统为：

$$

\begin{aligned}
\dot{\mathbf u}
&=
D_u\mathbf D_{xx}\mathbf u
+
\mathbf u
-
\frac13\mathbf u^{\odot3}
-
\mathbf v,
\\
\dot{\mathbf v}
&=
\varepsilon
\left(
\mathbf u
+
a\mathbf1
-
b\mathbf v
\right).
\end{aligned}

$$

完整状态定义为：

$$

\boxed{
\mathbf z(t)
=
\begin{bmatrix}
\mathbf u(t)\\
\mathbf v(t)
\end{bmatrix}
\in
\mathbb R^{2N_x\times1}.
}

$$

因此：

$$

\mathsf{FHN32}:
\quad
d_z=d_y=64,

$$

$$

\mathsf{FHN64}:
\quad
d_z=d_y=128.

$$

## 4.3 初值分布

令 $(u_\star,v_\star)$ 为静息平衡点：

$$

u_\star-\frac13u_\star^3-v_\star=0,
\qquad
v_\star=\frac{u_\star+a}{b}.

$$

定义周期距离：

$$

d_{\mathrm{per}}(x,c)
:=
\min_{n\in\mathbb Z}
|x-c+nL_{\mathrm{FHN}}|.

$$

对第 $\nu$ 条轨线，随机选取脉冲数：

$$

J_\nu\in\{1,2\},

$$

并以相同概率生成单脉冲与双脉冲初值。脉冲中心满足周期最小间距约束：

$$

d_{\mathrm{per}}
\left(
c_{\nu,j},
c_{\nu,\ell}
\right)
\ge
\frac{L_{\mathrm{FHN}}}{4},
\qquad
j\neq\ell.

$$

初值定义为：

$$

u_0^{(\nu)}(x)
=
u_\star
+
\sum_{j=1}^{J_\nu}
A_{\nu,j}
\exp
\left(
-
\frac{
d_{\mathrm{per}}(x,c_{\nu,j})^2
}{
2w_{\nu,j}^2
}
\right)
+
\delta_u\xi_u^{(\nu)}(x),

$$

$$

v_0^{(\nu)}(x)
=
v_\star
+
\delta_v\xi_v^{(\nu)}(x),

$$

其中：

$$

A_{\nu,j}\sim\mathcal U[1.8,2.4],
\qquad
w_{\nu,j}\sim\mathcal U[1.0,1.6],

$$

$$

\delta_u=0.03,
\qquad
\delta_v=0.01.

$$

$\xi_u^{(\nu)}$ 与 $\xi_v^{(\nu)}$ 是零均值、低频、周期平滑随机场，仅包含：

$$

|k|\le3

$$

的 Fourier 模态，并被缩放为单位离散 RMS。该缩放只用于定义初值扰动幅度，不是数据对象的保存后标准化。

该初值协议的目标是覆盖传播脉冲、波列与弱脉冲相互作用，而不让训练数据退化为单个静息平衡点附近的小扰动。

## 4.4 FHN 数值积分

FHN32 与 FHN64 均采用：

$$

\boxed{
\text{周期有限差分}
+
\text{方法线}
+
\texttt{Rodas5P()}
}

$$

的数值路线。

生产积分设置为：

$$

\boxed{
\mathrm{reltol}=10^{-8},
\qquad
\mathrm{abstol}=10^{-10}.
}

$$

积分器内部时间步由刚性求解器自适应确定；数据保存时只在固定时刻

$$

t_m=m\tau

$$

处写出状态，不保留不规则内部节点。

每条 FHN 轨线先运行：

$$

T_{\mathrm{warm}}^{\mathrm{FHN}}=32,

$$

随后记录：

$$

T_{\mathrm{record}}=256.

$$

仅当数值解有限，且 warm-up 末端仍保持非平凡空间活动时，才接受该轨线。活动量定义为：

$$

A_{\mathrm{FHN}}(t)
:=
\max_{0\le j<N_x}u_j(t)
-
\min_{0\le j<N_x}u_j(t).

$$

实际正式数据采用的要求：

$$

A_{\mathrm{FHN}}
\left(
T_{\mathrm{warm}}^{\mathrm{FHN}}
\right)
\ge0.35.

$$

未满足条件的初值重新生成；这一步只剔除已经退化到近似均匀静息态的无效样本。

---

# 5. KS64：时空混沌数据

## 5.1 连续模型

在周期区间：

$$

x\in[0,L_{\mathrm{KS}}),
\qquad
L_{\mathrm{KS}}=22,

$$

上定义 Kuramoto–Sivashinsky 方程：

$$

\boxed{
\partial_tu
+
u\partial_xu
+
\partial_{xx}u
+
\partial_{xxxx}u
=
0.
}

$$

等价地：

$$

\partial_tu
=
-u\partial_xu
-
\partial_{xx}u
-
\partial_{xxxx}u.

$$

使用空间均值为零的状态空间：

$$

\boxed{
\int_0^{L_{\mathrm{KS}}}u(x,t)\,\mathrm dx
=
0.
}

$$

离散状态定义为：

$$

\boxed{
\mathbf z(t)
=
\mathbf u(t)
=
\begin{bmatrix}
u(x_0,t)\\
\vdots\\
u(x_{N_x-1},t)
\end{bmatrix}
\in
\mathbb R^{N_x\times1},
\qquad
N_x=64.
}

$$

因此：

$$

\boxed{
d_z=d_y=64.
}

$$

## 5.2 Fourier 伪谱形式

定义 Fourier 系数：

$$

u(x,t)
=
\sum_k
\widehat u_k(t)
\mathrm e^{i\kappa_kx},
\qquad
\kappa_k
=
\frac{2\pi k}{L_{\mathrm{KS}}}.

$$

KS 的 Fourier 半离散形式为：

$$

\frac{\mathrm d}{\mathrm dt}
\widehat u_k
=
\left(
\kappa_k^2-\kappa_k^4
\right)
\widehat u_k
-
\frac{i\kappa_k}{2}
\widehat{u^2}_k.

$$

写成半线性形式：

$$

\dot{\widehat{\mathbf u}}
=
\mathbf L\widehat{\mathbf u}
+
\mathcal N
\left(
\widehat{\mathbf u}
\right),

$$

其中：

$$

\left(
\mathbf L\widehat{\mathbf u}
\right)_k
=
\left(
\kappa_k^2-\kappa_k^4
\right)
\widehat u_k,

$$

$$

\mathcal N_k
\left(
\widehat{\mathbf u}
\right)
=
-\frac{i\kappa_k}{2}
\mathcal F
\left[
\left(
\mathcal F^{-1}
\widehat{\mathbf u}
\right)^2
\right]_k.

$$

## 5.3 去混叠与 ETDRK4

定义 $2/3$ 去混叠掩码：

$$

m_k
=
\begin{cases}
1,
&
|\kappa_k|
\le
\frac23\kappa_{\max},
\\
0,
&
\text{otherwise}.
\end{cases}

$$

非线性项实际取为：

$$

\mathcal N_k^{\mathrm{deal}}
=
m_k\mathcal N_k.

$$

KS 使用固定内部时间步：

$$

\boxed{
\delta t_{\mathrm{KS}}=0.05.
}

$$

由于：

$$

\tau=0.25=5\delta t_{\mathrm{KS}},

$$

每五个 ETDRK4 内部步写出一个训练 snapshot。

ETDRK4 对线性刚性项进行指数推进，对非线性项进行四阶显式校正。对半线性刚性 PDE，这类 exponential Runge–Kutta 方法以精确处理线性部分和缓解传统显式方法时间步限制为主要特征。citeturn953134search13turn953134search29

实现中预计算：

$$

\mathbf E
=
\exp
\left(
\delta t_{\mathrm{KS}}\mathbf L
\right),
\qquad
\mathbf E_{1/2}
=
\exp
\left(
\frac12\delta t_{\mathrm{KS}}\mathbf L
\right),

$$

以及 ETDRK4 所需的系数：

$$

\mathbf Q,
\qquad
\mathbf f_1,
\qquad
\mathbf f_2,
\qquad
\mathbf f_3.

$$

这些系数使用复平面轮廓平均稳定计算，轮廓节点数取：

$$

M_{\mathrm{contour}}=32.

$$

每步推进后显式设置：

$$

\widehat u_0=0,

$$

以消除有限精度下的零模态漂移。

## 5.4 KS 初值分布

对正 Fourier 模态：

$$

n=1,\ldots,8,

$$

生成独立复随机系数：

$$

\widehat u_n^{(\nu)}(0)
=
\frac{
\alpha_n^{(\nu)}
}{
1+(n/4)^4
},

$$

其中 $\alpha_n^{(\nu)}$ 为独立复高斯随机变量。

随后强制 Hermitian 对称：

$$

\widehat u_{-n}^{(\nu)}(0)
=
\overline{
\widehat u_n^{(\nu)}(0)
},

$$

并取：

$$

\widehat u_0^{(\nu)}(0)=0.

$$

经逆 Fourier 变换得到实值初场后，将其 RMS 缩放为：

$$

\left[
\frac1{N_x}
\sum_{j=0}^{N_x-1}
\left(
u_j^{(\nu)}(0)
\right)^2
\right]^{1/2}
=
\rho_\nu,
\qquad
\rho_\nu\sim\mathcal U[0.5,1.0].

$$

每条 KS 轨线先执行 burn-in：

$$

\boxed{
T_{\mathrm{warm}}^{\mathrm{KS}}=200,
}

$$

随后记录长度：

$$

T_{\mathrm{record}}=256

$$

的均匀采样轨线。

---

# 6. 数据存储规范

每个对象单独保存为一个 HDF5 文件：

```text
data/pdeid_fhn32_fhn64_ks64_julia/
├── fhn32.h5
├── fhn64.h5
├── ks64.h5
├── fhn32.toml
├── fhn64.toml
├── ks64.toml
├── numeric_certificate.json
└── Manifest.toml
```

每个 HDF5 文件至少包含：

```text
/state_rtd          shape = [R, M + 1, d_z], Float64
/time               shape = [M + 1], Float64
/split/train_idx    shape = [320], Int64
/split/val_idx      shape = [80], Int64
/split/test_idx     shape = [80], Int64
/meta/system_name
/meta/task_code
/meta/state_layout
/meta/field_names
/meta/spatial_domain
/meta/nx
/meta/tau
/meta/t_warm
/meta/t_record
/meta/numerics
/meta/initial_condition_protocol
/meta/master_seed
/certificate/time_discretization
/certificate/spatial_resolution
/certificate/invariants
```

其中：

$$

\boxed{
\texttt{/state\_rtd}[\nu,m,:]
=
\mathbf z_m^{(\nu)}.
}

$$

对于 FHN：

```text
field_names = ["u", "v"]
state_layout = "[u_0,...,u_{N_x-1},v_0,...,v_{N_x-1}]"
```

对于 KS：

```text
field_names = ["u"]
state_layout = "[u_0,...,u_{N_x-1}]"
```

原始数据文件不保存训练集标准化、归一化、均值、方差或 field-shared 统计量。`/state_rtd` 是完整状态的 raw physical-coordinate 数据。若下游 MP-KDSM 或其他学习任务需要标准化，应由下游读取器在训练任务内部显式计算和记录，不改变本数据对象的 HDF5 schema。

---

# 7. 数值数据证书

本任务必须将“数值积分误差”与“模型识别误差”分开记录。

## 7.1 一步时间离散误差

对固定的检查初值集合：

$$

\mathcal I_{\mathrm{chk}},
\qquad
|\mathcal I_{\mathrm{chk}}|=8,

$$

从相同 source state 出发，分别使用生产积分器与参考积分器推进一个采样间隔 $\tau$：

$$

\mathbf z_{+}^{\mathrm{prod}}
=
\mathbf F_{\mathrm{num}}^{\tau,\delta_{\mathrm{prod}}}
\left(
\mathbf z
\right),

$$

$$

\mathbf z_{+}^{\mathrm{ref}}
=
\mathbf F_{\mathrm{num}}^{\tau,\delta_{\mathrm{ref}}}
\left(
\mathbf z
\right).

$$

定义原始状态空间的相对一步误差：

$$

\varepsilon_{\mathrm{time}}^{(1)}
=
\left[
\frac1{
|\mathcal I_{\mathrm{chk}}|
}
\sum_{i\in\mathcal I_{\mathrm{chk}}}
\frac{
\left\|
\mathbf z_{i,+}^{\mathrm{prod}}
-
\mathbf z_{i,+}^{\mathrm{ref}}
\right\|_2^2
}{
\left\|
\mathbf z_{i,+}^{\mathrm{ref}}
\right\|_2^2
+10^{-16}
}
\right]^{1/2}.

$$

FHN 的参考积分参数取：

$$

\mathrm{reltol}_{\mathrm{ref}}
=
10^{-10},
\qquad
\mathrm{abstol}_{\mathrm{ref}}
=
10^{-12}.

$$

KS 的参考内部步长取：

$$

\delta t_{\mathrm{KS,ref}}
=
0.025.

$$

要求生产数据满足：

$$

\boxed{
\varepsilon_{\mathrm{time}}^{(1)}
\le10^{-4}.
}

$$

该阈值作用于原始状态空间的相对误差，不依赖任何数据对象内置标准化统计量。

## 7.2 空间离散证书

FHN64 使用：

$$

N_x^{\mathrm{ref}}=128

$$

作为空间参考分辨率；将高分辨率解限制到 $N_x=64$ 网格后，记录 one-step 空间离散差异：

$$

\varepsilon_{\mathrm{space,FHN64}}^{(1)}.

$$

KS64 使用：

$$

N_x^{\mathrm{ref}}=128

$$

作为 Fourier 参考分辨率；参考场先截断到 $64$ 个低频模态，再比较对应 physical-grid 状态，记录：

$$

\varepsilon_{\mathrm{space,KS64}}^{(1)}.

$$

FHN32 与 FHN64 的差异本身是任务定义的一部分，不把 FHN32 当作 FHN64 的低精度副本；但仍记录：

$$

\varepsilon_{\mathrm{FHN32}\leftarrow\mathrm{FHN64}}^{(1)}

$$

作为解释跨分辨率性能差异的辅助信息。

## 7.3 物理与数值健康度

FHN 记录：

$$

A_{\mathrm{FHN}}(t)
=
\max_j u_j(t)-\min_j u_j(t),

$$

以及：

$$

\|\mathbf z(t)\|_2,
\qquad
\min_j u_j(t),
\qquad
\max_j u_j(t).

$$

KS 记录：

$$

\overline u(t)
=
\frac1{N_x}
\sum_{j=0}^{N_x-1}
u_j(t),

$$

$$

E_{\mathrm{KS}}(t)
=
\frac1{2N_x}
\|\mathbf u(t)\|_2^2,

$$

以及 Fourier 能量谱：

$$

\mathcal E_k(t)
=
|\widehat u_k(t)|^2.

$$

KS 必须满足：

$$

\left|
\overline u(t)
\right|
\le
10^{-12}

$$

在 `Float64` 数值精度范围内保持零均值。

---

# 8. 与 MP-KDSM 的接口边界

本任务生成的是统一的、均匀离散、完整状态、无控制数据。

因此后续 MP-KDSM 使用 raw complete-state inputs and targets：

$$

\mathbf z_m^{(\nu)}
=
\mathbf y_m^{(\nu)},

$$

训练阶段使用：

$$

\mathcal H_{\mathrm{roll}}
=
\{1,2,4,8,16,32,64\},

$$

并在物理时间上评估：

$$

h\tau,
\qquad
h=1,\ldots,64.

$$

由于三组数据均为均匀采样，后续 MP 可使用标准离散对角谱传播：

$$

\mathbf\Lambda^h.

$$

HDMD-SpecEnv 仅在模型训练前、仅使用 training split 执行；数据生成阶段不预先拟合或写入最终 Koopman 谱。其职责是从训练轨线中预估可见谱包络，而不是替代 MP 的谱学习。fileciteturn8file5turn8file8

主预测链保持为 direct spectral rollout：

$$

\widehat{\widetilde{\mathbf y}}_{s,h}^{(\nu)}
=
\mathbf B_{\mathrm K}
\boldsymbol{\chi}_{\mathrm K}
\left(
\mathbf\Lambda^h
\boldsymbol{\varphi}_s^{(\nu)}
\right).

$$

本任务不将数据生成流程与 feedback re-lift 预测混合。

---

# 9. 后续评估要求

所有对象至少报告：

$$

\operatorname{RelRMSE}_{\mathrm{phys}}(h),
\qquad
\operatorname{MAE}_{\mathrm{phys}}(h),

$$

$$

\operatorname{NRMSE}_{\mathrm{ch}}(h),
\qquad
\operatorname{NMAE}_{\mathrm{ch}}(h),
\qquad
h=1,\ldots,64.

$$

这些指标是项目中的模型无关默认预测层。fileciteturn8file11turn8file1

FHN 额外分通道报告：

$$

\operatorname{RMSE}_{u}(h),
\qquad
\operatorname{RMSE}_{v}(h).

$$

KS 额外报告循环平移对齐误差：

$$

d_{\mathrm{orb}}
\left(
\mathbf u,
\widehat{\mathbf u}
\right)
=
\min_{q=0,\ldots,N_x-1}
\left\|
\mathbf u
-
\mathbf S_q\widehat{\mathbf u}
\right\|_2,

$$

其中 $\mathbf S_q$ 为循环移位矩阵。

对于 KS，还应启用自治混沌系统的长期统计评价，并与点态预测误差分开解释。项目评估协议已明确区分预测准确性、长期统计一致性与 Koopman 表示质量；KS 属于应启用长期统计层的对象。fileciteturn8file2turn8file9

---

# 10. 交付物

本任务完成时应提交：

$$

\boxed{
3\text{ 个 HDF5 原始轨线文件}
}

$$

$$

\boxed{
3\text{ 个冻结参数 TOML 文件}
}

$$

$$

\boxed{
1\text{ 份 Julia }Project.toml
+
1\text{ 份 Manifest.toml}
}

$$

$$

\boxed{
1\text{ 份数值数据证书 JSON}
}

$$

以及以下图件：

1. FHN32 与 FHN64 的 $(x,t)$-space heatmap，分别展示 $u$ 与 $v$；
2. KS64 的 $(x,t)$-space heatmap；
3. KS64 的时间平均 Fourier 能量谱；
4. 三个对象的 $\varepsilon_{\mathrm{time}}^{(1)}$；
5. FHN64 与 KS64 的空间分辨率证书；
6. 每个 split 的状态均值、标准差与轨线长度汇总表。

任务完成的标准不是“某个后续 MP 模型达到固定预测分数”，而是：

$$

\boxed{
\text{三组数据均给出可复现、均匀采样、完整状态、数值误差可量化的离散 PDE 流映射。}
}

$$

由此，后续实验可以明确区分：

$$

\boxed{
\text{FHN32/FHN64 的失败是否来自高维场重构与传播困难；}
}

$$

以及：

$$

\boxed{
\text{KS64 的失败是否进一步来自时空混沌、相位漂移与有限对角谱闭合边界。}
}

$$
:::

下一步可据此固定三个 Julia 配置文件与统一的 HDF5 schema。
