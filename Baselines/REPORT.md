# 官网示例验证报告

快照时间：2026 年 10 月 20 日 23:17（北京时间）。

覆盖总览与 32 个详情页，共 659 次示例展示，去重后为 600 份原始源码。官网静态页面中的 659 次展示均有 SVG。

首轮可生成 227 份，本轮可生成 304 份，剩余 296 份记录为待支持。

这里的可生成表示完成原生解析与布局、SVG XML 有效及场景边界检查通过，不代表文字语义完整或与 Pele 像素一致。

每份源码都在自然宽度以及 320、480、640 点宽度下尝试渲染。部分图形仍保留自然宽度，画布可以缩放和平移。

[打开逐例图像对照](report.html)

| 图形 | 可生成 | 待支持 | 总数 |
| --- | ---: | ---: | ---: |
| agentflow | 0 | 12 | 12 |
| architecture | 2 | 4 | 6 |
| block | 15 | 15 | 30 |
| c4 | 0 | 6 | 6 |
| class | 33 | 9 | 42 |
| cynefin | 3 | 0 | 3 |
| er | 4 | 22 | 26 |
| eventmodeling | 7 | 5 | 12 |
| flowchart | 98 | 76 | 174 |
| gantt | 2 | 9 | 11 |
| gitGraph | 12 | 23 | 35 |
| ishikawa | 0 | 1 | 1 |
| journey | 1 | 0 | 1 |
| kanban | 1 | 2 | 3 |
| mindmap | 9 | 6 | 15 |
| packet | 2 | 2 | 4 |
| pie | 2 | 1 | 3 |
| quadrantChart | 1 | 2 | 3 |
| radar | 2 | 1 | 3 |
| railroad | 3 | 11 | 14 |
| requirement | 5 | 5 | 10 |
| sankey | 4 | 4 | 8 |
| sequence | 36 | 3 | 39 |
| state | 22 | 3 | 25 |
| swimlane | 12 | 2 | 14 |
| timeline | 9 | 7 | 16 |
| treeView | 2 | 12 | 14 |
| treemap | 2 | 6 | 8 |
| usecase | 1 | 23 | 24 |
| venn | 7 | 1 | 8 |
| wardley | 4 | 16 | 20 |
| xychart | 3 | 7 | 10 |

## agentflow

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-d0feca50d6211e21](report.html#official-d0feca50d6211e21) | 待支持 | [第 37 例](https://pele.run/examples) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-4c546d7812fae4ab](report.html#official-4c546d7812fae4ab) | 待支持 | [第 38 例](https://pele.run/examples) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-f2101f354fdae5a2](report.html#official-f2101f354fdae5a2) | 待支持 | [第 1 例](https://pele.run/examples/agentflow) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-c01cb465b4b372eb](report.html#official-c01cb465b4b372eb) | 待支持 | [第 2 例](https://pele.run/examples/agentflow) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-fd6a77e1c98668d6](report.html#official-fd6a77e1c98668d6) | 待支持 | [第 3 例](https://pele.run/examples/agentflow) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 8 行。 |
| [official-72ddb9fc72ab937a](report.html#official-72ddb9fc72ab937a) | 待支持 | [第 4 例](https://pele.run/examples/agentflow) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-05cb31ddbb76bdf6](report.html#official-05cb31ddbb76bdf6) | 待支持 | [第 5 例](https://pele.run/examples/agentflow) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-5c89eae1c581b64f](report.html#official-5c89eae1c581b64f) | 待支持 | [第 6 例](https://pele.run/examples/agentflow) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-c0455db4242a041c](report.html#official-c0455db4242a041c) | 待支持 | [第 7 例](https://pele.run/examples/agentflow) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 3 行。 |
| [official-2a44766f654fd681](report.html#official-2a44766f654fd681) | 待支持 | [第 9 例](https://pele.run/examples/agentflow) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-475c7f21f53077e4](report.html#official-475c7f21f53077e4) | 待支持 | [第 11 例](https://pele.run/examples/agentflow) | unsupported-configuration：配置项 agentflow 尚未支持。 第 3 行。 |
| [official-69451cfd3a686cf3](report.html#official-69451cfd3a686cf3) | 待支持 | [第 12 例](https://pele.run/examples/agentflow) | unsupported-configuration：配置项 layout 尚未支持。 第 3 行。 |

## architecture

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-9d6b42afa3299dfe](report.html#official-9d6b42afa3299dfe) | 可生成，视觉待核对 | [第 39 例](https://pele.run/examples) | 492.957 × 704 |
| [official-35afb2a472e38d68](report.html#official-35afb2a472e38d68) | 待支持 | [第 40 例](https://pele.run/examples) | unsupported-syntax：暂不支持这条架构图语法。 第 24 行。 |
| [official-bc2e0b86f3114544](report.html#official-bc2e0b86f3114544) | 可生成，视觉待核对 | [第 2 例](https://pele.run/examples/architecture) | 484.863 × 370 |
| [official-7744f879b77a36a2](report.html#official-7744f879b77a36a2) | 待支持 | [第 3 例](https://pele.run/examples/architecture) | unsupported-syntax：暂不支持这条架构图语法。 第 10 行。 |
| [official-b090a75233e19893](report.html#official-b090a75233e19893) | 待支持 | [第 4 例](https://pele.run/examples/architecture) | unsupported-syntax：暂不支持这条架构图语法。 第 9 行。 |
| [official-3ed71c734c4a7031](report.html#official-3ed71c734c4a7031) | 待支持 | [第 7 例](https://pele.run/examples/architecture) | unsupported-syntax：暂不支持这个架构图图标。 第 4 行。 |

## block

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-c574652df330f12f](report.html#official-c574652df330f12f) | 待支持 | [第 1 例](https://pele.run/examples) | unsupported-syntax：块图暂不支持嵌套块或这条布局指令。 第 2 行。 |
| [official-7ddc40305625dcd5](report.html#official-7ddc40305625dcd5) | 待支持 | [第 2 例](https://pele.run/examples) | unsupported-syntax：块图暂不支持嵌套块或这条布局指令。 第 4 行。 |
| [official-78e30a8aaf7fb9a0](report.html#official-78e30a8aaf7fb9a0) | 待支持 | [第 1 例](https://pele.run/examples/block) | unsupported-syntax：块图暂不支持嵌套块或这条布局指令。 第 4 行。 |
| [official-24e2536fc7a02abb](report.html#official-24e2536fc7a02abb) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/block) | 508 × 96 |
| [official-50dc2ed1ddf81876](report.html#official-50dc2ed1ddf81876) | 可生成，视觉待核对 | [第 4 例](https://pele.run/examples/block) | 508 × 200 |
| [official-6fbaef0c0b994cc3](report.html#official-6fbaef0c0b994cc3) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples/block) | 508 × 200 |
| [official-bd54fe8aea77a0c8](report.html#official-bd54fe8aea77a0c8) | 待支持 | [第 6 例](https://pele.run/examples/block) | syntax：end 没有对应的 subgraph。 第 2 行。 |
| [official-8c1f8d5387a4888c](report.html#official-8c1f8d5387a4888c) | 待支持 | [第 8 例](https://pele.run/examples/block) | syntax：end 没有对应的 subgraph。 第 2 行。 |
| [official-2a2aedc0e1a70079](report.html#official-2a2aedc0e1a70079) | 可生成，视觉待核对 | [第 9 例](https://pele.run/examples/block) | 164 × 96 |
| [official-a5a467c814bf0c94](report.html#official-a5a467c814bf0c94) | 可生成，视觉待核对 | [第 10 例](https://pele.run/examples/block) | 164 × 96 |
| [official-3eeec690367a6d71](report.html#official-3eeec690367a6d71) | 可生成，视觉待核对 | [第 11 例](https://pele.run/examples/block) | 164 × 96 |
| [official-fd481f6b76858a8b](report.html#official-fd481f6b76858a8b) | 可生成，视觉待核对 | [第 12 例](https://pele.run/examples/block) | 164 × 96 |
| [official-1493c7342a308ca2](report.html#official-1493c7342a308ca2) | 可生成，视觉待核对 | [第 13 例](https://pele.run/examples/block) | 164 × 96 |
| [official-7134441c41f218d3](report.html#official-7134441c41f218d3) | 待支持 | [第 14 例](https://pele.run/examples/block) | unsupported-syntax：块图暂不支持嵌套块或这条布局指令。 第 2 行。 |
| [official-66fde5799aa4c0f7](report.html#official-66fde5799aa4c0f7) | 可生成，视觉待核对 | [第 15 例](https://pele.run/examples/block) | 164 × 96 |
| [official-6dd28f68976ab76a](report.html#official-6dd28f68976ab76a) | 待支持 | [第 16 例](https://pele.run/examples/block) | unsupported-syntax：块图暂不支持嵌套块或这条布局指令。 第 2 行。 |
| [official-0c75f48188937507](report.html#official-0c75f48188937507) | 可生成，视觉待核对 | [第 17 例](https://pele.run/examples/block) | 680 × 96 |
| [official-1d2ef9d1ea44d352](report.html#official-1d2ef9d1ea44d352) | 待支持 | [第 18 例](https://pele.run/examples/block) | unsupported-syntax：块图暂不支持嵌套块或这条布局指令。 第 2 行。 |
| [official-ab04e71554b0a34c](report.html#official-ab04e71554b0a34c) | 可生成，视觉待核对 | [第 20 例](https://pele.run/examples/block) | 508 × 200 |
| [official-7c6756e88c82bb95](report.html#official-7c6756e88c82bb95) | 可生成，视觉待核对 | [第 21 例](https://pele.run/examples/block) | 1024 × 96 |
| [official-f84186409cf32f76](report.html#official-f84186409cf32f76) | 可生成，视觉待核对 | [第 22 例](https://pele.run/examples/block) | 508 × 96 |
| [official-e29ee1ca59125b3c](report.html#official-e29ee1ca59125b3c) | 可生成，视觉待核对 | [第 23 例](https://pele.run/examples/block) | 680 × 96 |
| [official-0eeed10abc3140de](report.html#official-0eeed10abc3140de) | 待支持 | [第 24 例](https://pele.run/examples/block) | unsupported-syntax：块图暂不支持嵌套块或这条布局指令。 第 4 行。 |
| [official-b6eebb8cba7e7a58](report.html#official-b6eebb8cba7e7a58) | 待支持 | [第 25 例](https://pele.run/examples/block) | unsupported-syntax：块图暂不支持嵌套块或这条布局指令。 第 4 行。 |
| [official-f3c3e654997c3a54](report.html#official-f3c3e654997c3a54) | 待支持 | [第 26 例](https://pele.run/examples/block) | unsupported-syntax：块图暂不支持嵌套块或这条布局指令。 第 4 行。 |
| [official-c1690d0b0e175012](report.html#official-c1690d0b0e175012) | 待支持 | [第 27 例](https://pele.run/examples/block) | unsupported-syntax：块图暂不支持嵌套块或这条布局指令。 第 3 行。 |
| [official-668adabdd9df94a6](report.html#official-668adabdd9df94a6) | 待支持 | [第 28 例](https://pele.run/examples/block) | unsupported-syntax：块图暂不支持嵌套块或这条布局指令。 第 4 行。 |
| [official-fddacaac62f065cc](report.html#official-fddacaac62f065cc) | 可生成，视觉待核对 | [第 29 例](https://pele.run/examples/block) | 508 × 96 |
| [official-6a5c5e673d9bdb2e](report.html#official-6a5c5e673d9bdb2e) | 待支持 | [第 30 例](https://pele.run/examples/block) | unsupported-syntax：块图暂不支持嵌套块或这条布局指令。 第 3 行。 |
| [official-9636dee43e31f64c](report.html#official-9636dee43e31f64c) | 待支持 | [第 31 例](https://pele.run/examples/block) | unsupported-syntax：块图暂不支持嵌套块或这条布局指令。 第 3 行。 |

## c4

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-2c37fb813bb3cd99](report.html#official-2c37fb813bb3cd99) | 待支持 | [第 3 例](https://pele.run/examples) | unsupported-syntax：暂不支持 C4 宏 UpdateRelStyle。 第 27 行。 |
| [official-3a8fd915f7952f8c](report.html#official-3a8fd915f7952f8c) | 待支持 | [第 1 例](https://pele.run/examples/c4) | unsupported-syntax：暂不支持 C4 宏 UpdateElementStyle。 第 36 行。 |
| [official-6da24ed5cded0058](report.html#official-6da24ed5cded0058) | 待支持 | [第 2 例](https://pele.run/examples/c4) | unsupported-syntax：暂不支持 C4 宏 UpdateElementStyle。 第 36 行。 |
| [official-87baedf88b6688ce](report.html#official-87baedf88b6688ce) | 待支持 | [第 4 例](https://pele.run/examples/c4) | unsupported-syntax：暂不支持 C4 宏 UpdateRelStyle。 第 19 行。 |
| [official-78a9531bbd743e92](report.html#official-78a9531bbd743e92) | 待支持 | [第 6 例](https://pele.run/examples/c4) | unsupported-syntax：暂不支持 C4 宏 UpdateRelStyle。 第 14 行。 |
| [official-303a34d8423cf50e](report.html#official-303a34d8423cf50e) | 待支持 | [第 7 例](https://pele.run/examples/c4) | unsupported-syntax：暂不支持 C4 宏 Rel_U。 第 39 行。 |

## class

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-be113905a27fe612](report.html#official-be113905a27fe612) | 可生成，视觉待核对 | [第 4 例](https://pele.run/examples) | 438.93 × 350 |
| [official-a43edf6f2250127a](report.html#official-a43edf6f2250127a) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples) | 788.438 × 358 |
| [official-3d132bfb3376ac4b](report.html#official-3d132bfb3376ac4b) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/class) | 516.781 × 321 |
| [official-fe97e849dbea718b](report.html#official-fe97e849dbea718b) | 可生成，视觉待核对 | [第 2 例](https://pele.run/examples/class) | 954.695 × 279 |
| [official-01f53b9e79db0fe3](report.html#official-01f53b9e79db0fe3) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/class) | 748.656 × 358 |
| [official-b5e4497849dcb550](report.html#official-b5e4497849dcb550) | 可生成，视觉待核对 | [第 4 例](https://pele.run/examples/class) | 343.82 × 472 |
| [official-8d92da500c497c53](report.html#official-8d92da500c497c53) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples/class) | 343.82 × 472 |
| [official-618353c4e48dac71](report.html#official-618353c4e48dac71) | 可生成，视觉待核对 | [第 6 例](https://pele.run/examples/class) | 240 × 198 |
| [official-498d9363ba8ed96f](report.html#official-498d9363ba8ed96f) | 可生成，视觉待核对 | [第 7 例](https://pele.run/examples/class) | 229.453 × 156 |
| [official-cb3671b844c32248](report.html#official-cb3671b844c32248) | 可生成，视觉待核对 | [第 8 例](https://pele.run/examples/class) | 192.484 × 156 |
| [official-01f18827962a86cd](report.html#official-01f18827962a86cd) | 可生成，视觉待核对 | [第 9 例](https://pele.run/examples/class) | 149.203 × 156 |
| [official-53b5bb9ec41a4729](report.html#official-53b5bb9ec41a4729) | 可生成，视觉待核对 | [第 10 例](https://pele.run/examples/class) | 205.852 × 150 |
| [official-e8b9c18297d18e58](report.html#official-e8b9c18297d18e58) | 可生成，视觉待核对 | [第 11 例](https://pele.run/examples/class) | 205.852 × 150 |
| [official-f0aa236caedfd3b0](report.html#official-f0aa236caedfd3b0) | 可生成，视觉待核对 | [第 12 例](https://pele.run/examples/class) | 228.203 × 150 |
| [official-ae91d8c13908d53c](report.html#official-ae91d8c13908d53c) | 可生成，视觉待核对 | [第 13 例](https://pele.run/examples/class) | 518.914 × 216 |
| [official-be1089506d91fe79](report.html#official-be1089506d91fe79) | 可生成，视觉待核对 | [第 14 例](https://pele.run/examples/class) | 965.082 × 156 |
| [official-5bf186aeaa81d334](report.html#official-5bf186aeaa81d334) | 可生成，视觉待核对 | [第 15 例](https://pele.run/examples/class) | 965.082 × 190 |
| [official-029e13c779ccef5e](report.html#official-029e13c779ccef5e) | 可生成，视觉待核对 | [第 16 例](https://pele.run/examples/class) | 345.316 × 190 |
| [official-534a9ea547b5f63e](report.html#official-534a9ea547b5f63e) | 可生成，视觉待核对 | [第 17 例](https://pele.run/examples/class) | 100.992 × 156 |
| [official-bc06236e060fb614](report.html#official-bc06236e060fb614) | 可生成，视觉待核对 | [第 18 例](https://pele.run/examples/class) | 75.8125 × 156 |
| [official-b06c5b3c31557767](report.html#official-b06c5b3c31557767) | 可生成，视觉待核对 | [第 19 例](https://pele.run/examples/class) | 236.754 × 294 |
| [official-570ea6adde22d184](report.html#official-570ea6adde22d184) | 可生成，视觉待核对 | [第 20 例](https://pele.run/examples/class) | 325.172 × 164 |
| [official-09461b572f3e64fd](report.html#official-09461b572f3e64fd) | 可生成，视觉待核对 | [第 21 例](https://pele.run/examples/class) | 219.383 × 164 |
| [official-0d65c6d0a5ad4ca1](report.html#official-0d65c6d0a5ad4ca1) | 可生成，视觉待核对 | [第 22 例](https://pele.run/examples/class) | 589.078 × 350 |
| [official-f609930d3f256adb](report.html#official-f609930d3f256adb) | 可生成，视觉待核对 | [第 23 例](https://pele.run/examples/class) | 413.984 × 372 |
| [official-6ae0bb98620e85b7](report.html#official-6ae0bb98620e85b7) | 可生成，视觉待核对 | [第 24 例](https://pele.run/examples/class) | 589.078 × 350 |
| [official-389b20dbb0e53539](report.html#official-389b20dbb0e53539) | 可生成，视觉待核对 | [第 25 例](https://pele.run/examples/class) | 381.016 × 190 |
| [official-ffa1285b52b93c7e](report.html#official-ffa1285b52b93c7e) | 可生成，视觉待核对 | [第 26 例](https://pele.run/examples/class) | 136.898 × 84 |
| [official-463be631e2f87726](report.html#official-463be631e2f87726) | 可生成，视觉待核对 | [第 27 例](https://pele.run/examples/class) | 146.797 × 128 |
| [official-612be9621bc21023](report.html#official-612be9621bc21023) | 可生成，视觉待核对 | [第 28 例](https://pele.run/examples/class) | 334.258 × 194 |
| [official-3efc2c903a0e392e](report.html#official-3efc2c903a0e392e) | 可生成，视觉待核对 | [第 29 例](https://pele.run/examples/class) | 146.797 × 128 |
| [official-0a59646c6c1de9af](report.html#official-0a59646c6c1de9af) | 可生成，视觉待核对 | [第 30 例](https://pele.run/examples/class) | 408.211 × 236 |
| [official-594dbbe914ff48d5](report.html#official-594dbbe914ff48d5) | 可生成，视觉待核对 | [第 31 例](https://pele.run/examples/class) | 343.18 × 124 |
| [official-2d2e70a6d4d7aef6](report.html#official-2d2e70a6d4d7aef6) | 待支持 | [第 32 例](https://pele.run/examples/class) | unsupported-syntax：暂不支持这条类图语法：link Shape "https://www.github.com" "This is a tooltip for a link" 第 3 行。 |
| [official-500154a2ebe2ea23](report.html#official-500154a2ebe2ea23) | 待支持 | [第 33 例](https://pele.run/examples/class) | unsupported-syntax：暂不支持这条类图语法：callback Shape "callbackFunction" "This is a tooltip for a callback" 第 3 行。 |
| [official-73500fcfdc6ba76a](report.html#official-73500fcfdc6ba76a) | 待支持 | [第 34 例](https://pele.run/examples/class) | unsupported-syntax：暂不支持这条类图语法：callback Class01 "callbackFunction" "Callback tooltip" 第 4 行。 |
| [official-35072ea890247cd8](report.html#official-35072ea890247cd8) | 待支持 | [第 35 例](https://pele.run/examples/class) | unsupported-syntax：暂不支持这条类图语法：style Animal fill:#f9f,stroke:#333,stroke-width:4px 第 4 行。 |
| [official-f91449deb55589d8](report.html#official-f91449deb55589d8) | 待支持 | [第 36 例](https://pele.run/examples/class) | syntax：类声明包含未识别的内容。 第 2 行。 |
| [official-b748773195c45c55](report.html#official-b748773195c45c55) | 待支持 | [第 37 例](https://pele.run/examples/class) | syntax：类声明包含未识别的内容。 第 2 行。 |
| [official-4fa7040920669722](report.html#official-4fa7040920669722) | 待支持 | [第 38 例](https://pele.run/examples/class) | syntax：类声明包含未识别的内容。 第 2 行。 |
| [official-8b617777a9ad567d](report.html#official-8b617777a9ad567d) | 待支持 | [第 39 例](https://pele.run/examples/class) | syntax：类声明包含未识别的内容。 第 2 行。 |
| [official-d8142d901771e849](report.html#official-d8142d901771e849) | 待支持 | [第 40 例](https://pele.run/examples/class) | syntax：Front matter 缩进无效。 第 2 行。 |

## cynefin

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-1065e06731e40265](report.html#official-1065e06731e40265) | 可生成，视觉待核对 | [第 41 例](https://pele.run/examples) | 900 × 580 |
| [official-4fb60908c114c6b9](report.html#official-4fb60908c114c6b9) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/cynefin) | 900 × 620 |
| [official-c41ec80b216c2903](report.html#official-c41ec80b216c2903) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/cynefin) | 900 × 580 |

## er

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-7b827b95e8846857](report.html#official-7b827b95e8846857) | 待支持 | [第 6 例](https://pele.run/examples) | unsupported-syntax：暂不支持这条实体关系图语法：subgraph title1 第 2 行。 |
| [official-fc39dc2a89974e1c](report.html#official-fc39dc2a89974e1c) | 待支持 | [第 7 例](https://pele.run/examples) | unsupported-syntax：暂不支持这条实体关系图语法：CAR ／／--o{ NAMED-DRIVER : allows 第 2 行。 |
| [official-a0bf1cab82de84b4](report.html#official-a0bf1cab82de84b4) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/er) | 311.285 × 318 |
| [official-973dfeffadbed6ce](report.html#official-973dfeffadbed6ce) | 待支持 | [第 2 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：ORDER ／／--／{ LINE-ITEM : contains 第 6 行。 |
| [official-421f7b70668e1fe6](report.html#official-421f7b70668e1fe6) | 待支持 | [第 3 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：ORDER ／／--／{ LINE-ITEM : contains 第 8 行。 |
| [official-97d409b3f28fbd92](report.html#official-97d409b3f28fbd92) | 可生成，视觉待核对 | [第 4 例](https://pele.run/examples/er) | 297.172 × 450 |
| [official-28d45c0741343f4e](report.html#official-28d45c0741343f4e) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples/er) | 297.172 × 450 |
| [official-99e1dfb4c158699e](report.html#official-99e1dfb4c158699e) | 待支持 | [第 6 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法："This ❤ Unicode" 第 2 行。 |
| [official-d5199c1220398e92](report.html#official-d5199c1220398e92) | 待支持 | [第 7 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法："This **is** _Markdown_" 第 2 行。 |
| [official-719e355f1c64ad84](report.html#official-719e355f1c64ad84) | 待支持 | [第 8 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：CAR ／／--o{ NAMED-DRIVER : allows 第 2 行。 |
| [official-fff06d91b2ed0ed8](report.html#official-fff06d91b2ed0ed8) | 待支持 | [第 9 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：CAR 1 to zero or more NAMED-DRIVER : allows 第 2 行。 |
| [official-38d6e4a4399d6bef](report.html#official-38d6e4a4399d6bef) | 待支持 | [第 10 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：CAR ／／--o{ NAMED-DRIVER : allows 第 2 行。 |
| [official-64765bbdf6549438](report.html#official-64765bbdf6549438) | 可生成，视觉待核对 | [第 11 例](https://pele.run/examples/er) | 196.805 × 128 |
| [official-48baec41314cb4f5](report.html#official-48baec41314cb4f5) | 待支持 | [第 12 例](https://pele.run/examples/er) | syntax：实体关系基数标记无效。 第 9 行。 |
| [official-84744d9ec428f780](report.html#official-84744d9ec428f780) | 待支持 | [第 14 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：ORDER ／／--／{ LINE-ITEM : contains 第 9 行。 |
| [official-4accb2527f09e89b](report.html#official-4accb2527f09e89b) | 待支持 | [第 15 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：ORDER ／／--／{ LINE-ITEM : contains 第 9 行。 |
| [official-33d261ba8ae1b647](report.html#official-33d261ba8ae1b647) | 待支持 | [第 17 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：subgraph title1 第 2 行。 |
| [official-13b0f9ca3d8532da](report.html#official-13b0f9ca3d8532da) | 待支持 | [第 18 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：subgraph "Customer Domain" 第 2 行。 |
| [official-aef1ac587e4aaaee](report.html#official-aef1ac587e4aaaee) | 待支持 | [第 19 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：subgraph id1 [title 1] 第 2 行。 |
| [official-cb5e089f3dc8d91b](report.html#official-cb5e089f3dc8d91b) | 待支持 | [第 20 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：subgraph title1 第 2 行。 |
| [official-3bffcd114da1c5a6](report.html#official-3bffcd114da1c5a6) | 待支持 | [第 21 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：subgraph TOP 第 3 行。 |
| [official-2090df21742496c1](report.html#official-2090df21742496c1) | 待支持 | [第 22 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：style id1 fill:#f9f,stroke:#333,stroke-width:4px 第 3 行。 |
| [official-685e5730a5e743fa](report.html#official-685e5730a5e743fa) | 待支持 | [第 23 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：CAR:::someclass { 第 3 行。 |
| [official-cd17cfb2345a33fb](report.html#official-cd17cfb2345a33fb) | 待支持 | [第 24 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：PERSON:::foo ／／--／／ CAR : owns 第 12 行。 |
| [official-1838b7a479e51100](report.html#official-1838b7a479e51100) | 待支持 | [第 25 例](https://pele.run/examples/er) | unsupported-syntax：暂不支持这条实体关系图语法：PERSON:::foo ／／--／／ CAR : owns 第 12 行。 |
| [official-59995f5cd6f4cfc7](report.html#official-59995f5cd6f4cfc7) | 待支持 | [第 26 例](https://pele.run/examples/er) | unsupported-configuration：配置项 layout 尚未支持。 第 4 行。 |

## eventmodeling

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-60ed88ab0a168f78](report.html#official-60ed88ab0a168f78) | 待支持 | [第 8 例](https://pele.run/examples) | unsupported-syntax：事件建模当前支持 tf、rf 帧和显式来源引用。 第 3 行。 |
| [official-106d6b780f0ab5fe](report.html#official-106d6b780f0ab5fe) | 待支持 | [第 9 例](https://pele.run/examples) | unsupported-syntax：事件建模当前支持 tf、rf 帧和显式来源引用。 第 3 行。 |
| [official-16482e95f341dafd](report.html#official-16482e95f341dafd) | 待支持 | [第 1 例](https://pele.run/examples/eventmodeling) | unsupported-syntax：帧标识符重复，或使用了尚未支持的数据块。 第 4 行。 |
| [official-8bc30355f050add9](report.html#official-8bc30355f050add9) | 可生成，视觉待核对 | [第 2 例](https://pele.run/examples/eventmodeling) | 740 × 454 |
| [official-7af74f9e828ebc30](report.html#official-7af74f9e828ebc30) | 待支持 | [第 3 例](https://pele.run/examples/eventmodeling) | unsupported-syntax：帧标识符重复，或使用了尚未支持的数据块。 第 4 行。 |
| [official-10ff19b737311e89](report.html#official-10ff19b737311e89) | 待支持 | [第 4 例](https://pele.run/examples/eventmodeling) | unsupported-syntax：事件建模当前支持 tf、rf 帧和显式来源引用。 第 3 行。 |
| [official-af1099fbb284b4ec](report.html#official-af1099fbb284b4ec) | 可生成，视觉待核对 | [第 7 例](https://pele.run/examples/eventmodeling) | 1500 × 454 |
| [official-39056a94a65db550](report.html#official-39056a94a65db550) | 可生成，视觉待核对 | [第 9 例](https://pele.run/examples/eventmodeling) | 740 × 454 |
| [official-420a8b823865365e](report.html#official-420a8b823865365e) | 可生成，视觉待核对 | [第 10 例](https://pele.run/examples/eventmodeling) | 1120 × 454 |
| [official-697ff74e11854d94](report.html#official-697ff74e11854d94) | 可生成，视觉待核对 | [第 11 例](https://pele.run/examples/eventmodeling) | 740 × 454 |
| [official-65f1af911f10492c](report.html#official-65f1af911f10492c) | 可生成，视觉待核对 | [第 12 例](https://pele.run/examples/eventmodeling) | 930 × 454 |
| [official-73bc66ae906e75f1](report.html#official-73bc66ae906e75f1) | 可生成，视觉待核对 | [第 13 例](https://pele.run/examples/eventmodeling) | 600 × 454 |

## flowchart

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-4b7f53d8caa034dd](report.html#official-4b7f53d8caa034dd) | 可生成，视觉待核对 | [第 10 例](https://pele.run/examples) | 458.133 × 252 |
| [official-80b86f15a9c2e222](report.html#official-80b86f15a9c2e222) | 可生成，视觉待核对 | [第 11 例](https://pele.run/examples) | 968.598 × 206 |
| [official-205ffca8b17765de](report.html#official-205ffca8b17765de) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/flowchart) | 113 × 185 |
| [official-e79dcb1cf43646f7](report.html#official-e79dcb1cf43646f7) | 可生成，视觉待核对 | [第 2 例](https://pele.run/examples/flowchart) | 209 × 279 |
| [official-f4c11b4ae7e28778](report.html#official-f4c11b4ae7e28778) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/flowchart) | 355.13 × 354.331 |
| [official-b1a86eb4d3ddd767](report.html#official-b1a86eb4d3ddd767) | 可生成，视觉待核对 | [第 4 例](https://pele.run/examples/flowchart) | 426.742 × 490.728 |
| [official-473503ae919a4459](report.html#official-473503ae919a4459) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples/flowchart) | 334.852 × 344 |
| [official-c845199fdb0cae08](report.html#official-c845199fdb0cae08) | 可生成，视觉待核对 | [第 6 例](https://pele.run/examples/flowchart) | 347.477 × 156 |
| [official-5b213c539aca8c49](report.html#official-5b213c539aca8c49) | 可生成，视觉待核对 | [第 7 例](https://pele.run/examples/flowchart) | 846.117 × 156 |
| [official-d8f42ce884ca6e26](report.html#official-d8f42ce884ca6e26) | 可生成，视觉待核对 | [第 8 例](https://pele.run/examples/flowchart) | 347.477 × 156 |
| [official-4b930f38170c815c](report.html#official-4b930f38170c815c) | 可生成，视觉待核对 | [第 9 例](https://pele.run/examples/flowchart) | 846.117 × 156 |
| [official-2a836390a7e361a2](report.html#official-2a836390a7e361a2) | 可生成，视觉待核对 | [第 10 例](https://pele.run/examples/flowchart) | 385 × 307 |
| [official-367c9f044e93ca09](report.html#official-367c9f044e93ca09) | 可生成，视觉待核对 | [第 11 例](https://pele.run/examples/flowchart) | 65.1709 × 284 |
| [official-a29fa225b0510ee6](report.html#official-a29fa225b0510ee6) | 可生成，视觉待核对 | [第 12 例](https://pele.run/examples/flowchart) | 301 × 284 |
| [official-bee4f0e7a6f09db2](report.html#official-bee4f0e7a6f09db2) | 可生成，视觉待核对 | [第 13 例](https://pele.run/examples/flowchart) | 289 × 279 |
| [official-804516d3947f1f4c](report.html#official-804516d3947f1f4c) | 可生成，视觉待核对 | [第 14 例](https://pele.run/examples/flowchart) | 229.641 × 439.145 |
| [official-d2fcc1c3e8a46170](report.html#official-d2fcc1c3e8a46170) | 可生成，视觉待核对 | [第 15 例](https://pele.run/examples/flowchart) | 229.641 × 439.145 |
| [official-24fa6f8f0a46e91f](report.html#official-24fa6f8f0a46e91f) | 可生成，视觉待核对 | [第 16 例](https://pele.run/examples/flowchart) | 600.504 × 197 |
| [official-a2675cb9b035eb76](report.html#official-a2675cb9b035eb76) | 可生成，视觉待核对 | [第 17 例](https://pele.run/examples/flowchart) | 600.504 × 197 |
| [official-34ef5b9aef8a604e](report.html#official-34ef5b9aef8a604e) | 可生成，视觉待核对 | [第 18 例](https://pele.run/examples/flowchart) | 2473 × 321.603 |
| [official-fb69454bcb92930a](report.html#official-fb69454bcb92930a) | 待支持 | [第 19 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：text。 第 14 行。 |
| [official-9334cad70180d663](report.html#official-9334cad70180d663) | 待支持 | [第 20 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：sm-circ。 第 2 行。 |
| [official-cdc2dbda9c3897e4](report.html#official-cdc2dbda9c3897e4) | 待支持 | [第 21 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：notch-pent。 第 2 行。 |
| [official-ec2aede73454d590](report.html#official-ec2aede73454d590) | 待支持 | [第 22 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：flip-tri。 第 2 行。 |
| [official-219718738a2e5e26](report.html#official-219718738a2e5e26) | 待支持 | [第 23 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：bolt。 第 2 行。 |
| [official-084265e7aa9a9086](report.html#official-084265e7aa9a9086) | 可生成，视觉待核对 | [第 24 例](https://pele.run/examples/flowchart) | 345.789 × 2425 |
| [official-0de019e610f30ca1](report.html#official-0de019e610f30ca1) | 待支持 | [第 25 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：text。 第 14 行。 |
| [official-e5dd23004adc8249](report.html#official-e5dd23004adc8249) | 待支持 | [第 26 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：sm-circ。 第 2 行。 |
| [official-4c008390386b819f](report.html#official-4c008390386b819f) | 待支持 | [第 27 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：notch-pent。 第 2 行。 |
| [official-1e5aaf27a8b96aa3](report.html#official-1e5aaf27a8b96aa3) | 待支持 | [第 28 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：flip-tri。 第 2 行。 |
| [official-f30d24d8fe943d4d](report.html#official-f30d24d8fe943d4d) | 待支持 | [第 29 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：bolt。 第 2 行。 |
| [official-d9875485a148cf13](report.html#official-d9875485a148cf13) | 可生成，视觉待核对 | [第 30 例](https://pele.run/examples/flowchart) | 243.742 × 648 |
| [official-a63a1d50b5cea2f6](report.html#official-a63a1d50b5cea2f6) | 可生成，视觉待核对 | [第 31 例](https://pele.run/examples/flowchart) | 881.156 × 206 |
| [official-e3b987c0101e4ddd](report.html#official-e3b987c0101e4ddd) | 可生成，视觉待核对 | [第 32 例](https://pele.run/examples/flowchart) | 193 × 677 |
| [official-6606abb8e03414a5](report.html#official-6606abb8e03414a5) | 可生成，视觉待核对 | [第 33 例](https://pele.run/examples/flowchart) | 615.562 × 317 |
| [official-70fc79788b7a6edf](report.html#official-70fc79788b7a6edf) | 可生成，视觉待核对 | [第 34 例](https://pele.run/examples/flowchart) | 236.094 × 272 |
| [official-a9c271f53aa87abc](report.html#official-a9c271f53aa87abc) | 可生成，视觉待核对 | [第 35 例](https://pele.run/examples/flowchart) | 1861.41 × 178 |
| [official-36749f10893c74f8](report.html#official-36749f10893c74f8) | 可生成，视觉待核对 | [第 36 例](https://pele.run/examples/flowchart) | 1283.13 × 156 |
| [official-c102b3a25ea3b367](report.html#official-c102b3a25ea3b367) | 可生成，视觉待核对 | [第 37 例](https://pele.run/examples/flowchart) | 3884.92 × 156 |
| [official-ba4a854268a3d0fa](report.html#official-ba4a854268a3d0fa) | 可生成，视觉待核对 | [第 38 例](https://pele.run/examples/flowchart) | 224.688 × 2556 |
| [official-599ede39e4d6e1b5](report.html#official-599ede39e4d6e1b5) | 可生成，视觉待核对 | [第 39 例](https://pele.run/examples/flowchart) | 414.781 × 156 |
| [official-7d18bca1aae80fa0](report.html#official-7d18bca1aae80fa0) | 可生成，视觉待核对 | [第 40 例](https://pele.run/examples/flowchart) | 462.266 × 749 |
| [official-7e14e3c0e2cb44ee](report.html#official-7e14e3c0e2cb44ee) | 可生成，视觉待核对 | [第 41 例](https://pele.run/examples/flowchart) | 798.484 × 222 |
| [official-661d0b11d13deb3a](report.html#official-661d0b11d13deb3a) | 可生成，视觉待核对 | [第 42 例](https://pele.run/examples/flowchart) | 988.219 × 250 |
| [official-ed258e38dcf0e183](report.html#official-ed258e38dcf0e183) | 可生成，视觉待核对 | [第 43 例](https://pele.run/examples/flowchart) | 443.298 × 292.848 |
| [official-1607e7c62788b6d5](report.html#official-1607e7c62788b6d5) | 可生成，视觉待核对 | [第 44 例](https://pele.run/examples/flowchart) | 533.945 × 181.967 |
| [official-d366d4eb195dfca4](report.html#official-d366d4eb195dfca4) | 可生成，视觉待核对 | [第 45 例](https://pele.run/examples/flowchart) | 462.453 × 389 |
| [official-2d57b5027d8772f2](report.html#official-2d57b5027d8772f2) | 待支持 | [第 46 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-59755f0029f21cfb](report.html#official-59755f0029f21cfb) | 待支持 | [第 47 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-ca4e0a268bb6226a](report.html#official-ca4e0a268bb6226a) | 待支持 | [第 48 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-87c41ad0a9435d7e](report.html#official-87c41ad0a9435d7e) | 待支持 | [第 49 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-02ac901fc5372a73](report.html#official-02ac901fc5372a73) | 待支持 | [第 50 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-7e24db31e25ca1b2](report.html#official-7e24db31e25ca1b2) | 待支持 | [第 51 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-7f9d6a7b716f89f8](report.html#official-7f9d6a7b716f89f8) | 待支持 | [第 52 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-8f91772821001588](report.html#official-8f91772821001588) | 待支持 | [第 53 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-f63352092df12275](report.html#official-f63352092df12275) | 待支持 | [第 54 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-8c7dfe6b59664744](report.html#official-8c7dfe6b59664744) | 待支持 | [第 55 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-48edfc752e15b47e](report.html#official-48edfc752e15b47e) | 待支持 | [第 56 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-dcb17579a45018f1](report.html#official-dcb17579a45018f1) | 待支持 | [第 57 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-1facf2ef981243c6](report.html#official-1facf2ef981243c6) | 待支持 | [第 58 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-e56e876a9b68eee8](report.html#official-e56e876a9b68eee8) | 待支持 | [第 60 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-8c9864c9048436e2](report.html#official-8c9864c9048436e2) | 待支持 | [第 61 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 flowchart.curve 尚未支持。 第 4 行。 |
| [official-ff9a1774bb7e9a41](report.html#official-ff9a1774bb7e9a41) | 可生成，视觉待核对 | [第 62 例](https://pele.run/examples/flowchart) | 240 × 110 |
| [official-f4db835df6afe3f2](report.html#official-f4db835df6afe3f2) | 可生成，视觉待核对 | [第 63 例](https://pele.run/examples/flowchart) | 240 × 110 |
| [official-f70aed641f746c2a](report.html#official-f70aed641f746c2a) | 可生成，视觉待核对 | [第 64 例](https://pele.run/examples/flowchart) | 165.844 × 62 |
| [official-c73fdea4fca45502](report.html#official-c73fdea4fca45502) | 待支持 | [第 65 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 htmlLabels 尚未支持。 第 3 行。 |
| [official-6686c2010c31ba66](report.html#official-6686c2010c31ba66) | 可生成，视觉待核对 | [第 66 例](https://pele.run/examples/flowchart) | 87.3359 × 156 |
| [official-9221e419f59c0a81](report.html#official-9221e419f59c0a81) | 可生成，视觉待核对 | [第 67 例](https://pele.run/examples/flowchart) | 205.195 × 62 |
| [official-db4aa3083cae19b2](report.html#official-db4aa3083cae19b2) | 可生成，视觉待核对 | [第 68 例](https://pele.run/examples/flowchart) | 968.598 × 206 |
| [official-c8329226c7005848](report.html#official-c8329226c7005848) | 可生成，视觉待核对 | [第 70 例](https://pele.run/examples/flowchart) | 232.805 × 62 |
| [official-848620f02e99e05d](report.html#official-848620f02e99e05d) | 可生成，视觉待核对 | [第 71 例](https://pele.run/examples/flowchart) | 247.805 × 62 |
| [official-fe5831e2389554d0](report.html#official-fe5831e2389554d0) | 可生成，视觉待核对 | [第 72 例](https://pele.run/examples/flowchart) | 248.805 × 62 |
| [official-c57732f4dea61398](report.html#official-c57732f4dea61398) | 可生成，视觉待核对 | [第 73 例](https://pele.run/examples/flowchart) | 120.766 × 76.9665 |
| [official-6b39e85e8e60c32e](report.html#official-6b39e85e8e60c32e) | 可生成，视觉待核对 | [第 74 例](https://pele.run/examples/flowchart) | 226.739 × 226.739 |
| [official-bb15e35a39985eb4](report.html#official-bb15e35a39985eb4) | 可生成，视觉待核对 | [第 75 例](https://pele.run/examples/flowchart) | 377.341 × 70 |
| [official-306e952eea6e380b](report.html#official-306e952eea6e380b) | 可生成，视觉待核对 | [第 76 例](https://pele.run/examples/flowchart) | 260.805 × 169.003 |
| [official-dcf721a3f4beee64](report.html#official-dcf721a3f4beee64) | 可生成，视觉待核对 | [第 77 例](https://pele.run/examples/flowchart) | 377.341 × 70 |
| [official-832a1ec82f995ef8](report.html#official-832a1ec82f995ef8) | 可生成，视觉待核对 | [第 78 例](https://pele.run/examples/flowchart) | 377.341 × 70 |
| [official-a51d852be5d3bbed](report.html#official-a51d852be5d3bbed) | 可生成，视觉待核对 | [第 79 例](https://pele.run/examples/flowchart) | 377.341 × 70 |
| [official-6b1ad0dda6c60bab](report.html#official-6b1ad0dda6c60bab) | 可生成，视觉待核对 | [第 80 例](https://pele.run/examples/flowchart) | 198.227 × 70 |
| [official-2f0bf28294a31aec](report.html#official-2f0bf28294a31aec) | 可生成，视觉待核对 | [第 81 例](https://pele.run/examples/flowchart) | 229.789 × 70 |
| [official-2d81e8b9d03f23ed](report.html#official-2d81e8b9d03f23ed) | 可生成，视觉待核对 | [第 82 例](https://pele.run/examples/flowchart) | 238.739 × 238.739 |
| [official-8f6bee2432ba9b4b](report.html#official-8f6bee2432ba9b4b) | 待支持 | [第 83 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：manual-file。 第 2 行。 |
| [official-cfb3b33ba4ec000c](report.html#official-cfb3b33ba4ec000c) | 可生成，视觉待核对 | [第 84 例](https://pele.run/examples/flowchart) | 172.992 × 62 |
| [official-520a982ac547b084](report.html#official-520a982ac547b084) | 可生成，视觉待核对 | [第 85 例](https://pele.run/examples/flowchart) | 164.508 × 62 |
| [official-26d721957df8d7a3](report.html#official-26d721957df8d7a3) | 可生成，视觉待核对 | [第 86 例](https://pele.run/examples/flowchart) | 169.5 × 62 |
| [official-4a2ae373f0d2498d](report.html#official-4a2ae373f0d2498d) | 待支持 | [第 87 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：subproc。 第 2 行。 |
| [official-c63dbcd17538c2ad](report.html#official-c63dbcd17538c2ad) | 可生成，视觉待核对 | [第 88 例](https://pele.run/examples/flowchart) | 120.766 × 76.9665 |
| [official-7b261343fbfaf308](report.html#official-7b261343fbfaf308) | 可生成，视觉待核对 | [第 89 例](https://pele.run/examples/flowchart) | 73.6249 × 73.6249 |
| [official-a4bed0a9c19df28f](report.html#official-a4bed0a9c19df28f) | 可生成，视觉待核对 | [第 90 例](https://pele.run/examples/flowchart) | 208.018 × 70 |
| [official-753ca710b1ac1dee](report.html#official-753ca710b1ac1dee) | 可生成，视觉待核对 | [第 91 例](https://pele.run/examples/flowchart) | 142.289 × 94.9307 |
| [official-6f8583b8b0e2f07e](report.html#official-6f8583b8b0e2f07e) | 可生成，视觉待核对 | [第 92 例](https://pele.run/examples/flowchart) | 309.789 × 70 |
| [official-b920fc09d3e79f52](report.html#official-b920fc09d3e79f52) | 可生成，视觉待核对 | [第 93 例](https://pele.run/examples/flowchart) | 229.438 × 70 |
| [official-89a471241f408285](report.html#official-89a471241f408285) | 可生成，视觉待核对 | [第 94 例](https://pele.run/examples/flowchart) | 229.438 × 70 |
| [official-d47a9e81b902e765](report.html#official-d47a9e81b902e765) | 待支持 | [第 95 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：datastore。 第 2 行。 |
| [official-b153dad4f8ca0655](report.html#official-b153dad4f8ca0655) | 可生成，视觉待核对 | [第 96 例](https://pele.run/examples/flowchart) | 243.526 × 70 |
| [official-de84549bf410270e](report.html#official-de84549bf410270e) | 可生成，视觉待核对 | [第 97 例](https://pele.run/examples/flowchart) | 285.492 × 70 |
| [official-a60f1b1f561afa1f](report.html#official-a60f1b1f561afa1f) | 可生成，视觉待核对 | [第 98 例](https://pele.run/examples/flowchart) | 84.3789 × 84.3789 |
| [official-82e0f657dc5d85d7](report.html#official-82e0f657dc5d85d7) | 待支持 | [第 99 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：text。 第 2 行。 |
| [official-85b0a8dd09d11b3b](report.html#official-85b0a8dd09d11b3b) | 待支持 | [第 100 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：notch-rect。 第 2 行。 |
| [official-50674ff2e8365bec](report.html#official-50674ff2e8365bec) | 待支持 | [第 101 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：lin-rect。 第 2 行。 |
| [official-eefd96427a777eb2](report.html#official-eefd96427a777eb2) | 待支持 | [第 102 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：sm-circ。 第 2 行。 |
| [official-839363fa35f716c9](report.html#official-839363fa35f716c9) | 待支持 | [第 103 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：framed-circle。 第 2 行。 |
| [official-62c7e909d6f6d2c0](report.html#official-62c7e909d6f6d2c0) | 待支持 | [第 104 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：fork。 第 2 行。 |
| [official-2406ad02ae7265c8](report.html#official-2406ad02ae7265c8) | 待支持 | [第 105 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：hourglass。 第 2 行。 |
| [official-bf6938b0951c8f37](report.html#official-bf6938b0951c8f37) | 待支持 | [第 106 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：comment。 第 2 行。 |
| [official-1f8f0a5158f1bd14](report.html#official-1f8f0a5158f1bd14) | 待支持 | [第 107 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：brace-r。 第 2 行。 |
| [official-77b6694cfcf57783](report.html#official-77b6694cfcf57783) | 待支持 | [第 108 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：braces。 第 2 行。 |
| [official-7634b95b0a83f5a7](report.html#official-7634b95b0a83f5a7) | 待支持 | [第 109 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：bolt。 第 2 行。 |
| [official-a2ce1eed42a80214](report.html#official-a2ce1eed42a80214) | 待支持 | [第 110 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：doc。 第 2 行。 |
| [official-3a814849f81b02e1](report.html#official-3a814849f81b02e1) | 待支持 | [第 111 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：delay。 第 2 行。 |
| [official-ca8d8066bf48b5a3](report.html#official-ca8d8066bf48b5a3) | 待支持 | [第 112 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：das。 第 2 行。 |
| [official-4638fffcd951ca61](report.html#official-4638fffcd951ca61) | 待支持 | [第 113 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：lin-cyl。 第 2 行。 |
| [official-07f75620ccb9e4d1](report.html#official-07f75620ccb9e4d1) | 待支持 | [第 114 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：curv-trap。 第 2 行。 |
| [official-06e5dd63714486cd](report.html#official-06e5dd63714486cd) | 待支持 | [第 115 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：div-rect。 第 2 行。 |
| [official-9fde480c3c89b388](report.html#official-9fde480c3c89b388) | 待支持 | [第 116 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：tri。 第 2 行。 |
| [official-9256ec4395374c55](report.html#official-9256ec4395374c55) | 待支持 | [第 117 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：win-pane。 第 2 行。 |
| [official-f67ac6d593083853](report.html#official-f67ac6d593083853) | 待支持 | [第 118 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：f-circ。 第 2 行。 |
| [official-59f0daf6279490b4](report.html#official-59f0daf6279490b4) | 待支持 | [第 119 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：lin-doc。 第 2 行。 |
| [official-8106d06596bb16c0](report.html#official-8106d06596bb16c0) | 待支持 | [第 120 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：notch-pent。 第 2 行。 |
| [official-df37b14d183fcdc5](report.html#official-df37b14d183fcdc5) | 待支持 | [第 121 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：flip-tri。 第 2 行。 |
| [official-b595757319467b19](report.html#official-b595757319467b19) | 待支持 | [第 122 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：sl-rect。 第 2 行。 |
| [official-12a1109775b51abe](report.html#official-12a1109775b51abe) | 待支持 | [第 123 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：docs。 第 2 行。 |
| [official-4a6522e28377d094](report.html#official-4a6522e28377d094) | 待支持 | [第 124 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：processes。 第 2 行。 |
| [official-12232e66b8e521b2](report.html#official-12232e66b8e521b2) | 待支持 | [第 125 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：flag。 第 2 行。 |
| [official-022e2327ceeaa8cf](report.html#official-022e2327ceeaa8cf) | 待支持 | [第 126 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：bow-rect。 第 2 行。 |
| [official-4dc7b8e96f70cc6c](report.html#official-4dc7b8e96f70cc6c) | 待支持 | [第 127 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：cross-circ。 第 2 行。 |
| [official-d42a5304c164faa6](report.html#official-d42a5304c164faa6) | 待支持 | [第 128 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：tag-doc。 第 2 行。 |
| [official-d6fe112460599283](report.html#official-d6fe112460599283) | 待支持 | [第 129 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持节点形状：tag-rect。 第 2 行。 |
| [official-302d8d0973b8d245](report.html#official-302d8d0973b8d245) | 待支持 | [第 130 例](https://pele.run/examples/flowchart) | unsupported-syntax：节点属性仅支持不重复的 shape 和 label。 第 2 行。 |
| [official-9a39031c41fcb0e6](report.html#official-9a39031c41fcb0e6) | 待支持 | [第 131 例](https://pele.run/examples/flowchart) | unsupported-syntax：节点属性仅支持不重复的 shape 和 label。 第 3 行。 |
| [official-85a2f8b3229ec602](report.html#official-85a2f8b3229ec602) | 可生成，视觉待核对 | [第 132 例](https://pele.run/examples/flowchart) | 160 × 62 |
| [official-9733d593d7c58fd4](report.html#official-9733d593d7c58fd4) | 可生成，视觉待核对 | [第 133 例](https://pele.run/examples/flowchart) | 160 × 62 |
| [official-39f13d6306c2997c](report.html#official-39f13d6306c2997c) | 待支持 | [第 134 例](https://pele.run/examples/flowchart) | syntax：连线标签尚未闭合。 第 2 行。 |
| [official-d2f58af55ba28028](report.html#official-d2f58af55ba28028) | 可生成，视觉待核对 | [第 135 例](https://pele.run/examples/flowchart) | 259.104 × 62 |
| [official-d5d4d42882dee089](report.html#official-d5d4d42882dee089) | 可生成，视觉待核对 | [第 136 例](https://pele.run/examples/flowchart) | 197.545 × 62 |
| [official-6a86b6e0b7cb8bb5](report.html#official-6a86b6e0b7cb8bb5) | 可生成，视觉待核对 | [第 137 例](https://pele.run/examples/flowchart) | 197.545 × 62 |
| [official-1bb084024e89e351](report.html#official-1bb084024e89e351) | 可生成，视觉待核对 | [第 138 例](https://pele.run/examples/flowchart) | 160 × 62 |
| [official-3dcfb621c76053c4](report.html#official-3dcfb621c76053c4) | 可生成，视觉待核对 | [第 139 例](https://pele.run/examples/flowchart) | 197.545 × 62 |
| [official-2b838b9975e215d2](report.html#official-2b838b9975e215d2) | 可生成，视觉待核对 | [第 140 例](https://pele.run/examples/flowchart) | 160 × 62 |
| [official-235e40b72637d036](report.html#official-235e40b72637d036) | 可生成，视觉待核对 | [第 141 例](https://pele.run/examples/flowchart) | 197.545 × 62 |
| [official-30e40d14fabfa9e9](report.html#official-30e40d14fabfa9e9) | 可生成，视觉待核对 | [第 142 例](https://pele.run/examples/flowchart) | 160 × 62 |
| [official-9806df4622bb2d0f](report.html#official-9806df4622bb2d0f) | 可生成，视觉待核对 | [第 143 例](https://pele.run/examples/flowchart) | 338.332 × 62 |
| [official-583da5e48ac9e2ca](report.html#official-583da5e48ac9e2ca) | 可生成，视觉待核对 | [第 144 例](https://pele.run/examples/flowchart) | 256 × 148 |
| [official-daedeeb47874c4e5](report.html#official-daedeeb47874c4e5) | 可生成，视觉待核对 | [第 145 例](https://pele.run/examples/flowchart) | 152 × 156 |
| [official-69cadca59319ddac](report.html#official-69cadca59319ddac) | 可生成，视觉待核对 | [第 146 例](https://pele.run/examples/flowchart) | 152 × 156 |
| [official-e1068d4490409d3c](report.html#official-e1068d4490409d3c) | 待支持 | [第 147 例](https://pele.run/examples/flowchart) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-fa96150719680e00](report.html#official-fa96150719680e00) | 待支持 | [第 148 例](https://pele.run/examples/flowchart) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-4d814bb7de2a5933](report.html#official-4d814bb7de2a5933) | 待支持 | [第 149 例](https://pele.run/examples/flowchart) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-b03ea11e4f024eb7](report.html#official-b03ea11e4f024eb7) | 待支持 | [第 150 例](https://pele.run/examples/flowchart) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-fab31634d01ab87e](report.html#official-fab31634d01ab87e) | 可生成，视觉待核对 | [第 151 例](https://pele.run/examples/flowchart) | 160 × 62 |
| [official-217131610d97964f](report.html#official-217131610d97964f) | 可生成，视觉待核对 | [第 152 例](https://pele.run/examples/flowchart) | 160 × 62 |
| [official-cf2bb1f7c453d5e4](report.html#official-cf2bb1f7c453d5e4) | 可生成，视觉待核对 | [第 153 例](https://pele.run/examples/flowchart) | 352 × 62 |
| [official-49d93245842947c3](report.html#official-49d93245842947c3) | 可生成，视觉待核对 | [第 154 例](https://pele.run/examples/flowchart) | 215.254 × 486.781 |
| [official-96d66977bb2506fd](report.html#official-96d66977bb2506fd) | 可生成，视觉待核对 | [第 155 例](https://pele.run/examples/flowchart) | 225.135 × 421.781 |
| [official-0b5f81881322a47d](report.html#official-0b5f81881322a47d) | 可生成，视觉待核对 | [第 156 例](https://pele.run/examples/flowchart) | 244.398 × 62 |
| [official-1991365e32c80782](report.html#official-1991365e32c80782) | 可生成，视觉待核对 | [第 157 例](https://pele.run/examples/flowchart) | 433.664 × 62 |
| [official-b9675066f5fb1cb7](report.html#official-b9675066f5fb1cb7) | 可生成，视觉待核对 | [第 158 例](https://pele.run/examples/flowchart) | 244.844 × 460 |
| [official-8af2741f77e4425f](report.html#official-8af2741f77e4425f) | 可生成，视觉待核对 | [第 159 例](https://pele.run/examples/flowchart) | 109.859 × 308 |
| [official-1c231ae5c6296a88](report.html#official-1c231ae5c6296a88) | 可生成，视觉待核对 | [第 160 例](https://pele.run/examples/flowchart) | 131.859 × 706 |
| [official-6897cf10b879aea9](report.html#official-6897cf10b879aea9) | 可生成，视觉待核对 | [第 161 例](https://pele.run/examples/flowchart) | 432.586 × 424 |
| [official-011362669b9324c8](report.html#official-011362669b9324c8) | 待支持 | [第 163 例](https://pele.run/examples/flowchart) | unsupported-syntax：节点属性仅支持不重复的 shape 和 label。 第 8 行。 |
| [official-14571e1d97419b3c](report.html#official-14571e1d97419b3c) | 待支持 | [第 164 例](https://pele.run/examples/flowchart) | unsupported-configuration：配置项 htmlLabels 尚未支持。 第 3 行。 |
| [official-91b6b817ef7138b7](report.html#official-91b6b817ef7138b7) | 待支持 | [第 165 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持样式指令和交互指令。 第 5 行。 |
| [official-708f9d59a147723b](report.html#official-708f9d59a147723b) | 待支持 | [第 166 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持样式指令和交互指令。 第 6 行。 |
| [official-d4a0fe2fb1e21a59](report.html#official-d4a0fe2fb1e21a59) | 可生成，视觉待核对 | [第 167 例](https://pele.run/examples/flowchart) | 338.332 × 62 |
| [official-9ed74c540b8e1189](report.html#official-9ed74c540b8e1189) | 待支持 | [第 168 例](https://pele.run/examples/flowchart) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-f4ddc73bd88be46e](report.html#official-f4ddc73bd88be46e) | 待支持 | [第 169 例](https://pele.run/examples/flowchart) | unsupported-syntax：暂不支持样式指令和交互指令。 第 3 行。 |
| [official-f76e6573d220a56a](report.html#official-f76e6573d220a56a) | 待支持 | [第 170 例](https://pele.run/examples/flowchart) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-2f558b7a3d584673](report.html#official-2f558b7a3d584673) | 待支持 | [第 171 例](https://pele.run/examples/flowchart) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-53bb4045f74d8c9d](report.html#official-53bb4045f74d8c9d) | 待支持 | [第 172 例](https://pele.run/examples/flowchart) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-e5ab6951896e8d3c](report.html#official-e5ab6951896e8d3c) | 可生成，视觉待核对 | [第 173 例](https://pele.run/examples/flowchart) | 632.914 × 178 |
| [official-a18dbc06d2617b03](report.html#official-a18dbc06d2617b03) | 可生成，视觉待核对 | [第 174 例](https://pele.run/examples/flowchart) | 251.008 × 178 |
| [official-46c4d04542ff7c8e](report.html#official-46c4d04542ff7c8e) | 可生成，视觉待核对 | [第 175 例](https://pele.run/examples/flowchart) | 737.199 × 148 |

## gantt

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-eb63c5df30e42f5d](report.html#official-eb63c5df30e42f5d) | 待支持 | [第 12 例](https://pele.run/examples) | unsupported-syntax：甘特图暂不支持这个日期格式。 第 3 行。 |
| [official-caed15f5cf495e64](report.html#official-caed15f5cf495e64) | 可生成，视觉待核对 | [第 13 例](https://pele.run/examples) | 1000 × 390 |
| [official-9994b276372df6ec](report.html#official-9994b276372df6ec) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/gantt) | 1000 × 390 |
| [official-b854a6f49b60d200](report.html#official-b854a6f49b60d200) | 待支持 | [第 2 例](https://pele.run/examples/gantt) | unsupported-syntax：甘特图暂不支持这个日期格式。 第 2 行。 |
| [official-c79e89c00972e73f](report.html#official-c79e89c00972e73f) | 待支持 | [第 3 例](https://pele.run/examples/gantt) | syntax：无法解析任务日期或时长。 第 5 行。 |
| [official-908a1947f25e930b](report.html#official-908a1947f25e930b) | 待支持 | [第 4 例](https://pele.run/examples/gantt) | syntax：甘特任务需要冒号和时间定义。 第 5 行。 |
| [official-4cd3811ad968ce17](report.html#official-4cd3811ad968ce17) | 待支持 | [第 5 例](https://pele.run/examples/gantt) | unsupported-syntax：甘特图暂不支持这个日期格式。 第 2 行。 |
| [official-9bf761ee7c35a4d8](report.html#official-9bf761ee7c35a4d8) | 待支持 | [第 6 例](https://pele.run/examples/gantt) | unsupported-syntax：甘特图暂不支持这个日期格式。 第 2 行。 |
| [official-b651c090529ba2c6](report.html#official-b651c090529ba2c6) | 待支持 | [第 7 例](https://pele.run/examples/gantt) | syntax：甘特任务需要冒号和时间定义。 第 2 行。 |
| [official-c4f89c3ee4131419](report.html#official-c4f89c3ee4131419) | 待支持 | [第 8 例](https://pele.run/examples/gantt) | unsupported-configuration：暂不支持 Front matter 字段 displayMode。 第 2 行。 |
| [official-2705bc263a5778c5](report.html#official-2705bc263a5778c5) | 待支持 | [第 11 例](https://pele.run/examples/gantt) | syntax：Front matter 缩进无效。 第 3 行。 |

## gitGraph

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-1e4751fdc7cf19be](report.html#official-1e4751fdc7cf19be) | 待支持 | [第 14 例](https://pele.run/examples) | unsupported-syntax：暂不支持这条提交属性：parent:"B" 第 14 行。 |
| [official-9ecf12a72dac0389](report.html#official-9ecf12a72dac0389) | 待支持 | [第 15 例](https://pele.run/examples) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-d28b30afdeb64f84](report.html#official-d28b30afdeb64f84) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/git) | 840 × 344 |
| [official-37651ecf35070f3d](report.html#official-37651ecf35070f3d) | 可生成，视觉待核对 | [第 2 例](https://pele.run/examples/git) | 440 × 206 |
| [official-014ef174b0d395b7](report.html#official-014ef174b0d395b7) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/git) | 440 × 206 |
| [official-c86bfe00a1c3a284](report.html#official-c86bfe00a1c3a284) | 可生成，视觉待核对 | [第 4 例](https://pele.run/examples/git) | 740 × 206 |
| [official-cc5aab199637d7bc](report.html#official-cc5aab199637d7bc) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples/git) | 840 × 206 |
| [official-39e8da00bc00c7c6](report.html#official-39e8da00bc00c7c6) | 可生成，视觉待核对 | [第 6 例](https://pele.run/examples/git) | 640 × 296 |
| [official-ac1b918a3402075d](report.html#official-ac1b918a3402075d) | 可生成，视觉待核对 | [第 7 例](https://pele.run/examples/git) | 840 × 296 |
| [official-f6fcc0446da1b8c4](report.html#official-f6fcc0446da1b8c4) | 可生成，视觉待核对 | [第 8 例](https://pele.run/examples/git) | 1140 × 296 |
| [official-3347d92631a07bc2](report.html#official-3347d92631a07bc2) | 可生成，视觉待核对 | [第 9 例](https://pele.run/examples/git) | 1140 × 386 |
| [official-2b5676bb24021917](report.html#official-2b5676bb24021917) | 待支持 | [第 11 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-9db160f1ea2da2a3](report.html#official-9db160f1ea2da2a3) | 待支持 | [第 12 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-654c165edb80bec8](report.html#official-654c165edb80bec8) | 待支持 | [第 13 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-c24fff4aa6e688a0](report.html#official-c24fff4aa6e688a0) | 待支持 | [第 14 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-2ea996869e041ddf](report.html#official-2ea996869e041ddf) | 待支持 | [第 15 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-5249bf30205cf685](report.html#official-5249bf30205cf685) | 待支持 | [第 16 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-e5d172db98243b16](report.html#official-e5d172db98243b16) | 待支持 | [第 17 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-69f5b8199e78050f](report.html#official-69f5b8199e78050f) | 可生成，视觉待核对 | [第 18 例](https://pele.run/examples/git) | 1040 × 296 |
| [official-5a05d6be65b2b583](report.html#official-5a05d6be65b2b583) | 可生成，视觉待核对 | [第 19 例](https://pele.run/examples/git) | 280 × 1056 |
| [official-d143f4d6a3ee24e3](report.html#official-d143f4d6a3ee24e3) | 可生成，视觉待核对 | [第 20 例](https://pele.run/examples/git) | 280 × 1056 |
| [official-5375a7af420cc1b6](report.html#official-5375a7af420cc1b6) | 待支持 | [第 21 例](https://pele.run/examples/git) | unsupported-configuration：配置项 gitGraph 尚未支持。 第 3 行。 |
| [official-de1e3eeca8d4a60c](report.html#official-de1e3eeca8d4a60c) | 待支持 | [第 22 例](https://pele.run/examples/git) | unsupported-configuration：配置项 gitGraph 尚未支持。 第 3 行。 |
| [official-2e6d85f337707401](report.html#official-2e6d85f337707401) | 待支持 | [第 23 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-c71743cecb2dabd7](report.html#official-c71743cecb2dabd7) | 待支持 | [第 24 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-5e3445f0fc879faa](report.html#official-5e3445f0fc879faa) | 待支持 | [第 25 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-18580869f46e70b9](report.html#official-18580869f46e70b9) | 待支持 | [第 26 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-0dd68e5f46812c9c](report.html#official-0dd68e5f46812c9c) | 待支持 | [第 28 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-d598a6f6d8055bc8](report.html#official-d598a6f6d8055bc8) | 待支持 | [第 29 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-34f436ae88876391](report.html#official-34f436ae88876391) | 待支持 | [第 30 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-05ddd198c9c03bca](report.html#official-05ddd198c9c03bca) | 待支持 | [第 31 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-32211c1ef5aae521](report.html#official-32211c1ef5aae521) | 待支持 | [第 32 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-79fc3314444f16a4](report.html#official-79fc3314444f16a4) | 待支持 | [第 33 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-a54589c703299306](report.html#official-a54589c703299306) | 待支持 | [第 34 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-8e25ca4d90ecae9d](report.html#official-8e25ca4d90ecae9d) | 待支持 | [第 35 例](https://pele.run/examples/git) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |

## ishikawa

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-b3ea7b01b554303d](report.html#official-b3ea7b01b554303d) | 待支持 | [第 42 例](https://pele.run/examples) | unsupported-syntax：鱼骨图当前支持一个结果、主因和次因三级结构。 |

## journey

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-e978837ae6de4a8b](report.html#official-e978837ae6de4a8b) | 可生成，视觉待核对 | [第 34 例](https://pele.run/examples) | 932 × 440 |

## kanban

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-6a07fd6d17bc2fcc](report.html#official-6a07fd6d17bc2fcc) | 待支持 | [第 16 例](https://pele.run/examples) | unsupported-syntax：树形图暂不支持图标、样式或元数据指令。 第 3 行。 |
| [official-1463e787daaa07b2](report.html#official-1463e787daaa07b2) | 待支持 | [第 17 例](https://pele.run/examples) | unsupported-configuration：配置项 kanban 尚未支持。 第 3 行。 |
| [official-64d471958b3a3c6b](report.html#official-64d471958b3a3c6b) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/kanban) | 320 × 212 |

## mindmap

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-c7e65154315ddffe](report.html#official-c7e65154315ddffe) | 待支持 | [第 18 例](https://pele.run/examples) | unsupported-syntax：树形图暂不支持图标、样式或元数据指令。 第 5 行。 |
| [official-68b700854711a93f](report.html#official-68b700854711a93f) | 待支持 | [第 19 例](https://pele.run/examples) | semantic：思维导图必须只有一个根节点。 |
| [official-93fe6d456e63e3bc](report.html#official-93fe6d456e63e3bc) | 待支持 | [第 1 例](https://pele.run/examples/mindmap) | unsupported-syntax：树形图暂不支持图标、样式或元数据指令。 第 5 行。 |
| [official-50120b037f074517](report.html#official-50120b037f074517) | 可生成，视觉待核对 | [第 2 例](https://pele.run/examples/mindmap) | 1110 × 220 |
| [official-43863c877bb21c72](report.html#official-43863c877bb21c72) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/mindmap) | 420 × 130 |
| [official-b34484235942c5c0](report.html#official-b34484235942c5c0) | 可生成，视觉待核对 | [第 4 例](https://pele.run/examples/mindmap) | 420 × 130 |
| [official-cc31217d41be20e6](report.html#official-cc31217d41be20e6) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples/mindmap) | 420 × 130 |
| [official-19a347a297bd5484](report.html#official-19a347a297bd5484) | 可生成，视觉待核对 | [第 6 例](https://pele.run/examples/mindmap) | 420 × 130 |
| [official-25d14aaf879efe22](report.html#official-25d14aaf879efe22) | 可生成，视觉待核对 | [第 7 例](https://pele.run/examples/mindmap) | 420 × 130 |
| [official-53d07cd0b16d68dc](report.html#official-53d07cd0b16d68dc) | 可生成，视觉待核对 | [第 8 例](https://pele.run/examples/mindmap) | 420 × 130 |
| [official-85604c1294449e7d](report.html#official-85604c1294449e7d) | 可生成，视觉待核对 | [第 9 例](https://pele.run/examples/mindmap) | 420 × 130 |
| [official-3a13884fa1743ddb](report.html#official-3a13884fa1743ddb) | 待支持 | [第 10 例](https://pele.run/examples/mindmap) | unsupported-syntax：树形图暂不支持图标、样式或元数据指令。 第 4 行。 |
| [official-7d02f0df9d19c3f3](report.html#official-7d02f0df9d19c3f3) | 待支持 | [第 11 例](https://pele.run/examples/mindmap) | unsupported-syntax：树形图暂不支持图标、样式或元数据指令。 第 4 行。 |
| [official-5106c1aa1c30fe90](report.html#official-5106c1aa1c30fe90) | 可生成，视觉待核对 | [第 12 例](https://pele.run/examples/mindmap) | 1110 × 220 |
| [official-d34688197fc3593a](report.html#official-d34688197fc3593a) | 待支持 | [第 13 例](https://pele.run/examples/mindmap) | semantic：思维导图必须只有一个根节点。 |

## packet

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-48358a7c12b012d9](report.html#official-48358a7c12b012d9) | 可生成，视觉待核对 | [第 20 例](https://pele.run/examples) | 800 × 668 |
| [official-16d2b45d5aab2633](report.html#official-16d2b45d5aab2633) | 待支持 | [第 21 例](https://pele.run/examples) | unsupported-configuration：配置项 packet 尚未支持。 第 3 行。 |
| [official-fb4fdb7915186d14](report.html#official-fb4fdb7915186d14) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/packet) | 800 × 294 |
| [official-3567105d88bb41a5](report.html#official-3567105d88bb41a5) | 待支持 | [第 5 例](https://pele.run/examples/packet) | unsupported-configuration：配置项 packet 尚未支持。 第 3 行。 |

## pie

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-ae29388222377629](report.html#official-ae29388222377629) | 可生成，视觉待核对 | [第 22 例](https://pele.run/examples) | 620 × 428 |
| [official-f41484cd94dd8483](report.html#official-f41484cd94dd8483) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/pie) | 620 × 428 |
| [official-0618966cc9f61ec4](report.html#official-0618966cc9f61ec4) | 待支持 | [第 2 例](https://pele.run/examples/pie) | unsupported-configuration：配置项 pie 尚未支持。 第 3 行。 |

## quadrantChart

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-19ab9ebf1e76dde2](report.html#official-19ab9ebf1e76dde2) | 可生成，视觉待核对 | [第 23 例](https://pele.run/examples) | 648 × 570 |
| [official-ba45a7442b75146f](report.html#official-ba45a7442b75146f) | 待支持 | [第 3 例](https://pele.run/examples/quadrant) | unsupported-configuration：配置项 quadrantChart 尚未支持。 第 3 行。 |
| [official-cb0348713c1706e9](report.html#official-cb0348713c1706e9) | 待支持 | [第 4 例](https://pele.run/examples/quadrant) | unsupported-syntax：暂不支持这条象限图语法：Campaign A: [0.9, 0.0] radius: 12 第 9 行。 |

## radar

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-39b48990c83837bf](report.html#official-39b48990c83837bf) | 可生成，视觉待核对 | [第 43 例](https://pele.run/examples) | 620 × 578 |
| [official-3e866a35e9ee4a7a](report.html#official-3e866a35e9ee4a7a) | 可生成，视觉待核对 | [第 44 例](https://pele.run/examples) | 620 × 554 |
| [official-8ac5e8cdf4bde31e](report.html#official-8ac5e8cdf4bde31e) | 待支持 | [第 3 例](https://pele.run/examples/radar) | unsupported-configuration：配置项 radar 尚未支持。 第 3 行。 |

## railroad

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-cef5806e4a73cac6](report.html#official-cef5806e4a73cac6) | 待支持 | [第 45 例](https://pele.run/examples) | syntax：铁路图规则需要名称和 = 或 <-。 第 2 行。 |
| [official-013df6171827f1de](report.html#official-013df6171827f1de) | 待支持 | [第 46 例](https://pele.run/examples) | syntax：铁路图规则需要名称和 = 或 <-。 第 2 行。 |
| [official-dbcef8ff2cd577d1](report.html#official-dbcef8ff2cd577d1) | 待支持 | [第 1 例](https://pele.run/examples/railroad) | syntax：铁路图规则需要名称和 = 或 <-。 第 2 行。 |
| [official-7eaf506537b9c6a5](report.html#official-7eaf506537b9c6a5) | 待支持 | [第 2 例](https://pele.run/examples/railroad) | syntax：铁路图规则需要名称和 = 或 <-。 第 2 行。 |
| [official-9288050492569224](report.html#official-9288050492569224) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/railroad) | 360 × 296 |
| [official-21d44260da42bc0d](report.html#official-21d44260da42bc0d) | 可生成，视觉待核对 | [第 4 例](https://pele.run/examples/railroad) | 360 × 106 |
| [official-58d07ac0e2d73d5c](report.html#official-58d07ac0e2d73d5c) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples/railroad) | 360 × 154 |
| [official-ecb34dcea625666b](report.html#official-ecb34dcea625666b) | 待支持 | [第 6 例](https://pele.run/examples/railroad) | syntax：铁路图规则需要名称和 = 或 <-。 第 2 行。 |
| [official-9794f34e0a3fb230](report.html#official-9794f34e0a3fb230) | 待支持 | [第 7 例](https://pele.run/examples/railroad) | syntax：铁路图规则需要名称和 = 或 <-。 第 2 行。 |
| [official-e4b8b1a4559eba40](report.html#official-e4b8b1a4559eba40) | 待支持 | [第 8 例](https://pele.run/examples/railroad) | syntax：暂不支持铁路图函数 term。 第 2 行。 |
| [official-41e29febcb6136f5](report.html#official-41e29febcb6136f5) | 待支持 | [第 11 例](https://pele.run/examples/railroad) | unsupported-syntax：铁路图暂不支持这个词法符号：1。 第 5 行。 |
| [official-e5b8b271aac85395](report.html#official-e5b8b271aac85395) | 待支持 | [第 12 例](https://pele.run/examples/railroad) | unsupported-syntax：铁路图暂不支持这个词法符号：1。 第 5 行。 |
| [official-e825d5ab3c9b8fcf](report.html#official-e825d5ab3c9b8fcf) | 待支持 | [第 13 例](https://pele.run/examples/railroad) | syntax：铁路图规则需要名称和 = 或 <-。 第 2 行。 |
| [official-3fab267fc31fd24f](report.html#official-3fab267fc31fd24f) | 待支持 | [第 14 例](https://pele.run/examples/railroad) | unsupported-syntax：铁路图暂不支持这个词法符号：!。 第 4 行。 |

## requirement

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-767a13512a7a7467](report.html#official-767a13512a7a7467) | 可生成，视觉待核对 | [第 24 例](https://pele.run/examples) | 452.43 × 454 |
| [official-4bff091ab718b957](report.html#official-4bff091ab718b957) | 可生成，视觉待核对 | [第 25 例](https://pele.run/examples) | 461.666 × 172 |
| [official-c95f5d8a69f02ce3](report.html#official-c95f5d8a69f02ce3) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/requirement) | 326.592 × 523 |
| [official-7919bd6c635cc68d](report.html#official-7919bd6c635cc68d) | 可生成，视觉待核对 | [第 2 例](https://pele.run/examples/requirement) | 184.164 × 344 |
| [official-5045f117e286cf38](report.html#official-5045f117e286cf38) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/requirement) | 452.43 × 454 |
| [official-6aee0ba9c47a09ff](report.html#official-6aee0ba9c47a09ff) | 待支持 | [第 5 例](https://pele.run/examples/requirement) | unsupported-syntax：暂不支持这条需求图语法。 第 3 行。 |
| [official-b9d0e63b6c8ae816](report.html#official-b9d0e63b6c8ae816) | 待支持 | [第 6 例](https://pele.run/examples/requirement) | unsupported-syntax：暂不支持这条需求图语法。 第 67 行。 |
| [official-eead694e962481bf](report.html#official-eead694e962481bf) | 待支持 | [第 8 例](https://pele.run/examples/requirement) | unsupported-syntax：暂不支持这条需求图语法。 第 14 行。 |
| [official-fe43760d819f1555](report.html#official-fe43760d819f1555) | 待支持 | [第 9 例](https://pele.run/examples/requirement) | unsupported-syntax：暂不支持这条需求图语法。 第 14 行。 |
| [official-20800df0cf5254ab](report.html#official-20800df0cf5254ab) | 待支持 | [第 10 例](https://pele.run/examples/requirement) | unsupported-syntax：暂不支持这条需求图语法。 第 3 行。 |

## sankey

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-b2407cbd8da61671](report.html#official-b2407cbd8da61671) | 待支持 | [第 26 例](https://pele.run/examples) | unsupported-configuration：配置项 sankey 尚未支持。 第 3 行。 |
| [official-9c049429c8fe41b1](report.html#official-9c049429c8fe41b1) | 可生成，视觉待核对 | [第 27 例](https://pele.run/examples) | 780 × 380 |
| [official-c6739c6a83029fbe](report.html#official-c6739c6a83029fbe) | 待支持 | [第 1 例](https://pele.run/examples/sankey) | unsupported-configuration：配置项 sankey 尚未支持。 第 3 行。 |
| [official-2134589c75e25712](report.html#official-2134589c75e25712) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/sankey) | 780 × 380 |
| [official-9cc115a6cef2e767](report.html#official-9cc115a6cef2e767) | 可生成，视觉待核对 | [第 4 例](https://pele.run/examples/sankey) | 780 × 380 |
| [official-0b3aede151cc98dc](report.html#official-0b3aede151cc98dc) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples/sankey) | 780 × 380 |
| [official-57a2dc77e55611cf](report.html#official-57a2dc77e55611cf) | 待支持 | [第 6 例](https://pele.run/examples/sankey) | unsupported-configuration：配置项 sankey 尚未支持。 第 3 行。 |
| [official-1bafcf479a9a4573](report.html#official-1bafcf479a9a4573) | 待支持 | [第 8 例](https://pele.run/examples/sankey) | unsupported-configuration：配置项 sankey 尚未支持。 第 3 行。 |

## sequence

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-d3a60a7a57394be9](report.html#official-d3a60a7a57394be9) | 可生成，视觉待核对 | [第 28 例](https://pele.run/examples) | 888.297 × 726 |
| [official-a6b0082ad10a3227](report.html#official-a6b0082ad10a3227) | 待支持 | [第 29 例](https://pele.run/examples) | unsupported-syntax：暂不支持这条时序图语法：link Alice: Dashboard @ https://dashboard.contoso.com/alice 第 4 行。 |
| [official-b46ca8f030ae22c7](report.html#official-b46ca8f030ae22c7) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/sequence) | 888.297 × 726 |
| [official-b2066a62d878a2b2](report.html#official-b2066a62d878a2b2) | 可生成，视觉待核对 | [第 2 例](https://pele.run/examples/sequence) | 560.766 × 434 |
| [official-4a0634e0703e2b37](report.html#official-4a0634e0703e2b37) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/sequence) | 888.297 × 726 |
| [official-469a26df510d0cc0](report.html#official-469a26df510d0cc0) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples/sequence) | 512 × 374 |
| [official-2ae466706c787aa9](report.html#official-2ae466706c787aa9) | 可生成，视觉待核对 | [第 6 例](https://pele.run/examples/sequence) | 512 × 374 |
| [official-09a6b5bea4819db4](report.html#official-09a6b5bea4819db4) | 可生成，视觉待核对 | [第 7 例](https://pele.run/examples/sequence) | 550.625 × 374 |
| [official-969bb3ce641248b4](report.html#official-969bb3ce641248b4) | 可生成，视觉待核对 | [第 8 例](https://pele.run/examples/sequence) | 512 × 374 |
| [official-c1a1ef0597c2a313](report.html#official-c1a1ef0597c2a313) | 可生成，视觉待核对 | [第 9 例](https://pele.run/examples/sequence) | 512 × 374 |
| [official-f158c3d82a5bf4f7](report.html#official-f158c3d82a5bf4f7) | 可生成，视觉待核对 | [第 10 例](https://pele.run/examples/sequence) | 512 × 374 |
| [official-bbb78a10baa2dc83](report.html#official-bbb78a10baa2dc83) | 可生成，视觉待核对 | [第 11 例](https://pele.run/examples/sequence) | 531.875 × 374 |
| [official-c7329c9b4aba72a7](report.html#official-c7329c9b4aba72a7) | 可生成，视觉待核对 | [第 12 例](https://pele.run/examples/sequence) | 512 × 374 |
| [official-b833048175d5418f](report.html#official-b833048175d5418f) | 可生成，视觉待核对 | [第 13 例](https://pele.run/examples/sequence) | 560.766 × 374 |
| [official-be26e07607d48aa8](report.html#official-be26e07607d48aa8) | 可生成，视觉待核对 | [第 14 例](https://pele.run/examples/sequence) | 763.922 × 494 |
| [official-ed25c7aa66b7d018](report.html#official-ed25c7aa66b7d018) | 可生成，视觉待核对 | [第 15 例](https://pele.run/examples/sequence) | 763.922 × 494 |
| [official-1371ae9ae607217a](report.html#official-1371ae9ae607217a) | 可生成，视觉待核对 | [第 16 例](https://pele.run/examples/sequence) | 573.844 × 374 |
| [official-5fa9f1e6f236b76b](report.html#official-5fa9f1e6f236b76b) | 可生成，视觉待核对 | [第 17 例](https://pele.run/examples/sequence) | 909.828 × 734 |
| [official-93d3c0ff3d5d384a](report.html#official-93d3c0ff3d5d384a) | 可生成，视觉待核对 | [第 18 例](https://pele.run/examples/sequence) | 972.117 × 506 |
| [official-a013ca4947e10afb](report.html#official-a013ca4947e10afb) | 待支持 | [第 19 例](https://pele.run/examples/sequence) | unsupported-syntax：暂不支持这条时序图语法：Alice->>()John: Hello John 第 4 行。 |
| [official-4a26f3e25a184539](report.html#official-4a26f3e25a184539) | 可生成，视觉待核对 | [第 20 例](https://pele.run/examples/sequence) | 560.766 × 398 |
| [official-028189a67587cce2](report.html#official-028189a67587cce2) | 可生成，视觉待核对 | [第 21 例](https://pele.run/examples/sequence) | 560.766 × 374 |
| [official-8a0283b4e38a5069](report.html#official-8a0283b4e38a5069) | 可生成，视觉待核对 | [第 22 例](https://pele.run/examples/sequence) | 560.766 × 494 |
| [official-592325d675379703](report.html#official-592325d675379703) | 可生成，视觉待核对 | [第 23 例](https://pele.run/examples/sequence) | 440 × 320 |
| [official-a9915542fa20e2bf](report.html#official-a9915542fa20e2bf) | 可生成，视觉待核对 | [第 24 例](https://pele.run/examples/sequence) | 560.766 × 380 |
| [official-c68e948fd0030ddd](report.html#official-c68e948fd0030ddd) | 可生成，视觉待核对 | [第 25 例](https://pele.run/examples/sequence) | 556.578 × 420 |
| [official-40a5ae34a0899545](report.html#official-40a5ae34a0899545) | 可生成，视觉待核对 | [第 26 例](https://pele.run/examples/sequence) | 573.129 × 420 |
| [official-d042768225fc2a2c](report.html#official-d042768225fc2a2c) | 可生成，视觉待核对 | [第 27 例](https://pele.run/examples/sequence) | 560.766 × 444 |
| [official-5ba07f36cdf08b28](report.html#official-5ba07f36cdf08b28) | 可生成，视觉待核对 | [第 28 例](https://pele.run/examples/sequence) | 556.68 × 674 |
| [official-6c0cb8e242cbf8bd](report.html#official-6c0cb8e242cbf8bd) | 可生成，视觉待核对 | [第 29 例](https://pele.run/examples/sequence) | 684 × 604 |
| [official-af802c7e61fb4116](report.html#official-af802c7e61fb4116) | 可生成，视觉待核对 | [第 30 例](https://pele.run/examples/sequence) | 1055.49 × 714 |
| [official-201a0912328e98f2](report.html#official-201a0912328e98f2) | 可生成，视觉待核对 | [第 31 例](https://pele.run/examples/sequence) | 552 × 660 |
| [official-a74c5de6ef55136d](report.html#official-a74c5de6ef55136d) | 可生成，视觉待核对 | [第 32 例](https://pele.run/examples/sequence) | 512 × 384 |
| [official-07788f7e3ced9064](report.html#official-07788f7e3ced9064) | 可生成，视觉待核对 | [第 33 例](https://pele.run/examples/sequence) | 952.125 × 564 |
| [official-14a8499e6a606733](report.html#official-14a8499e6a606733) | 可生成，视觉待核对 | [第 34 例](https://pele.run/examples/sequence) | 720 × 820 |
| [official-c404e4ed538f9b3b](report.html#official-c404e4ed538f9b3b) | 可生成，视觉待核对 | [第 35 例](https://pele.run/examples/sequence) | 560.766 × 374 |
| [official-942c34f9cb6c3d14](report.html#official-942c34f9cb6c3d14) | 可生成，视觉待核对 | [第 36 例](https://pele.run/examples/sequence) | 610.773 × 374 |
| [official-df13c1b9dfa70137](report.html#official-df13c1b9dfa70137) | 可生成，视觉待核对 | [第 37 例](https://pele.run/examples/sequence) | 832.766 × 764 |
| [official-0f2f5747cfd48644](report.html#official-0f2f5747cfd48644) | 待支持 | [第 39 例](https://pele.run/examples/sequence) | unsupported-syntax：暂不支持这条时序图语法：links Alice: {"Dashboard": "https://dashboard.contoso.com/alice", "Wiki": "https://wiki.contoso.com/alice"} 第 4 行。 |

## state

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-9921022022234a8b](report.html#official-9921022022234a8b) | 可生成，视觉待核对 | [第 30 例](https://pele.run/examples) | 264.016 × 562 |
| [official-17d68bbfe39896a1](report.html#official-17d68bbfe39896a1) | 可生成，视觉待核对 | [第 31 例](https://pele.run/examples) | 534.113 × 1501.6 |
| [official-e658870b4c3402e2](report.html#official-e658870b4c3402e2) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/state) | 350.677 × 439 |
| [official-eebe01b06a3fbe2d](report.html#official-eebe01b06a3fbe2d) | 可生成，视觉待核对 | [第 2 例](https://pele.run/examples/state) | 336.746 × 758.042 |
| [official-16d97bc5b2256b16](report.html#official-16d97bc5b2256b16) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/state) | 847.75 × 371 |
| [official-fc35188de9f919aa](report.html#official-fc35188de9f919aa) | 可生成，视觉待核对 | [第 4 例](https://pele.run/examples/state) | 240 × 482 |
| [official-39acf723262aa564](report.html#official-39acf723262aa564) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples/state) | 229.961 × 434 |
| [official-1e1b107393bac8ac](report.html#official-1e1b107393bac8ac) | 可生成，视觉待核对 | [第 6 例](https://pele.run/examples/state) | 264.016 × 562 |
| [official-bd780a3a2d167f10](report.html#official-bd780a3a2d167f10) | 可生成，视觉待核对 | [第 8 例](https://pele.run/examples/state) | 101.695 × 62 |
| [official-31acb54a992766ee](report.html#official-31acb54a992766ee) | 可生成，视觉待核对 | [第 9 例](https://pele.run/examples/state) | 237.039 × 62 |
| [official-e7475df8ff02639a](report.html#official-e7475df8ff02639a) | 可生成，视觉待核对 | [第 10 例](https://pele.run/examples/state) | 237.039 × 62 |
| [official-ad45017122efa301](report.html#official-ad45017122efa301) | 可生成，视觉待核对 | [第 11 例](https://pele.run/examples/state) | 69.4062 × 156 |
| [official-ad6754c39467d7b5](report.html#official-ad6754c39467d7b5) | 可生成，视觉待核对 | [第 12 例](https://pele.run/examples/state) | 84.6758 × 190 |
| [official-f6ff1530a8fe9c57](report.html#official-f6ff1530a8fe9c57) | 可生成，视觉待核对 | [第 13 例](https://pele.run/examples/state) | 66.9375 × 246 |
| [official-885c8b1b173cbaf7](report.html#official-885c8b1b173cbaf7) | 可生成，视觉待核对 | [第 14 例](https://pele.run/examples/state) | 370.57 × 396 |
| [official-8375051aace412a1](report.html#official-8375051aace412a1) | 可生成，视觉待核对 | [第 15 例](https://pele.run/examples/state) | 205.305 × 790 |
| [official-d637094dd39ae470](report.html#official-d637094dd39ae470) | 可生成，视觉待核对 | [第 16 例](https://pele.run/examples/state) | 251.773 × 732 |
| [official-8b4cf7c3adaa9c5f](report.html#official-8b4cf7c3adaa9c5f) | 可生成，视觉待核对 | [第 17 例](https://pele.run/examples/state) | 197.727 × 403.677 |
| [official-9e139d5ea8476442](report.html#official-9e139d5ea8476442) | 可生成，视觉待核对 | [第 18 例](https://pele.run/examples/state) | 223.281 × 528 |
| [official-14b527de19785b23](report.html#official-14b527de19785b23) | 可生成，视觉待核对 | [第 19 例](https://pele.run/examples/state) | 719.461 × 156 |
| [official-e98ccbbe271e462a](report.html#official-e98ccbbe271e462a) | 可生成，视觉待核对 | [第 21 例](https://pele.run/examples/state) | 484 × 148 |
| [official-19213af7efbabc66](report.html#official-19213af7efbabc66) | 可生成，视觉待核对 | [第 22 例](https://pele.run/examples/state) | 229.961 × 434 |
| [official-186122eccfe5e212](report.html#official-186122eccfe5e212) | 待支持 | [第 23 例](https://pele.run/examples/state) | unsupported-syntax：暂不支持这条状态图语法：classDef notMoving fill:white 第 7 行。 |
| [official-592b1439148ea5a9](report.html#official-592b1439148ea5a9) | 待支持 | [第 24 例](https://pele.run/examples/state) | unsupported-syntax：暂不支持这条状态图语法：classDef notMoving fill:white 第 7 行。 |
| [official-7b7ab5b3a5f94bab](report.html#official-7b7ab5b3a5f94bab) | 待支持 | [第 25 例](https://pele.run/examples/state) | unsupported-syntax：暂不支持这条状态图语法：classDef yourState font-style:italic,font-weight:bold,fill:white 第 2 行。 |

## swimlane

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-867cca281590bce5](report.html#official-867cca281590bce5) | 可生成，视觉待核对 | [第 47 例](https://pele.run/examples) | 1413.98 × 640 |
| [official-eaf819cfb8594d42](report.html#official-eaf819cfb8594d42) | 可生成，视觉待核对 | [第 48 例](https://pele.run/examples) | 1645.18 × 640 |
| [official-7677982d4cd415d8](report.html#official-7677982d4cd415d8) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/swimlane) | 818.055 × 640 |
| [official-04962e5b09528a12](report.html#official-04962e5b09528a12) | 可生成，视觉待核对 | [第 2 例](https://pele.run/examples/swimlane) | 800.203 × 640 |
| [official-4de93e7a0c26892b](report.html#official-4de93e7a0c26892b) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/swimlane) | 800.203 × 640 |
| [official-8dfe9a424d0b625f](report.html#official-8dfe9a424d0b625f) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples/swimlane) | 344.57 × 228 |
| [official-60c192d9e1edf6ad](report.html#official-60c192d9e1edf6ad) | 可生成，视觉待核对 | [第 6 例](https://pele.run/examples/swimlane) | 886.266 × 428 |
| [official-aa3016964e4787fc](report.html#official-aa3016964e4787fc) | 可生成，视觉待核对 | [第 7 例](https://pele.run/examples/swimlane) | 820.348 × 640 |
| [official-c97fe4d378535c6b](report.html#official-c97fe4d378535c6b) | 可生成，视觉待核对 | [第 8 例](https://pele.run/examples/swimlane) | 977.85 × 428 |
| [official-4eca0116897bbb8d](report.html#official-4eca0116897bbb8d) | 待支持 | [第 9 例](https://pele.run/examples/swimlane) | syntax：此处需要连线，例如 -->、-->／标签／、-.-> 或 ==>。 第 2 行。 |
| [official-d35379f671d80f98](report.html#official-d35379f671d80f98) | 可生成，视觉待核对 | [第 10 例](https://pele.run/examples/swimlane) | 1275.51 × 640 |
| [official-27ad3133a24aae1a](report.html#official-27ad3133a24aae1a) | 可生成，视觉待核对 | [第 12 例](https://pele.run/examples/swimlane) | 718.398 × 689.145 |
| [official-3328f094a66a6a94](report.html#official-3328f094a66a6a94) | 待支持 | [第 13 例](https://pele.run/examples/swimlane) | unsupported-syntax：暂不支持样式指令和交互指令。 第 13 行。 |
| [official-74df22ac9f981a34](report.html#official-74df22ac9f981a34) | 可生成，视觉待核对 | [第 14 例](https://pele.run/examples/swimlane) | 1049.08 × 655.41 |

## timeline

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-66c69b29e13b8450](report.html#official-66c69b29e13b8450) | 可生成，视觉待核对 | [第 32 例](https://pele.run/examples) | 1040 × 274 |
| [official-fa1cfcc5b78e3a4c](report.html#official-fa1cfcc5b78e3a4c) | 可生成，视觉待核对 | [第 33 例](https://pele.run/examples) | 840 × 404 |
| [official-1b6ef8c6e2bb6038](report.html#official-1b6ef8c6e2bb6038) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/timeline) | 840 × 284 |
| [official-632b53443b0ca687](report.html#official-632b53443b0ca687) | 可生成，视觉待核对 | [第 2 例](https://pele.run/examples/timeline) | 840 × 284 |
| [official-523985f9a7ca3ab9](report.html#official-523985f9a7ca3ab9) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/timeline) | 1040 × 274 |
| [official-c2440af8294c7015](report.html#official-c2440af8294c7015) | 可生成，视觉待核对 | [第 4 例](https://pele.run/examples/timeline) | 840 × 464 |
| [official-e2806e53df11c521](report.html#official-e2806e53df11c521) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples/timeline) | 840 × 354 |
| [official-fc46654076ba27e4](report.html#official-fc46654076ba27e4) | 可生成，视觉待核对 | [第 6 例](https://pele.run/examples/timeline) | 840 × 304 |
| [official-4a436bf5cde4cf70](report.html#official-4a436bf5cde4cf70) | 可生成，视觉待核对 | [第 7 例](https://pele.run/examples/timeline) | 840 × 284 |
| [official-56b167410e41154b](report.html#official-56b167410e41154b) | 待支持 | [第 8 例](https://pele.run/examples/timeline) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-6ee60b83a541e264](report.html#official-6ee60b83a541e264) | 待支持 | [第 9 例](https://pele.run/examples/timeline) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-d355ed477cfd4b67](report.html#official-d355ed477cfd4b67) | 待支持 | [第 10 例](https://pele.run/examples/timeline) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-a24bead1895db6a5](report.html#official-a24bead1895db6a5) | 待支持 | [第 11 例](https://pele.run/examples/timeline) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-f09678e83888b535](report.html#official-f09678e83888b535) | 待支持 | [第 12 例](https://pele.run/examples/timeline) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-87eacd36f6ef7b35](report.html#official-87eacd36f6ef7b35) | 待支持 | [第 13 例](https://pele.run/examples/timeline) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |
| [official-399391685b5266aa](report.html#official-399391685b5266aa) | 待支持 | [第 14 例](https://pele.run/examples/timeline) | unsupported-configuration：配置项 logLevel 尚未支持。 第 3 行。 |

## treeView

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-713fb18511ddb1cc](report.html#official-713fb18511ddb1cc) | 待支持 | [第 49 例](https://pele.run/examples) | unsupported-configuration：配置项 treeView 尚未支持。 第 3 行。 |
| [official-1d23e1ff0c7afdda](report.html#official-1d23e1ff0c7afdda) | 待支持 | [第 50 例](https://pele.run/examples) | unsupported-syntax：树形图暂不支持图标、样式或元数据指令。 第 4 行。 |
| [official-fca891cb5a0356b1](report.html#official-fca891cb5a0356b1) | 待支持 | [第 1 例](https://pele.run/examples/treeview) | unsupported-syntax：树形图暂不支持图标、样式或元数据指令。 第 3 行。 |
| [official-6b40fe28208f3581](report.html#official-6b40fe28208f3581) | 待支持 | [第 2 例](https://pele.run/examples/treeview) | unsupported-syntax：目录树当前支持空格缩进格式。 第 2 行。 |
| [official-39fe66e893ae8c0d](report.html#official-39fe66e893ae8c0d) | 待支持 | [第 3 例](https://pele.run/examples/treeview) | unsupported-syntax：目录树当前支持空格缩进格式。 第 2 行。 |
| [official-3056eee3048bf090](report.html#official-3056eee3048bf090) | 待支持 | [第 4 例](https://pele.run/examples/treeview) | unsupported-syntax：目录树当前支持空格缩进格式。 第 2 行。 |
| [official-9a7ffe1ec7b32a9a](report.html#official-9a7ffe1ec7b32a9a) | 待支持 | [第 5 例](https://pele.run/examples/treeview) | unsupported-syntax：树形图暂不支持图标、样式或元数据指令。 第 3 行。 |
| [official-04e61b50f48a3523](report.html#official-04e61b50f48a3523) | 待支持 | [第 6 例](https://pele.run/examples/treeview) | unsupported-syntax：树形图暂不支持图标、样式或元数据指令。 第 3 行。 |
| [official-4d3420e45f7a8f7d](report.html#official-4d3420e45f7a8f7d) | 待支持 | [第 7 例](https://pele.run/examples/treeview) | unsupported-configuration：配置项 treeView 尚未支持。 第 3 行。 |
| [official-a20065d1be5d947a](report.html#official-a20065d1be5d947a) | 待支持 | [第 9 例](https://pele.run/examples/treeview) | unsupported-syntax：树形图暂不支持图标、样式或元数据指令。 第 3 行。 |
| [official-8fefcf2b5cab12a0](report.html#official-8fefcf2b5cab12a0) | 待支持 | [第 10 例](https://pele.run/examples/treeview) | unsupported-configuration：配置项 treeView 尚未支持。 第 3 行。 |
| [official-47b72aedb6fc36c7](report.html#official-47b72aedb6fc36c7) | 可生成，视觉待核对 | [第 12 例](https://pele.run/examples/treeview) | 420 × 164 |
| [official-3a512e31979952f0](report.html#official-3a512e31979952f0) | 可生成，视觉待核对 | [第 13 例](https://pele.run/examples/treeview) | 420 × 254 |
| [official-3cb8979e83d9be9f](report.html#official-3cb8979e83d9be9f) | 待支持 | [第 14 例](https://pele.run/examples/treeview) | unsupported-configuration：配置项 treeView 尚未支持。 第 3 行。 |

## treemap

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-19c01aaa93ab7b48](report.html#official-19c01aaa93ab7b48) | 待支持 | [第 51 例](https://pele.run/examples) | unsupported-configuration：配置项 treemap 尚未支持。 第 3 行。 |
| [official-20b3fefc8d096e4c](report.html#official-20b3fefc8d096e4c) | 可生成，视觉待核对 | [第 52 例](https://pele.run/examples) | 820 × 468 |
| [official-bac2c087ac52db3b](report.html#official-bac2c087ac52db3b) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/treemap) | 820 × 468 |
| [official-64135f10e0b3a08c](report.html#official-64135f10e0b3a08c) | 待支持 | [第 3 例](https://pele.run/examples/treemap) | unsupported-syntax：树形图暂不支持图标、样式或元数据指令。 第 4 行。 |
| [official-5f240e126b287f1b](report.html#official-5f240e126b287f1b) | 待支持 | [第 4 例](https://pele.run/examples/treemap) | unsupported-syntax：树形图暂不支持图标、样式或元数据指令。 第 4 行。 |
| [official-9acc1e6e648be555](report.html#official-9acc1e6e648be555) | 待支持 | [第 5 例](https://pele.run/examples/treemap) | unsupported-configuration：配置项 theme 尚未支持。 第 3 行。 |
| [official-8b628158795a4271](report.html#official-8b628158795a4271) | 待支持 | [第 6 例](https://pele.run/examples/treemap) | unsupported-configuration：配置项 treemap 尚未支持。 第 3 行。 |
| [official-9c4e6d63b7c161fc](report.html#official-9c4e6d63b7c161fc) | 待支持 | [第 8 例](https://pele.run/examples/treemap) | unsupported-configuration：配置项 treemap 尚未支持。 第 3 行。 |

## usecase

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-38e641131baa1707](report.html#official-38e641131baa1707) | 待支持 | [第 53 例](https://pele.run/examples) | unsupported-configuration：配置项 usecase 尚未支持。 第 3 行。 |
| [official-1d13bb4851a2b199](report.html#official-1d13bb4851a2b199) | 待支持 | [第 54 例](https://pele.run/examples) | unsupported-syntax：暂不支持这条用例图语法。 第 22 行。 |
| [official-00339c496aec5a45](report.html#official-00339c496aec5a45) | 待支持 | [第 1 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 3 行。 |
| [official-d5da69a08ca9bd49](report.html#official-d5da69a08ca9bd49) | 待支持 | [第 2 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 16 行。 |
| [official-602930284299ce28](report.html#official-602930284299ce28) | 待支持 | [第 4 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 4 行。 |
| [official-512322076f2110a9](report.html#official-512322076f2110a9) | 待支持 | [第 5 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 2 行。 |
| [official-5e2ceaa9a657fdc2](report.html#official-5e2ceaa9a657fdc2) | 待支持 | [第 6 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 2 行。 |
| [official-e30205185984ab8a](report.html#official-e30205185984ab8a) | 待支持 | [第 7 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 2 行。 |
| [official-cc7884f2722a0260](report.html#official-cc7884f2722a0260) | 待支持 | [第 8 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 2 行。 |
| [official-2b04d71e8026a82f](report.html#official-2b04d71e8026a82f) | 可生成，视觉待核对 | [第 9 例](https://pele.run/examples/usecase) | 440.738 × 106 |
| [official-b4b9e11d329da958](report.html#official-b4b9e11d329da958) | 待支持 | [第 10 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 2 行。 |
| [official-2d94b58bf0c1709c](report.html#official-2d94b58bf0c1709c) | 待支持 | [第 11 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 2 行。 |
| [official-d4aaab4d50a96bf6](report.html#official-d4aaab4d50a96bf6) | 待支持 | [第 12 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 7 行。 |
| [official-05f26a014a27f80a](report.html#official-05f26a014a27f80a) | 待支持 | [第 13 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 4 行。 |
| [official-9cb66c38e51b5a4d](report.html#official-9cb66c38e51b5a4d) | 待支持 | [第 14 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 7 行。 |
| [official-5b4f68379af67286](report.html#official-5b4f68379af67286) | 待支持 | [第 15 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 5 行。 |
| [official-ddec036429b83779](report.html#official-ddec036429b83779) | 待支持 | [第 16 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 2 行。 |
| [official-a77aca89d95cdd7f](report.html#official-a77aca89d95cdd7f) | 待支持 | [第 17 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 3 行。 |
| [official-d30527c997c57b15](report.html#official-d30527c997c57b15) | 待支持 | [第 18 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 2 行。 |
| [official-5e65e7026d2e1873](report.html#official-5e65e7026d2e1873) | 待支持 | [第 19 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 16 行。 |
| [official-2845caa6b012296d](report.html#official-2845caa6b012296d) | 待支持 | [第 20 例](https://pele.run/examples/usecase) | unsupported-configuration：配置项 usecase 尚未支持。 第 4 行。 |
| [official-d2ecf4a337d37930](report.html#official-d2ecf4a337d37930) | 待支持 | [第 22 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 2 行。 |
| [official-e4fb4f72cd84fab7](report.html#official-e4fb4f72cd84fab7) | 待支持 | [第 23 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 3 行。 |
| [official-ad6a3a578b0f599b](report.html#official-ad6a3a578b0f599b) | 待支持 | [第 24 例](https://pele.run/examples/usecase) | unsupported-syntax：暂不支持这条用例图语法。 第 3 行。 |

## venn

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-7401455503e883e6](report.html#official-7401455503e883e6) | 可生成，视觉待核对 | [第 55 例](https://pele.run/examples) | 570.411 × 588.901 |
| [official-cd2ead2b0d04ca5f](report.html#official-cd2ead2b0d04ca5f) | 可生成，视觉待核对 | [第 56 例](https://pele.run/examples) | 570.411 × 380 |
| [official-9a53dbe64737af6c](report.html#official-9a53dbe64737af6c) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/venn) | 570.411 × 588.901 |
| [official-7e1f629a073676a8](report.html#official-7e1f629a073676a8) | 可生成，视觉待核对 | [第 3 例](https://pele.run/examples/venn) | 570.411 × 424 |
| [official-43f17aa16bc50895](report.html#official-43f17aa16bc50895) | 可生成，视觉待核对 | [第 4 例](https://pele.run/examples/venn) | 570.411 × 380 |
| [official-4ac8b1e3dba7ce46](report.html#official-4ac8b1e3dba7ce46) | 可生成，视觉待核对 | [第 5 例](https://pele.run/examples/venn) | 555.541 × 532.023 |
| [official-dbe2e15b8822e28a](report.html#official-dbe2e15b8822e28a) | 可生成，视觉待核对 | [第 6 例](https://pele.run/examples/venn) | 531.119 × 380 |
| [official-ac6de7c7813c6c44](report.html#official-ac6de7c7813c6c44) | 待支持 | [第 8 例](https://pele.run/examples/venn) | unsupported-syntax：韦恩图当前支持 set、union 和区域 text 声明。 第 7 行。 |

## wardley

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-8a4d5669a9f5d506](report.html#official-8a4d5669a9f5d506) | 待支持 | [第 57 例](https://pele.run/examples) | unsupported-syntax：暂不支持这条 Wardley 图语法。 第 20 行。 |
| [official-6ac86d29b6ee9eca](report.html#official-6ac86d29b6ee9eca) | 待支持 | [第 58 例](https://pele.run/examples) | unsupported-syntax：暂不支持这条 Wardley 图语法。 第 5 行。 |
| [official-ee7968c51b2dfc94](report.html#official-ee7968c51b2dfc94) | 待支持 | [第 1 例](https://pele.run/examples/wardley) | unsupported-syntax：暂不支持这条 Wardley 图语法。 第 20 行。 |
| [official-30bd5186b8416c3f](report.html#official-30bd5186b8416c3f) | 待支持 | [第 3 例](https://pele.run/examples/wardley) | unsupported-syntax：暂不支持这条 Wardley 图语法。 第 3 行。 |
| [official-c8a676b374edb468](report.html#official-c8a676b374edb468) | 可生成，视觉待核对 | [第 4 例](https://pele.run/examples/wardley) | 864 × 576 |
| [official-24cf67f618fb8e52](report.html#official-24cf67f618fb8e52) | 待支持 | [第 5 例](https://pele.run/examples/wardley) | semantic：地图坐标需要 0 到 1 的小数或 0 到 100 的百分数。 第 5 行。 |
| [official-f8939bf3c47509e8](report.html#official-f8939bf3c47509e8) | 可生成，视觉待核对 | [第 6 例](https://pele.run/examples/wardley) | 864 × 576 |
| [official-0dba7eb5e8a69ad3](report.html#official-0dba7eb5e8a69ad3) | 可生成，视觉待核对 | [第 7 例](https://pele.run/examples/wardley) | 864 × 576 |
| [official-eaade9886d10fc14](report.html#official-eaade9886d10fc14) | 待支持 | [第 8 例](https://pele.run/examples/wardley) | unsupported-syntax：暂不支持这条 Wardley 图语法。 第 4 行。 |
| [official-d1f89162a665f281](report.html#official-d1f89162a665f281) | 待支持 | [第 10 例](https://pele.run/examples/wardley) | unsupported-syntax：暂不支持这条 Wardley 图语法。 第 11 行。 |
| [official-bd99ec4274a9f135](report.html#official-bd99ec4274a9f135) | 可生成，视觉待核对 | [第 11 例](https://pele.run/examples/wardley) | 864 × 576 |
| [official-16bd41b8a1695cac](report.html#official-16bd41b8a1695cac) | 待支持 | [第 12 例](https://pele.run/examples/wardley) | unsupported-syntax：暂不支持这条 Wardley 图语法。 第 6 行。 |
| [official-a21a41f96bb7ef97](report.html#official-a21a41f96bb7ef97) | 待支持 | [第 13 例](https://pele.run/examples/wardley) | semantic：地图关系引用了未知组件。 |
| [official-78f1f8e0586b761b](report.html#official-78f1f8e0586b761b) | 待支持 | [第 14 例](https://pele.run/examples/wardley) | semantic：地图关系引用了未知组件。 |
| [official-fa9bb12669913552](report.html#official-fa9bb12669913552) | 待支持 | [第 15 例](https://pele.run/examples/wardley) | semantic：地图关系引用了未知组件。 |
| [official-6ba6230ffb4f7a61](report.html#official-6ba6230ffb4f7a61) | 待支持 | [第 16 例](https://pele.run/examples/wardley) | unsupported-syntax：暂不支持这条 Wardley 图语法。 第 9 行。 |
| [official-c5d091f2bc8cb332](report.html#official-c5d091f2bc8cb332) | 待支持 | [第 17 例](https://pele.run/examples/wardley) | unsupported-syntax：暂不支持这条 Wardley 图语法。 第 11 行。 |
| [official-fcf464d599f56ace](report.html#official-fcf464d599f56ace) | 待支持 | [第 18 例](https://pele.run/examples/wardley) | unsupported-syntax：暂不支持这条 Wardley 图语法。 第 11 行。 |
| [official-d85436bace2b6f19](report.html#official-d85436bace2b6f19) | 待支持 | [第 19 例](https://pele.run/examples/wardley) | unsupported-syntax：暂不支持这条 Wardley 图语法。 第 3 行。 |
| [official-4be02ccb84d6157a](report.html#official-4be02ccb84d6157a) | 待支持 | [第 20 例](https://pele.run/examples/wardley) | unsupported-syntax：暂不支持这条 Wardley 图语法。 第 3 行。 |

## xychart

| 示例 | 状态 | 原始位置 | 结果或原因 |
| --- | --- | --- | --- |
| [official-2cd11b0877977c24](report.html#official-2cd11b0877977c24) | 可生成，视觉待核对 | [第 35 例](https://pele.run/examples) | 896 × 510 |
| [official-250da2c7e81d1f0a](report.html#official-250da2c7e81d1f0a) | 待支持 | [第 36 例](https://pele.run/examples) | unsupported-configuration：配置项 xyChart 尚未支持。 第 3 行。 |
| [official-26b0cd5e3c3bcf2c](report.html#official-26b0cd5e3c3bcf2c) | 可生成，视觉待核对 | [第 1 例](https://pele.run/examples/xychart) | 896 × 510 |
| [official-3685342d92ac9491](report.html#official-3685342d92ac9491) | 可生成，视觉待核对 | [第 2 例](https://pele.run/examples/xychart) | 688 × 510 |
| [official-fbe6837b9d1a9a5d](report.html#official-fbe6837b9d1a9a5d) | 待支持 | [第 3 例](https://pele.run/examples/xychart) | unsupported-configuration：配置项 themeVariables 尚未支持。 第 3 行。 |
| [official-ade44d5c559d10e3](report.html#official-ade44d5c559d10e3) | 待支持 | [第 4 例](https://pele.run/examples/xychart) | unsupported-configuration：配置项 xyChart 尚未支持。 第 3 行。 |
| [official-55d282bc9b85f6b3](report.html#official-55d282bc9b85f6b3) | 待支持 | [第 5 例](https://pele.run/examples/xychart) | unsupported-configuration：配置项 xyChart 尚未支持。 第 3 行。 |
| [official-58d05b223eab0fcc](report.html#official-58d05b223eab0fcc) | 待支持 | [第 6 例](https://pele.run/examples/xychart) | semantic：需要有限的数值。 第 5 行。 |
| [official-ff4787edb814b8de](report.html#official-ff4787edb814b8de) | 待支持 | [第 7 例](https://pele.run/examples/xychart) | semantic：需要有限的数值。 第 5 行。 |
| [official-4191b7b5dc6ecbe6](report.html#official-4191b7b5dc6ecbe6) | 待支持 | [第 8 例](https://pele.run/examples/xychart) | unsupported-configuration：配置项 xyChart 尚未支持。 第 3 行。 |
