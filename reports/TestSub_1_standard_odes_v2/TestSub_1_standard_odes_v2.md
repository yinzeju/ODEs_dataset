# TestSub-1：Standard ODE v2 数据生成与资格验收报告

## 1. 实验简述

本次依据用户提供的 2026-09-15 版 TestSub-1 笔记，重建自治 ODE 数据资源。新版将固定工况 CAN 与物理参数族 COND 分开，采用跨工况一致的原坐标初值分布，并区分已见工况的新初态泛化与未见工况插值。实际项目目录为 `D:/MyVault/Projects/Julia/ODEs_dataset`。

执行过程为数学与数据合同测试、全流程 smoke、独立数值探针资格化、正式 clean 轨线生成、Train 专用噪声标定、两档噪声视图生成和全部文件读回验收。正式资源包括 10 个方程族、11 个 CAN 配置，以及 6 个 COND 族分别对应的 Split-I、Split-C，共 23 组资源。总计 34,432 条独立轨线、63,559,296 个完整状态快照、357 个 JLD2 视图文件，数据文件占 10,783,728,301 字节，约 10.04 GiB。

最终所有验收通过，积分失败数为 0。195 个独立探针的最大归一化状态差为 5.65115e-10；全部正式轨线的最大归一化能量残差为 7.92622e-10。新资源通过验收后，已删除旧 `lowdim_nonlinear_v1` 数值文件及其三个旧生成代码入口，保存旧清单和哈希。此次只完成数据生成与数值资格化，不包含模型训练、隐参数辨识或预测性能实验。

| 项目 | 本次实际绑定 |
| --- | --- |
| 实验身份 | `TestSub_1_standard_odes_v2` |
| 资源身份 | `standard_odes_v2_20260916` |
| 协议身份 | `Standard_ODEs_v2` |
| 终止阶段 | `qualified_raw_dataset_release` |
| Core branch、训练模型、预测指标 | N.A. |
| 观测与目标 | 完整物理状态；clean、5 dB、15 dB 观测；目标始终为 clean |
| 数据轴 | `trajectory × time × state_component` |
| 精度 | Float64 积分，Float32 存储；不执行状态标准化 |
| 执行环境 | Julia 1.12.5；12 个 Julia 线程；BLAS 单线程 |
| 随机主种子 | 202609160；SHA-256 分离 IC、split、noise、probe 命名空间，派生 48 位整数种子 |
| 配置与源码身份 | `338a0f38ca7746815043d25110f403f7407d5ced3ca33b04a099c362253608bb` |
| 最终读回完成时间 | 2026-09-16 01:18:32，Australia/Sydney，UTC+10 |

数学来源为用户给定的 [TestSub-1 笔记](<D:/MyVault/Document/Obsidian/Notebook/系统辨识和模型学习/Koopman Space/Part 0 Benchmark & Evaluation/TestSub-1. lowdim_nonlinear_v1_math.md>)；项目保存了[本次冻结副本](../../docs/notes/mathematical%20explanation/standard_odes_v2_math.md)。完整方程、来源 DOI、初值分布与安全集以该副本为准。此任务采用笔记中的本地多初值人口，没有下载或重新发布文献 FPUT 长轨文件。

## 2. K0 主指标与本次验收指标

Physical RelRMSE 为 N.A.，因为没有训练或评价预测模型。本次主验收对象是数据正确性，阈值在正式生成前写入配置。

| 指标 | 预声明要求 | 实测结果 |
| --- | --- | --- |
| 独立探针状态收敛 | 不超过 1e-7 | 最大 5.65115e-10，通过 |
| 正式保守能量或带符号能量平衡残差 | 不超过 1e-8 | 最大 7.92622e-10，通过 |
| 局部重启对象的长期统计差 | 不超过 0.35 | 最大 0.0682806，通过 |
| 积分失败、非有限值、支撑越界 | 0 | 0 |
| 5 dB 共享参考实测 SNR | 各分片/通道偏差不超过 0.15 dB | 4.944431–5.065444 dB |
| 15 dB 共享参考实测 SNR | 各分片/通道偏差不超过 0.15 dB | 14.955383–15.039322 dB |
| 完整文件哈希、读回与数据合同 | 全部通过 | 357/357 个视图文件通过 |
| 独立元数据审计 | 字段完整、参数/标签/种子匹配、探针与正式种子不重叠 | 357 个视图各 42 项必需字段，通过；种子重叠 0 |
| Float32 量化误差 | 独立登记 | 最大绝对误差 7.62870e-6，发生于增长型实对角系统 |

状态门禁使用固定参考坐标尺度。对非混沌对象比较完整记录；Lorenz、Rössler 与 FPUT 采用预先声明的局部重启和一步一致性，同时比较整段占据统计。局部重启在每个探针记录上均匀选择 5 个起点；混沌重启时长为 0.2，FPUT 为 1.0 个模型时间单位。长期统计包含逐通道均值、RMS、10 帧滞后相关和 5%/95% 分位数，前三类幅值统计按固定尺度与参考 RMS 归一化，相关量直接比较。

0.35 的统计门槛属于本次显式登记的工程资格设置，不是文献提供的普适混沌误差界。有限探针和有限记录能够支持本次发布资格，不能证明无限时间的轨线重合、吸引子测度完全相同或所有未来初态都满足同一误差界。

## 3. 初始化、物理配置与样本人口

### 3.1 状态、初值与可变工况

完整物理参数保存在每个工况分片中；`condition_values` 按轨线保存活动条件坐标。完整轨线的 IC 种子、pre-burn 初态、记录初态、split 角色和父轨线身份均有明确记录。不同条件独立抽样，使用相同原坐标初值法则，未做工况相关的时间或速度缩放。

| 方程族/配置 | 完整主要系数 | 本次初值人口 |
| --- | --- | --- |
| 实对角线性 | 连续率 -1、-0.3、0.1、0.5 | 四维盒 [-1,1] 上均匀 |
| 旋转收缩 | gamma=0.15，omega=2π | 面积均匀 Ann(0.5,1) |
| 阻尼线性振子 | gamma=0.05，CAN omega0=1；COND omega0∈[0.8,1.2] | Ann(0.5,1) |
| Duffing medium | alpha=1，delta=0.08，beta=10，暴露指标 40 | Ann(1.5,2) |
| Duffing strong | alpha=1，delta=0.08，beta=20，暴露指标 320 | Ann(3,4) |
| Duffing COND | alpha=1，delta=0.08，beta∈[5,25] | 固定 Ann(1.5,2) |
| 非线性摆 | CAN omega0=1；COND omega0∈[0.8,1.2] | CAN 按 H<0.99 拒绝抽样；COND 用 omega_min=0.8 的共同 0.95 分离轨裕度 |
| Van der Pol | CAN mu=0.3；COND mu∈[0.1,0.9] | 0.5 Ann(0.5,1.5)+0.5 Ann(2.5,3.5) |
| Axås–Haller | m=k=1，c=0.03，alpha2=-2；CAN beta3=1，COND beta3∈[0.5,1.5] | 四维半径 0.5 均匀球提议；共享 beta3=1.5 安全能量限制 [1/240,1/30] |
| FPUT–β | 32 质量块、单位质量/线性刚度、固定端点；CAN beta=1，COND beta∈[0.5,1.5] | 全 32 模态高斯激发；线性能量对数均匀于 [0.5,2]；不按真实 beta 重配平总能量 |
| Lorenz63 | sigma=10，rho=28，beta=8/3 | pre-burn 盒 [-12,12]×[-12,12]×[8,32] 均匀；burn-in=10 |
| Rössler | a=b=0.2，c=5.7 | pre-burn 盒 [-8,8]×[-8,8]×[0.5,8] 均匀；burn-in=50 |

环形分布采用半径平方均匀与独立均匀相位。Axås–Haller 初始提议拒绝率较高，单分片最高约 96.32%，符合预声明的小能量安全域；这些拒绝发生在初始安全采样阶段。正式积分失败后没有补抽轨线。摆未执行逐帧 angle wrap；FPUT 两端点是方程中的固定常量，而非动态状态补零修复。

### 3.2 时间与划分

快照数为 $M$，一步转移数为 $M-1$，记录时长为 $(M-1)\tau$，闭区间包含起始帧与终止帧。所有 CAN 的 Train/Val/Test 为 384/64/64；摆为 6144/1024/1024。各 CAN 的完整采样规模和实测结果列于第 6 节。

| COND 族 | 采样间隔 | 快照数 | 记录时长 | Split-I 总轨线数 | Split-C 总轨线数 |
| --- | --- | --- | --- | --- | --- |
| 阻尼线性振子 | 0.02 | 2001 | 40 | 2304 | 1536 |
| Duffing | 0.01 | 2049 | 20.48 | 2304 | 1536 |
| 非线性摆 | 0.02 | 2001 | 40 | 2304 | 1536 |
| Van der Pol | 0.02 | 3001 | 60 | 2304 | 1536 |
| Axås–Haller | 0.1 | 1001 | 100 | 2304 | 1536 |
| FPUT–β | 0.05 | 4097 | 204.8 | 1152 | 768 |

每族参数区间统一映射 9 个 r=j/8 工况。Split-I 每个低维工况分为 192/32/32，FPUT 为 96/16/16。Split-C 的训练工况为 r=0、2/8、4/8、6/8、1，验证为 1/8、5/8，测试为 3/8、7/8；低维每个训练工况 256 条、留出工况 64 条，FPUT 分别为 128 和 32 条。Split-I 与 Split-C 的轨线和种子池独立。

所有非混沌耗散系统保留启动暂态；只有两种混沌 CAN 执行规定 burn-in。时间单位按模型登记，Axås–Haller 使用 m=k=1 的模型时间，未统一冒称所有记录以秒为单位。Lorenz 与 Rössler 候选 COND，以及独立文献 replay，不属于本次首版启用范围。

## 4. 训练

N.A.。没有训练字典、Koopman 算子、SSM 教师、隐参数 provider 或 normalizer，没有使用验证/测试预测误差选择配置。初始状态、轨线能量与物理工况分别存储，未将它们混合为条件标签。

## 5. 冻结构建与后处理

### 5.1 数值求解器

| 对象 | 正式方法 | reltol / abstol | 内部最大步长或子步 |
| --- | --- | --- | --- |
| 三种线性对象 | 从初态解析传播；以矩阵指数独立检查公式 | N.A. | N.A. |
| Duffing | DP5(4) | 1e-11 / 1e-13 | 0.0005 |
| 摆、Van der Pol | DP5(4) | 1e-11 / 1e-13 | 0.004 |
| Axås–Haller | DP5(4) | 1e-11 / 1e-13 | 0.02 |
| Lorenz63 | DP5(4) | 1e-10 / 1e-12 | 0.002 |
| Rössler | DP5(4) | 1e-10 / 1e-12 | 0.004 |
| FPUT–β | Yoshida 四阶对称 velocity-Verlet 组合 | N.A. | 8 子步，内部步长 0.00625 |

DP5 使用 `OrdinaryDiffEqLowOrderRK` 2.2.0。在每个输出时刻设置 `tstops`，保存求解器到达该时刻的解，避免另引入输出插值误差；接口含义参考 [SciML 求解器选项](https://docs.sciml.ai/DiffEqDocs/dev/basics/common_solver_opts/)。耗散系统和 Van der Pol 将带符号能量变化率积分作为增广状态一并求解。阻尼线性振子的耗散积分使用解析指数—三角积分，避免粗采样求积。

探针加严方案将 DP5 容差缩小十倍并将最大步长减半；FPUT 对比 8 与 16 子步。FPUT 全部探针在起始 8 子步配置即通过，因此 CAN 和所有 COND 共用 8 子步。数值尺度为 $\mathbf D_{\mathrm{num}}=D\mathbf I$：普通二维对象 D=1，Duffing medium/strong 分别 2/4，Van der Pol 为 3.5，Axås–Haller 为 0.5，Lorenz 为 20，Rössler 为 10，FPUT 为 1。能量尺度对应为普通振子/摆 1、Duffing 42/1288、Van der Pol 6.125、Axås–Haller 1/30、FPUT 2，完整配置均冻结保存。

### 5.2 噪声与存储

每个资源只用 clean Train 计算逐通道未中心化二阶矩；COND 按训练工况等权、工况内轨线等权、全记录快照等权。功率绑定为已发布 Float32 clean 状态的 Float64 累积二阶矩；存储量化误差单独留证。两档噪声分别按该共享功率产生独立高斯样本，不按轨线或工况重缩放。每个物理时刻的噪声被冻结，下游所有窗口复用。

clean 目标与 clean 观测引用同一个状态数组，噪声文件显式引用同目录 clean 目标。文件读回检查父轨线身份、split、维数、有限性、时间轴、初始状态、完整参数绑定、配置哈希和目标引用。所有文件都登记 SHA-256。

### 5.3 实际调整与前后证据

初次运行遇到 DP5 未由现有 `OrdinaryDiffEq` 入口导出的问题，因此通过 `Pkg.PRESERVE_ALL` 安装匹配的 `OrdinaryDiffEqLowOrderRK`，保持其他包版本不变，并修正一处 Julia 广播语法。自动预编译提示项目原有根包缺少源入口；本项目实际采用脚本运行，后续完整 smoke 和正式脚本均成功。

第一轮完整 smoke 的数学检查为 370/370，通过全部 119 个 clean 分片。噪声阶段一个 FPUT 留出分片每通道只有 66 个样本，实测偏差最大 2.75935 dB，超过预设 2.5 dB smoke 门槛。将 smoke 可见工况的轨线数从 4/2/2 增至 16/8/8，整组留出工况从 2 增至 8；最小噪声样本数增至 264。重跑全部流程后，23 组、119 分片、2752 条 smoke 轨线和 357 个视图文件全部通过。正式规模、0.15 dB 正式噪声门槛、物理方程、初值法则与数值阈值均未更改。

## 6. 最终冻结评价

下表由正式 release manifest 自动汇总。能量栏在实对角、旋转、Lorenz、Rössler 中记为 N.A.，不把生成器占位零值解释为这些系统的能量守恒证书。保守系统检查漂移；耗散系统检查能量平衡；Van der Pol 检查带符号积分平衡。

| 配置 / 层级 | Split | 状态维数 | 采样间隔 | 快照数 | 轨线数 | 最大能量残差 | 最大 Float32 绝对误差 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| axas_haller_2023_2dof / CAN | Split-I | 4 | 0.1 | 1001 | 512 | 2.3135E-011 | 7.4499E-009 |
| axas_haller_cond_beta3 / COND | Split-C | 4 | 0.1 | 1001 | 1536 | 2.3616E-011 | 1.0037E-008 |
| axas_haller_cond_beta3 / COND | Split-I | 4 | 0.1 | 1001 | 2304 | 2.3445E-011 | 7.4506E-009 |
| duffing_chi320_strong / CAN | Split-I | 2 | 0.01 | 2049 | 512 | 4.4102E-012 | 1.9073E-006 |
| duffing_chi40_medium / CAN | Split-I | 2 | 0.01 | 2049 | 512 | 1.8812E-014 | 4.7573E-007 |
| duffing_cond_beta / COND | Split-C | 2 | 0.01 | 2049 | 1536 | 1.9384E-013 | 4.7681E-007 |
| duffing_cond_beta / COND | Split-I | 2 | 0.01 | 2049 | 2304 | 1.9611E-013 | 4.7683E-007 |
| fput_beta_32dof / CAN | Split-I | 64 | 0.05 | 8193 | 512 | 5.1134E-010 | 2.3842E-007 |
| fput32_cond_beta / COND | Split-C | 64 | 0.05 | 4097 | 768 | 7.9262E-010 | 2.3842E-007 |
| fput32_cond_beta / COND | Split-I | 64 | 0.05 | 4097 | 1152 | 5.4793E-010 | 2.3842E-007 |
| linear_diagonal / CAN | Split-I | 4 | 0.01 | 1025 | 512 | N.A. | 7.6287E-006 |
| lorenz63_standard / CAN | Split-I | 3 | 0.01 | 4097 | 512 | N.A. | 1.9073E-006 |
| damped_linear_oscillator / CAN | Split-I | 2 | 0.02 | 3001 | 512 | 2.1816E-016 | 2.9802E-008 |
| damped_linear_cond_w0 / COND | Split-C | 2 | 0.02 | 2001 | 1536 | 3.9571E-016 | 5.9600E-008 |
| damped_linear_cond_w0 / COND | Split-I | 2 | 0.02 | 2001 | 2304 | 3.1060E-016 | 5.9604E-008 |
| nonlinear_pendulum_lusch2018 / CAN | Split-I | 2 | 0.02 | 51 | 8192 | 2.9215E-015 | 1.1921E-007 |
| pendulum_cond_w0 / COND | Split-C | 2 | 0.02 | 2001 | 1536 | 3.0128E-014 | 1.1921E-007 |
| pendulum_cond_w0 / COND | Split-I | 2 | 0.02 | 2001 | 2304 | 2.7312E-014 | 1.1921E-007 |
| rossler_standard / CAN | Split-I | 3 | 0.02 | 4097 | 512 | N.A. | 9.5358E-007 |
| linear_rotation_contraction_2d / CAN | Split-I | 2 | 0.01 | 2049 | 512 | N.A. | 2.9801E-008 |
| vanderpol_autonomous_mu03 / CAN | Split-I | 2 | 0.02 | 5001 | 512 | 4.6862E-014 | 1.1921E-007 |
| vanderpol_cond_mu / COND | Split-C | 2 | 0.02 | 3001 | 1536 | 2.6799E-013 | 2.3767E-007 |
| vanderpol_cond_mu / COND | Split-I | 2 | 0.02 | 3001 | 2304 | 2.6693E-013 | 2.3731E-007 |

正式数据全部通过几何支撑、有限值、轨线身份唯一性、IC 种子唯一性、条件划分、clean-target 对齐、训练参考功率与完整读回检查。每条轨线能量诊断、最大能量正增量、Float32 误差以及 FPUT 的初始/平均/终止模态能量、总能量和最大相对位移均保留于数据诊断；每分片还保存能量残差的 50%/95%/99% 分位数和拒绝率。

这些结果说明资源满足本次数值发布合同。尚未运行条件激发辨识、SSM 适用性审计或预测模型比较，因此不对参数可辨识精度、谱学习能力或长时间预测效果作结论。完整状态和轨线已保留，可由下游按前半/后半时段及合法历史窗口进一步评价。

## 7. Artifact Manifest 与收尾

| 证据 | 相对正式资源根目录的位置 |
| --- | --- |
| 完整文件与配置索引 | `release_manifest.json` |
| 最终读回证书 | `verification.json` |
| 元数据与种子隔离审计 | `metadata_audit.json` |
| 195 条独立数值探针 | `numerical_probes.json` |
| FPUT 子步资格历史 | `fput_refinement_history.json` |
| 配置、依赖、笔记与生成源码 | `frozen_config.json`、`Julia_Manifest.toml`、`protocol_note_snapshot.md`、`generator_source/` |
| 工况共享噪声参考 | 各资源目录 `noise_reference.json` |
| 旧版删除清单及旧发布索引 | `retirement_record.json`、`retired_v1_release_manifest.json` |

正式资源根目录：`data/releases/standard_odes_v2_20260916/`。当前指针为 `data/standard_odes_active.json`。中文报告的 `tables/resource_results.json` 保留本次资源汇总，`logs/` 保存 smoke 与正式执行日志副本。

复现命令与读取示例见[生成说明](../../docs/notes/file%20explanation/standard_odes_v2_file_explanation.md)。本次删除旧版 `data/processed/lowdim_nonlinear_v1`、`data/manifests/lowdim_nonlinear_v1` 和 `data/releases/lowdim_nonlinear_v1`，共回收 498,534,110 字节。旧笔记、历史报告和 Git 历史仍保留；项目原有的其他未提交修改未纳入本次完成提交。

## 8. 2026-09-16 后续仓库清理

按用户后续要求，主分支仅保留本轮 Standard ODE v2 及其生成、验证、报告和复现材料。234 个旧代码、配置、测试、笔记和报告文件，以及全部 9 处原有未提交修改，已保存到本地分支 `archive/abolish-pre-standard-odes-v2-20260916` 的 `abolish/` 下。归档提交为 `db6bc0a88a6d230fb1d4bf94b717658ee60f1566`，逐文件 SHA-256 和 Git 内容记录均通过核验。

其他正式数据及全部 smoke 临时数据已删除，共 1,837 个文件、5,819,595,100 字节（5.42 GiB）。Git 归档保留代码、报告和数据删除清单，不包含这些数值数据本身。历史 smoke 证书已另存于本报告的 `cleanup/smoke_verification_before_cleanup.json`。当前主仓库保留的数据仍为 34,432 条轨线、63,559,296 个状态快照，核心源码、物理配置和依赖锁未修改。

清理后再次运行的 370 项针对性测试全部通过；357 个视图文件的完整读回、哈希校验，以及 42 项必需字段的元数据审计全部通过。完整证据位于 `cleanup/`，清理说明见[仓库清理记录](../../docs/notes/file%20explanation/standard_odes_v2_cleanup.md)。本次不涉及数据再生成或模型训练；旧操作记录在主分支保留，其对应旧文件可从归档分支查阅。
