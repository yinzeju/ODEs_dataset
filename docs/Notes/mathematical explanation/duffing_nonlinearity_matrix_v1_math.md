# Duffing 非线性二维检测数据生成数学说明

## 0. 数据集定位

本数据集记为

$$

\boxed{
\texttt{duffing\_nonlinearity\_matrix\_v1}.
}

$$

它是一个**通用动力系统学习测试数据集**，不绑定任何特定学习器或特定训练框架。数据集项目只负责生成

$$

\boxed{
\text{轨线张量}
\quad
\text{观测张量}
\quad
\text{目标张量}
\quad
\text{任务尺度 metadata}
}

$$

不负责训练模型，也不负责直接判断某个算法是否有效。

本数据集的核心目标是构造一组**数据充足、格式统一、非线性覆盖范围宽、可二维归因**的 Duffing 任务矩阵，用于回答：

$$

\boxed{
\text{在数据足够充分时，学习器的 rollout 指标是否随 Duffing 非线性强度增强而系统性恶化？}
}

$$

本数据集同时改变

$$

\boxed{
\beta
\quad\text{与}\quad
Q,
}

$$

其中 $\beta$ 是 Duffing 三次项系数，$Q$ 是初值幅值尺度。二者共同决定有效非线性强度。

---

# 1. 统一动力系统对象

所有 Duffing 对象统一采用二维物理状态

$$

\mathbf x_{\mathrm{phys}}
=
\begin{bmatrix}
q\\
p
\end{bmatrix}
\in\mathcal X_{\mathrm{phys}}\subseteq\mathbb R^2,

$$

其中 $q$ 是位移，$p=\dot q$ 是速度。

本数据集第一版不引入外部强迫，因此

$$

\gamma=0,
\qquad
\texttt{forcing\_type}=\texttt{force\_none}.

$$

于是物理状态就是完整自治状态：

$$

\mathcal X=\mathcal X_{\mathrm{phys}},
\qquad
d_x=2.

$$

Duffing 主方程统一写为

$$

\boxed{
\dot q=p,
}

$$

$$

\boxed{
\dot p=-\delta p-\alpha q-\beta q^3.
}

$$

固定线性参数为

$$

\boxed{
\alpha=1,
\qquad
\delta=0.08.
}

$$

因此每个 Duffing cell 的动力系统为

$$

\boxed{
\dot q=p,
\qquad
\dot p=-0.08p-q-\beta q^3.
}

$$

这里 $\beta\ge0$。当 $\beta=0$ 时，系统退化为连续线性阻尼振子；当 $\beta>0$ 时，系统为单井 hardening Duffing。

---

# 2. 有效非线性强度指标

仅改变 $\beta$ 并不足以刻画 Duffing 非线性强度。因为非线性恢复力与线性恢复力之比为

$$

\frac{|\beta q^3|}{|\alpha q|}
=
\frac{|\beta|q^2}{|\alpha|}.

$$

若初值主要落在 $|q|\lesssim Q$ 的区域，则典型非线性强度定义为

$$

\boxed{
\chi_{\mathrm{nl}}(\beta,Q)
:=
\frac{\beta Q^2}{\alpha}.
}

$$

由于本数据集固定 $\alpha=1$，所以

$$

\boxed{
\chi_{\mathrm{nl}}(\beta,Q)=\beta Q^2.
}

$$

因此本数据集的二维任务尺度为

$$

\boxed{
(\beta,Q)
\longmapsto
\chi_{\mathrm{nl}}=\beta Q^2.
}

$$

---

# 3. 保留的线性基础对象

为了排除算法实现、ODE 管线、split、rollout 公式和读出 refit 的底层错误，本数据集保留两个非 Duffing 基础线性对象。

## 3.1 L0：精确离散线性旋转对象

对象名为

$$

\boxed{
\texttt{dynsys\_nlmat\_\_L0\_discrete\_damped\_rotation}.
}

$$

直接生成离散系统：

$$

\mathbf x_{m+1}
=
\mathbf A_{r,\omega}\mathbf x_m,

$$

其中

$$

\mathbf A_{r,\omega}
=
r
\begin{bmatrix}
\cos\omega & -\sin\omega\\
\sin\omega & \cos\omega
\end{bmatrix}.

$$

推荐参数为

$$

\boxed{
r=0.995,
\qquad
\omega=0.08.
}

$$

该对象没有 ODE 积分误差，没有 Duffing 非线性，没有 forcing channel。若学习器在 L0 上失败，应优先怀疑算法实现或评估公式。

## 3.2 L1：连续线性阻尼振子对象

对象名为

$$

\boxed{
\texttt{dynsys\_nlmat\_\_L1\_continuous\_linear\_oscillator}.
}

$$

动力系统为

$$

\dot{\mathbf x}
=
\mathbf A_{\mathrm{lin}}\mathbf x,

$$

其中

$$

\mathbf A_{\mathrm{lin}}
=
\begin{bmatrix}
0 & 1\\
-\alpha & -\delta
\end{bmatrix}
=
\begin{bmatrix}
0 & 1\\
-1 & -0.08
\end{bmatrix}.

$$

解析连续谱为

$$

\gamma_{\pm}
=
-\frac{\delta}{2}
\pm
i\sqrt{\alpha-\frac{\delta^2}{4}},

$$

离散采样谱为

$$

\boxed{
\lambda_\pm^{\mathrm{true}}
=
\exp(\tau\gamma_\pm).
}

$$

metadata 中应保存

$$

\gamma_\pm,
\qquad
\lambda_\pm^{\mathrm{true}},
\qquad
\mathbf F_{\mathrm{lin}}^\tau:=\exp(\tau\mathbf A_{\mathrm{lin}}).

$$

---

# 4. Duffing 二维非线性检测矩阵

## 4.1 $\beta$ 等级

本数据集使用宽覆盖但不冗余的 $\beta$ 等级：

$$

\boxed{
\mathcal B
:=
\{
0,\,
0.05,\,
0.2,\,
0.5,\,
1.0,\,
2.0,\,
5.0,\,
10.0
\}.
}

$$

其中：

- $\beta=0$：Duffing 管线下的线性对象；
- $\beta=0.05$：近线性 / 弱非线性区；
- $\beta=0.2,0.5$：中等非线性区；
- $\beta=1.0,2.0$：显著 hardening 非线性区；
- $\beta=5.0,10.0$：强非线性 stress-test 区。

## 4.2 初值幅值等级

初值幅值等级缩减为

$$

\boxed{
\mathcal Q
:=
\{
0.25,\,
0.5,\,
1.0,\,
1.5,\,
2.0
\}.
}

$$

因此 Duffing 主矩阵共有

$$

|\mathcal B|\times|\mathcal Q|
=
8\times5
=
\boxed{40}

$$

个 cell。

对应有效非线性强度覆盖范围为

$$

\chi_{\mathrm{nl}}
=
\beta Q^2
\in[0,40].

$$

其中最强 cell 为

$$

\beta=10,
\qquad
Q=2,
\qquad
\chi_{\mathrm{nl}}=40.

$$

---

# 5. 二维 cell 记号

对每个

$$

(\beta_\ell,Q_k)\in\mathcal B\times\mathcal Q,

$$

生成对象

$$

\boxed{
\texttt{duffing\_nlmat\_\_D\_beta\_<beta>\_\_Q\_<Q>}.
}

$$

例如：

$$

\beta=0.2,\ Q=1.0
\quad\Rightarrow\quad
\texttt{duffing\_nlmat\_\_D\_beta\_0200\_\_Q\_100}.

$$

$$

\beta=10.0,\ Q=2.0
\quad\Rightarrow\quad
\texttt{duffing\_nlmat\_\_D\_beta\_10000\_\_Q\_200}.

$$

metadata 中必须保存原始浮点参数，不应只依赖 object name 反推。

---

# 6. 初值采样协议

每条轨线初值写为

$$

\mathbf x_0^{(r)}
=
\begin{bmatrix}
q_0^{(r)}\\
p_0^{(r)}
\end{bmatrix}.

$$

为了让 $Q$ 真正表示初值幅值尺度，采用近似能量圆盘采样：

$$

q_0=a\cos\theta,
\qquad
p_0=a\sin\theta,

$$

其中

$$

\theta\sim\operatorname{Unif}[0,2\pi).

$$

每个 $Q_k$ 使用壳层采样：

$$

\boxed{
a\in[0.75Q_k,Q_k].
}

$$

具体令

$$

u\sim\operatorname{Unif}[0,1],

$$

并取

$$

\boxed{
a
=
\sqrt{
(0.75Q_k)^2
+
u\bigl(Q_k^2-(0.75Q_k)^2\bigr)
}.
}

$$

该公式使初值在二维相平面环形区域内近似均匀分布。

为了比较不同 $\beta$ 的影响，必须使用共同初值库。对每个 $Q_k$，先生成固定初值集合

$$

\mathcal I_{Q_k}
=
\{
\mathbf x_0^{(r,Q_k)}
\}_{r=1}^R.

$$

然后对所有 $\beta_\ell\in\mathcal B$ 复用同一组初值：

$$

\boxed{
\mathbf x_0^{(r,\beta_\ell,Q_k)}
=
\mathbf x_0^{(r,Q_k)}.
}

$$

---

# 7. 数据规模协议

为了排除“数据不足导致误差缺陷”，每个 cell 使用较大的 trajectory-level 数据规模。

推荐每个 cell 使用

$$

\boxed{
R_{\mathrm{train}}=384,
\qquad
R_{\mathrm{val}}=64,
\qquad
R_{\mathrm{test}}=64.
}

$$

总轨线数为

$$

\boxed{
R=512.
}

$$

Duffing 主矩阵总轨线数为

$$

40\times512=20480.

$$

采样间隔取

$$

\boxed{
\tau=0.01.
}

$$

每条轨线保存

$$

M_{\mathrm{traj}}+1=1025

$$

个快照，即

$$

\boxed{
M_{\mathrm{traj}}=1024.
}

$$

总物理时间长度为

$$

T_{\mathrm{end}}=M_{\mathrm{traj}}\tau=10.24.

$$

训练集 one-step pair 数量为

$$

R_{\mathrm{train}}M_{\mathrm{traj}}
=
384\times1024
=
393216.

$$

因此每个 cell 都有约 $3.9\times10^5$ 个 one-step 训练快照对，足以显著降低样本不足导致的偶然误差。

---

# 8. 数值积分协议

对 Duffing 和 L1 连续系统，使用高精度自适应 ODE solver。推荐：

$$

\texttt{Vern9}
\quad\text{或}\quad
\texttt{DOP853}.

$$

容差设为

$$

\boxed{
\mathrm{reltol}=10^{-10},
\qquad
\mathrm{abstol}=10^{-12}.
}

$$

为了保证强非线性高频 cell 的采样稳定，设置最大内部步长

$$

\boxed{
\Delta t_{\max}
\le
\frac{\tau}{5}.
}

$$

在本数据集中 $\tau=0.01$，因此建议

$$

\Delta t_{\max}\le0.002.

$$

所有对象必须共享相同采样网格

$$

\mathbf t=(0,\tau,2\tau,\dots,M_{\mathrm{traj}}\tau)^\top.

$$

---

# 9. 统一输出数据格式

所有对象，包括 L0、L1 和 Duffing cell，必须输出完全统一的数据格式。

状态张量为

$$

\boxed{
\mathcal X_{\mathrm{phys}}
\in
\mathbb R^{R\times(M_{\mathrm{traj}}+1)\times2}.
}

$$

其元素定义为

$$

\mathcal X_{\mathrm{phys}}[r,m,:]
=
(q_m^{(r)},p_m^{(r)}).

$$

在推荐配置下，每个对象满足

$$

\boxed{
\mathcal X_{\mathrm{phys}}
\in
\mathbb R^{512\times1025\times2}.
}

$$

默认物理观测为

$$

\boxed{
\mathcal Z^{\mathrm{phys}}
=
\mathcal X_{\mathrm{phys}}.
}

$$

字段名为

$$

\boxed{
\texttt{obs\_phys}.
}

$$

为了统一接口，同时保存

$$

\boxed{
\texttt{obs\_full}.
}

$$

由于本数据集无强迫项，完整状态退化为物理状态，因此

$$

\boxed{
\texttt{obs\_full}
=
\texttt{obs\_phys}.
}

$$

目标观测统一为物理状态：

$$

\boxed{
\mathbf y(\mathbf z_m)=
(q_m,p_m)^\top.
}

$$

保存

$$

\boxed{
\mathcal Y^{\mathrm{phys}}
\in
\mathbb R^{R\times(M_{\mathrm{traj}}+1)\times2},
}

$$

并令

$$

\boxed{
\mathcal Y^{\mathrm{phys}}
=
\mathcal X_{\mathrm{phys}}.
}

$$

字段名为

$$

\boxed{
\texttt{target\_phys}.
}

$$

---

# 10. split 协议

所有 split 必须在 trajectory level 上完成。

定义轨线索引集合

$$

\mathcal R=\{1,\dots,R\}.

$$

划分为

$$

\mathcal R_{\mathrm{train}},
\qquad
\mathcal R_{\mathrm{val}},
\qquad
\mathcal R_{\mathrm{test}},

$$

满足

$$

|\mathcal R_{\mathrm{train}}|=384,
\qquad
|\mathcal R_{\mathrm{val}}|=64,
\qquad
|\mathcal R_{\mathrm{test}}|=64.

$$

要求

$$

\mathcal R_{\mathrm{train}}
\cap
\mathcal R_{\mathrm{val}}
=
\mathcal R_{\mathrm{train}}
\cap
\mathcal R_{\mathrm{test}}
=
\mathcal R_{\mathrm{val}}
\cap
\mathcal R_{\mathrm{test}}
=
\varnothing.

$$

split 必须在构造 one-step pairs 和 rollout windows 之前完成。所有 $(\beta,Q)$-cell 应使用相同的 split index。

---

# 11. one-step pairs 与 rollout windows

对每条轨线 $r$，构造 one-step pair：

$$

(\mathbf z_m^{(r)},\mathbf z_{m+1}^{(r)}),
\qquad
m=0,\dots,M_{\mathrm{traj}}-1.

$$

默认评估 horizon 设为

$$

\boxed{
\mathcal H_{\mathrm{eval}}
=
\{1,2,4,8,16,32,64\}.
}

$$

对每个 $h\in\mathcal H_{\mathrm{eval}}$，窗口起点 $s$ 满足

$$

s+h\le M_{\mathrm{traj}}.

$$

对应目标为

$$

\mathbf y_{s+h}^{(r)}.

$$

数据集本身不强制保存所有 rollout windows，但 metadata 必须声明这些窗口可由完整轨线无歧义构造。

---

# 12. metadata 字段规范

每个对象至少保存以下 metadata：

```text
dataset_id = duffing_nonlinearity_matrix_v1
object_id
system_family
parameter_alpha
parameter_delta
parameter_beta
parameter_gamma
amplitude_level_Q
nonlinearity_index_chi
forcing_type
state_dimension
observation_keys
target_keys
default_observation_key
default_target_key
tau
trajectory_length
num_snapshots
num_trajectories
split_train
split_val
split_test
split_role_per_trajectory
initial_condition_seed
solver_name
solver_tolerances
max_internal_step
noise_level
true_discrete_matrix
true_continuous_matrix
true_continuous_spectrum
true_discrete_spectrum
generation_status
```

对 Duffing cell 保存：

$$

\texttt{parameter\_alpha}=1,

$$

$$

\texttt{parameter\_delta}=0.08,

$$

$$

\texttt{parameter\_beta}=\beta_\ell,

$$

$$

\texttt{parameter\_gamma}=0,

$$

$$

\texttt{amplitude\_level\_Q}=Q_k,

$$

$$

\texttt{nonlinearity\_index\_chi}=\beta_\ell Q_k^2.

$$

---

# 13. 数据验收检查

生成完成后，不训练模型，但必须做以下验收。

## 13.1 形状检查

每个对象满足

$$

\mathcal X_{\mathrm{phys}},
\mathcal Z^{\mathrm{phys}},
\mathcal Y^{\mathrm{phys}}
\in
\mathbb R^{512\times1025\times2}.

$$

## 13.2 split 检查

确认 train / val / test 轨线数为

$$

384/64/64.

$$

确认 split 发生在 trajectory level，而不是 window level。

## 13.3 有限值检查

所有对象必须满足

$$

\max_{r,m}
\|\mathbf x_m^{(r)}\|_2
<
+\infty.

$$

若任何 cell 出现 NaN、Inf 或数值爆炸，则该 cell 标记为

$$

\texttt{generation\_status}
=
\texttt{failed\_numerical\_integration}.

$$

## 13.4 能量趋势检查

Duffing 能量定义为

$$

\boxed{
E(q,p)
=
\frac12p^2
+
\frac12\alpha q^2
+
\frac14\beta q^4.
}

$$

沿精确轨线有

$$

\frac{\mathrm d}{\mathrm dt}E(q(t),p(t))
=
-\delta p(t)^2
\le0.

$$

因此每条轨线应整体呈现能量下降趋势。数值验收不要求每个采样点严格下降，但应检查

$$

E_{M_{\mathrm{traj}}}^{(r)}
\le
E_0^{(r)}
+
\varepsilon_{\mathrm{num}}.

$$

建议

$$

\varepsilon_{\mathrm{num}}=10^{-8}

$$

或按相对误差设置。

## 13.5 共同初值检查

对固定 $Q_k$，所有 $\beta_\ell$ 的初值库必须一致：

$$

\mathbf x_{0}^{(r,\beta_\ell,Q_k)}
=
\mathbf x_{0}^{(r,\beta_{\ell'},Q_k)}.

$$

若不一致，则 $\beta$-方向比较失去严格意义。

---

# 14. 预期诊断解释

## 14.1 L0 失败

若 L0 失败，优先怀疑：

$$

\boxed{
\text{算法实现、复值输出头、Gram 计算、读出 refit、rollout 公式。}
}

$$

此时不应归因于 Duffing 非线性。

## 14.2 L0 健康但 L1 失败

若 L0 健康但 L1 失败，优先怀疑：

$$

\boxed{
\text{ODE 采样、连续系统数据管线、时间步长、归一化或 tensor adapter。}
}

$$

## 14.3 L1 健康但 $\beta=0$ Duffing cell 失败

若 L1 健康但 Duffing matrix 中 $\beta=0$ 的 cell 失败，说明虽然数学系统相同，但 Duffing 数据生成管线与 L1 管线存在不一致。

此时应检查：

$$

\boxed{
\text{object adapter}
\quad
\text{field names}
\quad
\text{split}
\quad
\text{normalization}
\quad
\text{metadata dispatch}.
}

$$

## 14.4 固定 $Q$，随 $\beta$ 变差

若固定 $Q_k$ 后，

$$

\beta\uparrow
\quad\Longrightarrow\quad
h16\uparrow,
\quad
\varepsilon_{\mathrm K}\uparrow,
\quad
D_{\mathrm{phase}}\uparrow,

$$

则说明模型边界主要来自三次非线性系数增强。

## 14.5 固定 $\beta$，随 $Q$ 变差

若固定 $\beta_\ell$ 后，

$$

Q\uparrow
\quad\Longrightarrow\quad
h16\uparrow,
\quad
D_{\mathrm{phase}}\uparrow,
\quad
\operatorname{cond}(\mathbf G_M^{(\varphi)})\uparrow,

$$

则说明模型主要受幅值诱导的频率漂移影响。

## 14.6 按 $\chi_{\mathrm{nl}}$ 归一后呈现单调性

若不同 $(\beta,Q)$ cell 的误差主要随

$$

\chi_{\mathrm{nl}}=\beta Q^2

$$

变化，而不强烈依赖 $\beta$ 和 $Q$ 的具体组合，则说明 $\chi_{\mathrm{nl}}$ 是合适的任务尺度指标。

若相同 $\chi_{\mathrm{nl}}$ 下，不同 $(\beta,Q)$ cell 的结果差异很大，则说明除非线性强度外，还存在其他影响因素，例如：

$$

\boxed{
\text{频率漂移}
\quad
\text{阻尼时间尺度}
\quad
\text{轨线覆盖区域}
\quad
\text{谱退化}
\quad
\text{经验测度差异}.
}

$$

---

# 15. 推荐对象总表

基础对象：

| object_id | 类型 | 作用 |
|---|---|---|
| `dynsys_nlmat__L0_discrete_damped_rotation` | 精确离散线性系统 | 排查算法闭环 |
| `dynsys_nlmat__L1_continuous_linear_oscillator` | 连续线性阻尼振子 | 排查 ODE 管线 |
| `duffing_nlmat__D_beta_0000__Q_<Q>` | Duffing 管线下的线性系统 | 对齐 Duffing 数据格式 |

Duffing matrix：

$$

\boxed{
\beta\in
\{
0,0.05,0.2,0.5,1,2,5,10
\},
}

$$

$$

\boxed{
Q\in
\{
0.25,0.5,1.0,1.5,2.0
\}.
}

$$

生成全部

$$

\boxed{
40
}

$$

个 Duffing cell。

---

# 16. 最终数据生成链条

本数据集应形成如下诊断阶梯：

$$

\boxed{
\texttt{L0}
\longrightarrow
\texttt{L1}
\longrightarrow
\texttt{Duffing } \beta=0
\longrightarrow
\texttt{Duffing }(\beta,Q)\text{ matrix}.
}

$$

其中 Duffing matrix 的二维任务尺度为

$$

\boxed{
(\beta,Q)
\longmapsto
\chi_{\mathrm{nl}}=\beta Q^2.
}

$$

最终希望得到的不是单个对象上的偶然 $h16$，而是整张误差曲面：

$$

\boxed{
(\beta,Q)
\longmapsto
\Bigl(
h16,\,
h32,\,
h64,\,
\varepsilon_{\mathrm K},\,
\varepsilon_{\mathrm{rec}}^{\mathrm{traj}},\,
D_{\mathrm{phase}},\,
D_{\mathrm{spec}},\,
\lambda_{\min}(\mathbf G_M^{(\varphi)}),\,
\operatorname{cond}(\mathbf G_M^{(\varphi)})
\Bigr).
}

$$

如果学习器是健康的，那么在统一数据格式、足够数据规模和固定训练配置下，至少应观察到：

$$

\boxed{
\chi_{\mathrm{nl}}\uparrow
\quad\Rightarrow\quad
\text{rollout / phase / spectral diagnostics 整体变差。}
}

$$

如果误差曲面仍然不随 $\chi_{\mathrm{nl}}$ 呈现可解释变化，则说明问题不再主要是数据不足，而应回到模型结构、联合训练反传耦合、谱核心健康 gate 或 rollout 评估口径本身。