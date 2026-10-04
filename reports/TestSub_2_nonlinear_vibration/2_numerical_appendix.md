---
title: TestSub2 非线性振动数据数值附录
experiment_id: TestSub_2_nonlinear_vibration
task_series_code: TestSub
task_code: "2"
paired_main_report: TestSub_2_nonlinear_vibration.md
release_id: testsub2_nv_20261004
date: 2026-10-04
---

# TestSub2 非线性振动数据数值附录

[返回主报告](TestSub_2_nonlinear_vibration.md)。本附录取值来自冻结发布清单、每条轨线证书及机械装配记录，机器可读依据为[收尾证据](TestSub_2_nonlinear_vibration_evidence.json)。所有表均描述实际完成的 ODE/FE CAN 与独立 QUAL；学习模型训练、优化器、checkpoint 选择与预测评分均为 `N.A.`。

## 1. 数据规模与状态合同

完整状态为 $\mathbf{x}=\operatorname{col}(\mathbf{q},\mathbf{v})\in\mathbb{R}^{2n_q}$。数组行是状态通道、列是时间，按消去约束后的原始节点自由度顺序排列。每条轨线都有 4097 个 Float64 快照；从释放时刻开始，初速度、动态外力和 burn-in 均为零。

| 配置 | $n_q$ | 状态维数 | Train / Val / Test | CAN 合计 | 独立 QUAL |
| --- | --- | --- | --- | --- | --- |
| Duffing8 | 8 | 16 | 12 / 4 / 4 | 20 | 4 |
| Beam FE12 | 33 | 66 | 3 / 1 / 2 | 6 | 1 |
| Shell NR | 1320 | 2640 | 3 / 1 / 2 | 6 | 1 |
| Shell IR12 | 1320 | 2640 | 9 / 3 / 3 | 15 | 3 |
| Plate FE200 | 606 | 1212 | 9 / 3 / 3 | 15 | 3 |

CAN 总计 62 条，划分总数为 36 / 12 / 14；QUAL 共 12 条。CAN 共 254,014 个完整状态快照，QUAL 共 49,164 个。不同配置的状态维数不同，因此快照总数不等于标量元素数。

参考周期为 $P_\star=2\pi/\omega_\star$，输出间隔 $\tau=P_\star/128$，记录长度 $T_{\mathrm{rec}}=32P_\star$。Duffing 时间单位为无量纲模型时间，其余时间单位为秒；同一配置所有轨线使用相同冻结网格。

| 配置 | 参考模态 | $P_\star$ | $\tau$ | $T_{\mathrm{rec}}$ |
| --- | --- | --- | --- | --- |
| Duffing8 | 1 | 6.20874493529 | 0.048505819807 | 198.679837929 |
| Beam FE12 | 1 | 0.00955292419443 | 7.4632220269e-05 | 0.305693574222 |
| Shell NR | 1 | 0.0426108041052 | 0.000332896907072 | 1.36354573137 |
| Shell IR12 | 1 | 0.0421057460414 | 0.000328951140949 | 1.34738387333 |
| Plate FE200 | 2 | 0.00822843899773 | 6.42846796698e-05 | 0.263310047928 |

## 2. 机械参数与初值

Duffing8 无量纲参数为质量 $m=1$、黏性系数 $c=0.02$、地基刚度 $k_{\mathrm g}=1$、耦合刚度 $k_{\mathrm c}=0.2$、三次刚度 $\alpha=0.1$，两端位移固定。全部 FE 使用 $E=70\,\mathrm{GPa}$、$\rho=2700\,\mathrm{kg/m^3}$；壳与板的泊松比为 $0.33$。

| 配置 | 长 / 宽 / 厚（m） | 网格与约束 | 曲率高度（m） | 实际阻尼 |
| --- | --- | --- | --- | --- |
| Beam FE12 | 1 / 0.05 / 0.02 | 12 个单元；横向三次 Hermite、轴向线性；两端固支 | N.A. | $\mathbf C=(10^6/E)\mathbf K$，材料阻尼模量 $10^6\,\mathrm{Pa\,s}$ |
| Shell NR | 2 / 1 / 0.01 | 400 个 Allman 三角形；两相对边平移约束 | 0.1 | $a_{\mathrm M}=0.402153037835$，$a_{\mathrm K}=8.63116746107\times10^{-6}$ |
| Shell IR12 | 2 / 1 / 0.01 | 400 个 Allman 三角形；两相对边平移约束 | 0.041 | $a_{\mathrm M}=0.398078548249$，$a_{\mathrm K}=8.92846854055\times10^{-6}$ |
| Plate FE200 | 1 / 1 / 0.01 | 200 个 Allman 三角形；四边平移约束 | 0 | $a_{\mathrm M}=1$，$a_{\mathrm K}=4\times10^{-6}$ |

壳/板采用 $\mathbf C=a_{\mathrm M}\mathbf M+a_{\mathrm K}\mathbf K$，其中 $a_{\mathrm M}$ 单位为 $\mathrm{s^{-1}}$，$a_{\mathrm K}$ 单位为秒；壳的前两模态阻尼比均按 $0.20\%$ 构造。壳/板保留公开 Allman 单元的局部质量、旋转装配和非线性面内剪切实现。梁使用五点 Gauss 积分。

初值规则如下。静态对象的幅值是规定 probe 的位移；壳 IR12 和板的模态幅值是全部平移通道的最大绝对值。下列 FE 幅值统一以毫米表示。

| 配置与初值族 | Train | Validation | Test | QUAL |
| --- | --- | --- | --- | --- |
| Duffing8：模态 1/2/3 与三模态正混合；按非线性暴露量设幅值 | 0.01 / 0.07 / 0.20 | 0.045 | 0.135 | 0.11 |
| Beam FE12：中点静态释放（mm） | 1.5 / 2.0 / 2.5 | 1.8 | 1.6 / 2.2 | 2.3 |
| Shell NR：静态 probe 释放（mm） | 10.5 / 12.0 / 13.5 | 11.0 | 10.0 / 12.5 | 12.8 |
| Shell IR12：模态 1、2、混合（mm） | 2.4 / 3.2 / 4.0，各三方向 | 3.6，各三方向 | 3.92，各三方向 | 4.16，各三方向 |
| Plate FE200：模态 2、3、混合（mm） | 3.6 / 4.8 / 6.0，各三方向 | 5.4，各三方向 | 5.88，各三方向 | 6.24，各三方向 |

Duffing 混合方向的暴露量另乘 $0.96+0.08U$，其中 $U\sim\mathrm{Uniform}(0,1)$。混合系数由独立 $0.25+U$ 生成并归一化。随机数发生器为 Xoshiro；其 UInt64 种子由命名空间字符串 SHA-256 的前八字节按大端顺序构造：`TestSub2-NV-20261004/object_id/configuration_id/resource/split/i/family/level/mixture/clean`。实际逐轨线混合系数、幅值及静态载荷保存在各配置的 `audit_only/trajectory_manifests/`。

暴露量 $r_{\mathrm{nl}}$ 按笔记式 (2.8) 计算，采用冻结数值尺度的位移块及 $\varepsilon_{\mathrm{num}}=\operatorname{eps}(\mathrm{Float64})$。它用于描述初态，不参与 Test 轨线筛选。

| 配置 | 实际 CAN 初态非线性暴露量范围 |
| --- | --- |
| Duffing8 | 0.01 — 0.200282347 |
| Beam FE12 | 0.772535762 — 0.895921481 |
| Shell NR | 0.997223334 — 0.998052426 |
| Shell IR12 | 15.571974 — 78.0170184 |
| Plate FE200 | 16.3936068 — 32.8568144 |

## 3. 求解配置与保存规则

Julia 版本为 1.12.5。GPU 为 NVIDIA GeForce RTX 4070 SUPER，壳/板保留全部机械模态，位移与速度实分量均采用 Float64 精度。完整依赖版本以两个环境的 `Manifest.toml` 及各生成绑定的冻结副本为准。

| 适用对象 / 阶段 | 算法 | 相对容差 | 绝对容差 | 最大内部步长 |
| --- | --- | --- | --- | --- |
| Duffing8、梁 / base | Rodas5P + UMFPACK + 解析 Jacobian | 2e-10 | 2e-12 | $P_\star/256$ |
| Duffing8、梁 / fine | 同上 | 2e-12 | 2e-14 | $P_\star/512$ |
| 壳、板 / base | GPU Vern9；完整可逆模态坐标 | 1e-8 | 1e-10 | $P_\star/128$ |
| 壳、板 / fine | 同上 | 2e-10 | 2e-12 | $P_\star/256$ |

发布的是 fine 轨线。当前 CPU 源码已包含后续尝试的 KLU 选项，而本批 CPU 轨线的真实生产版本为上表的 UMFPACK；两者不能混同。完整源绑定见第 7 节。

数值误差尺度为 $\mathbf D_{\mathrm{num}}=\operatorname{diag}(\mathbf s_q,\omega_\star\mathbf s_q)$。Duffing 的 $\mathbf s_q$ 各分量为 1，梁为 0.02，壳/板为 0.01，分别按各通道的物理单位解释；此尺度是数值缩放，不是学习标准化或物理度量。Train-only 标准化使用完整 Train 快照的总体标准差，逐通道下限为冻结数值尺度的 $10^{-12}$ 倍，且不覆盖原始状态。

## 4. 最终冻结资格结果

定义
$$
\varepsilon_{\mathrm{state}}=
\max_m\frac{\lVert\mathbf D_{\mathrm{num}}^{-1}(\mathbf x_m^{\mathrm{base}}-\mathbf x_m^{\mathrm{fine}})\rVert_2}
{\max\{1,\lVert\mathbf D_{\mathrm{num}}^{-1}\mathbf x_m^{\mathrm{fine}}\rVert_2\}}.
$$

机械能 $E$ 包括动能和完整非线性势能；耗散功 $W_{\mathrm d}$ 随积分累计，其导数为 $\mathbf v^\top\mathbf C\mathbf v$。能量检查为
$$
\varepsilon_E=\max_m\frac{\lvert E(t_m)+W_{\mathrm d}(t_m)-E(0)\rvert}{\max\{E(0),\operatorname{eps}(\mathrm{Float64})\}}.
$$
GPU 路径使用正的 $E(0)$ 作分母，本批初能量均远大于机器 epsilon。两类误差门槛均为 $10^{-7}$；base 与 fine 均检查能量，最小阻尼功率容差为 $-10^{-12}$。

下表状态误差取相应完整轨线集合的最大值，能量误差对其 base/fine 两次积分共同取最大值；没有将较小的 fine-only 指标冒充两次积分的最大值。

| 配置 | CAN 最大状态误差 | CAN 最大能量误差 | QUAL 最大状态误差 | QUAL 最大能量误差 |
| --- | --- | --- | --- | --- |
| Duffing8 | 8.476423971e-10 | 2.049008176e-10 | 2.735686516e-10 | 1.197418769e-10 |
| Beam FE12 | 1.119641503e-11 | 2.179296812e-12 | 8.833609207e-12 | 1.614592402e-12 |
| Shell NR | 1.239760555e-11 | 1.056812556e-11 | 1.125348649e-11 | 9.809487489e-12 |
| Shell IR12 | 2.088224098e-11 | 2.468887238e-11 | 1.929639587e-11 | 1.752395029e-11 |
| Plate FE200 | 3.723958860e-11 | 8.482216504e-13 | 3.539766182e-11 | 6.834558681e-13 |

附加检查均通过：45 项 CPU 与 46 项 GPU 针对性检查、完整轨线回读、训练统计量复核、CAN/QUAL 初态分离和学习加载器审计路径拒绝。下表给出机械装配诊断；这些有限差分/线性模型诊断与上表的时间积分指标含义不同。

| 配置 | 势能梯度相对差 | 非线性切向相对差 | 模态方程相对残差 | 公开刚度一致性 | 公开阻尼一致性 |
| --- | --- | --- | --- | --- | --- |
| Duffing8 | 4.400126e-12 | 1.173913e-08 | 3.452110e-16 | N.A. | N.A. |
| Beam FE12 | 2.207755e-13 | 9.116565e-12 | 2.150353e-11 | N.A. | N.A. |
| Shell NR | 2.444003e-11 | 2.897380e-12 | 3.056471e-10 | 1.079465e-14 | 7.255125e-13 |
| Shell IR12 | 4.842073e-12 | 2.811234e-12 | 2.709186e-10 | 9.336652e-15 | 4.313963e-12 |
| Plate FE200 | 1.146897e-08 | 3.419179e-12 | 5.241363e-11 | 4.235356e-15 | 4.237381e-15 |

公开矩阵一致性只对壳和板有对应参考数据。完整状态的运动学 RHS 复核最大残差为 4.471406e-15。未执行连续体网格收敛研究、学习训练或预测测试；它们的结果为 `N.A.`。

## 5. 求解调整记录

初始目标是在完整状态、既定精度及 32 周期条件下可行地生成全部轨线。所有调整保持物理方程、CAN 数量、Float64 精度和最终资格门槛不变。

| 原方案 / 观察 | 调整与原因 | 实际前后证据 / 处置 |
| --- | --- | --- |
| CPU Rodas5P + UMFPACK 完成 ODE/梁，但壳推进较慢 | 尝试 KLU 减少稀疏分解成本，随后将高维积分转向 GPU | 未完成 CPU 壳运行停止；已资格通过的 ODE/梁不重写 |
| 早期 ETDRK4 非有限结果 | 将被 Julia 解析为 Float32 字面量的 `2f2` 改为明确的 `2*f2` | 补充解析标量解回归检查；错误候选未发布 |
| ETDRK4 每输出间隔 8/16 子步 | 增加到 64/128 子步以检查细化 | 状态误差 1.417989e-2 → 4.623928e-6；fine 能量误差 1.470215e-3 → 8.051420e-7，仍失败，拒绝发布 |
| GPU 直接物理坐标 Vern9 在严格容差下过慢 | 改用缩放后的完整可逆模态坐标，保留全部自由度 | 独立完整 QUAL 通过；没有用模态截断获得加速 |
| 严格完整模态 fine 参考计算耗时 521.337 s | 独立 QUAL 比较 base 1e-8/1e-10 与 fine 2e-10/2e-12，并将步长上限减半 | base 360.329 s；状态差 2.576455e-11，base/fine 能量误差约 9.92e-12 / 9.83e-12，接受该配置 |
| 小 GPU batch 的通用矩阵乘法效率有限 | 对 batch 2–8 使用完整基变换的自定义 Float64 点积核 | 变换基准与 46 项 GPU 检查通过；积分参数及已发布数据不变，每条正式轨线仍独立资格检查 |

完整调整记录与原始证据在发布目录 `audit_only/validation/integration_adjustment_history.json` 及同目录相关 JSON/日志；收尾证据保留主要记录。选参依据为独立 QUAL，未按 CAN Test 结果反向选参。

| 配置 | base 求解时间（s） | fine 求解时间（s） | 合计（s） | 计时口径 |
| --- | --- | --- | --- | --- |
| Duffing8 | 12.679 | 10.650 | 23.329 | CAN+QUAL 逐次积分求和 |
| Beam FE12 | 21.430 | 43.798 | 65.228 | CAN+QUAL 逐次积分求和 |
| Shell NR | 473.258 | 662.083 | 1135.340 | CAN+QUAL 同一批次，仅计一次 |
| Shell IR12 | 858.222 | 1213.587 | 2071.808 | CAN+QUAL 同一批次，仅计一次 |
| Plate FE200 | 174.957 | 251.544 | 426.500 | CAN+QUAL 同一批次，仅计一次 |

上表最终成功积分合计 3722.206 s（约 62.04 min），不代表整个开发任务耗时；不含已停止候选、调试、缓存准备、装配、回读和文档工作。完整开发总耗时及峰值内存/显存为 `not recorded`。

## 6. 存储大小

使用实际文件长度；MB = 1,000,000 字节，GB = 1,000,000,000 字节，GiB = 1,073,741,824 字节。辅助文件包含独立 QUAL、归一化参数、机械模型、证书与审计材料。

| 配置 | 正式 CAN（MB） | 辅助文件（MB） | 合计（MB） | 合计精确字节 |
| --- | --- | --- | --- | --- |
| Duffing8 | 11.17 | 4.70 | 15.87 | 15,874,149 |
| Beam FE12 | 13.18 | 2.95 | 16.13 | 16,130,022 |
| Shell NR | 519.38 | 103.05 | 622.42 | 622,421,684 |
| Shell IR12 | 1298.44 | 277.31 | 1575.75 | 1,575,747,852 |
| Plate FE200 | 596.38 | 124.53 | 720.91 | 720,913,091 |
| 共享发布与审计 | — | 1.03 | 1.03 | 1,029,122 |
| 总计 | 2438.55 | 513.56 | 2952.12 | 2,952,115,920 |

总计 425 个文件、2.952115920 GB（2.749372199 GiB）。其中 423 个数据与审计文件由 catalog 登记，另两个文件是 catalog 自身和根发布清单。统计不含本报告目录、依赖缓存、项目 runs 目录和 Standard ODE v2。HV 与噪声数据未生成。

## 7. 版本、来源与证据入口

| 对象 | 版本或校验值 |
| --- | --- |
| 发布清单 SHA-256 | `9069e4f8c0d215a879cd2eb66a3b910b279f5750dd41c08d2fcab675ab9d1756` |
| artifact catalog SHA-256 | `94f04c02b700d8a9882ae2f04a7bdaa1873272be12c802b533a2d24fd2f768bd` |
| 数学笔记 SHA-256 | `173eff90d848d7abb8a56b7620b007ce6c0dc0a5371618515ecf6fd940bef58e` |
| CPU 生成绑定 | `add4a54bd864922b9c3c7cc3374ffe9ca6611d74bed638e54061fc1244938ba8` |
| GPU 生成绑定 | `2324b2de66bd648313c920d13da3b1b8a8b6ccf6addab61ad67fe290ec5c8a98` |
| SSMLearn 源提交 | `305581114f62239b70c1fe44bce69cbf939326ea` |
| YetAnotherFEcode v1.1 源提交 | `50bc5c5ba75f2b5b32c5753dedcbd60612444f0d` |
| Exp2 云端文件 blob SHA | `7fa370f128dec078ef35baf47ac9ce01fcd49e70`；2026-10-04 从默认分支读取 |

各配置在 `manifests/learner_manifest.json` 声明逐轨线路径、SHA-256、物理单位与通道顺序，在 `qualification/` 保存 CAN/QUAL 数值证书和机械装配证据。源快照内保存完整配置、依赖版本及精确数学笔记。公开 FE 来源见 [SSMLearn](https://github.com/haller-group/SSMLearn/tree/305581114f62239b70c1fe44bce69cbf939326ea/examples) 与 [YetAnotherFEcode](https://github.com/jain-shobhit/YetAnotherFEcode/tree/50bc5c5ba75f2b5b32c5753dedcbd60612444f0d)。

全量回读日志：`runs/testsub2_nv/final_verification.log`、`runs/testsub2_nv/frozen_verification.log`。收尾重新校验所有 catalog 文件、精确文件集合、活动指针与数学笔记；审计时间为 `2026-10-04T06:58-07:00`。报告与收尾文件位于发布目录外，不改变已冻结数据集的哈希或存储大小。

旧数据清理范围：旧 release 60,575,313,099 字节、旧 runs 126,069,997 字节、旧 active pointer 248 字节，总计 60,701,383,344 字节。相关代码与退役清单在归档提交中保留；Standard ODE v2 活动指针 SHA-256 仍为 `491bca6405ae5d756a5b340564cf337fb53faf70b80a3417bdfc6e985acb1158`。
