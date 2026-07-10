# 高维非线性动力系统数据生成协议
## Lorenz–96 / Kuramoto–Sivashinsky–64 / FitzHugh–Nagumo–64

## 0. 名称、目标与任务边界

定义高维非线性动力系统完整状态数据生成任务：

$$

\boxed{
\mathsf{HDND\text{-}Data}
:=
\text{High-Dimensional Nonlinear Dynamics Data Generation}.
}

$$

本任务生成三个自治、确定性、完整状态可观测的高维动力系统数据集：

$$

\boxed{
\mathsf{L96\text{-}40},
\qquad
\mathsf{KS64},
\qquad
\mathsf{FHN64}.
}

$$

三者分别承担不同的数据验证角色：

$$

\boxed{
\mathsf{L96\text{-}40}
:
\text{高维局部耦合混沌 ODE};
}

$$

$$

\boxed{
\mathsf{KS64}
:
\text{平移对称的时空混沌耗散 PDE};
}

$$

$$

\boxed{
\mathsf{FHN64}
:
\text{多通道反应–扩散传播 PDE}.
}

$$

本任务仅负责：

$$

\boxed{
\text{连续系统定义}
+
\text{空间离散}
+
\text{高精度时间积分}
+
\text{轨线生成}
+
\text{轨线级数据划分}
+
\text{数值证书}
+
\text{动力学与数据集统计证书}.
}

$$

本任务不执行：

$$

\text{数据标准化},
\qquad
\text{模型训练},
\qquad
\text{核参数选择},
\qquad
\text{reference-center 编译},

$$

$$

\text{Koopman 谱学习},
\qquad
\text{预测误差优化},
\qquad
\text{人工噪声注入}.

$$

数据生成阶段的唯一规范输出是原始物理坐标：

$$

\boxed{
\mathbf z_m^{(\nu)}
=
\mathbf y_m^{(\nu)}
=
\mathbf x_m^{(\nu)}.
}

$$

标准化属于后续算法的数据接口层。它只能在轨线划分完成后，由训练集合计算，并不得写回原始数据文件。

---

# 1. 统一动力学与数据接口

设完整状态空间为

$$

\mathcal X_{\mathrm{sys}}
\subseteq
\mathbb R^{d_z\times1},

$$

连续动力系统写为

$$

\dot{\mathbf x}
=
\mathbf f_{\mathrm{sys}}(\mathbf x),
\qquad
\mathbf x(t)\in\mathcal X_{\mathrm{sys}}.

$$

其连续流映射记为

$$

\mathbf F_{\mathrm{sys}}^t:
\mathcal X_{\mathrm{sys}}
\to
\mathcal X_{\mathrm{sys}}.

$$

在基础保存间隔

$$

\tau_{\mathrm{base}}>0

$$

下，数据轨线满足

$$

\boxed{
\mathbf z_{m+1}^{(\nu)}
=
\mathbf F_{\mathrm{num}}^{\tau_{\mathrm{base}}}
\left(
\mathbf z_m^{(\nu)}
\right),
\qquad
m=0,\ldots,M_{\mathrm{traj}}-1.
}

$$

其中

$$

\mathbf F_{\mathrm{num}}^{\tau_{\mathrm{base}}}

$$

是高精度数值积分器诱导的离散流映射。

每个系统生成

$$

\boxed{
|\mathcal R|=480
}

$$

条完整轨线，并按完整 trajectory 划分为

$$

\boxed{
\mathcal R
=
\mathcal R_{\mathrm{train}}
\sqcup
\mathcal R_{\mathrm{val}}
\sqcup
\mathcal R_{\mathrm{test}},
}

$$

其中

$$

\boxed{
|\mathcal R_{\mathrm{train}}|=320,
\qquad
|\mathcal R_{\mathrm{val}}|=80,
\qquad
|\mathcal R_{\mathrm{test}}|=80.
}

$$

同一条轨线的 snapshot、one-step pair 或 rollout window 不得分散到不同集合。

---

# 2. 原始物理数据原则

## 2.1 数据生成阶段不做标准化

积分器始终在物理坐标中推进：

$$

\mathbf x(t)\in\mathcal X_{\mathrm{sys}}.

$$

HDF5 主数据集保存：

$$

\boxed{
\mathbf z_m^{(\nu)}
=
\mathbf x^{(\nu)}(t_m)
}

$$

的 `Float64` 数值。

数据生成器可以输出以下描述性统计：

$$

\operatorname{mean},
\qquad
\operatorname{std},
\qquad
\min,
\qquad
\max,
\qquad
\operatorname{RMS},

$$

但这些统计量只构成数据集诊断，不构成标准化映射。

原始数据文件中不设置：

```text
/normalization/mean
/normalization/std
/normalized_state
```

等对象。

后续训练器可以只由

$$

\mathcal R_{\mathrm{train}}

$$

计算标准化参数，但该过程不属于本文。

## 2.2 固定保存时间与自适应内部节点

即使生产积分器采用自适应内部时间步，数据也只在固定时刻

$$

t_m=m\tau_{\mathrm{base}}

$$

保存。

因此：

$$

\boxed{
\text{积分器内部节点可以不规则，正式数据时间轴必须均匀。}
}

$$

## 2.3 数值精度

全部系统采用：

$$

\boxed{
\texttt{Float64}
}

$$

完成：

$$

\text{初值生成},
\quad
\text{warm-up},
\quad
\text{正式积分},
\quad
\text{混沌指标计算},
\quad
\text{数据集诊断}.

$$

原始 HDF5 状态也以 `Float64` 保存。

---

# 3. 统一基础配置

三个对象采用以下基础配置：

| 对象 | 状态维数 | 基础采样间隔 | 记录时间 | 快照数 | 主要积分方法 |
|---|---:|---:|---:|---:|---|
| L96–40 | $40$ | $\tau_{\mathrm{base}}=0.05$ | $102.4$ | $2049$ | 自适应高阶显式 Runge–Kutta |
| KS64 | $64$ | $\tau_{\mathrm{base}}=0.05$ | $256$ | $5121$ | Fourier 伪谱 ETDRK4 |
| FHN64 | $128$ | $\tau_{\mathrm{base}}=0.05$ | $256$ | $5121$ | 高阶空间离散与自适应刚性积分 |

定义派生采样间隔集合：

$$

\boxed{
\mathcal T_{\mathrm{view}}
=
\{0.05,0.10,0.25\}.
}

$$

派生数据不重复写入状态张量，而通过整数 stride 定义：

$$

\mathbf z_m^{(\tau=0.10)}
=
\mathbf z_{2m}^{(\tau_{\mathrm{base}})},

$$

$$

\mathbf z_m^{(\tau=0.25)}
=
\mathbf z_{5m}^{(\tau_{\mathrm{base}})}.

$$

因此，同一条高精度物理轨线可以支持：

$$

\boxed{
\text{细采样结构学习}
+
\text{中等采样闭合学习}
+
\text{原有 }\tau=0.25\text{ 预测 benchmark}.
}

$$

---

# 4. Lorenz–96–40 数据

## 4.1 连续动力系统

取

$$

\boxed{
N_x=40,
\qquad
F_0=8.
}

$$

状态为

$$

\mathbf x
=
\begin{bmatrix}
x_1&\cdots&x_{40}
\end{bmatrix}^{\top}
\in
\mathbb R^{40\times1}.

$$

Lorenz–96 动力系统为

$$

\boxed{
\frac{\mathrm d x_j}{\mathrm dt}
=
\left(
x_{j+1}-x_{j-2}
\right)x_{j-1}
-
x_j
+
F_0,
\qquad
j=1,\ldots,40,
}

$$

并采用周期索引：

$$

x_{j+40}=x_j.

$$

该系统原有数据协议采用 $F_0=8$、$N_x=40$、$\tau=0.05$ 和完整状态输出；本文保留这些物理对象，但将固定步长 RK4 升级为高精度自适应积分。fileciteturn8file2

## 4.2 高精度积分器

生产积分器采用：

$$

\boxed{
\text{自适应九阶显式 Runge--Kutta}
}

$$

或具有等价误差控制能力的高阶显式积分器。

生产容差取为

$$

\boxed{
\mathrm{reltol}=10^{-10},
\qquad
\mathrm{abstol}=10^{-12}.
}

$$

限制最大内部步长：

$$

\boxed{
\Delta t_{\max}=0.01.
}

$$

参考积分器采用相同方法或独立高阶方法，并取

$$

\boxed{
\mathrm{reltol}_{\mathrm{ref}}=10^{-12},
\qquad
\mathrm{abstol}_{\mathrm{ref}}=10^{-14},
\qquad
\Delta t_{\max,\mathrm{ref}}=0.0025.
}

$$

生产数据仅在

$$

t_m=0.05m

$$

处写出。

## 4.3 初值与 burn-in

第 $\nu$ 条轨线的预初值为

$$

\boxed{
\mathbf x_{\mathrm{init}}^{(\nu)}
=
F_0\mathbf1
+
\delta_{\mathrm{init}}
\boldsymbol{\xi}^{(\nu)},
}

$$

其中

$$

\delta_{\mathrm{init}}=0.01,
\qquad
\boldsymbol{\xi}^{(\nu)}
\sim
\mathcal N
\left(
\mathbf0,\mathbf I_{40}
\right).

$$

每条轨线使用独立 seed。

正式记录前执行

$$

\boxed{
T_{\mathrm{burn}}^{\mathrm{L96}}=100.
}

$$

定义首个正式状态：

$$

\mathbf z_0^{(\nu)}
=
\mathbf F_{\mathrm{num}}^{T_{\mathrm{burn}}^{\mathrm{L96}}}
\left(
\mathbf x_{\mathrm{init}}^{(\nu)}
\right).

$$

burn-in 数据不进入正式轨线。

## 4.4 记录长度

取

$$

\boxed{
M_{\mathrm{traj}}^{\mathrm{L96}}=2048,
\qquad
T_{\mathrm{record}}^{\mathrm{L96}}=102.4.
}

$$

每条轨线保存

$$

2049

$$

个状态。

## 4.5 L96 数值证书

从正式轨线中分层抽取检查状态

$$

\left\{
\mathbf z_{\mathrm{chk},s}
\right\}_{s=1}^{S_{\mathrm{chk}}},
\qquad
S_{\mathrm{chk}}=256.

$$

分别用生产积分器和参考积分器推进一个基础采样间隔：

$$

\mathbf z_{s,+}^{\mathrm{prod}}
=
\mathbf F_{\mathrm{prod}}^{0.05}
\left(
\mathbf z_{\mathrm{chk},s}
\right),

$$

$$

\mathbf z_{s,+}^{\mathrm{ref}}
=
\mathbf F_{\mathrm{ref}}^{0.05}
\left(
\mathbf z_{\mathrm{chk},s}
\right).

$$

定义一步相对积分误差：

$$

\boxed{
\varepsilon_{\mathrm{time,L96}}^{(1)}
=
\left[
\frac{
\sum_{s=1}^{S_{\mathrm{chk}}}
\left\|
\mathbf z_{s,+}^{\mathrm{prod}}
-
\mathbf z_{s,+}^{\mathrm{ref}}
\right\|_2^2
}{
\sum_{s=1}^{S_{\mathrm{chk}}}
\left\|
\mathbf z_{s,+}^{\mathrm{ref}}
\right\|_2^2
+
\varepsilon_{\mathrm{num}}
}
\right]^{1/2}.
}

$$

建议验收条件为

$$

\boxed{
\varepsilon_{\mathrm{time,L96}}^{(1)}
\le10^{-8}.
}

$$

由于 L96 是混沌系统，不以长时间逐点重合检验积分器。长时间生产解与参考解的差异应通过统计量比较，而不是要求轨线永久 shadowing。

## 4.6 L96 动力学数据指标

定义空间平均：

$$

\overline x_m^{(\nu)}
=
\frac1{N_x}
\sum_{j=1}^{N_x}
x_{m,j}^{(\nu)},

$$

空间能量：

$$

E_m^{(\nu)}
=
\frac1{2N_x}
\left\|
\mathbf x_m^{(\nu)}
\right\|_2^2,

$$

空间方差：

$$

V_m^{(\nu)}
=
\frac1{N_x}
\sum_{j=1}^{N_x}
\left(
x_{m,j}^{(\nu)}
-
\overline x_m^{(\nu)}
\right)^2.

$$

数据证书必须记录：

$$

\operatorname{mean}(E),
\quad
\operatorname{std}(E),
\quad
\min(E),
\quad
\max(E),

$$

$$

\operatorname{mean}(V),
\quad
\operatorname{std}(V),

$$

以及每个 split 的早期–晚期漂移：

$$

\Delta E_{\mathrm{stat}}
=
\frac{
\left|
\overline E_{\mathrm{late}}
-
\overline E_{\mathrm{early}}
\right|
}{
|\overline E_{\mathrm{early}}|
+
\varepsilon_{\mathrm{num}}
}.

$$

另记录：

$$

\boxed{
\text{空间相关函数},
\quad
\text{时间自相关函数},
\quad
\text{积分自相关时间},
\quad
\text{功率谱密度}.
}

$$

---

# 5. Kuramoto–Sivashinsky–64 数据

## 5.1 连续模型

在周期区间

$$

x\in[0,L_{\mathrm{KS}}),
\qquad
L_{\mathrm{KS}}=22,

$$

定义 KS 方程：

$$

\boxed{
\partial_tu
=
-u\partial_xu
-
\partial_{xx}u
-
\partial_{xxxx}u.
}

$$

采用零均值状态空间：

$$

\boxed{
\int_0^{L_{\mathrm{KS}}}
u(x,t)\,\mathrm dx
=
0.
}

$$

空间网格为

$$

x_j
=
\frac{jL_{\mathrm{KS}}}{N_x},
\qquad
j=0,\ldots,N_x-1,
\qquad
N_x=64.

$$

状态定义为

$$

\boxed{
\mathbf z(t)
=
\mathbf u(t)
\in
\mathbb R^{64\times1}.
}

$$

原有 KS64 数据协议采用 Fourier 伪谱、$2/3$ 去混叠和 ETDRK4；本文保留该结构保持型积分路线，但将内部步长进一步缩小。fileciteturn8file1

## 5.2 Fourier 半离散形式

定义 Fourier 系数

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

半离散系统为

$$

\frac{\mathrm d\widehat u_k}{\mathrm dt}
=
\left(
\kappa_k^2-\kappa_k^4
\right)
\widehat u_k
-
\frac{i\kappa_k}{2}
\widehat{u^2}_k.

$$

记

$$

\dot{\widehat{\mathbf u}}
=
\mathbf L\widehat{\mathbf u}
+
\mathcal N(\widehat{\mathbf u}).

$$

## 5.3 去混叠

采用 $2/3$ 去混叠：

$$

m_k
=
\begin{cases}
1,
&
|k|
\le
\left\lfloor N_x/3\right\rfloor,
\\
0,
&
\text{otherwise}.
\end{cases}

$$

非线性项为

$$

\mathcal N_k^{\mathrm{deal}}
=
m_k\mathcal N_k.

$$

每次非线性评估后应用去混叠掩码。

## 5.4 高精度 ETDRK4

生产内部步长取为

$$

\boxed{
\delta t_{\mathrm{KS}}=0.01.
}

$$

基础保存间隔为

$$

\boxed{
\tau_{\mathrm{base}}
=
5\delta t_{\mathrm{KS}}
=
0.05.
}

$$

ETDRK4 预计算：

$$

\mathbf E,
\qquad
\mathbf E_{1/2},
\qquad
\mathbf Q,
\qquad
\mathbf f_1,
\qquad
\mathbf f_2,
\qquad
\mathbf f_3.

$$

轮廓积分节点数取

$$

\boxed{
M_{\mathrm{contour}}=64.
}

$$

每一步推进后显式设置

$$

\boxed{
\widehat u_0=0.
}

$$

参考时间积分采用

$$

\boxed{
\delta t_{\mathrm{KS,ref}}=0.005.
}

$$

空间参考分辨率采用

$$

\boxed{
N_x^{\mathrm{ref}}=128.
}

$$

参考解比较前截断到 KS64 的低频模态，再变换回 $64$ 点物理网格。

## 5.5 初值与 warm-up

对正 Fourier 模态

$$

n=1,\ldots,8

$$

生成

$$

\widehat u_n^{(\nu)}(0)
=
\frac{
\alpha_n^{(\nu)}
}{
1+(n/4)^4
},

$$

其中

$$

\alpha_n^{(\nu)}

$$

为独立复高斯变量。

强制 Hermitian 对称：

$$

\widehat u_{-n}^{(\nu)}(0)
=
\overline{
\widehat u_n^{(\nu)}(0)
},

$$

并令

$$

\widehat u_0^{(\nu)}(0)=0.

$$

逆变换后，将初场 RMS 调整为

$$

\left[
\frac1{N_x}
\sum_{j=0}^{N_x-1}
u_j^{(\nu)}(0)^2
\right]^{1/2}
=
\rho_\nu,

$$

其中

$$

\rho_\nu
\sim
\mathcal U[0.5,1.0].

$$

正式记录前执行

$$

\boxed{
T_{\mathrm{warm}}^{\mathrm{KS}}=200.
}

$$

## 5.6 记录长度

取

$$

\boxed{
T_{\mathrm{record}}^{\mathrm{KS}}=256,
\qquad
M_{\mathrm{traj}}^{\mathrm{KS}}=5120.
}

$$

每条轨线保存

$$

5121

$$

个物理状态。

## 5.7 KS 时间与空间误差证书

定义生产与参考时间积分差异：

$$

\boxed{
\varepsilon_{\mathrm{time,KS}}^{(1)}
=
\left[
\frac{
\sum_s
\left\|
\mathbf u_{s,+}^{\mathrm{prod}}
-
\mathbf u_{s,+}^{\mathrm{ref}}
\right\|_2^2
}{
\sum_s
\left\|
\mathbf u_{s,+}^{\mathrm{ref}}
\right\|_2^2
+
\varepsilon_{\mathrm{num}}
}
\right]^{1/2}.
}

$$

建议要求

$$

\boxed{
\varepsilon_{\mathrm{time,KS}}^{(1)}
\le10^{-6}.
}

$$

定义空间分辨率误差：

$$

\boxed{
\varepsilon_{\mathrm{space,KS}}^{(1)}
=
\left[
\frac{
\sum_s
\left\|
\mathbf u_{s,+}^{64}
-
\mathcal R_{128\to64}
\mathbf u_{s,+}^{128}
\right\|_2^2
}{
\sum_s
\left\|
\mathcal R_{128\to64}
\mathbf u_{s,+}^{128}
\right\|_2^2
+
\varepsilon_{\mathrm{num}}
}
\right]^{1/2},
}

$$

其中

$$

\mathcal R_{128\to64}

$$

表示 Fourier 截断与物理网格恢复。

## 5.8 KS 数据集指标

定义空间均值：

$$

\overline u_m^{(\nu)}
=
\frac1{N_x}
\sum_{j=0}^{N_x-1}
u_{m,j}^{(\nu)}.

$$

必须满足

$$

\boxed{
\max_{\nu,m}
\left|
\overline u_m^{(\nu)}
\right|
\le10^{-12}.
}

$$

定义总能量：

$$

E_{\mathrm{KS},m}^{(\nu)}
=
\frac1{2N_x}
\left\|
\mathbf u_m^{(\nu)}
\right\|_2^2,

$$

Fourier 能量谱：

$$

\mathcal E_k
=
\frac1{M_{\mathrm{stat}}}
\sum_{\nu,m}
\left|
\widehat u_{m,k}^{(\nu)}
\right|^2.

$$

定义高频尾部比例：

$$

\boxed{
r_{\mathrm{tail}}
=
\frac{
\sum_{|k|>N_x/4}
\mathcal E_k
}{
\sum_k\mathcal E_k
+
\varepsilon_{\mathrm{num}}
}.
}

$$

定义去混叠带外能量：

$$

r_{\mathrm{alias}}
=
\frac{
\sum_{|k|>N_x/3}
|\widehat u_k|^2
}{
\sum_k|\widehat u_k|^2
+
\varepsilon_{\mathrm{num}}
}.

$$

数据证书还应包括：

$$

\boxed{
\text{时间平均 Fourier 能量谱},
}

$$

$$

\boxed{
\text{空间自相关函数},
\quad
\text{时间自相关函数},
\quad
\text{积分自相关时间},
}

$$

$$

\boxed{
\text{早期–晚期能量统计差异},
\quad
\text{train/val/test 能谱差异}.
}

$$

---

# 6. FitzHugh–Nagumo–64 数据

## 6.1 连续模型

在周期区间

$$

x\in[0,L_{\mathrm{FHN}}),
\qquad
L_{\mathrm{FHN}}=32,

$$

定义反应–扩散系统：

$$

\boxed{
\begin{aligned}
\partial_tu
&=
D_u\partial_{xx}u
+
u
-
\frac13u^3
-
v,
\\
\partial_tv
&=
D_v\partial_{xx}v
+
\varepsilon
\left(
u+a-bv
\right).
\end{aligned}
}

$$

参数取为

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

不引入外部强迫：

$$

I_{\mathrm{ext}}=0.

$$

状态定义为

$$

\boxed{
\mathbf z(t)
=
\begin{bmatrix}
\mathbf u(t)\\
\mathbf v(t)
\end{bmatrix}
\in
\mathbb R^{128\times1}.
}

$$

## 6.2 高阶周期空间离散

取

$$

N_x=64,
\qquad
\Delta x
=
\frac{L_{\mathrm{FHN}}}{N_x}
=
0.5.

$$

采用周期四阶中心差分：

$$

\boxed{
\left(
\mathbf D_{xx}^{(4)}\mathbf q
\right)_j
=
\frac{
-q_{j+2}
+
16q_{j+1}
-
30q_j
+
16q_{j-1}
-
q_{j-2}
}{
12\Delta x^2
}.
}

$$

下标按模 $N_x$ 取值。

半离散系统为

$$

\begin{aligned}
\dot{\mathbf u}
&=
D_u\mathbf D_{xx}^{(4)}\mathbf u
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

## 6.3 高精度刚性积分器

生产积分器采用：

$$

\boxed{
\text{五阶或更高阶的 L-stable Rosenbrock / implicit Runge--Kutta 方法}.
}

$$

生产容差为

$$

\boxed{
\mathrm{reltol}=10^{-10},
\qquad
\mathrm{abstol}=10^{-12}.
}

$$

限制最大内部步长：

$$

\boxed{
\Delta t_{\max}=0.02.
}

$$

正式状态只在

$$

t_m=0.05m

$$

保存。

参考积分采用独立的高精度刚性方法，并取

$$

\boxed{
\mathrm{reltol}_{\mathrm{ref}}=10^{-12},
\qquad
\mathrm{abstol}_{\mathrm{ref}}=10^{-14}.
}

$$

空间参考分辨率取

$$

\boxed{
N_x^{\mathrm{ref}}=128.
}

$$

## 6.4 静息平衡

静息平衡满足

$$

u_\star-\frac13u_\star^3-v_\star=0,

$$

$$

v_\star
=
\frac{u_\star+a}{b}.

$$

记

$$

\mathbf z_\star
=
\begin{bmatrix}
u_\star\mathbf1\\
v_\star\mathbf1
\end{bmatrix}.

$$

## 6.5 分制度初值族

FHN64 不再只保留 warm-up 后仍处于活跃波传播状态的轨线，而采用四类可追踪的初值制度：

$$

\boxed{
\mathcal G_{\mathrm{FHN}}
=
\{
\mathrm{active},
\mathrm{formation},
\mathrm{collision},
\mathrm{recovery}
\}.
}

$$

480 条轨线按以下数量生成：

$$

\boxed{
\begin{aligned}
|\mathcal R_{\mathrm{active}}|
&=240,
\\
|\mathcal R_{\mathrm{formation}}|
&=96,
\\
|\mathcal R_{\mathrm{collision}}|
&=96,
\\
|\mathcal R_{\mathrm{recovery}}|
&=48.
\end{aligned}
}

$$

每个 split 保持相同比例：

| 制度 | train | val | test |
|---|---:|---:|---:|
| active | 160 | 40 | 40 |
| formation | 64 | 16 | 16 |
| collision | 64 | 16 | 16 |
| recovery | 32 | 8 | 8 |

定义周期距离：

$$

d_{\mathrm{per}}(x,c)
=
\min_{n\in\mathbb Z}
|x-c+nL_{\mathrm{FHN}}|.

$$

一般脉冲初值写为

$$

u_0^{(\nu)}(x)
=
u_\star
+
\sum_{\ell=1}^{J_\nu}
A_{\nu,\ell}
\exp
\left(
-
\frac{
d_{\mathrm{per}}(x,c_{\nu,\ell})^2
}{
2w_{\nu,\ell}^2
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
\delta_v\xi_v^{(\nu)}(x).

$$

其中

$$

A_{\nu,\ell}
\sim
\mathcal U[1.6,2.6],

$$

$$

w_{\nu,\ell}
\sim
\mathcal U[0.8,1.8],

$$

$$

\delta_u=0.03,
\qquad
\delta_v=0.01.

$$

随机场

$$

\xi_u^{(\nu)},
\qquad
\xi_v^{(\nu)}

$$

为零均值、周期平滑、单位 RMS 的低频随机场，只包含

$$

|k|\le3

$$

的 Fourier 模态。

### 6.5.1 Active regime

取

$$

J_\nu\in\{1,2\},
\qquad
T_{\mathrm{warm}}=32.

$$

该制度主要包含成熟传播脉冲与波列。

### 6.5.2 Formation regime

取

$$

J_\nu\in\{1,2\},
\qquad
T_{\mathrm{warm}}=0.

$$

正式轨线包含脉冲形成、阈值跨越和早期恢复过程。

### 6.5.3 Collision regime

取

$$

J_\nu\in\{2,3,4\},
\qquad
T_{\mathrm{warm}}=4.

$$

脉冲中心满足最小周期距离约束，用于生成相向传播、追赶和碰撞状态。

### 6.5.4 Recovery regime

取亚阈值或弱超阈值扰动：

$$

A_{\nu,\ell}
\sim
\mathcal U[0.2,1.5],

$$

$$

J_\nu\in\{0,1,2\},
\qquad
T_{\mathrm{warm}}=0.

$$

该制度覆盖静息态附近、衰减过程和弱激发恢复。

所有制度均保留，不再以 warm-up 末端活动量作为全局拒绝条件。只拒绝：

$$

\boxed{
\text{非有限数值解}
\quad\text{或}\quad
\text{明显违反预设物理幅值界的积分失败轨线}.
}

$$

## 6.6 记录长度

取

$$

\boxed{
T_{\mathrm{record}}^{\mathrm{FHN}}=256,
\qquad
M_{\mathrm{traj}}^{\mathrm{FHN}}=5120.
}

$$

每条轨线保存

$$

5121

$$

个完整状态。

## 6.7 FHN 时间与空间误差证书

由于 $u$ 与 $v$ 的自然幅值不同，时间积分误差按两个物理场分块计算。

定义

$$

\varepsilon_u^{(1)}
=
\left[
\frac{
\sum_s
\left\|
\mathbf u_{s,+}^{\mathrm{prod}}
-
\mathbf u_{s,+}^{\mathrm{ref}}
\right\|_2^2
}{
\sum_s
\left\|
\mathbf u_{s,+}^{\mathrm{ref}}
-
u_\star\mathbf1
\right\|_2^2
+
\varepsilon_{\mathrm{num}}
}
\right]^{1/2},

$$

$$

\varepsilon_v^{(1)}
=
\left[
\frac{
\sum_s
\left\|
\mathbf v_{s,+}^{\mathrm{prod}}
-
\mathbf v_{s,+}^{\mathrm{ref}}
\right\|_2^2
}{
\sum_s
\left\|
\mathbf v_{s,+}^{\mathrm{ref}}
-
v_\star\mathbf1
\right\|_2^2
+
\varepsilon_{\mathrm{num}}
}
\right]^{1/2}.

$$

定义总体时间证书：

$$

\boxed{
\varepsilon_{\mathrm{time,FHN}}^{(1)}
=
\left[
\frac12
\left(
(\varepsilon_u^{(1)})^2
+
(\varepsilon_v^{(1)})^2
\right)
\right]^{1/2}.
}

$$

建议要求

$$

\boxed{
\varepsilon_{\mathrm{time,FHN}}^{(1)}
\le10^{-6}.
}

$$

空间分辨率证书比较 $N_x=64$ 与 $N_x=128$ 的限制解：

$$

\boxed{
\varepsilon_{\mathrm{space,FHN}}^{(1)}
=
\left[
\frac12
\left(
(\varepsilon_{u,\mathrm{space}}^{(1)})^2
+
(\varepsilon_{v,\mathrm{space}}^{(1)})^2
\right)
\right]^{1/2}.
}

$$

## 6.8 FHN 数据集指标

定义场均值：

$$

\overline u(t)
=
\frac1{N_x}
\sum_j u_j(t),
\qquad
\overline v(t)
=
\frac1{N_x}
\sum_j v_j(t).

$$

定义场 RMS：

$$

u_{\mathrm{RMS}}(t)
=
\left[
\frac1{N_x}
\sum_j
\left(
u_j(t)-\overline u(t)
\right)^2
\right]^{1/2},

$$

$$

v_{\mathrm{RMS}}(t)
=
\left[
\frac1{N_x}
\sum_j
\left(
v_j(t)-\overline v(t)
\right)^2
\right]^{1/2}.

$$

定义活动量：

$$

\boxed{
A_{\mathrm{FHN}}(t)
=
\max_j u_j(t)
-
\min_j u_j(t).
}

$$

数据证书必须按 regime 和 split 分别统计：

$$

\operatorname{mean}(A_{\mathrm{FHN}}),
\qquad
\operatorname{std}(A_{\mathrm{FHN}}),
\qquad
\min(A_{\mathrm{FHN}}),
\qquad
\max(A_{\mathrm{FHN}}).

$$

同时记录：

$$

\boxed{
\text{传播波峰数量},
}

$$

$$

\boxed{
\text{波峰传播速度分布},
}

$$

$$

\boxed{
\text{脉冲半高宽分布},
}

$$

$$

\boxed{
u\text{ 与 }v\text{ 的局部相位延迟},
}

$$

$$

\boxed{
u,v\text{ 的空间相关长度},
}

$$

$$

\boxed{
u,v\text{ 的时间自相关时间},
}

$$

以及两个场各自的时间平均 Fourier 能量谱：

$$

\mathcal E_k^{u},
\qquad
\mathcal E_k^{v}.

$$

这些指标用于确认 FHN64 数据覆盖了：

$$

\boxed{
\text{成熟传播}
+
\text{脉冲形成}
+
\text{脉冲碰撞}
+
\text{恢复与静息邻域}.
}

$$

---

# 7. 混沌指标与长期统计证书

K0 协议明确区分了短期点态预测、自治混沌系统的长期统计一致性和 Koopman 表示质量；其中 KLD 与 MMD 用于比较长期经验测度。数据生成阶段不评价模型，但可以将相同原则用于检验不同数据 split 是否采样到了相容的长期动力学分布。fileciteturn8file0

本节适用于：

$$

\boxed{
\mathsf{L96\text{-}40}
\quad\text{与}\quad
\mathsf{KS64}.
}

$$

FHN64 默认不作为混沌系统处理，除非数值诊断明确给出正最大 Lyapunov 指数。

## 7.1 Lyapunov 谱

沿参考轨线求解切向方程：

$$

\dot{\boldsymbol{\delta x}}
=
\mathrm D\mathbf f
\left(
\mathbf x(t)
\right)
\boldsymbol{\delta x}.

$$

对 $d_z$ 个切向向量组成的矩阵

$$

\mathbf Q(t)
\in
\mathbb R^{d_z\times d_z}

$$

执行周期 QR 正交化。

设第 $r$ 次 QR 分解为

$$

\mathbf Y_r
=
\mathbf Q_r\mathbf R_r.

$$

第 $j$ 个 Lyapunov 指数估计为

$$

\boxed{
\widehat\lambda_j
=
\frac1{T_{\lambda}}
\sum_r
\log
\left|
(\mathbf R_r)_{jj}
\right|.
}

$$

应报告：

$$

\boxed{
\widehat\lambda_1,
\ldots,
\widehat\lambda_{d_z}.
}

$$

至少必须记录：

$$

\boxed{
\widehat\lambda_{\max}
=
\widehat\lambda_1,
}

$$

$$

\boxed{
T_{\mathrm{Lyap}}
=
\widehat\lambda_{\max}^{-1},
}

$$

$$

\boxed{
N_{\lambda,+}
=
\#\{j:\widehat\lambda_j>0\}.
}

$$

若存在整数 $r$ 满足

$$

\sum_{j=1}^{r}
\widehat\lambda_j
\ge0,
\qquad
\sum_{j=1}^{r+1}
\widehat\lambda_j
<0,

$$

定义 Kaplan–Yorke 维数：

$$

\boxed{
D_{\mathrm{KY}}
=
r
+
\frac{
\sum_{j=1}^{r}
\widehat\lambda_j
}{
|\widehat\lambda_{r+1}|
}.
}

$$

定义 Kolmogorov–Sinai 熵代理：

$$

\boxed{
h_{\mathrm{KS}}^{\mathrm{Lyap}}
=
\sum_{\widehat\lambda_j>0}
\widehat\lambda_j.
}

$$

为避免与 Kuramoto–Sivashinsky 缩写混淆，数据文件中使用字段：

```text
lyapunov_entropy_rate
```

而不使用单独的 `h_KS`。

Lyapunov 谱在独立的长诊断轨线上计算，不要求对全部 480 条正式轨线重复计算。

建议：

$$

\boxed{
R_{\lambda}^{\mathrm{L96}}=16,
\qquad
R_{\lambda}^{\mathrm{KS}}=8.
}

$$

## 7.2 自相关时间与有效样本量

对标量诊断 observable $g$，定义归一化时间自相关：

$$

\rho_g(\ell)
=
\frac{
\operatorname{Cov}
\left(
g_m,g_{m+\ell}
\right)
}{
\operatorname{Var}(g_m)
}.

$$

定义积分自相关时间：

$$

\boxed{
\tau_{\mathrm{int}}(g)
=
\tau_{\mathrm{base}}
\left[
1
+
2
\sum_{\ell=1}^{\ell_\star}
\rho_g(\ell)
\right].
}

$$

其中 $\ell_\star$ 由首次稳定过零或窗口截断规则确定。

对总快照数 $M_{\mathrm{tot}}$，定义有效独立样本量：

$$

\boxed{
M_{\mathrm{eff}}(g)
\approx
\frac{
M_{\mathrm{tot}}\tau_{\mathrm{base}}
}{
2\tau_{\mathrm{int}}(g)
}.
}

$$

L96 至少对以下 observable 计算：

$$

E,
\qquad
\overline x,
\qquad
x_1.

$$

KS 至少对以下 observable 计算：

$$

E_{\mathrm{KS}},
\qquad
|\widehat u_1|^2,
\qquad
|\widehat u_2|^2.

$$

## 7.3 Split 间长期经验测度一致性

设固定统计评价映射为

$$

\mathcal T_{\mathrm{stat}}
:
\mathcal X
\to
\mathbb R^q.

$$

高维系统采用只由训练数据确定的 PCA 投影：

$$

\mathcal T_{\mathrm{stat}}
=
\mathbf P_q^\top,

$$

其中 $q$ 由固定累计方差阈值或外部配置给定。

用 train、validation、test 长期状态分别构造经验测度：

$$

\widehat\mu_{\mathrm{train}},
\qquad
\widehat\mu_{\mathrm{val}},
\qquad
\widehat\mu_{\mathrm{test}}.

$$

报告：

$$

\boxed{
\widehat D_{\mathrm{KL}}
\left(
\widehat\mu_{\mathrm{train}}
\middle\|
\widehat\mu_{\mathrm{val}}
\right),
}

$$

$$

\boxed{
\widehat D_{\mathrm{KL}}
\left(
\widehat\mu_{\mathrm{train}}
\middle\|
\widehat\mu_{\mathrm{test}}
\right),
}

$$

以及

$$

\boxed{
\widehat{\operatorname{MMD}}^2
\left(
\widehat\mu_{\mathrm{train}},
\widehat\mu_{\mathrm{val}}
\right),
}

$$

$$

\boxed{
\widehat{\operatorname{MMD}}^2
\left(
\widehat\mu_{\mathrm{train}},
\widehat\mu_{\mathrm{test}}
\right).
}

$$

评价核必须在任何模型训练前固定，并只由真实训练数据确定。K0 中长期统计评价同样要求固定统计坐标、初值集合、样本数量和评价核。fileciteturn8file0

## 7.4 早期–晚期平稳性

将每条正式记录轨线分为前半段和后半段。

对任意统计 observable $g$，定义：

$$

\Delta_g^{(\nu)}
=
\frac{
\left|
\overline g_{\mathrm{late}}^{(\nu)}
-
\overline g_{\mathrm{early}}^{(\nu)}
\right|
}{
\operatorname{std}
\left(
g_m^{(\nu)}
\right)
+
\varepsilon_{\mathrm{num}}
}.

$$

报告：

$$

\operatorname{median}_\nu\Delta_g^{(\nu)},
\qquad
Q_{0.9}
\left(
\Delta_g^{(\nu)}
\right).

$$

该指标用于检测 warm-up 不充分，而不用于根据单条轨线的正常混沌涨落进行人为筛选。

---

# 8. 统一数据健康证书

每个系统必须执行以下检查。

## 8.1 有限性

要求所有状态满足：

$$

\boxed{
\operatorname{isfinite}
\left(
z_{m,j}^{(\nu)}
\right)
=
\mathrm{True}.
}

$$

## 8.2 张量尺寸

要求：

$$

\mathcal Z_{\mathrm{L96},\mathrm{train}}
\in
\mathbb R^{320\times2049\times40},

$$

$$

\mathcal Z_{\mathrm{L96},\mathrm{val}}
,
\mathcal Z_{\mathrm{L96},\mathrm{test}}
\in
\mathbb R^{80\times2049\times40},

$$

$$

\mathcal Z_{\mathrm{KS},\mathrm{train}}
\in
\mathbb R^{320\times5121\times64},

$$

$$

\mathcal Z_{\mathrm{FHN},\mathrm{train}}
\in
\mathbb R^{320\times5121\times128},

$$

验证集与测试集第一维均为 $80$。

## 8.3 时间轴

要求

$$

t_{m+1}-t_m
=
\tau_{\mathrm{base}}

$$

在机器精度范围内成立。

## 8.4 重复轨线检查

对不同轨线的首状态、随机 seed 和若干时间片计算 hash 与距离，排除：

$$

\boxed{
\text{重复 seed},
\quad
\text{重复初值},
\quad
\text{重复完整轨线}.
}

$$

## 8.5 周期边界单元测试

L96 检查：

$$

f_1(\mathbf x)
=
(x_2-x_{39})x_{40}-x_1+F_0,

$$

$$

f_{40}(\mathbf x)
=
(x_1-x_{38})x_{39}-x_{40}+F_0.

$$

KS 和 FHN 检查周期平移交换性：

$$

\mathbf F_{\mathrm{num}}^\tau
\mathbf S_q
\mathbf z
\approx
\mathbf S_q
\mathbf F_{\mathrm{num}}^\tau
\mathbf z.

$$

定义平移等变误差：

$$

\boxed{
\varepsilon_{\mathrm{shift}}
=
\frac{
\left\|
\mathbf F_{\mathrm{num}}^\tau
\mathbf S_q\mathbf z
-
\mathbf S_q
\mathbf F_{\mathrm{num}}^\tau\mathbf z
\right\|_2
}{
\left\|
\mathbf F_{\mathrm{num}}^\tau\mathbf z
\right\|_2
+
\varepsilon_{\mathrm{num}}
}.
}

$$

---

# 9. 数据存储规范

每个对象保存为独立 HDF5 文件：

```text
l96_nx40_raw_v2.h5
ks64_raw_v2.h5
fhn64_raw_v2.h5
```

逻辑结构为：

```text
/meta
    system_name
    state_dimension
    spatial_dimension
    physical_parameters
    base_sampling_interval
    derived_sampling_views
    record_time
    trajectory_count
    float_type
    solver_name
    solver_order
    reltol
    abstol
    max_internal_step
    spatial_discretization
    random_seed_master
    code_commit
    environment_hash

/train
    state
    time
    trajectory_id
    seed
    initial_state
    warmup_time
    regime_label

/val
    state
    time
    trajectory_id
    seed
    initial_state
    warmup_time
    regime_label

/test
    state
    time
    trajectory_id
    seed
    initial_state
    warmup_time
    regime_label

/diagnostics
    time_convergence
    space_convergence
    physical_statistics
    autocorrelation
    energy_spectrum
    lyapunov_spectrum
    split_distribution
    stationarity
```

L96 和 KS 的 `lyapunov_spectrum` 必须存在。

FHN 的 `regime_label` 必须存在；L96 和 KS 可统一写为：

```text
attractor
```

原始数据文件不包含标准化状态。

---

# 10. 数值证书与动力学证书输出

每个系统输出一个 JSON 证书：

```text
l96_nx40_data_certificate_v2.json
ks64_data_certificate_v2.json
fhn64_data_certificate_v2.json
```

统一字段至少包括：

```text
finite_check
shape_check
time_grid_check
duplicate_check
time_one_step_error
space_one_step_error
shift_equivariance_error
early_late_stationarity
split_statistics
autocorrelation_time
effective_sample_size
```

L96 和 KS 额外包括：

```text
largest_lyapunov_exponent
lyapunov_time
positive_lyapunov_count
kaplan_yorke_dimension
lyapunov_entropy_rate
train_val_kld
train_test_kld
train_val_mmd2
train_test_mmd2
```

KS 额外包括：

```text
zero_mode_error
mean_energy
energy_spectrum
high_frequency_tail_ratio
alias_band_energy_ratio
```

FHN 额外包括：

```text
regime_counts
activity_statistics
pulse_count_statistics
wave_speed_statistics
pulse_width_statistics
uv_phase_lag_statistics
u_energy_spectrum
v_energy_spectrum
```

---

# 11. 必须生成的图件

## 11.1 L96

1. 代表轨线的 $j$-$t$ heatmap；
2. 空间能量 $E(t)$；
3. 时间自相关曲线；
4. 功率谱密度；
5. Lyapunov 谱；
6. train/val/test 统计投影分布；
7. 生产积分与参考积分的一步误差分布。

## 11.2 KS64

1. $x$-$t$ heatmap；
2. 时间平均 Fourier 能量谱；
3. 高频能量尾部；
4. 总能量时间序列；
5. 时间与空间自相关；
6. Lyapunov 谱；
7. train/val/test 长期统计投影；
8. $N_x=64$ 与 $N_x=128$ 空间收敛图。

## 11.3 FHN64

1. $u(x,t)$ heatmap；
2. $v(x,t)$ heatmap；
3. active、formation、collision、recovery 四类代表轨线；
4. 活动量 $A_{\mathrm{FHN}}(t)$；
5. 波速与脉冲宽度分布；
6. $u,v$ 的 Fourier 能量谱；
7. $u,v$ 的时间自相关；
8. $N_x=64$ 与 $N_x=128$ 空间收敛图。

---

# 12. 最终固定配置

## 12.1 Lorenz–96–40

$$

\boxed{
N_x=40,
\qquad
F_0=8,
\qquad
\tau_{\mathrm{base}}=0.05,
}

$$

$$

\boxed{
T_{\mathrm{burn}}=100,
\qquad
T_{\mathrm{record}}=102.4,
\qquad
M_{\mathrm{traj}}=2048,
}

$$

$$

\boxed{
\mathrm{reltol}=10^{-10},
\qquad
\mathrm{abstol}=10^{-12},
\qquad
\Delta t_{\max}=0.01.
}

$$

## 12.2 KS64

$$

\boxed{
N_x=64,
\qquad
L_{\mathrm{KS}}=22,
\qquad
\tau_{\mathrm{base}}=0.05,
}

$$

$$

\boxed{
\delta t_{\mathrm{KS}}=0.01,
\qquad
M_{\mathrm{contour}}=64,
\qquad
N_x^{\mathrm{ref}}=128,
}

$$

$$

\boxed{
T_{\mathrm{warm}}=200,
\qquad
T_{\mathrm{record}}=256,
\qquad
M_{\mathrm{traj}}=5120.
}

$$

## 12.3 FHN64

$$

\boxed{
N_x=64,
\qquad
L_{\mathrm{FHN}}=32,
\qquad
\tau_{\mathrm{base}}=0.05,
}

$$

$$

\boxed{
\mathrm{reltol}=10^{-10},
\qquad
\mathrm{abstol}=10^{-12},
\qquad
\Delta t_{\max}=0.02,
}

$$

$$

\boxed{
N_x^{\mathrm{ref}}=128,
\qquad
T_{\mathrm{record}}=256,
\qquad
M_{\mathrm{traj}}=5120.
}

$$

## 12.4 统一轨线数

$$

\boxed{
|\mathcal R|=480,
}

$$

$$

\boxed{
|\mathcal R_{\mathrm{train}}|=320,
\qquad
|\mathcal R_{\mathrm{val}}|=80,
\qquad
|\mathcal R_{\mathrm{test}}|=80.
}

$$

---

# 13. 最终验收原则

数据生成任务的完成标准为：

$$

\boxed{
\text{原始物理轨线完整、有限、可复现且轨线级划分无泄漏};
}

$$

$$

\boxed{
\text{生产积分误差与空间离散误差显著低于后续模型误差尺度};
}

$$

$$

\boxed{
\text{L96 与 KS64 具有明确的正最大 Lyapunov 指数及稳定混沌统计};
}

$$

$$

\boxed{
\text{train、validation、test 对同一长期动力学分布具有一致覆盖};
}

$$

$$

\boxed{
\text{KS64 保持零均值、合理能谱与受控高频尾部};
}

$$

$$

\boxed{
\text{FHN64 覆盖传播、形成、碰撞和恢复等多种反应–扩散制度};
}

$$

$$

\boxed{
\text{数据生成阶段不执行任何标准化或模型相关处理}.
}

$$

由此，后续 SPDL、KEDMD、KDSM 或 MDKK 实验中的误差可以明确区分为：

$$

\boxed{
\text{数据数值误差}
\quad\neq\quad
\text{有限维 Koopman 闭合误差}
\quad\neq\quad
\text{多步预测误差}.
}

$$
