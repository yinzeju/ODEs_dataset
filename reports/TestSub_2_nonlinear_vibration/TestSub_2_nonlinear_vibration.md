---
title: TestSub2 非线性振动数据简报
experiment_id: TestSub_2_nonlinear_vibration
task_series_code: TestSub
task_code: "2"
release_id: testsub2_nv_20261004
status: dataset-qualified
date: 2026-10-04
paired_numeric_report: 2_numerical_appendix.md
pipeline_terminal_stage: frozen_dataset_verification
---

# TestSub2 非线性振动数据简报

## 0. 实验简述

本次任务依据用户指定的 [TestSub2 数学笔记](<D:/MyVault/Document/Obsidian/Notebook/系统辨识和模型学习/Koopman Space/Part 0 Evaluation & Benchmark/TestSub-2-ODE-FE-HV Nonlinear Vibration Dataset.md>)，生成用于后续系统辨识与模型学习的无外力自由衰减数据。旧 Structural Spectral v3 已退役，Standard ODE v2 保留。

实际生成对象为 Duffing8、固支梁、浅壳 NR、浅壳 IR12 和方板，共五个配置。Julia 完成机械模型装配、初值构造、基准与精细积分、资格检查和冻结发布；壳与板使用 GPU。按用户要求跳过 smoke、直接执行正式生成，并关闭额外噪声视图。HV 留待用户用 COMSOL 生成。

最终得到 **62 条 CAN 正式轨线和 12 条独立 QUAL 轨线**。每条轨线保存 4097 个 Float64 全状态快照，覆盖 32 个参考周期。发布目录共 **2.952 GB（2.749 GiB）**；全部数据通过数值资格和完整回读，可作为固定离散模型的后续学习数据。

| 身份项 | 本次取值 |
| --- | --- |
| 实验 / 数据版本 | `TestSub_2_nonlinear_vibration` / `testsub2_nv_20261004` |
| 方法与分支 | 完整机械方程积分；CPU Rodas5P 与 GPU Vern9 |
| 启用协议 | TestSub2 CAN、独立 QUAL、时间精细化、机械能量与访问边界检查 |
| 关闭 / 未执行 | 额外噪声与 smoke：`disabled`；严格 REPLAY：未执行；HV：外部待生成 |
| 学习模型训练与预测评分 | `N.A.`；本任务生成与验证数据，尚未训练学习模型 |
| 最终阶段 | 冻结数据集验证 `frozen_dataset_verification` |
| 数值记录 | [配套数值附录](2_numerical_appendix.md) |

## 1. 主要结果

主指标为笔记式 (12.1) 的全状态时间精细化误差。全部 CAN/QUAL 的最大值为 **$8.476424\times10^{-10}$**；能量平衡误差最大值为 **$2.049008\times10^{-10}$**，均通过预先规定的 $10^{-7}$ 门槛。这里的误差是基准积分与更严格积分之间的差异，不是相对未知精确解的严格误差上界，也不是学习模型的 Test 预测误差。

正式数据本体占 **2.439 GB**，资格轨线、机械模型、归一化参数和审计材料合计 **0.514 GB**。各配置的数量、维数、时间范围、误差和大小见[数值附录](2_numerical_appendix.md)。

## 2. 初始化

梁和 NR 壳从非线性静态加载平衡态释放；Duffing8、IR12 壳和板使用规定的纯模态及独立正系数混合初态。全部初速度为零，释放后没有动态外力，不设置 burn-in，也不裁去早期瞬态。划分单位是完整轨线，Train、Validation、Test 与 QUAL 不复用初态。

原始状态按 $\mathbf{x}=\operatorname{col}(\mathbf{q},\mathbf{v})$ 保存，位置和速度同时保留。单独保存仅由完整 Train 快照计算的通道均值和标准差，原始数据不被标准化覆盖。

## 3. 正式求解与调整

Duffing8 与梁使用 Float64 Rodas5P；已发布轨线绑定的是 UMFPACK 版本。壳和板最终使用 GPU Vern9，在保留全部机械模态的可逆坐标系中积分，再恢复为原始物理坐标；没有模态截断。每条轨线都完成收紧容差、最大内部步长减半的复算，并保存精细解。

最初的全状态 CPU 壳积分耗时较长。尝试 GPU ETDRK4 后，两组已完成候选仍未达到状态与能量门槛；直接物理坐标 GPU 方法在严格容差下也推进缓慢。最终完整模态坐标 Vern9 在独立 QUAL 上通过检查后用于正式生成。数值门槛、物理方程与数据预算均未放宽，CAN Test 未用于选容差或筛选轨线。具体设置及前后证据见附录“求解调整记录”。

## 4. 冻结后处理

实际依赖链为：机械模型与预声明初值 → 通过资格的精细轨线 → Train-only 归一化参数与学习访问清单 → 文件校验目录 → 发布清单和活动入口。

机械矩阵、模态、完整初值参数与能量审计保存在评价端目录；学习加载器只读取允许列表中的 CAN 状态与时间。发布文件逐一登记 SHA-256，源代码、依赖环境和数学笔记按对应生成版本冻结。

## 5. 最终冻结验证与边界

CPU 45 项、GPU 46 项针对性检查全部通过。五个配置的全量回读通过，包含形状、时间网格、零初速度、初态不重用、Train-only 统计量和证书一致性检查。再次只读验证确认发布清单和活动入口未改变；本次收尾又核对全部 **423 个已登记文件**以及精确文件集合，均通过。

本次结论适用于冻结 FE 网格的完整半离散方程；没有进行连续体网格收敛研究，也不宣称严格复现论文的单条轨线。GPU 原子累加允许浮点末位差异，重新生成不保证逐位相同。HV、噪声视图和下游学习模型的泛化能力不属于本次完成范围。

## 6. 产物与可追溯性

| 产物 | 入口与用途 |
| --- | --- |
| 冻结数据集 | [发布清单](../../data/releases/testsub2_nv_20261004/TestSub2/release_manifest.json)，定义五个配置、资格结果和源版本绑定 |
| 当前数据入口 | [活动指针](../../data/testsub2_nv_active.json)，绑定发布清单 SHA-256 |
| 再验证入口 | [PowerShell 入口](../../experiments/data_generation/run_testsub2_nv.ps1)，已发布时只做验证 |
| 数值与证据 | [数值附录](2_numerical_appendix.md)、[收尾证据](TestSub_2_nonlinear_vibration_evidence.json) |

旧代码保存在本地分支 `codex/abolish-structural-spectral-v3-20261004`，提交 `5c6d43b5387ef62c293ea7246b475dddf2dd1e94`。旧数据及运行输出删除量为 60,701,383,344 字节；代码归档不包含已删除的数值数据。

报告结构采用本次经认证 GitHub 接口读取的 [云端 Exp2 协议](https://github.com/yinzeju/Notebook/blob/main/系统辨识和模型学习/Koopman%20Space/Part%200%20Evaluation%20%26%20Benchmark/SKDM-Exp2-Experimental%20Reporting%20Protocol.md)，读取日期为 2026-10-04，文件 blob SHA 为 `7fa370f128dec078ef35baf47ac9ce01fcd49e70`。数学笔记当前 SHA-256 与两组冻结源绑定中的副本一致。
