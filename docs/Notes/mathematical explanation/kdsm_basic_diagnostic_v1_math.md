# KDSM 基础诊断数据生成数学指南

## 0. 数据集定位

本数据集记为

$$
\texttt{kdsm\_basic\_diagnostic\_v1}.
$$

它服务于 KDSM 的基础体检链条：

$$
\boxed{
\mathfrak T_q
\longmapsto
\mathfrak D_{\mathrm K}^{(\mathrm{diag})}(\mathfrak T_q)
\longmapsto
\mathfrak P_q
\longmapsto
\mathfrak I_{\mathrm K,q}^{(\mathrm{diag})}.
}
$$

数据集项目只负责生成轨线张量、观测张量、目标张量和 metadata，不负责训练 KDSM。此前 D0 Phase 1.1 已经证明，D0 不能只看点态重构，而应同时检查 Koopman 残差、decoded rollout、complex Gram、rank、phase、spectrum、spectral radius、decoder norm 和 rollout amplification。fileciteturn14file0

因此，本数据集的目标是构造一条从**精确线性系统**到**低非线性 Duffing**的任务阶梯：

$$
\boxed{
\text{离散线性旋转}
\to
\text{连续线性阻尼振子}
\to
\text{低非线性 Duffing 扫描}
\to
\text{当前 D0}.
}
$$

这条阶梯用于判断：

$$
\boxed{
\text{若线性系统失败，则优先怀疑算法或数据管线；}
}
$$

$$
\boxed{
\text{若线性系统健康而低非线性 Duffing 逐步变差，则说明问题来自任务尺度边界。}
}
$$

---

# 1. 统一数据对象

每个数据对象都生成轨线

$$
\mathbf x_0^{(r)},\mathbf x_1^{(r)},\dots,\mathbf x_M^{(r)},
\qquad
r=1,\dots,R,
$$

其中 $r$ 是轨线编号，$m$ 是时间快照编号。采样间隔为 $\tau>0$。

对所有基础对象，物理状态统一为

$$
\mathbf x_{\mathrm{phys}}
=
\begin{bmatrix}
q\\
p
\end{bmatrix}
\in\mathbb R^2.
$$

默认观测为

$$
\mathbf z_m=\mathbf x_{\mathrm{phys},m}
=
(q_m,p_m)^\top
\in\mathbb R^2.
$$

默认目标为

$$
\mathbf y_m=(q_m,p_m)^\top
\in\mathbb R^2.
$$

因此基础体检对象均满足

$$
d_z=2,\qquad d_y=2.
$$

这与 D0 的 `obs_aug_full -> target_phys` 设定一致；D0 无 forcing channel 时，`obs_aug_full` 实际退化为二维物理状态。fileciteturn14file0

---

# 2. 数据对象总表

建议生成以下对象。

| 对象名 | 数学类型 | 作用 |
|---|---|---|
| `kdsm_basic__L0_discrete_damped_rotation` | 精确离散线性系统 | 排查 KDSM 最小算法闭环是否有 bug |
| `kdsm_basic__L1_continuous_linear_oscillator` | 连续线性阻尼振子 | 排查 ODE 采样和 Duffing 管线是否有问题 |
| `kdsm_basic__BETA_0000_linear_duffing` | Duffing with $\beta=0$ | 与 D0 管线同形，但无非线性 |
| `kdsm_basic__BETA_0001_weak_duffing` | Duffing with $\beta=10^{-4}$ | 极弱非线性 |
| `kdsm_basic__BETA_0010_weak_duffing` | Duffing with $\beta=10^{-3}$ | 弱非线性 |
| `kdsm_basic__BETA_0050_weak_duffing` | Duffing with $\beta=5\times10^{-3}$ | 中弱非线性 |
| `kdsm_basic__BETA_0100_weak_duffing` | Duffing with $\beta=10^{-2}$ | 接近 D0 前级 |
| `kdsm_basic__D0_reference_near_linear_damped` | Duffing with $\beta=2\times10^{-2}$ | 对齐当前 D0 |

这里 `D0_reference_near_linear_damped` 应与当前 D0 的物理参数一致，即

$$
\alpha=1,\qquad
\beta=0.02,\qquad
\delta=0.08,\qquad
\gamma=0.
$$

当前 D0 在 Phase 1 数学说明中正是近线性阻尼 Duffing 主健康区对象，默认 $\mathbf z_m=(q_m,p_m)^\top$，$\mathbf y_m=(q_m,p_m)^\top$，且 $d_z=d_y=2$。fileciteturn14file1

---

# 3. 对象一：精确离散线性旋转

## 3.1 对象名称

$$
\boxed{
\texttt{kdsm\_basic\_\_L0\_discrete\_damped\_rotation}.
}
$$

## 3.2 动力系统

直接生成离散系统：

$$
\mathbf x_{m+1}
=
\mathbf A_{r,\omega}\mathbf x_m,
\qquad
\mathbf x_m=(q_m,p_m)^\top,
$$

其中

$$
\mathbf A_{r,\omega}
=
r
\begin{bmatrix}
\cos\omega & -\sin\omega\\
\sin\omega & \cos\omega
\end{bmatrix},
\qquad
0<r<1.
$$

推荐参数：

$$
r=0.995,\qquad
\omega=0.08.
$$

## 3.3 生成理由

这是最干净的 KDSM 算法体检对象。它没有 ODE 求解误差，没有 Duffing 非线性，也没有 forcing channel。

如果 KDSM 在该对象上不能取得低 Koopman 残差、低点态重构误差、健康 Gram 和低 decoded rollout，则说明问题大概率来自 KDSM 实现、复值输出头、Gram 计算、decoder refit 或 rollout 公式，而不是 Duffing 系统本身。

---

# 4. 对象二：连续线性阻尼振子

## 4.1 对象名称

$$
\boxed{
\texttt{kdsm\_basic\_\_L1\_continuous\_linear\_oscillator}.
}
$$

## 4.2 动力系统

取

$$
\dot q=p,
$$

$$
\dot p=-\delta p-\alpha q.
$$

矩阵形式为

$$
\dot{\mathbf x}
=
\mathbf A_{\mathrm{lin}}\mathbf x,
\qquad
\mathbf A_{\mathrm{lin}}
=
\begin{bmatrix}
0 & 1\\
-\alpha & -\delta
\end{bmatrix}.
$$

推荐参数与 D0 对齐：

$$
\alpha=1,\qquad
\delta=0.08.
$$

因此

$$
\dot q=p,
\qquad
\dot p=-0.08p-q.
$$

## 4.3 采样

用 ODE solver 生成连续轨线，再以固定间隔 $\tau$ 采样：

$$
\mathbf x_m=\mathbf x(m\tau).
$$

也可以使用解析离散流

$$
\mathbf x_{m+1}
=
\exp(\tau\mathbf A_{\mathrm{lin}})\mathbf x_m.
$$

若数据集项目允许，建议同时保存

$$
\mathbf F^\tau_{\mathrm{true}}
=
\exp(\tau\mathbf A_{\mathrm{lin}})
$$

到 metadata，用于后续解析谱对照。

## 4.4 解析谱

连续时间特征值为

$$
\gamma_{\pm}
=
-\frac{\delta}{2}
\pm
i\sqrt{\alpha-\frac{\delta^2}{4}}.
$$

离散时间谱点为

$$
\lambda_{\pm}^{\mathrm{true}}
=
\exp(\tau\gamma_{\pm}).
$$

metadata 中应保存

$$
\gamma_{\pm},\qquad
\lambda_{\pm}^{\mathrm{true}}.
$$

---

# 5. 对象三：低非线性 Duffing 扫描

## 5.1 对象名称

对每个 $\beta$ 生成一个对象：

$$
\boxed{
\texttt{kdsm\_basic\_\_BETA\_xxxx\_weak\_duffing}.
}
$$

建议集合为

$$
\beta\in
\left\{
0,\ 10^{-4},\ 10^{-3},\ 5\times10^{-3},\ 10^{-2},\ 2\times10^{-2}
\right\}.
$$

命名规则：

$$
\beta=0
\Rightarrow
\texttt{BETA\_0000\_linear\_duffing},
$$

$$
\beta=10^{-4}
\Rightarrow
\texttt{BETA\_0001\_weak\_duffing},
$$

$$
\beta=10^{-3}
\Rightarrow
\texttt{BETA\_0010\_weak\_duffing},
$$

$$
\beta=5\times10^{-3}
\Rightarrow
\texttt{BETA\_0050\_weak\_duffing},
$$

$$
\beta=10^{-2}
\Rightarrow
\texttt{BETA\_0100\_weak\_duffing},
$$

$$
\beta=2\times10^{-2}
\Rightarrow
\texttt{D0\_reference\_near\_linear\_damped}.
$$

## 5.2 动力系统

统一使用无强迫 Duffing：

$$
\dot q=p,
$$

$$
\dot p=-\delta p-\alpha q-\beta q^3.
$$

固定

$$
\alpha=1,\qquad
\delta=0.08,\qquad
\gamma=0.
$$

只扫描 $\beta$。

因此每个对象为

$$
\dot q=p,
$$

$$
\dot p=-0.08p-q-\beta q^3.
$$

## 5.3 生成理由

该扫描用于构造任务尺度阶梯：

$$
\beta=0
\to
10^{-4}
\to
10^{-3}
\to
5\times10^{-3}
\to
10^{-2}
\to
2\times10^{-2}.
$$

如果 $\beta=0$ 健康，而随 $\beta$ 增大逐渐出现 rollout pressure 或 Gram pressure，则可以判断当前 KDSM 的边界来自低非线性任务尺度，而不是基础实现错误。

D1 在既有报告中被定位为推进压力对象，而非 Phase 1 硬健康对象；因此这组弱非线性扫描应放在 D1 之前，用来细化从 D0 健康区到 D1 压力区的过渡。fileciteturn14file1

---

# 6. 初值分布

所有对象使用相同的初值采样协议，以便比较。

## 6.1 基础初值域

设

$$
\mathbf x_0=(q_0,p_0)^\top.
$$

推荐从椭圆或矩形区域采样：

$$
q_0\sim \operatorname{Unif}[-q_{\max},q_{\max}],
\qquad
p_0\sim \operatorname{Unif}[-p_{\max},p_{\max}].
$$

默认取

$$
q_{\max}=1.0,\qquad
p_{\max}=1.0.
$$

## 6.2 幅值分层

为了检查非线性强度，应额外保存 amplitude group：

$$
A_0:=\sqrt{q_0^2+p_0^2}.
$$

可分为三层：

$$
\mathcal A_{\mathrm{small}}:\ A_0\in[0.1,0.4],
$$

$$
\mathcal A_{\mathrm{mid}}:\ A_0\in(0.4,0.8],
$$

$$
\mathcal A_{\mathrm{large}}:\ A_0\in(0.8,1.2].
$$

低非线性 Duffing 的频率漂移会随幅值增强，因此 amplitude group 是后续解释 rollout pressure 的关键 metadata。

---

# 7. 采样协议

## 7.1 时间参数

推荐统一使用：

$$
\tau=0.05,
\qquad
M_{\mathrm{traj}}=256.
$$

每条轨线保存

$$
\mathbf x_0,\mathbf x_1,\dots,\mathbf x_{M_{\mathrm{traj}}}.
$$

如果希望与当前 KDSM horizon 对齐，则必须保证

$$
M_{\mathrm{traj}}\ge 16+1.
$$

当前 KDSM 报告使用 decoded rollout horizons

$$
H=\{1,2,4,8,16\},
$$

因此数据集应至少支持这些窗口。D0 Phase 1.1 也沿用了 $h\in\{1,2,4,8,16\}$ 作为 one-step 与 decoded rollout 诊断长度。fileciteturn14file0

## 7.2 轨线数量与 split

推荐沿用已有 KDSM 设定：

$$
R_{\mathrm{train}}=48,
\qquad
R_{\mathrm{val}}=8,
\qquad
R_{\mathrm{test}}=8.
$$

总轨线数：

$$
R=64.
$$

必须使用 trajectory-level split before windowing，即先划分完整轨线，再构造 one-step pairs 和 rollout windows。Phase 1 数学说明也明确要求先做轨线级切分，再构造 one-step pairs 和 rollout windows。fileciteturn13file10

---

# 8. 观测张量与目标张量

每个对象至少保存以下张量。

## 8.1 状态张量

保存

$$
\mathcal X
\in
\mathbb R^{R\times(M_{\mathrm{traj}}+1)\times 2},
$$

其中

$$
\mathcal X[r,m,:]
=
(q_m^{(r)},p_m^{(r)}).
$$

## 8.2 默认观测张量

保存

$$
\mathcal Z^{\mathrm{phys}}
\in
\mathbb R^{R\times(M_{\mathrm{traj}}+1)\times 2},
$$

并令

$$
\mathcal Z^{\mathrm{phys}}=\mathcal X.
$$

字段名建议：

$$
\texttt{obs\_phys}.
$$

## 8.3 KDSM 默认观测张量

为了和 Duffing 项目统一，保存

$$
\texttt{obs\_aug\_full}.
$$

对无强迫对象，

$$
\texttt{obs\_aug\_full}
=
\texttt{obs\_phys}.
$$

这与 D0 当前设定一致：由于没有 forcing channel，`obs_aug_full` 实际退化为二维物理状态。fileciteturn14file0

## 8.4 目标张量

保存

$$
\mathcal Y^{\mathrm{phys}}
\in
\mathbb R^{R\times(M_{\mathrm{traj}}+1)\times 2},
$$

并令

$$
\mathcal Y^{\mathrm{phys}}=\mathcal X.
$$

字段名建议：

$$
\texttt{target\_phys}.
$$

第一轮 KDSM 推荐使用 `target_phys`，用于检查谱核心是否承载物理 Duffing 状态。fileciteturn13file10

---

# 9. one-step pairs 与 rollout windows

数据集项目可以只保存完整轨线，由 KDSM 后处理构造窗口；但 metadata 中应明确默认构造方式。

## 9.1 one-step pairs

对每条轨线 $r$，构造

$$
(\mathbf z_m^{(r)},\mathbf z_{m+1}^{(r)}),
\qquad
m=0,\dots,M_{\mathrm{traj}}-1.
$$

矩阵形式为

$$
\mathbf Z_X
=
\begin{bmatrix}
\mathbf z_0 & \cdots & \mathbf z_{M_{\mathrm{eff}}-1}
\end{bmatrix},
\qquad
\mathbf Z_Y
=
\begin{bmatrix}
\mathbf z_1 & \cdots & \mathbf z_{M_{\mathrm{eff}}}
\end{bmatrix}.
$$

## 9.2 rollout windows

对

$$
H=\{1,2,4,8,16\},
$$

构造起点 $s$ 满足

$$
s+h\le M_{\mathrm{traj}}.
$$

保存或声明可构造目标：

$$
\mathbf y_{s+h}^{(r)}.
$$

注意：这里 $H$ 只用于外部诊断，不默认进入训练损失。Phase 1 数学说明也强调 decoded rollout 用于验证“对角推进 + 点态读出”是否形成可用预测器，而不改变模块基本训练对象。fileciteturn13file12

---

# 10. metadata 字段规范

每个数据对象至少保存：

```text
object_id
system_family
parameter_alpha
parameter_beta
parameter_delta
parameter_gamma
forcing_type
state_dimension
observation_keys
target_keys
tau
num_trajectories
trajectory_length
split_name
split_role_per_trajectory
initial_condition_seed
solver_name
solver_tolerances
noise_level
true_discrete_matrix
true_continuous_spectrum
true_discrete_spectrum
amplitude_group_per_trajectory
```

其中：

- `forcing_type = force_none`；
- `noise_level = 0`；
- `split_name = split_trajectory_I`；
- `observation_keys = [obs_phys, obs_aug_full]`；
- `target_keys = [target_phys]`。

对 L0 离散系统，保存 `true_discrete_matrix = A_{r,\omega}`。

对 L1 线性阻尼振子，保存

$$
\mathbf F^\tau_{\mathrm{true}}=\exp(\tau\mathbf A_{\mathrm{lin}}),
$$

以及

$$
\gamma_\pm,\qquad \lambda_\pm^{\mathrm{true}}.
$$

对非线性 Duffing，`true_discrete_matrix` 可为空，但必须保存 $\alpha,\beta,\delta,\gamma$。

---

# 11. 推荐生成流程

## Step 1：生成 L0 离散线性系统

生成对象：

$$
\texttt{kdsm\_basic\_\_L0\_discrete\_damped\_rotation}.
$$

直接迭代

$$
\mathbf x_{m+1}=\mathbf A_{r,\omega}\mathbf x_m.
$$

该对象应作为最低层 unit test 数据。

## Step 2：生成 L1 连续线性阻尼振子

生成对象：

$$
\texttt{kdsm\_basic\_\_L1\_continuous\_linear\_oscillator}.
$$

通过 ODE solver 或解析矩阵指数采样：

$$
\mathbf x_{m+1}=\exp(\tau\mathbf A_{\mathrm{lin}})\mathbf x_m.
$$

该对象用于检查 ODE 采样与数据管线。

## Step 3：生成 $\beta$-Duffing continuation

依次生成：

$$
\beta=0,\ 10^{-4},\ 10^{-3},\ 5\times10^{-3},\ 10^{-2},\ 2\times10^{-2}.
$$

系统为

$$
\dot q=p,
\qquad
\dot p=-0.08p-q-\beta q^3.
$$

该扫描用于定位非线性从何处开始触发 KDSM 的 Gram pressure 或 rollout pressure。

---

# 12. 数据验收检查

数据集项目生成后，不需要训练 KDSM，但应做基础数据验收。

## 12.1 形状检查

确认：

$$
\mathcal X,\mathcal Z^{\mathrm{phys}},\mathcal Y^{\mathrm{phys}}
\in
\mathbb R^{64\times257\times2}
$$

如果取 $M_{\mathrm{traj}}=256$。

## 12.2 split 检查

确认 train / val / test 轨线数为

$$
48/8/8.
$$

并确认没有 trajectory leakage。

## 12.3 有限值检查

所有轨线满足：

$$
\max_{r,m}\|\mathbf x_m^{(r)}\|_2<\infty.
$$

若出现 blow-up，该对象不能作为基础诊断数据。

## 12.4 单调能量趋势检查

对线性阻尼振子和弱 Duffing，无强迫且阻尼 $\delta>0$，能量应整体衰减。可记录

$$
E_m
=
\frac12p_m^2
+
\frac12\alpha q_m^2
+
\frac14\beta q_m^4.
$$

要求大多数轨线满足整体下降趋势。不要强制每一步严格下降，因为数值积分和采样可能产生微小波动。

---

# 13. 给 KDSM 的预期判读

生成完成后，KDSM 端应按如下逻辑使用。

## 13.1 L0 失败

若

$$
\texttt{L0\_discrete\_damped\_rotation}
$$

不健康，则优先怀疑 KDSM 算法实现或评估公式。

## 13.2 L0 健康但 L1 失败

若 L0 健康而 L1 失败，则优先检查 ODE solver、采样、数据归一化、split 或 tensor adapter。

## 13.3 L1 健康但 $\beta$ 扫描逐步变差

若

$$
\beta=0
$$

健康，而随 $\beta$ 增大逐步出现

$$
\varepsilon_{\mathrm{roll}}^{(16)}\uparrow,
\qquad
\operatorname{cond}(\mathbf G_M^{(\varphi)})\uparrow,
\qquad
\lambda_{\min}(\mathbf G_M^{(\varphi)})\downarrow,
$$

则说明当前 KDSM 的边界主要来自非线性任务尺度。

## 13.4 $\beta=0.02$ 对齐 D0

若

$$
\beta=0.02
$$

结果接近当前 D0，则说明新数据集与既有 `kdsm_duffing_diagnostic_v1` 的 D0 设定一致。

---

# 14. 最简结论

这份基础诊断数据集应当生成一条清晰阶梯：

$$
\boxed{
\texttt{L0}
\to
\texttt{L1}
\to
\texttt{BETA\_0000}
\to
\texttt{BETA\_0001}
\to
\texttt{BETA\_0010}
\to
\texttt{BETA\_0050}
\to
\texttt{BETA\_0100}
\to
\texttt{D0\_reference}.
}
$$

它的核心价值是把当前 D0 边界误差拆成三类可能来源：

$$
\boxed{
\text{算法实现问题}
\quad
\text{数据管线问题}
\quad
\text{非线性任务尺度问题}.
}
$$

如果这条数据阶梯生成正确，KDSM 后续就可以用同一套诊断向量逐级判定：当前问题到底是 bug、管线错位，还是对角谱核心在 Duffing 非线性上的自然能力边界。