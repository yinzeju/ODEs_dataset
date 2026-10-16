---
title: Dataset-2 与 Dataset-2.1 数据资源整理
experiment_id: Dataset_2_v2_resource_reorganization
task_series_code: Dataset
task_code: "2"
reuse_code: v2
date: 2026-10-16
paired_numeric_report: 2_numerical_appendix.md
pipeline_terminal_stage: frozen_data_organization_and_integrity_audit
---

# Dataset-2 与 Dataset-2.1 数据资源整理

## 0. 实验简述

本次工作统一结构动力学数据的协议身份和本地入口，消除旧 TestSub_2 少轨线人口、学习任务号命名和 NACA 多版本硬链接路径混杂。先修改用户指定的 Dataset-2 数学笔记，再整理现有数据；没有启动新仿真、学习或独立数值资格实验。

最终可用正式人口为三组各144条轨线，共432条。基础梁保留完整8193帧；强瞬态梁建立从释放初态开始的4096帧精确前缀，原始4097帧的144条文件及证书仍在谱系目录；机翼保留4096帧和原物理模型。每组均为96/24/24。快照数包含初态，时间区间数等于快照数减一。[完整数值记录](2_numerical_appendix.md)。

机翼全部状态、端口、精确初态、文件SHA及原运行门槛复核通过，144个文件均只有一个NTFS硬链接名称，集中于 `data/Dataset-2.1/`。旧发布与扩展容器已移除。清理实际释放 13.752701 GiB 分配空间；这是删除阶段的毛释放量，不扣除新增前缀和元数据所占空间。

| 身份 | 内容 |
|---|---|
| 方法 | 保留字节的目录移动、确定性状态前缀、显式谱系与哈希审计 |
| 主要指标 | 当前正式人口432条，三组各96/24/24，保留原件完整性 |
| 选择指标 | N.A.，没有模型选择或预测评分 |
| 终止阶段 | 冻结后的数据整理与完整性复核 |
| 最终入口 | `data/dataset2_active.json`、`data/dataset21_active.json` |
| 未执行 | 新积分、壳板新版人口、学习训练、独立时间／空间资格实验 |

## 1. 主结果

三组保留人口均满足144条轨线和互不重叠的原split。基础梁原件与机翼原件字节不变；强瞬态前缀逐元素等于原始记录前4096帧，初态和时间间隔不变。删除Dataset-1、旧TestSub_2 CAN/QUAL及废弃运行数值文件后，代码、配置、原证书和历史元数据仍可追溯，归档分支不包含已删除的原始轨线。

浅壳NR、IR12及方板FE200保留原数学模型，新预算统一为96/24/24与4096帧，当前本地人口均为零，合计432条待后续单独授权生成。不能把本次整理称为整个新版Dataset-2人口已完成。

## 2. 初始化与协议修订

数学来源为用户指定的 [Dataset-2笔记](D:/MyVault/Document/Obsidian/Notebook/系统辨识和模型学习/Koopman%20Space/Part%200%20Evaluation%20&%20Benchmark/Dataset-2-Nonlinear%20Structural%20Dynamics.md)。删除OSC-DUFFING8，明确两组梁共享弹性势能、材料与FE12网格；强瞬态配置使用原阻尼的0.75倍，并在6–10mm静态构型上叠加横向最大位移为静态幅值0.25倍的带符号第二模态。该比例不是模态能量比例；叠加后初态不再声称满足原静态平衡。基础梁使用1.5–2.5mm静态释放。原始幅值、split及初速度均保留。

## 3. 训练／主求解

N.A.。本次积分调用数为零。没有补算机翼、重新求解初态、更新学习模型或用Test误差决定数据取舍。数据删除由用户明确指定的对象范围决定。

## 4. 冻结后构建与清理

执行链为：协议笔记修订 → 原源码归档与删除清单冻结 → 原件目录移动 → 强瞬态精确前缀与完整回读 → 保留原件SHA核验 → 授权删除 → 机翼完整复核。前缀工程检查先通过6项合同，再处理原144条记录。

机翼父版本曾共享的接受文件在最终文件SHA核验后解除旧路径，当前每条只保留一个文件名称。原父清单、源capsule、worker记录和13个失败／暂停前缀作为历史证据保存。可视化不重绘，原146项迁移记录的字节保持一致，当前103个离线链接通过。

## 5. 最终冻结验收与边界

Dataset-2全部288条当前梁轨线通过文件哈希、状态／时间完整回读和split检查；机翼144条通过全部保存状态、连接件端口、精确初态、原数值门槛及SHA复核，原发布清单SHA为 `614c4fc54c6c1cfdd92afc976d7621bfd47893acb3573653458f77d25afcc9a0`。

机翼仍标记 `user_waived_independent_qualification`。强瞬态前缀继承原记录所覆盖前缀的数值证据，不把原4097帧终点指标改称当前终点指标。外部 `InvSub/202609` 的历史学习配置仍含旧路径，后续重跑前须按新入口重绑定；本次没有修改学习项目。

## 6. 产物与复现清单

当前目录为 `data/Dataset-2/VK-BEAM-CC/{BASE,TRANSIENT}/` 与 `data/Dataset-2.1/`。读取入口和历史路径映射见 `configs/dataset_catalog.json`、`data/dataset_relocations.json`。数值文件、源capsule和本地归档不随Git恢复；Git保存代码、配置、记录和紧凑证据。

本报告按本次从GitHub认证获取的Exp2结构组织：[云协议](https://github.com/yinzeju/Notebook/blob/main/系统辨识和模型学习/Koopman%20Space/Part%200%20Evaluation%20%26%20Benchmark/SKDM-Exp2-Experimental%20Reporting%20Protocol.md)，blob `7fa370f128dec078ef35baf47ac9ce01fcd49e70`，获取日期2026-10-16。[整理证据](evidence/reorganization.json)；[数值附录](2_numerical_appendix.md)。
