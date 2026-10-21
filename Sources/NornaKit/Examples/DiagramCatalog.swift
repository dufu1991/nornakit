import Foundation

extension DiagramExample {
    public static let catalog: [DiagramExample] = [
        .init(id: "sequence", title: "时序图", symbol: "arrow.left.arrow.right", source: """
        sequenceDiagram
            autonumber
            actor User as 用户
            participant App as 应用
            participant API as 服务端
            User->>App: 提交请求
            App->>+API: 校验并处理
            Note over App,API: 原生消息、激活与分支
            alt 请求有效
                API-->>App: 返回结果
            else 请求无效
                API-->>App: 返回错误
            end
            deactivate API
            App-->>User: 展示响应
        """),
        .init(id: "class", title: "类图", symbol: "square.stack.3d.up", source: """
        classDiagram
            direction LR
            class Renderer {
                +render(source)
            }
            class NativeRenderer {
                -scene DiagramScene
                +render(source)
            }
            class SVGExporter {
                +export(scene)
            }
            Renderer <|.. NativeRenderer
            NativeRenderer --> SVGExporter : exports
        """),
        .init(id: "state", title: "状态图", symbol: "circle.hexagongrid", source: """
        stateDiagram-v2
            [*] --> Idle
            Idle --> Parsing: 编辑源码
            Parsing --> Ready: 成功
            Parsing --> Error: 语法错误
            Error --> Parsing: 修正
            Ready --> [*]
        """),
        .init(id: "er", title: "实体关系图", symbol: "cylinder.split.1x2", source: """
        erDiagram
            PROJECT ||--o{ DIAGRAM : contains
            DIAGRAM ||--o{ EXPORT : produces
            PROJECT {
                string id PK
                string name
            }
            DIAGRAM {
                string id PK
                string source
            }
            EXPORT {
                string format
                string path
            }
        """),
        .init(id: "pie", title: "饼图", symbol: "chart.pie", source: """
        pie showData title 图形使用分布
            "流程图" : 46
            "时序图" : 28
            "关系图" : 16
            "其他" : 10
        """),
        .init(id: "gantt", title: "甘特图", symbol: "chart.bar.xaxis", source: """
        gantt
            title 原生引擎开发计划
            dateFormat YYYY-MM-DD
            section 核心
            场景模型 :done, scene, 2026-10-01, 5d
            时序图 :active, seq, after scene, 7d
            section 图形
            数据图表 :charts, 2026-10-06, 10d
            回归测试 :crit, tests, after charts, 4d
        """),
        .init(id: "gitGraph", title: "Git 分支图", symbol: "arrow.triangle.branch", source: """
        gitGraph
            commit id: "init"
            branch develop
            commit id: "native"
            commit id: "sequence"
            checkout main
            commit id: "docs"
            merge develop id: "release" tag: "v0.2"
        """),
        .init(id: "mindmap", title: "思维导图", symbol: "brain", source: """
        mindmap
            root((Norna))
                解析
                    Mermaid
                    语义校验
                布局
                    层级
                    时间轴
                绘制
                    CoreGraphics
                    SVG
        """),
        .init(id: "timeline", title: "时间线", symbol: "clock", source: """
        timeline
            title 原生渲染路线
            section 基础
                第一阶段 : 流程图 : 子图
                第二阶段 : 时序图 : 关系图
            section 扩展
                第三阶段 : 数据图表 : 高级布局
        """),
        .init(id: "journey", title: "用户旅程", symbol: "figure.walk", source: """
        journey
            title 从想法到图表
            section 编辑
                输入源码: 4: 用户
                查看预览: 5: 用户, 引擎
            section 调整
                修正语法: 2: 用户
                导出结果: 5: 用户, 引擎
        """),
        .init(id: "xychart", title: "XY 坐标图", symbol: "chart.xyaxis.line", source: """
        xychart-beta
            title "每周图表数量"
            x-axis [第一周, 第二周, 第三周, 第四周]
            y-axis "数量" 0 --> 100
            bar "创建" [24, 48, 62, 85]
            line "导出" [16, 35, 54, 72]
        """),
        .init(id: "quadrantChart", title: "象限图", symbol: "square.grid.2x2", source: """
        quadrantChart
            title 优先级评估
            x-axis 低成本 --> 高成本
            y-axis 低价值 --> 高价值
            quadrant-1 重点投入
            quadrant-2 优先实现
            quadrant-3 暂缓
            quadrant-4 重新评估
            时序图: [0.3, 0.8]
            全量兼容: [0.85, 0.85]
            自定义动画: [0.7, 0.25]
        """),
        .init(id: "requirement", title: "需求图", symbol: "checklist", source: """
        requirementDiagram
            requirement Native {
                id: REQ-001
                text: 纯 Swift 原生绘制
                risk: medium
                verifymethod: test
            }
            element Engine {
                type: software
                docRef: NornaKit
            }
            Engine - satisfies -> Native
        """),
        .init(id: "c4", title: "C4 架构图", symbol: "building.2", source: """
        C4Context
            title 图表工作台
            Person(user, "用户", "编辑图表")
            System_Boundary(studio, "Norna Studio") {
                System(editor, "编辑器", "Mermaid 源码")
                System(engine, "原生引擎", "Swift 几何布局")
            }
            Rel(user, editor, "编辑")
            Rel(editor, engine, "渲染")
        """),
        .init(id: "sankey", title: "桑基图", symbol: "arrow.triangle.merge", source: """
        sankey-beta
        输入,流程图,46
        输入,时序图,28
        输入,关系图,26
        流程图,原生画布,30
        流程图,SVG,16
        时序图,原生画布,20
        时序图,SVG,8
        关系图,SVG,26
        """),
        .init(id: "block", title: "块图", symbol: "rectangle.grid.3x2", source: """
        block-beta
            columns 3
            A[解析] B[布局] C[绘制]
            D[模型] E[场景] F[导出]
            A --> B
            B --> C
            D --> E
            E --> F
        """),
        .init(id: "packet", title: "数据包图", symbol: "square.split.2x2", source: """
        packet-beta
            title TCP 报文头
            0-15: "Source Port"
            16-31: "Destination Port"
            32-63: "Sequence Number"
            64-95: "Acknowledgment"
            96-99: "Offset"
            100-105: "Reserved"
            106-111: "Flags"
            112-127: "Window"
        """),
        .init(id: "kanban", title: "看板", symbol: "rectangle.split.3x1", source: """
        kanban
            todo[待处理]
                a[扩展语法兼容]
                b[优化复杂布局]
            doing[进行中]
                c[原生图形引擎]
            done[已完成]
                d[流程图与子图]
                e[通用矢量场景]
        """),
        .init(id: "architecture", title: "架构图", symbol: "server.rack", source: """
        architecture-beta
            group backend[服务层]
            service api(server)[API 网关] in backend
            service db(database)[数据库] in backend
            service web(internet)[客户端]
            web:R --> L:api
            api:R --> L:db
        """),
        .init(id: "radar", title: "雷达图", symbol: "hexagon", source: """
        radar-beta
            title 渲染能力
            axis 解析, 布局, 绘制, 导出, 交互
            curve native["原生实现"]{8,7,9,8,9}
            curve reference["目标"]{10,10,10,10,10}
            max 10
        """),
        .init(id: "treemap", title: "矩形树图", symbol: "rectangle.3.group", source: """
        treemap-beta
            "图形引擎"
                "解析": 32
                "布局": 44
                "绘制": 24
            "应用"
                "编辑": 18
                "交互": 12
        """),
        .init(id: "info", title: "信息图", symbol: "info.circle", source: "info\nshowInfo"),
        .init(id: "agentflow", title: "智能体流程", symbol: "sparkles", source: """
        agentflow-beta LR
            A[用户请求] --> B{路由}
            B --> C[研究智能体]
            B --> D[编码智能体]
            C --> E[汇总响应]
            D --> E
        """),
        .init(id: "usecase", title: "用例图", symbol: "person.2", source: """
        usecase-beta
            actor User[用户]
            systemBoundary Studio[图表工作台]
                Edit(编辑源码)
                Preview(查看预览)
                Export(导出图表)
            end
            User --> Edit
            User --> Preview
            User --> Export
        """),
        .init(id: "railroad", title: "语法铁路图", symbol: "point.topleft.down.curvedto.point.bottomright.up", source: """
        railroad-ebnf-beta
            diagram = "flowchart" direction [ node ] { edge node } ;
            direction = "TD" | "LR" | "BT" | "RL" ;
        """),
        .init(id: "treeView", title: "目录树", symbol: "folder", source: """
        treeView-beta
            Norna/
                Sources/
                    NornaKit/
                        DiagramScene.swift
                    NornaStudio/
                        StudioView.swift
                Tests/
                Package.swift
        """),
        .init(id: "venn", title: "韦恩图", symbol: "circle.lefthalf.filled", source: """
        venn-beta
            title 能力交集
            set Swift[Swift]: 60
            set Graphics[Graphics]: 45
            union Swift,Graphics: 20
        """),
        .init(id: "cynefin", title: "Cynefin 框架", symbol: "square.grid.2x2", source: """
        cynefin-beta
            title 问题处理方式
            complex
                "探索新的布局方法"
            complicated
                "分析兼容性差异"
            clear
                "修复确定的语法问题"
            chaotic
                "处理运行时崩溃"
            confusion
                "识别问题所属领域"
        """),
        .init(id: "wardley", title: "Wardley 地图", symbol: "map", source: """
        wardley-beta
            title 图表产品地图
            anchor 用户价值 [0.95, 0.4]
            component 编辑体验 [0.75, 0.6]
            component 原生引擎 [0.5, 0.35]
            component 系统框架 [0.15, 0.9]
            用户价值 -> 编辑体验
            编辑体验 -> 原生引擎
            原生引擎 -> 系统框架
        """),
        .init(id: "swimlane", title: "泳道图", symbol: "rectangle.split.2x1", source: """
        swimlane-beta LR
            subgraph User[用户]
                A[提交请求] --> B[确认结果]
            end
            subgraph Service[服务]
                C[处理请求] --> D[返回响应]
            end
            A --> C
            D --> B
        """),
        .init(id: "ishikawa", title: "鱼骨图", symbol: "fish", source: """
        ishikawa-beta
            渲染质量
                解析
                    语法覆盖
                    错误定位
                布局
                    节点分层
                    连线避障
                绘制
                    字体测量
                    路径精度
                验证
                    回归测试
                    视觉检查
        """),
        .init(id: "eventmodeling", title: "事件建模", symbol: "rectangle.3.group.bubble", source: """
        eventmodeling
            tf 01 ui 编辑器
            tf 02 cmd 提交源码
            tf 03 evt 源码已更新
            tf 04 rmo 图表场景
            tf 05 ui 预览画布
        """)
    ]
}
