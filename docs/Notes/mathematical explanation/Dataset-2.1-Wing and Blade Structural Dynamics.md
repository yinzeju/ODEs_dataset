---
title: Dataset-2.1：NACA 机翼与复合材料风机叶片的高维非线性自由振动资源
aliases:
  - Dataset-2.1
  - Dataset-2.1-Wing and Blade Structural Dynamics
  - NACA Wing and Composite Blade Dataset
  - FE-NACA-WING
  - FE-COMPOSITE-BLADE
status: draft
type: mathematical-protocol
parent:
  - "[[Dataset-2-Nonlinear Structural Dynamics]]"
related:
  - "[[Notation-Core Convention]]"
  - "[[Notation-Standard Convention]]"
  - "[[ODE-2.非线性机械系统的平衡点线性化与阻尼谱结构]]"
  - "[[ODE-12.有限元半离散、非线性时间积分与机械动力系统的统一视角]]"
  - "[[SKDM-K1.1-Dynamics Simulation Surrogates and Control-Conditioned Online Prediction]]"
  - "[[SKDM-Exp0-List of Evaluation Indicators]]"
updated: 2026-10-11
---

# Dataset-2.1：NACA 机翼与复合材料风机叶片的高维非线性自由振动资源
## 原始工程结构、几何非线性有限元、无重力无旋转工况、完整状态与多初值数据合同

> [!abstract] 初版唯一工况
> 本笔记选用两个具有公开来源的结构有限元模型：**SSMTool / YetAnotherFEcode 的 NACA 机翼**与 **COMSOL Application ID 68321 的复合材料风机叶片**。初版对两者统一关闭**重力、旋转、气动载荷及其他持续外部动态激励**，保持各自原有的根部固支、结构几何、材料和非线性有限元力学；采用固定小阻尼、多初态初始化与完整非线性时间积分，生成自治自由衰减（ring-down）轨线。
>
> 目标是建立**合格粗网格上的完整有限元动力学数据**，而非先以 POD、模态截断或 SSM 约化后再生成真值。初始资源计划为每模型约 $d_x=20\,000$ 状态、2048 个输出时间间隔、96/24/24 条 Train/Validation/Test 母轨线；所有实际网格自由度、瞬态设置、物理幅值和数值误差均须经过独立资格验证，未验证的目标值不能标记为已实现。
>
> NACA 模型重用已有开源有限元装配与几何非线性内力，只重新设计网格及多初值全阶瞬态。COMSOL 模型保留原教程的复合壳和层合材料，但**另设一个不含 Gravity 与 Rotating Frame 的非线性 Time Dependent 工况**；原教程的重力／离心静力及预应力模态结果不是本数据集的真值轨线。

## 0. 身份、来源与适用范围

### 0.1 两个数据对象

| 代号 | 基础来源 | 初版物理对象 | 主体改造 | 资料状态 |
|---|---|---|---|---|
| `FE-NACA-WING` | SSMTool 的 NACA wing；YetAnotherFEcode 三角壳模型 | 无重力、非旋转、固支、几何非线性机翼自由衰减 | 保留几何拓扑、重网格、重求谱、增加全阶多初值时间积分 | 原始源码与公开教程已核对；新网格与瞬态待本地认证 |
| `FE-COMPOSITE-BLADE` | COMSOL 6.3，Application 68321 | 无重力、零转速、固支、几何非线性层合壳叶片自由衰减 | 关闭原重力／旋转节点，增加无载模态、初态构造和全阶瞬态 | 官方材料、几何与建模教程已核对；实际 MPH DOF 与瞬态待本地认证 |

Dataset-2.1 仍是一份**候选模型与数据资源协议**。它读取 [[Dataset-2-Nonlinear Structural Dynamics]] 的完整状态、自由衰减及母轨线隔离原则，但不修改 Dataset-2 已冻结对象，不预先宣称已生成新数据集。两种模型分别训练和评价，不拼接为同一个固定参数动力系统。

### 0.2 来源事实、项目设定与本地认证必须分开

- **来源核对**：来自固定提交的 NACA 源码、SSMTool 教程、COMSOL 6.3 官方模型文档的几何、材料、单元、节点及分析设置。
- **初版设定**：本笔记针对无重力、非旋转、无动态强迫和多初值学习新规定的阻尼、初始化、输出、数据规模与验收路线；不视为原文已经完成的工作。
- **待本地认证**：重网格后的独立自由度、频率、初态有效域、时间积分器误差、COMSOL 约束变量、耗时和存储量。

### 0.3 初版明确关闭的作用

令 $\mathbf f_{\mathrm{ext}}$ 表示外部广义机械载荷；本版正式自由振动的共同合同为

$$
\boxed{
\mathbf f_{\mathrm{ext}}(t)\equiv\mathbf0,\qquad
\mathbf f_g\equiv\mathbf0,\qquad
\boldsymbol\Omega_{\mathrm{rot}}=\mathbf0,\qquad t\ge0.
}
\tag{0.1}
$$

这里**无重力**意味着不装配重力体力，也不在静止参考点保留重力预变形；**无旋转**意味着没有离心、陀螺、旋转坐标框架及其附加惯性项；**无动态强迫**意味着释放后的轨线上没有谐波、气动、点力或其他持续驱动。材料密度及质量矩阵**仍然保留**，不能因为关闭重力而删除惯性。数值积分中的初始条件由 $t=0$ 之前的独立预处理构造，预加载用的临时非重力载荷不进入正式轨线。

本版研究的是两个固定结构构型的自治非线性机械系统，不代表机翼的完整飞行载荷响应，也不代表风机实际旋转运行时的气动弹性响应。

# 第一部分：共同数学模型与全阶状态

## 1. 有限元半离散与参考平衡点

### 1.1 一般非线性机械关系

在约束处理前，两个有限元壳模型均可能包含独立动力学坐标与约束／辅助代数变量。采用 [[ODE-12.有限元半离散、非线性时间积分与机械动力系统的统一视角]] 的一般入口，设经过合法消元的独立机械坐标为

$$
\mathbf q(t)\in\mathbb R^{n_q},\qquad
\mathbf v(t):=\dot{\mathbf q}(t),\qquad
\mathbf a(t):=\ddot{\mathbf q}(t),
\tag{1.1}
$$

则半离散系统写成

$$
\boxed{
\mathbf g_h(\mathbf q,\mathbf v,\mathbf a)=\mathbf0.
}
\tag{1.2}
$$

下标 $h$ 仅表示固定有限元空间离散，不表示时间步长。式 (1.2) 允许构型依赖惯性、几何非线性、壳转动约束消元带来的项及一般速度依赖；它是**空间离散后、时间仍连续**的模型，不等于已经做过线性化。

在本版无载、无初始预应力的参考工况，拟采用应力自由构型 $\mathbf q_\star=\mathbf0$，但须对每份重网格后的实际模型检验

$$
\boxed{\mathbf g_h(\mathbf q_\star,\mathbf0,\mathbf0)=\mathbf0.}
\tag{1.3}
$$

若式 (1.3) 不满足，应先排查未关闭的载荷、初始化应力、层合材料方向、约束或残余数值作用，不能直接把未平衡的构型标记为零平衡点。

### 1.2 常质量、黏性阻尼的具体情形

当完成独立约束消元，且模型确实具有固定质量矩阵、固定线性黏性阻尼与仅依赖位移的内力时，式 (1.2) 专门化为

$$
\boxed{
\mathbf M\ddot{\mathbf q}
+\mathbf C\dot{\mathbf q}
+\mathbf f_{\mathrm{int}}(\mathbf q)=\mathbf0,
\qquad
\mathbf M=\mathbf M^\top\succ0.
}
\tag{1.4}
$$

NACA 的公开矩阵装配与内力回调明确支持式 (1.4) 的**拟定初版实现**。COMSOL 的壳法线变量具有附加几何约束；若其消元后存在构型依赖惯性、速度耦合或其他剩余项，就必须继续使用 (1.2)，不能静默把它替换成常质量的式 (1.4)。

对于 (1.4)，若弹性内力来源于可微势能 $\mathcal E_{\mathrm{el},h}(\mathbf q)$，则

$$
\mathbf f_{\mathrm{int}}(\mathbf q)
=\nabla_{\mathbf q}\mathcal E_{\mathrm{el},h}(\mathbf q),\qquad
\mathbf K_{\mathrm t}(\mathbf q)
:=D_{\mathbf q}\mathbf f_{\mathrm{int}}(\mathbf q).
\tag{1.5}
$$

式 (1.5) 是**保守弹性实现的条件表达**，不应由某个材料界面的名称自动推定。

### 1.3 参考点切向机械谱

根据 [[ODE-2.非线性机械系统的平衡点线性化与阻尼谱结构]]，在同一静止平衡点定义

$$
\boxed{
\begin{aligned}
\mathbf M_\star&:=D_{\mathbf a}\mathbf g_h(\mathbf q_\star,\mathbf0,\mathbf0),\\
\mathbf C_\star&:=D_{\mathbf v}\mathbf g_h(\mathbf q_\star,\mathbf0,\mathbf0),\\
\mathbf K_\star&:=D_{\mathbf q}\mathbf g_h(\mathbf q_\star,\mathbf0,\mathbf0).
\end{aligned}}
\tag{1.6}
$$

当 $\mathbf M_\star$ 可逆且约束状态已处理，线性切向自由振动满足

$$
\mathbf M_\star\,\delta\ddot{\mathbf q}
+\mathbf C_\star\,\delta\dot{\mathbf q}
+\mathbf K_\star\,\delta\mathbf q=\mathbf0.
\tag{1.7}
$$

无阻尼基准模态由

$$
\boxed{
\mathbf K_\star\boldsymbol\phi_j
=\omega_j^2\mathbf M_\star\boldsymbol\phi_j,
\qquad \omega_j>0
}
\tag{1.8}
$$

给出。只有在矩阵满足适当对称正定条件时，才采用经典质量正交模态；实际输出模态须登记归一化及符号。连续时间阻尼谱率 $\gamma_j$ 可通过相应二次特征值问题获得，固定采样间隔 $\tau$ 下的离散乘子是 $\lambda_j=e^{\gamma_j\tau}$。**重网格、改变阻尼或改变 COMSOL 工况之后，原教程谱值都只是来源参考，不能用作新数据集的真实谱标签。**

### 1.4 状态闭合与输出定义

若运动学与约束消元证明当前独立位置、速度足以确定未来，则取

$$
\boxed{
\mathbf x:=\operatorname{col}(\mathbf q,\mathbf v)
\in\mathcal X\subseteq\mathbb R^{d_x},
\qquad d_x=2n_q.
}
\tag{1.9}
$$

如果模型保留独立材料内变量或无法消除的动力学辅助状态，应明确扩展 $\mathbf x$；若 COMSOL 保留代数约束，则必须报告 DAE 身份与一致初始化，不能直接把求解器代数未知量数加倍作为 $d_x$。

正式标签为相同时间网格上的**完整闭合演化状态**：

$$
\mathbf x_m^{(\nu)}\approx
\mathbf F^{m\tau}(\mathbf x_0^{(\nu)}),
\qquad m=0,\ldots,2048.
\tag{1.10}
$$

翼尖位移、单点应力、动能、模态坐标等仅为附属物理观测与诊断，不取代正式状态。本文所有完整状态以机械独立自由度为准，而非以表面采样点或插值后的观测维数为准。

# 第二部分：`FE-NACA-WING` 模型

## 2. 公开几何、材料与有限元离散

### 2.1 原始模型身份

模型来自 SSMTool 的非侵入式 NACA wing 教程，有限元部分基于 YetAnotherFEcode，公开示例在固定提交 `de6cbc71427d23827feb9efd313cb63a1fc52ff8` 下可追溯。原始几何与网格装配分别由 `WING.geo`、`Wing.msh` 和 `build_model_nonIntrusive.m` 提供，主例 `NACAWing_NonIntrusive.m` 组织谱分析与周期受迫 FRC。原论文与开源教程并没有提供本笔记计划的 144 条全阶自由衰减母轨线。[^N1][^N2][^N3]

| 项目 | 固定源码或公开教程中的取值 | 初版资源处理 |
|---|---|---|
| 三角壳单元数量 | 49,968 | 重网格后重新统计，不沿用原规模 |
| 原约束后机械 DOF | $n_q=133\,920$ | 目标降到约 $10\,000$，以物理收敛为准 |
| 原一阶状态维数 | $d_x=267\,840$ | 目标约 $20\,000$ |
| 单元 | `TriShellElement` | 保留相同离散家族并记录实际版本 |
| 材料对象 | `KirchoffMaterial` | 沿用源码对象，不擅自等同于 COMSOL Shell 公式 |
| 杨氏模量 | $E=70\times10^9\,\mathrm{Pa}$ | 保留 |
| 泊松比 | $\nu_{\mathrm{mat}}=0.33$ | 保留 |
| 密度 | $\rho=2700\,\mathrm{kg/m^3}$ | 保留惯性质量，不装配重力 |
| 壳厚度 | $t_{\mathrm{shell}}=1.5\times10^{-3}\,\mathrm m$ | 保留 |
| 源码材料阻尼参数 | `kappa=1e5`（赋给 `DAMPING_MODULUS`） | 只登记源码值；实际装配阻尼另见 §4 |
| 固支 | `constrainedNodes` 的 1–6 分量设为零 | 保留翼根固支与节点映射 |
| 重力和体力 | `uniform_body_force` 调用处于注释状态 | 初版继续不启用 |
| 原外载 | 两个翼尖节点方向的力向量，用于谐波受迫例 | 自由衰减阶段完全不用该外载 |

**源码名称中 `KirchoffMaterial`、`TriShellElement` 的具体实现是有限元代码的约束；不能仅凭命名断言它与另一软件的 Kirchhoff–Love 或 Mindlin–Reissner 壳完全等价。** 原教程的 `Faces: [49968×3]` 是三角形连通数据，不可将 `Vertices: [149904×3]` 的重复顶点记录误认为 149,904 个独立网格节点。

### 2.2 几何与网格生成参数

原 `WING.geo` 导入 `AIRFOIL.geo`，并给出：[^N3]

| `.geo` 对象 | 原设置 | 数学／几何意义 | 初版处理 |
|---|---|---|---|
| `SF` | $0.7$ | 源几何的缩放参数 | 保留，具体翼型须以几何文件为准 |
| `L` | $5\,\mathrm m$ | 展向长度参数 | 保留 |
| `n` | 25 | 源码标注的 airfoil ribs 数 | **保留**；减少它会改变结构而非仅变粗网格 |
| `l` | $L/(n-1)$ | 相邻截面间距 | 随 `L,n` 一起固定 |
| `La` | 6 | 每个展向挤出段的网格层数 | 优先作为网格粗化变量 |
| `a1`,`a2` | 由导入几何定义，当前未核定其初始数值 | `Transfinite Line` 的分段节点数 | 读取实际 `AIRFOIL.geo` 后分区粗化 |
| `DMN1/DMN2/DMN3` | 1/2/3 | 曲面蒙皮、纵向加劲面、肋／加劲面分组 | 保留 Physical Surface 语义 |
| `EBC` | 101 | 固定边界分组 | 保留 |
| `NBC1` | 201 | 原示例外力区域标识 | 初版仅作为来源几何标识，不施加动态载荷 |

`WING.geo` 中 `Layers{La}`、`Transfinite Line` 和 `Transfinite Surface` 明确参与网格生成。因此**只调整 Gmsh 的全局单元尺寸未必能有效控制最终 DOF**。本版建议在保持 `L`、`n`、蒙皮／肋／纵向加劲拓扑和边界编号的条件下，以 `La=3`、`La=2` 为两个待试的粗化候选，并同时依据实际 `AIRFOIL.geo` 中 `a1,a2` 的定义减少局部离散。数值 $3,2$ 是项目提出的**试验候选**，不是已验证可达到 20k 状态的配置；其余几何线与连接处必须检查最小分辨率。

目前没有从所核对的文件确认一个具体的 NACA 四位数翼型编号。**几何身份是冻结的几何文件、曲线与网格，而不是自行猜测某个 NACA 型号。**

### 2.3 根部、连接与网格降规模的边界

原几何在展向起点形成固支根部，`build_model_nonIntrusive.m` 对 `constrainedNodes` 的六个节点机械分量施加固定边界。正式重网格后须同时保持：

1. 根部固支的物理位置与六分量处理约定；
2. 蒙皮、内部纵向加劲结构及各肋的连接／共享边；
3. 实际壳厚、材料、密度与单位体系；
4. 原几何分组到新节点、单元和约束 DOF 的确定映射。

原源码使用 `outnode=[337,349]`、`outdof=outnode*6-4` 选取两个物理翼尖方向的外力／观测位置。**重网格后这些整数不再具有可迁移的物理身份**；若保留翼尖观测，应按坐标和固定几何区域重新定位。不得为了满足 $d_x\approx20\,000$ 删除实体肋、复合节点方向或直接截断低阶模态。

## 3. NACA 的无外力非线性自由振动方程

### 3.1 与公开内力函数一致的模型

固定粗化网格装配的 $\mathbf M,\mathbf K_\star$，记 `internalForce` 对应完整几何非线性内力 $\mathbf f_{\mathrm{int}}(\mathbf q)$。公开源码定义

$$
\boxed{
\mathbf f_{\mathrm{nl}}(\mathbf q)
:=\mathbf f_{\mathrm{int}}(\mathbf q)
-\mathbf K_\star\mathbf q.
}
\tag{3.1}
$$

则初版全阶自由振动严格按同一源码内力评估实现

$$
\boxed{
\mathbf M\ddot{\mathbf q}
+\mathbf C\dot{\mathbf q}
+\mathbf K_\star\mathbf q
+\mathbf f_{\mathrm{nl}}(\mathbf q)=\mathbf0.
}
\tag{3.2}
$$

式 (3.2) 与 (1.4) 在采用 (3.1) 时是**代数恒等**；并非把非线性力截断成预设二次／三次多项式。模型通过 `internalForce` 保留该壳单元实现提供的完整非线性内力。若加载、几何或初态改变，必须重新核对 $\mathbf f_{\mathrm{int}}(\mathbf0)=\mathbf0$、$D\mathbf f_{\mathrm{int}}(\mathbf0)=\mathbf K_\star$ 与根部约束相容性。

### 3.2 NACA 阻尼和参考频率

公开装配使用 Rayleigh 阻尼，实际生效的阻尼矩阵是

$$
\boxed{
\mathbf C=a_M\mathbf M+a_K\mathbf K_\star,
\qquad
\zeta_j=\frac12\left(\frac{a_M}{\omega_j}+a_K\omega_j\right).
}
\tag{3.3}
$$

源码解算式右端的 `0.004` 等于 $2\zeta_j$，因此其前两个目标模态的阻尼比是 $\zeta_1=\zeta_2=0.002$，即 $0.2\%$；教程亦输出此值。**`DAMPING_MODULUS` 参数虽然传入材料对象，但 `MyAssembly.damping_matrix()` 在核对版本中被注释，不能把两者叠加说成已装配的物理阻尼。** 本版按源码实际生效的 Rayleigh 形式建模。[^N1][^N2]

重网格后取新网格的 $\omega_1,\omega_2>0$，并令

$$
\boxed{
\zeta_1=\zeta_2=\zeta_\star^{\mathrm N}=0.002.
}
\tag{3.4}
$$

当 $\omega_1\ne\omega_2$，解得

$$
\boxed{
 a_M=\frac{2\zeta_\star^{\mathrm N}\omega_1\omega_2}{\omega_1+\omega_2},
\qquad
 a_K=\frac{2\zeta_\star^{\mathrm N}}{\omega_1+\omega_2}.
}
\tag{3.5}
$$

这样保持**目标阻尼比**，而不是错误地把旧网格的 $a_M,a_K$ 当成新网格的固定物理参数。Rayleigh 阻尼会对高阶频率产生不同强度的衰减，须在选定频带上审计 $\zeta_j$。

原公开教程的第一对阻尼谱率约为 $-0.0587\pm29.3428\,\mathrm i\;\mathrm{s}^{-1}$，仅用作新网格频率量级与趋势的来源参考，不能直接继承为新模型谱率。[^N1]

### 3.3 NACA 初始化与数值真值

对正式初态 $\mathbf x_0^{(\nu)}=\operatorname{col}(\mathbf q_0^{(\nu)},\mathbf0)$，每次独立积分式 (3.2)。初态优先取基于本次**新网格无重力模态**的单模态或少量模态组合，辅以非重力静态形变释放，详见 §7。全阶参考积分建议采用带非线性迭代的隐式二阶结构动力学格式，例如 Newmark $\beta_{\mathrm N}=1/4,\gamma_{\mathrm N}=1/2$ 作为待资格验证的基线；时间积分仍使用全部自由度而不在低阶模态空间上推进。其物理阻尼与时间离散产生的数值耗散须分别审计。实际积分、稀疏求解及导数调用由数值实现决定，不在本笔记写实现代码。

# 第三部分：`FE-COMPOSITE-BLADE` 模型

## 4. COMSOL 原始叶片结构与材料参数

### 4.1 来源模型和几何

模型基于 **COMSOL 6.3 的 Application ID 68321，`wind_turbine_composite_blade`**，对应 Application Library 路径 `Composite_Materials_Module/Dynamics_and_Vibration/wind_turbine_composite_blade`。其几何基于 NREL 5 MW 参考叶片：长 $61.5\,\mathrm m$，由 19 个展向截面、外壳蒙皮（skin）和内部加强腹板（spar）组成。原教程未考虑气动载荷，但包括重力、离心静力和离心预应力模态分析；**这些原有载荷研究仅说明模型来源，不进入本版自由振动配置**。[^C1]

官方截面几何参数如下，长度单位为 m，扭角为角度：

| 截面 | 展向位置 | 弦长 | 扭角 | 截面类型 |
|---:|---:|---:|---:|---|
| 1 | 0 | 3.200 | 13.080 | 圆形根部 |
| 2 | 1.36 | 3.540 | 13.080 | 圆形 |
| 3 | 4.10 | 3.850 | 13.080 | 圆形 |
| 4 | 6.83 | 4.167 | 13.080 | 圆形 |
| 5 | 10.25 | 4.550 | 13.080 | DU 99-W-405 |
| 6 | 14.35 | 4.652 | 11.480 | DU 99-W-350 |
| 7 | 18.45 | 4.458 | 10.160 | DU 99-W-350 |
| 8 | 22.55 | 4.249 | 9.011 | DU 97-W-300 |
| 9 | 26.65 | 4.007 | 7.795 | DU 91-W2-250 |
| 10 | 30.75 | 3.748 | 6.544 | DU 91-W2-250 |
| 11 | 34.85 | 3.502 | 5.361 | DU 93-W-210 |
| 12 | 38.95 | 3.256 | 4.188 | DU 93-W-210 |
| 13 | 43.05 | 3.010 | 3.125 | NACA 64-618 |
| 14 | 47.15 | 2.764 | 2.319 | NACA 64-618 |
| 15 | 51.25 | 2.518 | 1.526 | NACA 64-618 |
| 16 | 54.67 | 2.313 | 0.863 | NACA 64-618 |
| 17 | 57.40 | 2.086 | 0.370 | NACA 64-618 |
| 18 | 60.13 | 1.400 | 0.160 | NACA 64-618 |
| 19 | 61.50 | 0.700 | 0.000 | NACA 64-618 |

此表说明工程几何的主要参数；实际曲线、曲面、连接和局部实体标识以官方 `.mphbin/.mph` 文件为准，不能仅凭这 19 行生成一个新近似外形后称为原模型。原教程的几何选区包括 `Skin Boundaries`（Boundary 50）、`Spar Boundaries`（Boundaries 3、5）与根部 `Fixed Edges`（Edge 10）。这些编号在**原几何版本**下有效；重建几何后须核对其物理对应，而非沿用裸编号。[^C1]

### 4.2 有限元接口和参考网格

| 对象 | 官方教程基线 | 本数据集处理 |
|---|---|---|
| 物理接口 | `Shell (shell)` | 保留 |
| 层合材料 | `Linear Elastic Material, Layered` | 保留 |
| 厚度结构 | 等效单层 ESL 壳理论，跨厚度数值积分 | 保留，不改成逐层三维实体网格 |
| 面内网格 | 所有壳面使用 `Mapped` | 保留并调整尺寸 |
| 原最大单元尺寸 | $0.5\,\mathrm m$ | 先读取实际 DOF；过大时设计较粗网格 |
| 参考根部边界 | `Fixed Constraint` 作用于 `Fixed Edges` | 保留 |
| 单元阶次 | 需读取本地 MPH 的 `Displacement field` 设置 | 不根据图示猜测 |
| 原模型单元数、实际独立 $n_q$ | 官方教程未公布可靠总数 | 本地导出确认 |

**本模型用的是 `Shell` 下的层合材料模型，而不是另一个名为 `Layered Shell (lshell)` 的独立物理接口。** COMSOL 的 Shell 接口基于含横向剪切的 Mindlin–Reissner／MITC 壳运动学；层合材料采用 ESL 表示，厚度方向的虚拟积分与面内网格自由度应分开登记。材料铺层数不能乘以壳表面节点数以估计状态维数。[^C2][^C3]

### 4.3 正交各向异性层合材料

官方教程使用以下材料参数（纤维轴与层合材料局部坐标系绑定）：[^C1]

| 材料 | $E_1$ (GPa) | $E_2$ (GPa) | $G_{12}$ (GPa) | $\nu_{12}$ | $\nu_{23}$ | $\rho$ ($\mathrm{kg/m^3}$) |
|---|---:|---:|---:|---:|---:|---:|
| Carbon–Epoxy | 139 | 9 | 5.5 | 0.32 | 0.32 | 1560 |
| Glass–Vinylester | 41 | 9 | 4.1 | 0.30 | 0.30 | 1890 |
| PVC Foam | 0.250 | 0.250 | $0.250/[2(1+0.35)]\approx0.09259$ | 0.35 | 0.35 | 200 |

碳纤维和玻纤使用教程所述的横观各向同性材料设置；表中 $E_1,E_2,G_{12},\nu_{12},\nu_{23}$ 是其官方材料卡提供的参数，不代表任意正交各向异性本构所需的全部独立常数。PVC 泡沫由各向同性 $E=250\,\mathrm{MPa},\nu=0.35$ 给定。铺层方向取决于局部 `Boundary System`、`Reverse Normal` 与材料定义的面内轴，不能直接当作全局 $x,y,z$ 方向。

令单物理薄铺层厚度为 $t_{\mathrm{ply}}=0.28\,\mathrm{mm}$，泡沫芯厚度为 $t_{\mathrm{core}}=150\,\mathrm{mm}$：

| 层合组 | 内部材料及方向 | 厚度 |
|---|---|---:|
| `CE-[0]_10` | Carbon–Epoxy，10 层 $0^\circ$ | $10t_{\mathrm{ply}}=2.8\,\mathrm{mm}$ |
| `GV-[0/45/-45/90]_s_5` | Glass–Vinylester，每组 5 层，方向序列 $[0,45,-45,90,90,-45,45,0]^\circ$ | $40t_{\mathrm{ply}}=11.2\,\mathrm{mm}$ |
| `PF-[0]` | PVC Foam | $150\,\mathrm{mm}$ |

最终层合堆叠为

$$
\boxed{
\mathrm{CE}/\mathrm{GV}/\mathrm{PF}/\mathrm{GV}/\mathrm{CE},
\qquad
t_{\mathrm{tot}}
=2(2.8)+2(11.2)+150
=178\,\mathrm{mm}.
}
\tag{4.1}
$$

$178\,\mathrm{mm}$ 是**教程参数定义的层合厚度和**，并非逐点测得的三维几何壁厚，也不能据此推断整个 NREL 实际叶片采用完全相同铺层。COMSOL 将相同取向的五个物理铺层作为一个材料层组输入；该组仍属于同一壳动力学模型，不生成五倍的表面状态变量。正式版本需保存每一面、每一层组的局部方向、法向、层序和厚度积分设置。[^C1][^C3]

## 5. COMSOL 的新自由衰减工况

### 5.1 明确独立于原静力／旋转研究

COMSOL 原教程存在 `Gravity 1`、`Rotating Frame 1`、`Load Group: Gravity`、`Load Group: Centrifugal Force`，原参数 `RPM=15[rpm]`，并进行了 $0$–$30\,\mathrm{rpm}$ 的预应力特征频率研究。本数据集**不使用这些载荷研究作为初值或振动真值**。初版新工况声明：[^C1]

| 物理／研究对象 | 初版固定设置 | 数学效果 |
|---|---|---|
| 转速 | $\mathrm{RPM}=0$，并在新研究中停用 `Rotating Frame 1` | 无旋转参考框架、离心力与陀螺效应 |
| 重力 | 新研究中停用 `Gravity 1` | $\mathbf f_g=\mathbf0$ |
| 气动载荷 | 不添加 | 无气动力、流固耦合及风况输入 |
| 根部约束 | 保留 `Fixed Constraint 1` | 固支悬臂结构 |
| 材料 | 保留 §4.3 的弹性层合材料 | 有限应变／几何运动学可非线性，材料仍采用指定弹性模型 |
| 结构几何非线性 | `Include geometric nonlinearity = on`；采用 `From study step` 的 Total Lagrangian，或明确绑定 Total Lagrangian | 保留几何非线性内力 |
| 结构瞬态 | `Time Dependent`，`Structural Transient Behavior = Include inertial terms` | 求完整含惯性响应，不是 quasistatic |
| 正式瞬态外载 | 全部 $\mathbf0$ | 无持续强迫，初态决定自由衰减 |
| 参考平衡 | 无载静止平衡，拟定 $\mathbf q_\star=\mathbf0$ | 由残差检查认证 |

`Linear Elastic Material, Layered` 在 Study 中启用几何非线性时可采用 Total Lagrangian 运动学。这里的“线性弹性材料”描述**本构关系**，并不排除几何非线性导致的完整结构动力学非线性；同样，本版不增加损伤、脱层、塑性或未知的历史内部变量。[^C4]

### 5.2 完整壳状态与约束的处理

COMSOL Shell 3D 的基本场包括平移位移 $u,v,w$ 与**壳法线位移场** $a_x,a_y,a_z$，其界面中的字段常见为位移场 `u` 与法线位移场 `ar`。这后三个量并不应在有限转动下简单替换为物理旋转角 $\theta_x,\theta_y,\theta_z$。壳法线长度、折线连接及根部约束可能引入代数关系；软件提供的求解未知量数未必等于独立机械坐标数。[^C2]

初版数据发布必须在实际 MPH 结果上辨明：

- 用于时间推进的全部活动位移／法线位移变量及其同一时刻的导数；
- 根部固定变量、壳法线约束及其在 DOF 图中的映射；
- 求解器是否保留乘子或辅助代数未知量，以及它们是否已在输出状态中合法消去；
- 导出的 $\mathbf q,\mathbf v$ 是否为一个可复现且闭合的状态，而非仅是可视化位移场。

COMSOL LiveLink 官方提供 `mphxmeshinfo`（活动求解的 DOF／字段映射）与 `mphgetu`（瞬态求解向量及其时间导数）等接口，可作为诊断资源，但本笔记不规定实现代码。对于壳法线位移，**其求解变量的时间导数不应未经运动学变换就称为物理角速度**；原始变量与独立状态之间必须采用一致的运动学坐标。若不能证明 $d_x=2n_q$，则保留求解器 DAE／约束状态身份与一致性条件，**不可发布虚构的 20k 维完整 ODE 状态**。[^C5]

### 5.3 COMSOL 的动力学方程与阻尼方案

初版的**求解器级定义**仍是无外载、非旋转的非线性壳半离散关系

$$
\boxed{
\mathbf g_h^{\mathrm{blade}}(\mathbf q,\mathbf v,\mathbf a)=\mathbf0.
}
\tag{5.1}
$$

在本地确认独立坐标消元后具有常质量和相应固定黏性阻尼时，才进一步表述为

$$
\mathbf M\ddot{\mathbf q}+\mathbf C\dot{\mathbf q}
+\mathbf f_{\mathrm{int}}^{\mathrm{blade}}(\mathbf q)=\mathbf0.
\tag{5.2}
$$

初版优先采用 COMSOL `Linear Elastic Material, Layered > Damping` 所支持的 **Rayleigh damping**。为使模型参数明确，提出可复现的**项目基线候选**：使用本版无重力、零转速、无阻尼参考谱的前两个目标模态，设

$$
\boxed{\zeta_1=\zeta_2=\zeta_\star^{\mathrm B}=0.002.}
\tag{5.3}
$$

$0.002$ 是为了与 NACA 数据使用相同的两模态目标阻尼比而**由本项目选择**，不是 COMSOL 官方叶片的材料阻尼实测值；若实际叶片需要另一个目标阻尼比，应作为独立模型版本声明。输入 COMSOL 的 Rayleigh 参数时，可依据 §3.2 的公式从本地模态频率计算；需核查 COMSOL 在几何非线性工况下其材料级阻尼的实际有效算子，不把其求解内部算子无条件等同于全局常数 $a_M\mathbf M_\star+a_K\mathbf K_\star$。[^C6]

对于自由衰减数据，**物理阻尼**与 **Generalized-α 数值耗散**严格区分；不得通过高频数值耗散来实现计划中的物理 $\zeta_j$。

### 5.4 瞬态时间积分身份

COMSOL 6.3 官方建议对包含惯性项的结构瞬态使用 **Generalized-α**。新研究应以全阶 `Time Dependent` 为主，开启非线性迭代和几何非线性。`Amplification for high frequency` 越接近 1，高频算法耗散越弱；本版候选取 **1（或软件实际允许的近 1 设置）**，再通过独立时间细化确定是否允许更强数值耗散。输出采样间隔与积分器内部步长分别冻结；初态一致性、非线性收敛容差、最大内部步长和高频衰减均须留档。[^C7]

# 第四部分：统一多初值构造与数据资源

## 6. 初态生成必须与正式外力隔离

### 6.1 两种来源

对两个模型，正式初始速度统一为

$$
\boxed{\mathbf v_0^{(\nu)}=\mathbf0.}
\tag{6.1}
$$

**模态位移初态。** 在固定合格网格、无重力、零转速参考点计算低阶无阻尼模态，选择非空索引集 $I_0^{(\nu)}$，令

$$
\boxed{
\mathbf q_0^{(\nu)}
=\mathbf q_\star+
\sum_{j\in I_0^{(\nu)}}c_j^{(\nu)}\boldsymbol\phi_j.
}
\tag{6.2}
$$

取 $I_0^{(\nu)}\subseteq\{1,2,3,4\}$ 作为初版候选激发族：分别包含单模态、双模态以及少量多模态组合。这个集合是训练人口设计，不表示完整系统只有四个模态；允许的激发阶次与频带须在 QUAL 中根据重网格后的谱与采样共同冻结。应存储模态相位／符号、质量或物理位移归一化方式与系数单位，不能将质量归一化系数裸值直接解释为米。**式 (6.2) 只在约束已合法消元的局部独立坐标中使用**；对于含单位壳法线约束的 COMSOL 原始 `u/ar` 求解变量，不能直接逐项叠加原始模态向量并假定仍满足非线性约束。必须通过一致的局部构型映射或约束投影恢复可接受的求解器初态。

**非重力静态变形释放。** 在 $t<0$ 的辅助 Stationary／非线性静力求解中，对规定的分布载荷形状 $\mathbf f_{\mathrm{pre}}$ 与幅值系数 $a_\nu$ 求解

$$
\boxed{
\mathbf f_{\mathrm{int}}(\mathbf q_0^{(\nu)})
=a_\nu\mathbf f_{\mathrm{pre}},
\qquad\mathbf v_0^{(\nu)}=\mathbf0.
}
\tag{6.3}
$$

对 COMSOL，式 (6.3) 是可化为位移内力形式时的表达；更一般的约束静态问题应使用其实际 Stationary 残差和约束一致的解向量。释放后**停用此预加载**，正式时间积分始终消费 (3.2) 或 (5.1) 的无载模型。该辅助载荷不是重力，也不在正式数据中提供输入。

### 6.2 初始幅值与材料有效域

不同结构尺度与不同模态归一化不能共用一组未经说明的数值系数。令 $A_\nu$ 表示初态在一组固定物理空间点上的**最大平移位移幅值**，即

$$
A_\nu
:=\max_{\boldsymbol\xi\in\mathcal S_{\mathrm{amp}}}
\left\|\mathbf u_h(\boldsymbol\xi;\mathbf q_0^{(\nu)})
-\mathbf u_h(\boldsymbol\xi;\mathbf q_\star)\right\|_2.
\tag{6.4}
$$

$\mathcal S_{\mathrm{amp}}$ 是冻结的物理位置集合，不是学习器压缩坐标。每个模型先经独立 QUAL 确定 $A_{\max}^{\mathrm{qual}}$：在此范围内，结构应变、层合材料弹性适用性、约束和非线性时间积分均保持有效。建议在此上限内把初态分为三个强度层，取中心幅值候选

$$
\boxed{
A_\nu\in
\{0.15,\,0.40,\,0.70\}
A_{\max}^{\mathrm{qual}},
}
\tag{6.5}
$$

并允许在各层内预先声明小范围扰动。式 (6.5) 是**人口分层建议**，不是已经验证的实际米制幅值；不得以固定大挠度阈值替代材料应变与数值资格。COMSOL 初始法线变量／转动状态需与选定模态或静力解整体一致，不可只把三向平移位移赋值而将其余活动自由度任意置零。

### 6.3 非线性资格

每个结构的 QUAL 初态至少覆盖一个小幅值和一个具有可辨识非线性响应的有限幅值。对相同初态，比较完整非线性模型与参考点线性切向模型，验证非线性效应高于网格／时间误差；可观察量包括有限振幅频率漂移、模态间能量重分配、波形谐波及振幅依赖衰减。**启用几何非线性选项本身不是已经获得可学习非线性数据的证据。** 非线性程度是数值资格对象，不由初态幅值的裸数值判定。

## 7. 网格规模与空间收敛资格

### 7.1 规模目标和调整参数

初版目标为

$$
\boxed{
n_q\approx10\,000,
\qquad d_x\approx20\,000,
}
\tag{7.1}
$$

其中 $n_q$ 仅统计**独立机械坐标**。为避免过度为一个整数优化，建议把 $d_x=16\,000$–$24\,000$ 作为初次资源搜索的软区间；超出区间但保留目标动力学并通过资源验收的网格仍可以成为合格数据模型。只有实际约束后 $n_q$ 被确认，才按 (1.9) 登记一阶状态维度。

| 模型 | 优先调节的离散对象 | 不应为凑维数改变的物理对象 |
|---|---|---|
| NACA | `La`、`a1/a2` 对应的截面／Transfinite 密度，必要局部加密 | 25 肋、翼型轮廓、厚度、纵向加劲拓扑、固定区域 |
| COMSOL | `Mapped` 网格的面内尺寸和分区密度，候选最大单元尺寸 $0.75\,\mathrm m$、$1.0\,\mathrm m$；必要时调整已核实的空间单元阶次 | 19 截面几何、蒙皮与腹板、层合方向／厚度、根部固定 |

COMSOL 的 $0.75/1.0\,\mathrm m$ 仅是相对原 $0.5\,\mathrm m$ 的粗化试算值，不保证生成 Mapped 网格成功，也不保证任何模态精度。NACA 粗化与 COMSOL 网格改变都要建立独立模型版本，严禁用同一数据集标识覆盖不同网格动力学。

### 7.2 必须独立认证的量

每个模型至少设置一个候选网格和两个更细的校验网格；细网格只需要运行少量独立 QUAL 初态，正式生成数据仍使用固定的合格候选网格。

| 资格对象 | 比较方式 | 建议初步筛选条件（未认证） |
|---|---|---|
| 线性固有频率 | 目标模态相对频差 | 主要模态约 $2\%$–$3\%$ 以内 |
| 振型 | 映射到共同物理空间点的 MAC | 主要模态不低于 $0.95$ |
| 静态顺应性 | 同一非重力辅助载荷下的参考变形 | 达到预先声明的相对精度 |
| 非线性瞬态 | 同一初态的位移、速度、相位及幅值包络 | 与更细网格及时间积分一致 |
| 非线性机制 | 幅频变化、模态耦合和能量转移 | 目标现象对网格细化稳定 |
| 模型与约束 | 几何分组、壳法线、材料局部轴、力平衡 | 一致且无未处理病态模式 |

MAC 不能直接使用不同网格上长度不同的原始向量；应先做共同位置插值并冻结相应内积。表中阈值仅是本项目推荐的筛选建议，不表示任何官方模型已达到这些数值。

## 8. 时间积分与输出采样

### 8.1 输出网格与固定帧数

每条母轨线计划保存 **2048 个输出时间间隔与 2049 帧**：

$$
\boxed{
t_m=m\tau,
\quad m=0,\ldots,2048,
\qquad T_{\mathrm{rec}}=2048\tau.
}
\tag{8.1}
$$

$\tau$ 是数据和 Koopman 学习器的输出采样间隔，不等于求解器内部时间步长 $\Delta t_{\mathrm{int}}$。每模型所有正式轨线共享同一个冻结的 $\tau$；两个模型的自然频率不同，允许各自采用不同的实际秒制采样间隔。

以首阶参考周期 $P_1=2\pi/\omega_1$ 为基准，原笔记的初选是 $\tau=P_1/64$、$T_{\mathrm{rec}}=32P_1$。这只适用于有效激发频带较窄的情形。若最高需要准确解析的有效角频率为 $\omega_{\mathrm{eff}}$（包含实际存在的非线性谐波），建议候选采样改为

$$
\boxed{
\tau\le\min\left(
\frac{P_1}{64},
\frac{2\pi}{24\omega_{\mathrm{eff}}}
\right),
\qquad T_{\mathrm{rec}}=2048\tau.
}
\tag{8.2}
$$

这里每个最高有效周期至少 24 个输出间隔是**设计建议**，不是仅凭 Nyquist 定理自动推出的误差保证。$\omega_{\mathrm{eff}}$ 应由初态模态族、数值频谱和细采样 QUAL 共同确定；若 (8.2) 使慢振动观察时长不足，应增加正式输出帧数或单独冻结另一时间分辨率数据版本，不得把欠采样的轨线宣称为充分解析的多模态真值。

### 8.2 各模型的内部求解方案

| 项目 | NACA | COMSOL 复合材料叶片 |
|---|---|---|
| 时间模型 | 完整三角壳非线性内力 | 完整几何非线性层合壳方程及其约束 |
| 初选积分器 | 隐式 Newmark（$\beta_{\mathrm N}=1/4,\gamma_{\mathrm N}=1/2$） | Generalized-α，优先较弱高频算法耗散 |
| 内部时间设置 | 自适应／固定小步均可，按误差认证 | Generalized-α 内部步长与输出时间分别设置 |
| 非线性求解 | 由完整内力残差与一致切线求 Newton 更新 | COMSOL 非线性求解与一致性初始化 |
| 输出状态 | 约束处理后的 $\mathbf q_m,\mathbf v_m$ | 已认证的位移、法线位移及时间导数的独立状态映射 |
| 真值精度 | Float64 | 求解与归档以双精度结果为基线 |
| 必须区分 | Rayleigh 物理阻尼／积分误差 | 材料 Rayleigh 阻尼／Generalized-α 数值耗散 |

时间资格以独立 QUAL 初态检验细化收敛：减小内部时间步长或收紧误差／非线性容差，比较完整状态、相位、衰减包络与机械能／耗散收支。原位移时间序列的有限差分不能替代求解器一致速度。对 COMSOL，还必须核对初始化是否改变原规定的壳法线／约束状态，以及是否出现人工初始化瞬态。

### 8.3 能量与机械检查

在适用 (1.4) 且有可微保守内力势时，定义

$$
\mathcal E(t)
:=\frac12\mathbf v(t)^\top\mathbf M\mathbf v(t)
+\mathcal E_{\mathrm{el},h}(\mathbf q(t)).
\tag{8.3}
$$

由 (1.4) 和 (1.5) 得到精确平衡

$$
\boxed{\frac{\mathrm d\mathcal E}{\mathrm dt}
=-\mathbf v^\top\mathbf C\mathbf v\le0
\quad\text{当 }\mathbf C\succeq0.}
\tag{8.4}
$$

若实际 COMSOL 壳动力学是带约束或构型依赖惯性的 (5.1)，则能量审计应使用其真实机械功／能量表达和约束功，而不是把 (8.3)–(8.4) 无条件套用于求解器未知量。数值结果必须区分物理耗散、积分器误差、约束误差与输出插值误差。

## 9. 正式数据人口、精度与预算

### 9.1 每模型冻结的人口

| 字段 | 初版设计 |
|---|---|
| Train | 96 条完整母轨线 |
| Validation | 24 条完整母轨线 |
| Test | 24 条完整母轨线 |
| QUAL | 独立额外初态，不进入上述集合 |
| 每轨线记录 | $m=0,\ldots,2048$，2049 帧 |
| 状态 | 实际独立 $d_x$ 维全阶状态；目标约 20k |
| 初态 | §6 的单／多模态与非重力静态释放；$\mathbf v_0=\mathbf0$ |
| 外载 | 全部正式轨线 $\mathbf f_{\mathrm{ext}}\equiv\mathbf0$ |
| 噪声 | 初版不添加观测噪声／过程噪声 |
| 轨线划分 | 按初态与完整母轨线隔离；重复初态不得跨集合 |
| 学习坐标 | 保留物理单位真值；数值标准化仅由 Train 拟合并冻结 |
| 窗口 | 从单条完整母轨线按需提取，不作为独立划分单位 |

每模型 Train 包含 $96\times2048=196\,608$ 个相邻状态转移；Validation、Test 各 $24\times2048=49\,152$ 个。**这些数量是相互高度相关的时间转移数，不是独立样本数**。

### 9.2 全状态存储量

不压缩的状态数组大小为

$$
\boxed{
B=N_{\mathrm{traj}}\,d_x\,(2049)\,b,
}
\tag{9.1}
$$

其中 $b=8$ bytes 对应 Float64。若暂取 $d_x=20\,000$：

| 数据范围 | 轨线数 | Float64 (GB) | 可选 Float32 派生数组 (GB) |
|---|---:|---:|---:|
| 单条轨线 | 1 | 0.327840 | 0.163920 |
| 单模型 Train | 96 | 31.472640 | 15.736320 |
| 单模型 Validation | 24 | 7.868160 | 3.934080 |
| 单模型 Test | 24 | 7.868160 | 3.934080 |
| 单模型合计 | 144 | 47.208960 | 23.604480 |
| 两个模型合计 | 288 | 94.417920 | 47.208960 |

GB 为十进制 $10^9$ bytes。以上只是纯状态数组预算，不含 QUAL、稀疏矩阵、求解器中间文件、压缩索引、备份和临时输出。真实数组随实际状态维数按 $d_x/20\,000$ 缩放；NACA 原始 $d_x=267\,840$ 如直接按此合同生成，Float64 两者计算口径中的该单模型就约需 $632.222\,\mathrm{GB}$，因而重网格是必要的计算资源决策。

### 9.3 必须保存的状态元数据

每个模型版本至少保存：固定源文件及哈希、单元类型、各物理组及连接、局部材料方向、边界约束、独立 DOF 顺序与坐标映射、状态分量单位、$\mathbf q_\star$、$\mathbf M_\star/\mathbf K_\star$ 的可验证标识、阻尼参数、初态系数和物理幅值、求解器实际时间、帧间隔、Float64 真值及其完整性校验。COMSOL 另保存 `u/ar` 字段名、法线约束与实际速度导出映射。未认证字段不得靠默认值或维度估算回填。

## 10. 资格验收和发布门禁

本版不对未知本地配置预设已通过状态。以下门禁完成后，才允许从候选资源升级为正式数据集。

| 门禁 | NACA 的主要证据 | COMSOL 的主要证据 |
|---|---|---|
| G1 来源一致性 | 固定提交、几何文件、材料、Physical Surface、root BC 与力函数 | 6.3 MPH、壳接口、19 截面、材料层、材料轴与 Fixed Edges |
| G2 工况纯净性 | 重力／体力未启用；不向 (3.2) 注入翼尖谐波载荷 | Gravity 与 Rotating Frame 在新 Study 中停用；无气动或其他时间载荷 |
| G3 数学模型 | 实际 $\mathbf f_{\mathrm{int}}$、质量、线性化与阻尼相容 | 几何非线性与惯性项开启、约束／DAE 身份明确 |
| G4 完整状态 | 约束后 $n_q$、$\mathbf q/\mathbf v$ 与内力求解变量对应 | 壳法线位移和时间导数、乘子与独立 DOF 映射认证 |
| G5 空间资格 | 频率、MAC、静态响应、非线性轨线网格收敛 | 同左，并检查材料方向／厚度积分敏感性 |
| G6 时间资格 | Newmark / Newton、时间细化、能量和相位 | Generalized-α、初始化一致性、物理／算法耗散分离 |
| G7 资源资格 | 单轨线时间、稀疏求解主存峰值、流式导出 | 单轨线时间、COMSOL 结果文件、导出峰值与自动化可行性 |
| G8 数据资格 | 96/24/24 完整轨线隔离、哈希、时间与单位一致 | 同左；额外提交完整状态映射与许可证环境 |

发布前依次执行：来源模型冻结 → 无载工况冻结 → 网格与参考谱资格 → 初态幅值与有效频带资格 → 时间积分资格 → 独立 QUAL → 正式多初值生成 → 轨线级划分与数据核验。NACA 和风机叶片必须分别记录资格；一者通过不能代表另一者通过。

# 11. 来源索引与数学接口

## 11.1 NACA / YetAnotherFEcode

[^N1]: [SSMTool：NACA wing non-intrusive tutorial](https://ssmtool.mae.sustech.edu.cn/Tutorial/Examples/Non-Intrusive/NACA%20Wing/NACA%20Wing.html)，原始网格／DOF、Rayleigh 阻尼、谱结果和 SSM／FRC 主任务。其 `nt=128` 为 FRC 配置，不是本文的瞬态步数。
[^N2]: [SSMTool 固定版本：`build_model_nonIntrusive.m`](https://github.com/jain-shobhit/SSMTool/blob/de6cbc71427d23827feb9efd313cb63a1fc52ff8/examples/NACAWing/build_model_nonIntrusive.m)；[主入口 `NACAWing_NonIntrusive.m`](https://github.com/jain-shobhit/SSMTool/blob/de6cbc71427d23827feb9efd313cb63a1fc52ff8/examples/NACAWing/NACAWing_NonIntrusive.m)。以上固定提交核对了材料、边界、矩阵装配、Rayleigh 系数、已注释体力接口及实际谐波加载。
[^N3]: [YetAnotherFEcode / SSMTool 固定版本 `WING.geo`](https://github.com/jain-shobhit/SSMTool/blob/de6cbc71427d23827feb9efd313cb63a1fc52ff8/ext/YetAnotherFEcode/examples/Mechanical/3D/NACAWing/WING.geo)；其中 `AIRFOIL.geo` 中 `a1,a2` 的实际初值须在下载的完整子目录中补核。

原始工程模型参考 Jain, Tiso, Rutzmoser & Rixen (2017), *A quadratic manifold for model order reduction of nonlinear structural dynamics*, *Computers & Structures* 188, 80–94，[DOI](https://doi.org/10.1016/J.COMPSTRUC.2017.04.005)；非侵入式研究参考 Li, Thurnher, Xu & Jain (2025), *Data-free non-intrusive model reduction for nonlinear finite element models via spectral submanifolds*, *Computer Methods in Applied Mechanics and Engineering* 434, 117590，[DOI](https://doi.org/10.1016/j.cma.2024.117590)。以上论文的 SSM 约化任务与本文自行组织的多初值全阶自由振动数据不混淆。

## 11.2 COMSOL 官方文档（6.3 为参数基线）

[^C1]: [Stress and Modal Analysis of a Wind Turbine Composite Blade，Application ID 68321](https://doc.comsol.com/6.3/doc/com.comsol.help.models.compmat.wind_turbine_composite_blade/wind_turbine_composite_blade.html)；[Application Gallery](https://www.comsol.com/model/stress-and-modal-analysis-of-a-composite-wind-turbine-blade-68321)。几何、19 截面、材料、铺层、原载荷、原 `Mapped` 网格、选区与分析项目来源。
[^C2]: [The Shell and Plate Interfaces — Dependent Variables](https://doc.comsol.com/6.3/doc/com.comsol.help.sme/sme_ug_modeling.05.032.html)；[The Shell and Plate Interfaces](https://doc.comsol.com/6.3/doc/com.comsol.help.sme/sme_ug_shell_plate.08.02.html)。壳法线位移和约束的动力学身份。
[^C3]: [Layered and Nonlayered Shells](https://doc.comsol.com/6.3/doc/com.comsol.help.sme/sme_ug_modeling.05.033.html)。ESL、厚度虚拟积分及材料层数与表面 DOF 的区别。
[^C4]: [Linear Elastic Material, Layered](https://doc.comsol.com/6.3/doc/com.comsol.help.sme/sme_ug_shell_plate.08.08.html)；[Modeling Geometric Nonlinearity](https://doc.comsol.com/6.3/doc/com.comsol.help.sme/sme_ug_modeling.05.134.html)。几何非线性与材料弹性的独立条件。
[^C5]: [mphxmeshinfo](https://doc.comsol.com/6.3/doc/com.comsol.help.llmatlab/llmatlab_ug_ref.9.78.html)；[LiveLink for MATLAB User's Guide / `mphgetu`](https://doc.comsol.com/6.3/doc/com.comsol.help.llmatlab/LiveLinkForMATLABUsersGuide.pdf)。实际 DOF 映射与瞬态解及时间导数导出。
[^C6]: [Damping in Structural Mechanics](https://doc.comsol.com/6.3/doc/com.comsol.help.sme/sme_ug_solid.07.043.html)。Shell / `Linear Elastic Material, Layered` 的 Rayleigh 阻尼与数值耗散区别。
[^C7]: [Time-Domain Analysis](https://doc.comsol.com/6.3/doc/com.comsol.help.sme/sme_ug_modeling.05.006.html)；[Time-Dependent Solver](https://doc.comsol.com/6.3/doc/com.comsol.help.comsol/comsol_ref_solver.36.136.html)。Generalized-α、输出时间、内部步长、高频放大因子和 DAE 一致初始化。

## 11.3 项目内理论说明

本笔记的非线性有限元—完整状态数学入口对应 [[ODE-12.有限元半离散、非线性时间积分与机械动力系统的统一视角]]；平衡点切向矩阵与机械模态对应 [[ODE-2.非线性机械系统的平衡点线性化与阻尼谱结构]]；完整状态作为动力学代理首要标签的规定对应 [[SKDM-K1.1-Dynamics Simulation Surrogates and Control-Conditioned Online Prediction]]。上述理论接口不改变两份原有限元模型的具体几何、材料及求解设置。预测评分由 [[SKDM-Exp0-List of Evaluation Indicators]] 消费冻结数据后另行定义，Dataset-2.1 不预先指定神经网络、字典、Koopman 谱参数或训练损失。
