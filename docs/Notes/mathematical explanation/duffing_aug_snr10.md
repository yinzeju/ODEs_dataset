当前任务沿用上传说明中的单自由度 Duffing 参数与随机相位 multisine 背景，但把“单条长轨线切段”改为“固定强迫系统下的多初值独立轨线”，并将噪声统一设为 $10\,\mathrm{dB}$。fileciteturn3file0

建议任务代号为：

$$

\boxed{
\texttt{duffing\_aug\_snr10}
}

$$

其中 `aug` 表示强迫相位自治增广，`snr10` 表示物理状态观测信噪比为 $10\,\mathrm{dB}$。

:::writing{variant="document" id="61427"}
# KDSM-MP 单自由度增广 Duffing 数据生成任务

## 0. 任务名称与代号

本任务定义面向 KDSM-MP 的单自由度受迫 Duffing 数据生成协议。

任务代号为

$$

\boxed{
\texttt{duffing\_aug\_snr10}.
}

$$

任务目标是生成严格配对的

$$

\boxed{
\mathcal D_{\mathrm{clean}}
\quad\text{与}\quad
\mathcal D_{\mathrm{noise10}}
}

$$

两个数据视图，使其能够用于：

1. KDSM-MP 在确定性增广动力系统上的 clean 多步预测；
2. $10\,\mathrm{dB}$ 测量噪声下的 noisy-input/clean-target 训练；
3. clean 与 noise 条件下的严格公平比较。

本任务只讨论单自由度 Duffing，不生成二自由度数据，也不将加速度作为 KDSM-MP 的输入或目标。

---

# 1. 单自由度 Duffing 系统

设物理状态为

$$

\mathbf x(t)
=
\begin{bmatrix}
x(t)\\
v(t)
\end{bmatrix},
\qquad
v(t)=\dot x(t).

$$

动力学方程为

$$

\boxed{
m\ddot x(t)
+
c\dot x(t)
+
kx(t)
+
k_cx(t)^3
=
u(t).
}

$$

参数固定为

$$

\boxed{
m=1,
\qquad
c=40,
\qquad
k=3\times10^3,
\qquad
k_c=5\times10^8.
}

$$

对应一阶状态方程为

$$

\boxed{
\begin{aligned}
\dot x(t)
&=
v(t),
\\
\dot v(t)
&=
\frac{1}{m}
\left[
u(t)-cv(t)-kx(t)-k_cx(t)^3
\right].
\end{aligned}
}

$$

所有轨线共享完全相同的物理参数。

---

# 2. 固定 realization 的稀疏 multisine 强迫

## 2.1 公共基频

设置公共基频

$$

\boxed{
f_0=0.5\,\mathrm{Hz},
\qquad
\omega_0=2\pi f_0.
}

$$

公共相位变量记为

$$

\vartheta(t)\in S^1.

$$

第 $\nu$ 条轨线上的相位演化为

$$

\boxed{
\vartheta^{(\nu)}(t)
=
\omega_0t+\vartheta_0^{(\nu)}.
}

$$

## 2.2 强迫频率集合

第一版数据集使用 $J=16$ 个正频率分量：

$$

\boxed{
\mathcal F
=
\{
5,\,
7.5,\,
9,\,
12,\,
16,\,
20,\,
25,\,
30,\,
35,\,
40,\,
50,\,
60,\,
65,\,
70,\,
75,\,
80
\}
\ \mathrm{Hz}.
}

$$

对每个 $f_j\in\mathcal F$，定义整数谐波指标

$$

k_j:=\frac{f_j}{f_0}\in\mathbb N.

$$

因此

$$

f_j=k_jf_0.

$$

## 2.3 固定 Fourier realization

在整个数据集生成开始前，只生成一次随机相位：

$$

\boxed{
\phi_j
\sim
\operatorname{Unif}(0,2\pi),
\qquad
j=1,\ldots,J.
}

$$

随机种子必须固定并保存。

定义未归一化强迫模板

$$

U_{\mathrm{raw}}(\vartheta)
=
\frac{1}{\sqrt J}
\sum_{j=1}^{J}
\cos(k_j\vartheta+\phi_j).

$$

所有轨线共享同一个函数

$$

U_{\mathrm{raw}}.

$$

强迫峰值设为

$$

A=20.

$$

定义全局归一化系数

$$

\kappa_u
:=
\frac{A}{
\displaystyle
\max_{\vartheta\in[0,2\pi)}
\left|
U_{\mathrm{raw}}(\vartheta)
\right|
}.

$$

最终强迫模板为

$$

\boxed{
U(\vartheta)
=
\kappa_uU_{\mathrm{raw}}(\vartheta).
}

$$

第 $\nu$ 条轨线的外部强迫为

$$

\boxed{
u^{(\nu)}(t)
=
U\left(
\vartheta^{(\nu)}(t)
\right).
}

$$

必须满足

$$

\max_{\vartheta\in[0,2\pi)}
|U(\vartheta)|
=
20.

$$

归一化只允许对固定强迫模板执行一次，不允许逐轨线重新归一化。

---

# 3. 强迫相位自治增广

定义相位状态

$$

\boxed{
c_{\mathrm f}^{(\nu)}(t)
:=
\cos\vartheta^{(\nu)}(t),
\qquad
s_{\mathrm f}^{(\nu)}(t)
:=
\sin\vartheta^{(\nu)}(t).
}

$$

它们满足

$$

\boxed{
\begin{aligned}
\dot c_{\mathrm f}^{(\nu)}
&=
-\omega_0s_{\mathrm f}^{(\nu)},
\\
\dot s_{\mathrm f}^{(\nu)}
&=
\omega_0c_{\mathrm f}^{(\nu)}.
\end{aligned}
}

$$

因此扩展状态为

$$

\boxed{
\mathbf x_{\mathrm{aug}}^{(\nu)}(t)
=
\begin{bmatrix}
x^{(\nu)}(t)\\
v^{(\nu)}(t)\\
c_{\mathrm f}^{(\nu)}(t)\\
s_{\mathrm f}^{(\nu)}(t)
\end{bmatrix}.
}

$$

扩展系统满足自治方程

$$

\boxed{
\begin{aligned}
\dot x^{(\nu)}
&=
v^{(\nu)},
\\
\dot v^{(\nu)}
&=
u^{(\nu)}
-cv^{(\nu)}
-kx^{(\nu)}
-k_c\left(x^{(\nu)}\right)^3,
\\
\dot c_{\mathrm f}^{(\nu)}
&=
-\omega_0s_{\mathrm f}^{(\nu)},
\\
\dot s_{\mathrm f}^{(\nu)}
&=
\omega_0c_{\mathrm f}^{(\nu)},
\end{aligned}
}

$$

其中

$$

u^{(\nu)}
=
U\left(
\operatorname{atan2}
\left(
s_{\mathrm f}^{(\nu)},
c_{\mathrm f}^{(\nu)}
\right)
\right).

$$

实际数值实现中，应直接根据绝对相位计算 multisine，不应通过最近邻索引从预先离散的强迫数组中读取 ODE 内部时间对应的强迫值。

---

# 4. 轨线数量与数据划分

生成相互独立的轨线集合

$$

\mathcal R
=
\mathcal R_{\mathrm{train}}
\sqcup
\mathcal R_{\mathrm{val}}
\sqcup
\mathcal R_{\mathrm{test}}.

$$

轨线数量设置为

$$

\boxed{
|\mathcal R_{\mathrm{train}}|=512,
\qquad
|\mathcal R_{\mathrm{val}}|=128,
\qquad
|\mathcal R_{\mathrm{test}}|=128.
}

$$

总轨线数为

$$

\boxed{
R=768.
}

$$

划分必须在数据生成时固定并保存。

训练集、验证集和测试集之间不得共享同一条积分轨线，也不得先生成长轨线再随机切片分配到不同 split。

---

# 5. 初始条件采样

对每条轨线 $\nu$，独立采样

$$

\boxed{
x_0^{(\nu)}
\sim
\operatorname{Unif}
\left(
-5\times10^{-3},
5\times10^{-3}
\right),
}

$$

$$

\boxed{
v_0^{(\nu)}
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

相位状态初值为

$$

c_{\mathrm f,0}^{(\nu)}
=
\cos\vartheta_0^{(\nu)},
\qquad
s_{\mathrm f,0}^{(\nu)}
=
\sin\vartheta_0^{(\nu)}.

$$

物理初值、初始相位和轨线随机种子必须保存。

不同轨线只改变

$$

x_0^{(\nu)},
\qquad
v_0^{(\nu)},
\qquad
\vartheta_0^{(\nu)}.

$$

所有轨线共享同一组

$$

m,c,k,k_c,
\qquad
\{f_j\}_{j=1}^{J},
\qquad
\{\phi_j\}_{j=1}^{J},
\qquad
\{a_j\}_{j=1}^{J}.

$$

---

# 6. 数值积分与采样

## 6.1 仿真网格

高分辨率仿真采样率设置为

$$

\boxed{
f_{\mathrm{sim}}
=
2000\,\mathrm{Hz}.
}

$$

因此

$$

\Delta t_{\mathrm{sim}}
=
\frac{1}{f_{\mathrm{sim}}}
=
0.0005\,\mathrm{s}.

$$

每条轨线积分时长为

$$

\boxed{
T_{\mathrm{traj}}=4\,\mathrm{s}.
}

$$

使用时间点

$$

t_n
=
n\Delta t_{\mathrm{sim}},
\qquad
n=0,\ldots,7999.

$$

每条高分辨率轨线包含

$$

8000

$$

个时间点，不重复保存 $t=4\,\mathrm{s}$ 端点。

## 6.2 暂态处理

主数据集不删除暂态：

$$

\boxed{
T_{\mathrm{drop}}=0.
}

$$

每条轨线均从随机初值开始完整保留。

## 6.3 数值求解器

可使用 `ode45` 或同等级自适应积分器，建议设置

```matlab
RelTol = 1e-10;
AbsTol = 1e-12;
```

ODE 内部阶段必须解析计算

$$

u^{(\nu)}(t)
=
U(\omega_0t+\vartheta_0^{(\nu)}).

$$

禁止使用最近邻时间索引读取离散强迫数组。

---

# 7. 模型时间网格

KDSM-MP 使用的模型采样率设置为

$$

\boxed{
f_{\mathrm{model}}
=
500\,\mathrm{Hz}.
}

$$

因此

$$

\Delta t
=
\frac{1}{f_{\mathrm{model}}}
=
0.002\,\mathrm{s}.

$$

高分辨率结果必须先经过抗混叠滤波，再按比例 $4:1$ 降采样。

推荐使用固定的 polyphase resampling，例如

```matlab
resample(signal, 1, 4)
```

并对所有轨线和所有状态通道使用相同的滤波器设置。

降采样后，每条轨线包含

$$

\boxed{
M_{\mathrm{traj}}=2000
}

$$

个时间点：

$$

t_m=m\Delta t,
\qquad
m=0,\ldots,1999.

$$

---

# 8. KDSM-MP 的输入与目标

## 8.1 Clean 输入

对第 $\nu$ 条轨线和第 $m$ 个时间点，定义 clean 输入

$$

\boxed{
\mathbf z_{m,\mathrm{clean}}^{(\nu)}
=
\begin{bmatrix}
x_m^{(\nu)}\\
v_m^{(\nu)}\\
u_m^{(\nu)}\\
c_{\mathrm f,m}^{(\nu)}\\
s_{\mathrm f,m}^{(\nu)}
\end{bmatrix}
\in\mathbb R^5.
}

$$

## 8.2 Clean 目标

KDSM-MP 的预测目标只取物理状态：

$$

\boxed{
\mathbf y_m^{(\nu)}
=
\begin{bmatrix}
x_m^{(\nu)}\\
v_m^{(\nu)}
\end{bmatrix}
\in\mathbb R^2.
}

$$

因此 clean 数据视图为

$$

\boxed{
\mathcal D_{\mathrm{clean}}
:
\quad
\mathbf z_{m,\mathrm{clean}}^{(\nu)}
\longmapsto
\mathbf y_m^{(\nu)}.
}

$$

## 8.3 不使用加速度

本任务不将

$$

\ddot x_m^{(\nu)}

$$

作为输入或目标。

原因是

$$

\ddot x_m^{(\nu)}
=
u_m^{(\nu)}
-cv_m^{(\nu)}
-kx_m^{(\nu)}
-k_c\left(x_m^{(\nu)}\right)^3

$$

已经由 $(x_m,v_m,u_m)$ 代数确定，不构成新的独立状态信息。

---

# 9. KDSM-MP horizon 适配

数据集应支持 horizon 集合

$$

\boxed{
\mathcal H_{\mathrm{roll}}
=
\{1,2,4,8,16,32,64,128\}.
}

$$

对应物理预测时间为

$$

\boxed{
\mathcal T_{\mathrm{roll}}
=
\{
0.002,\,
0.004,\,
0.008,\,
0.016,\,
0.032,\,
0.064,\,
0.128,\,
0.256
\}
\ \mathrm{s}.
}

$$

最大 horizon 为

$$

h_{\max}=128.

$$

每条长度为 $2000$ 的轨线可使用的 window anchor 满足

$$

s+h_{\max}\le1999.

$$

训练 window 不允许跨越轨线边界。

---

# 10. 10 dB 噪声模型

## 10.1 加噪对象

只对物理传感器通道 $x$ 和 $v$ 加噪：

$$

\boxed{
x_m^{\delta,(\nu)}
=
x_m^{(\nu)}
+
\eta_{x,m}^{(\nu)},
}

$$

$$

\boxed{
v_m^{\delta,(\nu)}
=
v_m^{(\nu)}
+
\eta_{v,m}^{(\nu)}.
}

$$

其中

$$

\eta_{x,m}^{(\nu)}
\sim
\mathcal N(0,\sigma_{\eta_x}^2),

$$

$$

\eta_{v,m}^{(\nu)}
\sim
\mathcal N(0,\sigma_{\eta_v}^2).

$$

噪声在不同时间、不同轨线和不同通道之间相互独立。

强迫和相位通道保持 clean：

$$

u_m^\delta=u_m,

$$

$$

c_{\mathrm f,m}^\delta
=
c_{\mathrm f,m},
\qquad
s_{\mathrm f,m}^\delta
=
s_{\mathrm f,m}.

$$

## 10.2 训练集物理功率

噪声方差只允许使用 clean training split 计算。

定义训练集位移功率

$$

\boxed{
P_x^{\mathrm{train}}
=
\frac{1}{
|\mathcal R_{\mathrm{train}}|M_{\mathrm{traj}}
}
\sum_{\nu\in\mathcal R_{\mathrm{train}}}
\sum_{m=0}^{M_{\mathrm{traj}}-1}
\left|
x_m^{(\nu)}
\right|^2.
}

$$

定义训练集速度功率

$$

\boxed{
P_v^{\mathrm{train}}
=
\frac{1}{
|\mathcal R_{\mathrm{train}}|M_{\mathrm{traj}}
}
\sum_{\nu\in\mathcal R_{\mathrm{train}}}
\sum_{m=0}^{M_{\mathrm{traj}}-1}
\left|
v_m^{(\nu)}
\right|^2.
}

$$

## 10.3 10 dB 噪声方差

本任务固定

$$

\boxed{
\mathrm{SNR}=10\,\mathrm{dB}.
}

$$

因此

$$

10^{-\mathrm{SNR}/10}
=
10^{-1}
=
0.1.

$$

噪声方差定义为

$$

\boxed{
\sigma_{\eta_x}^2
=
0.1P_x^{\mathrm{train}},
}

$$

$$

\boxed{
\sigma_{\eta_v}^2
=
0.1P_v^{\mathrm{train}}.
}

$$

对应标准差为

$$

\boxed{
\sigma_{\eta_x}
=
\sqrt{0.1P_x^{\mathrm{train}}},
\qquad
\sigma_{\eta_v}
=
\sqrt{0.1P_v^{\mathrm{train}}}.
}

$$

同一组噪声方差必须用于 train、validation 和 test，不允许根据 validation/test 信号重新估计噪声功率。

## 10.4 Noisy 输入与 clean 目标

定义 noisy 输入

$$

\boxed{
\mathbf z_{m,\mathrm{noise10}}^{(\nu)}
=
\begin{bmatrix}
x_m^{\delta,(\nu)}\\
v_m^{\delta,(\nu)}\\
u_m^{(\nu)}\\
c_{\mathrm f,m}^{(\nu)}\\
s_{\mathrm f,m}^{(\nu)}
\end{bmatrix}.
}

$$

监督目标仍使用 clean 物理状态：

$$

\boxed{
\mathbf y_{m,\mathrm{noise10}}^{(\nu)}
=
\mathbf y_m^{(\nu)}
=
\begin{bmatrix}
x_m^{(\nu)}\\
v_m^{(\nu)}
\end{bmatrix}.
}

$$

因此 noise 数据视图为

$$

\boxed{
\mathcal D_{\mathrm{noise10}}
:
\quad
\mathbf z_{m,\mathrm{noise10}}^{(\nu)}
\longmapsto
\mathbf y_m^{(\nu)}.
}

$$

即

$$

\boxed{
\text{noisy physical input}
+
\text{clean forcing state}
\longmapsto
\text{clean physical target}.
}

$$

噪声应在降采样到 $500\,\mathrm{Hz}$ 的模型网格后添加。

---

# 11. Clean 与 noise 配对要求

clean 和 noise10 数据必须共享完全相同的：

$$

\boxed{
\begin{aligned}
&\text{轨线编号},\\
&\text{train/validation/test 划分},\\
&\text{物理初值},\\
&\text{初始强迫相位},\\
&\text{clean 物理轨线},\\
&\text{强迫序列},\\
&\text{相位状态},\\
&\text{时间网格}.
\end{aligned}
}

$$

两者唯一差别是：

$$

\boxed{
(x_m,v_m)
\quad\longrightarrow\quad
(x_m^\delta,v_m^\delta)
}

$$

是否作为 learner input。

不得为 noise 数据重新生成 Duffing 轨线或重新生成 multisine phases。

---

# 12. 标准化协议

数据生成阶段必须保存物理单位下的 raw clean/noisy 数据，不允许直接覆盖为最大值归一化结果。

只使用 clean training split 计算输入标准化统计量：

$$

\boxed{
\boldsymbol{\mu}_{\mathbf z}
=
\mathbb E_{\mathrm{train}}
\left[
\mathbf z_{\mathrm{clean}}
\right],
}

$$

$$

\boxed{
\boldsymbol{\sigma}_{\mathbf z}
=
\operatorname{Std}_{\mathrm{train}}
\left[
\mathbf z_{\mathrm{clean}}
\right].
}

$$

目标标准化统计量为

$$

\boxed{
\boldsymbol{\mu}_{\mathbf y}
=
\mathbb E_{\mathrm{train}}
\left[
\mathbf y
\right],
}

$$

$$

\boxed{
\boldsymbol{\sigma}_{\mathbf y}
=
\operatorname{Std}_{\mathrm{train}}
\left[
\mathbf y
\right].
}

$$

Clean 输入标准化为

$$

\widetilde{\mathbf z}_{m,\mathrm{clean}}^{(\nu)}
=
\frac{
\mathbf z_{m,\mathrm{clean}}^{(\nu)}
-
\boldsymbol{\mu}_{\mathbf z}
}{
\boldsymbol{\sigma}_{\mathbf z}
+
\varepsilon_{\mathrm{std}}
}.

$$

Noisy 输入使用同一组 clean-training statistics：

$$

\boxed{
\widetilde{\mathbf z}_{m,\mathrm{noise10}}^{(\nu)}
=
\frac{
\mathbf z_{m,\mathrm{noise10}}^{(\nu)}
-
\boldsymbol{\mu}_{\mathbf z}
}{
\boldsymbol{\sigma}_{\mathbf z}
+
\varepsilon_{\mathrm{std}}
}.
}

$$

目标标准化为

$$

\widetilde{\mathbf y}_m^{(\nu)}
=
\frac{
\mathbf y_m^{(\nu)}
-
\boldsymbol{\mu}_{\mathbf y}
}{
\boldsymbol{\sigma}_{\mathbf y}
+
\varepsilon_{\mathrm{std}}
}.

$$

建议取

$$

\varepsilon_{\mathrm{std}}=10^{-8}.

$$

不得使用 validation/test 统计量，也不得针对 clean 与 noise10 分别计算两套标准化尺度。

---

# 13. 推荐保存结构

## 13.1 主数据数组

建议保存：

```text
state_clean          [768, 2000, 2]
state_noise10        [768, 2000, 2]
forcing              [768, 2000, 1]
forcing_phase        [768, 2000, 2]
initial_state        [768, 2]
initial_phase        [768]
split_id             [768]
time_model           [2000]
```

其中：

```text
state_clean[..., 0] = x
state_clean[..., 1] = v

state_noise10[..., 0] = x_noisy
state_noise10[..., 1] = v_noisy

forcing_phase[..., 0] = cos(theta)
forcing_phase[..., 1] = sin(theta)
```

## 13.2 系统与强迫元数据

保存：

```text
mass
damping
linear_stiffness
cubic_stiffness

forcing_amplitude
forcing_base_frequency
forcing_frequencies
forcing_harmonic_indices
forcing_fourier_phases
forcing_normalization_factor
forcing_seed

fs_sim
fs_model
trajectory_duration
trajectory_seed
```

## 13.3 噪声元数据

保存：

```text
snr_db = 10
noise_seed
training_power_x
training_power_v
noise_variance_x
noise_variance_v
noise_std_x
noise_std_v
```

## 13.4 标准化统计量

保存：

```text
input_mean_clean_train
input_std_clean_train
target_mean_clean_train
target_std_clean_train
```

---

# 14. 文件命名

建议生成以下文件：

```text
kdsm_data_0dot1_duffing_aug_clean.mat
kdsm_data_0dot1_duffing_aug_snr10.mat
kdsm_data_0dot1_duffing_aug_metadata.json
```

其中：

- `clean.mat` 保存 clean 物理状态、强迫和相位状态；
- `snr10.mat` 保存与 clean 严格对齐的 $10\,\mathrm{dB}$ noisy 状态；
- `metadata.json` 保存系统参数、随机种子、频率集合、split 和标准化统计量。

也可以将 clean 与 noise10 保存到同一个文件，但变量名必须清楚区分。

---

# 15. 数据质量检查

生成完成后必须执行以下检查。

## 15.1 相位圆约束

验证

$$

\boxed{
\left(c_{\mathrm f,m}^{(\nu)}\right)^2
+
\left(s_{\mathrm f,m}^{(\nu)}\right)^2
\approx1.
}

$$

建议最大误差小于

$$

10^{-10}.

$$

## 15.2 强迫一致性

验证保存的强迫满足

$$

\boxed{
u_m^{(\nu)}
=
U\left(
\vartheta_m^{(\nu)}
\right).
}

$$

## 15.3 Clean/noise 对齐

验证

$$

\boxed{
\mathbf z_{\mathrm{noise10}}
-
\mathbf z_{\mathrm{clean}}
}

$$

只在 $x,v$ 两个通道上非零。

## 15.4 经验 SNR

在训练集上计算

$$

\mathrm{SNR}_x^{\mathrm{emp}}
=
10\log_{10}
\frac{
\sum |x|^2
}{
\sum |x^\delta-x|^2
},

$$

$$

\mathrm{SNR}_v^{\mathrm{emp}}
=
10\log_{10}
\frac{
\sum |v|^2
}{
\sum |v^\delta-v|^2
}.

$$

要求二者均接近

$$

10\,\mathrm{dB}.

$$

建议容差为

$$

\pm0.2\,\mathrm{dB}.

$$

## 15.5 Split 隔离

必须确认：

$$

\mathcal R_{\mathrm{train}},
\qquad
\mathcal R_{\mathrm{val}},
\qquad
\mathcal R_{\mathrm{test}}

$$

两两不交，并且任何 KDSM-MP window 都不能跨轨线边界。

## 15.6 数值有效性

所有数组必须满足：

$$

\boxed{
\text{不存在 NaN、Inf 或积分失败轨线}.
}

$$

若某条轨线积分失败，应重新生成该轨线并记录失败原因，不能静默删除后改变 split 数量。

---

# 16. 最终任务输出接口

Clean 数据集对应

$$

\boxed{
\mathbf z_{m,\mathrm{clean}}^{(\nu)}
=
\begin{bmatrix}
x_m^{(\nu)}\\
v_m^{(\nu)}\\
u_m^{(\nu)}\\
\cos\vartheta_m^{(\nu)}\\
\sin\vartheta_m^{(\nu)}
\end{bmatrix},
\qquad
\mathbf y_m^{(\nu)}
=
\begin{bmatrix}
x_m^{(\nu)}\\
v_m^{(\nu)}
\end{bmatrix}.
}

$$

Noise10 数据集对应

$$

\boxed{
\mathbf z_{m,\mathrm{noise10}}^{(\nu)}
=
\begin{bmatrix}
x_m^{\delta,(\nu)}\\
v_m^{\delta,(\nu)}\\
u_m^{(\nu)}\\
\cos\vartheta_m^{(\nu)}\\
\sin\vartheta_m^{(\nu)}
\end{bmatrix},
\qquad
\mathbf y_m^{(\nu)}
=
\begin{bmatrix}
x_m^{(\nu)}\\
v_m^{(\nu)}
\end{bmatrix}.
}

$$

因此本任务的最终数据关系为

$$

\boxed{
\mathcal D_{\mathrm{clean}}
:
\quad
(x,v,u,\cos\vartheta,\sin\vartheta)
\longmapsto
(x,v),
}

$$

以及

$$

\boxed{
\mathcal D_{\mathrm{noise10}}
:
\quad
(x^\delta,v^\delta,u,\cos\vartheta,\sin\vartheta)
\longmapsto
(x,v).
}

$$

两套数据共同服务于同一个自治增广 KDSM-MP 模型，其差别只在物理输入通道是否包含 $10\,\mathrm{dB}$ 测量噪声。