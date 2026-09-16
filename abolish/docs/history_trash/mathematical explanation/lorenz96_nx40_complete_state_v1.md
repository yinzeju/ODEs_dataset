# `l96_nx40_complete_state_v1`：Lorenz–96 完整状态轨线数据生成任务

## 0. 任务目标

本任务生成一个用于高维自治混沌动力学建模的标准 Lorenz–96 数据集。数据集只定义动力系统、数值积分、独立轨线、轨线级划分、原始物理坐标轨线与数据验收规则；不包含任何特定预测器、字典、核函数、神经网络训练逻辑或数据对象内置标准化资源。

本数据集的统一学习对象为完整状态离散动力学：

$$

\mathbf x_{m+1}
=
\mathbf F^\tau(\mathbf x_m),
\qquad
\mathbf x_m
\in
\mathcal X
=
\mathbb R^{40\times1}.

$$

学习器输入与物理预测目标统一取为完整状态：

$$

\boxed{
\mathbf z_m^{(\nu)}
=
\mathbf y_m^{(\nu)}
=
\mathbf x_m^{(\nu)}
\in
\mathbb R^{40\times1}.
}

$$

其中 $\nu$ 表示轨线索引，$m$ 表示轨线内离散时间索引。

---

# 1. Lorenz–96 动力系统

## 1.1 状态空间与参数

取空间维数

$$

\boxed{
N_x=40,
}

$$

常强迫参数

$$

\boxed{
F_0=8.
}

$$

连续时间动力系统为

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
j=1,\ldots,N_x.
}

$$

空间索引采用周期边界条件：

$$

\boxed{
x_{j+N_x}=x_j,
\qquad
j\in\mathbb Z.
}

$$

因此，例如

$$

x_0=x_{40},
\qquad
x_{-1}=x_{39},
\qquad
x_{41}=x_1.

$$

定义向量场

$$

\mathbf f:
\mathbb R^{40\times1}
\to
\mathbb R^{40\times1},

$$

其第 $j$ 个分量为

$$

f_j(\mathbf x)
=
\left(
x_{j+1}-x_{j-2}
\right)x_{j-1}
-
x_j
+
F_0.

$$

连续流映射记为

$$

\mathbf F^t:
\mathcal X
\to
\mathcal X.

$$

---

# 2. 数值积分与采样协议

## 2.1 内部积分步长

采用经典四阶 Runge–Kutta 方法，内部积分步长取为

$$

\boxed{
\Delta t_{\mathrm{int}}
=
0.005.
}

$$

记单步 RK4 数值推进为

$$

\Phi_{\Delta t_{\mathrm{int}}}^{\mathrm{RK4}}
:
\mathcal X
\to
\mathcal X.

$$

对于任意当前状态 $\mathbf x$，定义

$$

\mathbf k_1
=
\mathbf f(\mathbf x),

$$

$$

\mathbf k_2
=
\mathbf f
\left(
\mathbf x
+
\frac{\Delta t_{\mathrm{int}}}{2}
\mathbf k_1
\right),

$$

$$

\mathbf k_3
=
\mathbf f
\left(
\mathbf x
+
\frac{\Delta t_{\mathrm{int}}}{2}
\mathbf k_2
\right),

$$

$$

\mathbf k_4
=
\mathbf f
\left(
\mathbf x
+
\Delta t_{\mathrm{int}}
\mathbf k_3
\right).

$$

于是

$$

\boxed{
\Phi_{\Delta t_{\mathrm{int}}}^{\mathrm{RK4}}
(\mathbf x)
=
\mathbf x
+
\frac{\Delta t_{\mathrm{int}}}{6}
\left(
\mathbf k_1
+
2\mathbf k_2
+
2\mathbf k_3
+
\mathbf k_4
\right).
}

$$

所有轨线生成、burn-in 与采样均在 `float64` 精度下执行和保存。

---

## 2.2 学习采样间隔

每经过

$$

\boxed{
q_{\mathrm{save}}
=
10
}

$$

个内部 RK4 步保存一次状态。

因此，数据集的离散采样间隔为

$$

\boxed{
\tau
=
q_{\mathrm{save}}
\Delta t_{\mathrm{int}}
=
0.05.
}

$$

定义数值离散推进

$$

\mathbf F_{\mathrm{num}}^\tau
:=
\left(
\Phi_{\Delta t_{\mathrm{int}}}^{\mathrm{RK4}}
\right)^{q_{\mathrm{save}}}.

$$

于是保存轨线满足

$$

\boxed{
\mathbf x_{m+1}^{(\nu)}
=
\mathbf F_{\mathrm{num}}^\tau
\left(
\mathbf x_m^{(\nu)}
\right).
}

$$

这里 $\mathbf F_{\mathrm{num}}^\tau$ 是对真实流映射 $\mathbf F^\tau$ 的数值近似；数据集元信息必须同时记录 $\Delta t_{\mathrm{int}}$、$q_{\mathrm{save}}$ 与 $\tau$。

---

# 3. 独立初值与 burn-in

## 3.1 初值分布

第 $\nu$ 条轨线的初始状态定义为

$$

\boxed{
\mathbf x_{\mathrm{init}}^{(\nu)}
=
F_0\mathbf 1
+
\delta_{\mathrm{init}}
\boldsymbol{\xi}^{(\nu)},
}

$$

其中

$$

\mathbf 1
=
\begin{bmatrix}
1&\cdots&1
\end{bmatrix}^{\top}
\in
\mathbb R^{40\times1},

$$

$$

\boxed{
\delta_{\mathrm{init}}
=
0.01,
}

$$

且

$$

\boldsymbol{\xi}^{(\nu)}
\sim
\mathcal N
\left(
\mathbf 0,
\mathbf I_{40}
\right).

$$

每条轨线使用独立随机种子生成 $\boldsymbol{\xi}^{(\nu)}$。

任务配置中固定主随机种子

$$

\boxed{
\mathrm{seed}_{\mathrm{master}}
=
20260624.
}

$$

每条轨线的实际随机种子由主种子经确定性 seed-spawning 规则生成，并写入数据集元信息。

---

## 3.2 Burn-in

每条轨线在记录前执行 burn-in：

$$

\boxed{
T_{\mathrm{burn}}
=
100.
}

$$

对应的内部积分步数为

$$

\boxed{
N_{\mathrm{burn}}
=
\frac{
T_{\mathrm{burn}}
}{
\Delta t_{\mathrm{int}}
}
=
20\,000.
}

$$

定义 burn-in 后的首个保存状态：

$$

\boxed{
\mathbf x_0^{(\nu)}
=
\left(
\Phi_{\Delta t_{\mathrm{int}}}^{\mathrm{RK4}}
\right)^{N_{\mathrm{burn}}}
\left(
\mathbf x_{\mathrm{init}}^{(\nu)}
\right).
}

$$

burn-in 阶段的状态不写入正式训练、验证或测试数据集。

---

# 4. 每条轨线的记录长度

对每条 burn-in 后轨线，记录

$$

\boxed{
M_{\mathrm{traj}}+1
=
2049
}

$$

个快照，即

$$

\boxed{
M_{\mathrm{traj}}
=
2048
}

$$

个 one-step pairs。

因此

$$

\mathbf x_m^{(\nu)},
\qquad
m=0,\ldots,2048.

$$

记录区间的总物理时长为

$$

\boxed{
T_{\mathrm{rec}}
=
M_{\mathrm{traj}}\tau
=
2048\times0.05
=
102.4.
}

$$

每条轨线产生的 one-step pair 集为

$$

\boxed{
\mathcal P_{\nu}^{(1)}
=
\left\{
(\nu,m):
m=0,\ldots,2047
\right\}.
}

$$

---

# 5. 轨线级数据划分

总共生成

$$

\boxed{
|\mathcal R|
=
480
}

$$

条彼此独立的 burn-in 后轨线，并在**轨线层级**划分为：

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

具体数量固定为

$$

\boxed{
|\mathcal R_{\mathrm{train}}|
=
288,
\qquad
|\mathcal R_{\mathrm{val}}|
=
96,
\qquad
|\mathcal R_{\mathrm{test}}|
=
96.
}

$$

不允许按 snapshot、one-step pair 或窗口将同一条轨线拆分到不同集合。

因此：

$$

\boxed{
M_{\mathrm{pair,train}}
=
288\times2048
=
589\,824,
}

$$

$$

\boxed{
M_{\mathrm{pair,val}}
=
M_{\mathrm{pair,test}}
=
96\times2048
=
196\,608.
}

$$

原始快照数量为

$$

\boxed{
M_{\mathrm{snap,train}}
=
288\times2049
=
590\,112,
}

$$

$$

\boxed{
M_{\mathrm{snap,val}}
=
M_{\mathrm{snap,test}}
=
96\times2049
=
196\,704.
}

$$

---

# 6. 统一的多步可用窗口索引

本数据集预留最大多步预测 horizon：

$$

\boxed{
h_{\max}
=
64.
}

$$

推荐下游任务使用的 horizon 集为

$$

\boxed{
\mathcal H_{\mathrm{roll}}
=
\{1,2,4,8,16,32,64\}.
}

$$

对任意轨线 $\nu$，定义合法 window-anchor 集：

$$

\boxed{
\mathcal A_{\nu}^{\mathrm{win}}
=
\left\{
(\nu,s):
0\le s,
\quad
s+h_{\max}\le M_{\mathrm{traj}}
\right\}.
}

$$

因此

$$

s=0,\ldots,1984.

$$

每条轨线的合法窗口数为

$$

\boxed{
\left|
\mathcal A_{\nu}^{\mathrm{win}}
\right|
=
2048-64+1
=
1985.
}

$$

训练、验证、测试集合中的合法窗口总数分别为

$$

\boxed{
|\mathcal A_{\mathrm{train}}^{\mathrm{win}}|
=
288\times1985
=
571\,680,
}

$$

$$

\boxed{
|\mathcal A_{\mathrm{val}}^{\mathrm{win}}|
=
|\mathcal A_{\mathrm{test}}^{\mathrm{win}}|
=
96\times1985
=
190\,560.
}

$$

window 索引不需要物化为重复数据张量；只需保存轨线数组及其合法起点范围即可。

---

# 7. 原始物理坐标数据

## 7.1 物理坐标数据

数据生成阶段的主产物始终是原始物理坐标：

$$

\mathbf x_m^{(\nu)}
=
\mathbf z_m^{(\nu)}
=
\mathbf y_m^{(\nu)}.

$$

数值积分、burn-in、轨线切分与原始数据存储均在物理坐标中进行。

本数据对象本身不保存标准化、归一化、均值、方差或训练集统计量。若下游学习任务需要预处理，应在读取本 raw release 后由下游任务显式计算并记录，且不改变此数据对象的存储契约。

---

# 8. 数据集输出契约

建议数据集根目录命名为：

```text
l96_nx40_complete_state_v1/
```

其逻辑内容应至少包括：

```text
metadata.json
splits.json
train/
  trajectories
val/
  trajectories
test/
  trajectories
diagnostics/
  integration_check
  trajectory_statistics
```

其中每个 split 的轨线数据张量满足：

$$

\boxed{
\mathcal X_{\bullet}
\in
\mathbb R^{
|\mathcal R_{\bullet}|
\times
2049
\times
40
},
\qquad
\bullet
\in
\{
\mathrm{train},
\mathrm{val},
\mathrm{test}
\}.
}

$$

建议以 `float64` 保存原始轨线。

`metadata.json` 至少记录：

$$

\begin{aligned}
&
N_x=40,
\qquad
F_0=8,
\\
&
\Delta t_{\mathrm{int}}=0.005,
\qquad
q_{\mathrm{save}}=10,
\qquad
\tau=0.05,
\\
&
T_{\mathrm{burn}}=100,
\qquad
N_{\mathrm{burn}}=20\,000,
\\
&
M_{\mathrm{traj}}=2048,
\qquad
h_{\max}=64,
\\
&
\mathrm{seed}_{\mathrm{master}},
\qquad
\text{每条轨线的实际随机种子},
\\
&
\text{RK4 实现版本、生成时间与数据格式版本}.
\end{aligned}

$$

`splits.json` 必须记录所有 trajectory ID 与其唯一 split 标签。

---

# 9. 数值一致性与数据验收

## 9.1 基础完整性检查

必须满足：

$$

\boxed{
\text{所有轨线元素均为有限实数。}
}

$$

即检查：

$$

\operatorname{isfinite}
\left(
x_{m,j}^{(\nu)}
\right)
=
\mathrm{True},

$$

对全部

$$

\nu,
\qquad
m=0,\ldots,2048,
\qquad
j=1,\ldots,40

$$

成立。

同时验证轨线张量维度：

$$

\begin{aligned}
\mathcal X_{\mathrm{train}}
&\in
\mathbb R^{288\times2049\times40},
\\
\mathcal X_{\mathrm{val}}
&\in
\mathbb R^{96\times2049\times40},
\\
\mathcal X_{\mathrm{test}}
&\in
\mathbb R^{96\times2049\times40}.
\end{aligned}

$$

---

## 9.2 周期索引检查

在生成前，对向量场实现执行周期边界单元测试。至少验证：

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

该检查用于排除常见的零基索引、负索引和边界映射错误。

---

## 9.3 积分步长一致性诊断

从 burn-in 后状态中均匀抽取有限个检查点

$$

\left\{
\mathbf x_{\mathrm{chk},s}
\right\}_{s=1}^{S_{\mathrm{chk}}},
\qquad
S_{\mathrm{chk}}=128.

$$

比较一次 $\tau$ 推进在两种内部步长下的差异：

$$

\mathbf x_{\tau,s}^{(0.005)}
=
\left(
\Phi_{0.005}^{\mathrm{RK4}}
\right)^{10}
\left(
\mathbf x_{\mathrm{chk},s}
\right),

$$

$$

\mathbf x_{\tau,s}^{(0.0025)}
=
\left(
\Phi_{0.0025}^{\mathrm{RK4}}
\right)^{20}
\left(
\mathbf x_{\mathrm{chk},s}
\right).

$$

定义平均相对积分差异：

$$

\boxed{
\varepsilon_{\mathrm{RK}}
=
\frac{
1
}{
S_{\mathrm{chk}}
}
\sum_{s=1}^{S_{\mathrm{chk}}}
\frac{
\left\|
\mathbf x_{\tau,s}^{(0.005)}
-
\mathbf x_{\tau,s}^{(0.0025)}
\right\|_2
}{
\left\|
\mathbf x_{\tau,s}^{(0.0025)}
\right\|_2
+
10^{-12}
}.
}

$$

将 $\varepsilon_{\mathrm{RK}}$ 写入诊断文件。建议验收目标为

$$

\boxed{
\varepsilon_{\mathrm{RK}}
\le
10^{-6}.
}

$$

若未满足该条件，应优先检查 RK4 实现和周期索引，而不是直接改变数据规模。

---

## 9.4 吸引子统计诊断

定义每个快照的空间平均能量：

$$

\boxed{
E_m^{(\nu)}
=
\frac{
1
}{
2N_x
}
\left\|
\mathbf x_m^{(\nu)}
\right\|_2^2.
}

$$

对每条轨线记录：

$$

\overline E^{(\nu)},
\qquad
\operatorname{std}
\left(
E_m^{(\nu)}
\right),
\qquad
\min_m E_m^{(\nu)},
\qquad
\max_m E_m^{(\nu)}.

$$

并分别汇总 train、validation、test 三个 split 的能量均值与标准差。

此外，将每条记录轨线分为前半段与后半段，报告：

$$

\overline E_{\mathrm{early}}^{(\nu)},
\qquad
\overline E_{\mathrm{late}}^{(\nu)}.

$$

该诊断的作用是确认 burn-in 后轨线没有保留显著的初值过渡趋势；它是数据质量报告，不作为人为筛除个别轨线的依据。

---

# 10. 本任务明确不包含的内容

本任务不执行：

$$

\text{观测噪声注入},
\qquad
\text{部分观测},
\qquad
\text{控制输入},
\qquad
\text{延迟嵌入},

$$

$$

\text{空间 patch 构造},
\qquad
\text{循环移位数据增强},
\qquad
\text{局部核字典},
\qquad
\text{卷积或等变预处理},

$$

$$

\text{模型训练},
\qquad
\text{核参数筛选},
\qquad
\text{谱预估},
\qquad
\text{预测误差优化}.

$$

数据生成器只负责生成可复现、轨线独立、完整状态且数值可靠的 Lorenz–96 原始数据，以及由训练轨线唯一决定的标准化统计量。

---

# 11. 最终固定配置

$$

\boxed{
N_x=40,
\qquad
F_0=8,
\qquad
\Delta t_{\mathrm{int}}=0.005,
\qquad
\tau=0.05.
}

$$

$$

\boxed{
T_{\mathrm{burn}}=100,
\qquad
M_{\mathrm{traj}}=2048,
\qquad
M_{\mathrm{traj}}+1=2049.
}

$$

$$

\boxed{
|\mathcal R_{\mathrm{train}}|=24,
\qquad
|\mathcal R_{\mathrm{val}}|=8,
\qquad
|\mathcal R_{\mathrm{test}}|=8.
}

$$

$$

\boxed{
h_{\max}=64,
\qquad
\mathcal H_{\mathrm{roll}}
=
\{1,2,4,8,16,32,64\}.
}

$$

$$

\boxed{
\text{原始轨线使用 float64 保存；}
\quad
\text{标准化统计量仅由 train split 计算。}
}

$$
