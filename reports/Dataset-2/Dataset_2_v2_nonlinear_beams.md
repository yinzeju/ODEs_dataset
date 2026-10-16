---
title: Dataset-2 两组非线性梁数据报告
experiment_id: Dataset_2_v2_nonlinear_beams
task_series_code: Dataset
task_code: "2"
reuse_code: v2
date: 2026-10-16
paired_numeric_report: 2_numerical_appendix.md
pipeline_terminal_stage: frozen_dataset_integrity
---

# Dataset-2 两组非线性梁数据报告

## 0. 实验简述

Dataset-2 当前可用数据由两组两端固支 von Kármán 梁组成，用于研究完整状态自由衰减及瞬态动力学。基础配置BASE沿用较小幅值的非线性静态释放；TRANSIENT通过更大静态幅值、第二弯曲模态扰动及较小阻尼形成较长的多模态瞬态。两者具有共同材料、几何、有限元网格与弹性势能，但阻尼不同，因此分别登记为两个物理配置。

本报告汇总已有真值生成、时间细化资格证据，以及当前冻结数据的完整性结果。每组包含144条独立轨线，Train/Validation/Test为96/24/24，保留66维完整位移—速度状态。BASE完整保留8193个快照；TRANSIENT使用原4097帧记录的前4096帧，原件及证书另存谱系。快照数包含初态。本轮报告整理没有执行新积分或学习训练。

两组当前人口合计288条，均完成保存状态和时间回读。原始求解的时间细化误差、能量审计及当前前缀一致性支持这些冻结资源的使用边界；它们不证明连续体网格收敛、任意初态覆盖或非线性SSM严格不变性。[完整数值附录](2_numerical_appendix.md)。

| 报告身份 | 内容 |
|---|---|
| 数据对象 | Dataset-2 / VK-BEAM-CC / BASE与TRANSIENT |
| 方法／分支 | 完整非线性FE12自由衰减；两种阻尼与初态配置 |
| 数学协议 | 用户指定的[Dataset-2笔记](<D:/MyVault/Document/Obsidian/Notebook/系统辨识和模型学习/Koopman Space/Part 0 Evaluation & Benchmark/Dataset-2-Nonlinear Structural Dynamics.md>) |
| 主要指标 | 固定人口数、完整回读、源文件与前缀完整性；源时间细化误差 |
| 选择指标 | N.A.，没有学习模型或Test驱动的数据选择 |
| 冻结产物 | `dataset2_structural_v2_20261016`中两组梁 |
| 配套数值报告 | [2_numerical_appendix.md](2_numerical_appendix.md) |

## 1. 主结果

每组144条母轨线均使用预先固定的幅值网格和原split，窗口不作为新增轨线计数。BASE只有一族静态释放，人口增加主要来自幅值加密；不能把144条解释为广泛相位或初速度覆盖。TRANSIENT的第二模态线性能量在首个512帧区间占比为30.5%–31.2%，全部144条到从第2048步开始的区间才低于5%，最后区间第一模态占比为98.7%–99.0%。这些诊断覆盖当前4096帧前缀，描述模态衰减，不等于非线性SSM距离。

原始BASE与TRANSIENT最大时间细化状态误差分别为2.2150e-11、1.0812e-10，低于原1e-7门槛。当前TRANSIENT逐元素等于原始状态前缀，没有重采样或修改初态。完整参数、误差定义与证据见[数值附录](2_numerical_appendix.md)。

## 2. 初始化

模型采用12个梁单元；约束消元后33个机械自由度形成66维完整状态，没有动力学模态截断。BASE在1.5–2.5mm中点幅值区间求解非线性静态平衡后移除静载。TRANSIENT在6–10mm静态构型上叠加带符号第二弯曲模态，令其横向最大位移为静态幅值的0.25倍，并把阻尼降为BASE的0.75倍。该0.25是位移比例，不是能量比例；叠加后的构型不再声称满足叠加前的静态平衡。两组初速度均为零，从释放时刻记录，无动态外力与burn-in。

幅值均为144点等距网格，每组六个递增幅值的偏移0、1、4、5属于Train，偏移2属于Validation，偏移3属于Test；强瞬态扰动符号按六点分层交替。数据存储为原物理单位，学习器的normalizer必须另按Train数据拟合。

## 3. 原始主求解

原始人口由冻结的完整非线性梁核、Float64 Rodas5P/UMFPACK和解析Jacobian生成，每条轨线均有收紧容差与减半最大内部步长的时间细化对照。BASE记录32个参考周期；TRANSIENT原始记录16个参考周期。当前4096帧前缀的终点比原4097帧终点早一个输出间隔，不能混用终点诊断。

原生成完成receipt记录了源时间细化状态误差和能量误差。本轮仅读取既有证据，没有重新执行主求解、连续体网格细化或训练。学习器checkpoint、优化器与预测Test评分均为N.A.。

## 4. 冻结后构建

当前BASE保留原SKDM9文件字节与完整时间历史；TRANSIENT由明确的原144条记录确定性截取前4096帧，新文件逐元素完整回读并绑定源SHA和初态SHA。原始4097帧文件保存在 `data/Dataset-2/VK-BEAM-CC/TRANSIENT/provenance/source_release/`，不重复计入当前正式人口。历史生成ID作为谱系保留，当前对象名称以Dataset-2协议代号为准。

## 5. 最终冻结验收与解释边界

当前两组梁共288条通过完整状态／时间回读、哈希、布局及split检查，强瞬态144条通过精确前缀回读。原资格证据属于固定网格、固定物理配置和固定人口。BASE与TRANSIENT同时改变幅值、初态构造和阻尼，是配置组合差异，不能把瞬态变化单独归因于某一个因素。该数据报告不登记任何学习模型性能或泛化结论。

浅壳NR、IR12与方板FE200仍在数学协议中，预算各为96/24/24与4096帧，但当前本地新版人口为零。已删除的旧TestSub_2少轨线数据不能作为其当前完成证据。NACA机翼属于独立[Dataset-2.1报告](../Dataset-2.1/Dataset21_NLC6_v1_nonlinear_wing.md)。

## 6. 数据与复现清单

| 当前对象 | 入口 |
|---|---|
| Dataset-2当前人口 | `data/dataset2_active.json`、`data/Dataset-2/release_manifest.json` |
| 两组梁的冻结配置 | `configs/releases/dataset2_structural_v2.json` |
| 逐条当前读取 | `experiments/data_generation/verify_dataset2.jl` |
| 报告数值证据 | [evidence/data_report.json](evidence/data_report.json) |
| 原BASE验收记录 | [原SKDM9证据](evidence/source_skdm9_beam_extension.json) |
| 完整数值事实 | [2_numerical_appendix.md](2_numerical_appendix.md) |

本报告按认证获取的Exp2云协议组织，blob为 `7fa370f128dec078ef35baf47ac9ce01fcd49e70`，获取日期2026-10-16；[来源记录](evidence/report_protocol.json)。源capsule、完整原始数据及大体积媒体保存在本地，不随Git恢复。
