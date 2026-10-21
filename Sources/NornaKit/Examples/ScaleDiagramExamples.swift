import Foundation

public struct DiagramExampleComparison: Identifiable, Sendable {
    public var id: String { kind.rawValue }
    public let kind: DiagramKind
    public let simple: DiagramExample
    public let complex: DiagramExample
    public let layoutNote: String

    init(_ kind: DiagramKind, _ layoutNote: String, source: String) {
        self.kind = kind
        self.layoutNote = layoutNote
        simple = (DiagramExample.catalog + DiagramExample.flowcharts).first { $0.kind == kind }!
        complex = DiagramExample(id: "\(kind.rawValue)-complex", title: "\(kind.title) · 复杂示例",
                                 symbol: simple.symbol, source: source)
    }
}

extension DiagramKind {
    public var exampleComparison: DiagramExampleComparison? { DiagramExample.comparisons.first { $0.kind == self } }
    public var exampleLayoutNote: String {
        switch self {
        case .quadrantChart: "固定四象限坐标结构，增加数据点不改变分区方式，保留单例。"
        case .wardley: "固定价值链与演化坐标，增加组件不改变坐标结构，保留单例。"
        case .cynefin: "固定五领域框架，增加条目不改变领域结构，保留单例。"
        case .info: "固定的引擎信息展示，无需按数据规模拆分示例。"
        default: exampleComparison!.layoutNote
        }
    }
}

extension DiagramExample {
    public static let comparisons: [DiagramExampleComparison] = [
        .init(.flowchart, "节点增加后，分支、汇合与跨组连线需要重新分层和避障。", source: """
        flowchart TD
            Start([收到订单]) --> Check{检查订单}
            Check -->|有效| Stock[查询库存]
            Check -->|无效| Reject([请修改订单])
            subgraph Fulfillment[订单履约]
                Stock --> Available{库存充足？}
                Available -->|充足| Reserve[预留商品]
                Available -->|不足| Restock[创建补货任务]
                Restock --> Notify([等待补货])
                Reserve --> Payment[确认支付]
                Payment --> Risk[风险检查]
                Payment --> Confirm[确认收款]
                Risk --> Pack[打包商品]
                Confirm --> Pack
                Pack --> Ship[安排配送]
                Ship --> Delivered[确认签收]
            end
            Delivered --> Invoice[生成凭证]
            Invoice --> End([订单完成])
        """),
        .init(.sequence, "参与者与消息增加后，生命线间距、片段高度和消息换行随之变化。", source: """
        sequenceDiagram
            autonumber
            actor User as 用户
            participant Web as 客户端
            participant API as 订单服务
            participant Stock as 库存服务
            participant Pay as 支付服务
            participant Notify as 通知服务
            User->>Web: 提交订单
            Web->>+API: 创建订单
            API->>Stock: 检查并预留库存
            Stock-->>API: 返回预留结果
            alt 库存充足
                API->>Pay: 创建支付单
                Pay-->>API: 返回支付地址
                API-->>Web: 等待支付
                Web-->>User: 展示支付页面
                User->>Web: 确认支付
                Web->>Pay: 提交支付
                Pay-->>API: 支付完成通知
                API->>Stock: 确认扣减库存
                Stock-->>API: 扣减完成
                API->>Notify: 发送订单确认
                Notify-->>User: 推送订单状态
            else 库存不足
                API->>Notify: 发送缺货提醒
                Notify-->>User: 建议调整订单
            end
            API-->>-Web: 返回最终状态
            Web-->>User: 展示订单详情
        """),
        .init(.classDiagram, "类和关系增加后，卡片分层、成员分区与关系端口更加明显。", source: """
        classDiagram
            direction TD
            class Customer {
                +String name
                +placeOrder() Order
            }
            class Address {
                +String city
                +String detail
            }
            class Order {
                +String id
                +total() Money
            }
            class OrderItem {
                +int quantity
                +subtotal() Money
            }
            class Product {
                +String title
                +Money price
            }
            class Payment {
                +String status
                +authorize() bool
            }
            class Shipment {
                +String trackingID
                +dispatch()
            }
            Customer --> Order : 创建
            Customer --> Address : 保存
            Order "1" *-- "1..*" OrderItem
            OrderItem --> Product : 商品
            Order --> Payment : 支付
            Payment --> Shipment : 确认配送
        """),
        .init(.state, "更多状态会增加转移通道，复合状态需要独立布局。", source: """
        stateDiagram-v2
            [*] --> Draft
            Draft --> Submitted : 提交
            Submitted --> Reviewing : 开始审核
            Reviewing --> Rejected : 不通过
            Rejected --> Draft : 修改
            Reviewing --> Approved : 通过
            Approved --> Processing : 开始履约
            state Processing {
                [*] --> Packing
                Packing --> Shipping : 发货
                Shipping --> [*] : 签收
            }
            Processing --> Completed : 履约结束
            Completed --> Archived : 归档
            Archived --> [*]
        """),
        .init(.er, "实体数量和字段增加后，实体卡片的尺寸与关系分层随之扩展。", source: """
        erDiagram
            CUSTOMER ||--o{ ORDER : places
            CUSTOMER ||--o{ ADDRESS : owns
            ORDER ||--|{ ORDER_ITEM : includes
            ORDER_ITEM }o--|| PRODUCT : references
            ORDER ||--|o PAYMENT : paid_by
            PAYMENT ||--o{ PAYMENT_ATTEMPT : retries
            CUSTOMER {
                string id PK
                string name
                string email
            }
            ORDER {
                string id PK
                string customer_id FK
                string status
            }
            ORDER_ITEM {
                string id PK
                string product_id FK
                int quantity
            }
            PRODUCT {
                string id PK
                string title
                float price
            }
            ADDRESS {
                string city
                string detail
            }
            PAYMENT {
                string method
                string status
            }
            PAYMENT_ATTEMPT {
                string attempt_id
                string status
            }
        """),
        .init(.pie, "分类增加后，扇区变细，图例和标签更密集。", source: """
        pie showData title 团队功能使用分布
            "流程图" : 28
            "时序图" : 19
            "类图" : 12
            "状态图" : 10
            "架构图" : 8
            "实体关系图" : 7
            "思维导图" : 5
            "甘特图" : 4
            "数据图表" : 3
            "其他" : 2
        """),
        .init(.gantt, "更多任务和阶段会扩展时间跨度与任务行，窄画布需要更紧凑的时间轴。", source: """
        gantt
            title 产品交付计划
            dateFormat YYYY-MM-DD
            section 调研
                用户访谈 :done, interviews, 2026-10-01, 4d
                需求整理 :done, requirements, after interviews, 3d
                方案评审 :done, review, after requirements, 2d
            section 开发
                数据模型 :active, model, after review, 4d
                原生编辑器 :active, editor, after review, 8d
                布局引擎 :crit, layout, after model, 7d
                导出模块 :export, after model, 5d
            section 验证
                单元测试 :tests, after layout, 4d
                视觉回归 :visual, after export, 5d
                性能验证 :perf, after tests, 3d
            section 交付
                文档整理 :docs, after visual, 3d
                发布准备 :release, after perf, 2d
        """),
        .init(.gitGraph, "提交和分支增加后，会出现更多分支轨道、合并线与提交标签。", source: """
        gitGraph
            commit id: "init"
            branch develop
            commit id: "model"
            branch feature-layout
            commit id: "layers"
            commit id: "ports"
            checkout develop
            branch feature-export
            commit id: "svg"
            commit id: "theme"
            checkout develop
            merge feature-layout id: "merge-layout"
            merge feature-export id: "merge-export"
            commit id: "tests"
            checkout main
            merge develop id: "release" tag: "v1.0"
            branch hotfix
            commit id: "labels"
            checkout main
            merge hotfix id: "patch" tag: "v1.0.1"
        """),
        .init(.mindmap, "分支和层级增加后，左右子树展开，父节点位置随子树高度调整。", source: """
        mindmap
            root((图表产品))
                用户体验
                    源码编辑
                        语法提示
                        错误定位
                    原生交互
                        平移缩放
                        节点选择
                图形引擎
                    语法解析
                        流程与交互
                        数据与关系
                    布局计算
                        自动分层
                        连线避障
                质量保证
                    单元测试
                    视觉回归
                    性能分析
                交付
                    文档
                    示例
                    版本发布
        """),
        .init(.timeline, "阶段和事件增加后，横向时间线变长，窄画布会改为纵向排列。", source: """
        timeline
            title 产品演进路线
            section 探索
                一月 : 用户调研 : 需求访谈
                二月 : 技术验证 : 原型评审
            section 构建
                三月 : 解析器 : 场景模型
                四月 : 流程图 : 时序图
                五月 : 关系图 : 子图布局
            section 验证
                六月 : 视觉回归 : 性能优化
                七月 : 内部试用 : 问题修复
            section 交付
                八月 : 文档完善 : 正式发布
        """),
        .init(.journey, "更多阶段、步骤和参与者会扩展旅程，窄画布会重排步骤卡片。", source: """
        journey
            title 团队协作绘图旅程
            section 准备
                了解需求: 4: 产品, 设计
                收集资料: 3: 产品
                确认范围: 5: 产品, 开发
            section 创建
                编写源码: 4: 开发
                查看预览: 5: 开发, 设计
                调整布局: 3: 开发, 设计
            section 评审
                分享草稿: 4: 产品, 开发
                收集意见: 3: 产品, 设计
                完成修改: 5: 开发
            section 交付
                导出图表: 5: 开发
                更新文档: 4: 产品
                归档版本: 5: 产品, 开发
        """),
        .init(.xychart, "数据点和系列增加后，柱宽、折线密度、刻度与图例排列随之变化。", source: """
        xychart-beta
            title "全年图表使用量"
            x-axis [一月, 二月, 三月, 四月, 五月, 六月, 七月, 八月, 九月, 十月, 十一月, 十二月]
            y-axis "数量" 0 --> 240
            bar "新建" [42, 55, 68, 75, 98, 115, 128, 146, 165, 184, 202, 225]
            bar "共享" [18, 24, 32, 40, 47, 59, 68, 82, 96, 108, 125, 146]
            line "导出" [30, 38, 52, 61, 80, 92, 110, 125, 149, 162, 186, 210]
        """),
        .init(.requirement, "需求、实现和验证对象增加后，关系图会出现多层追踪路径。", source: """
        requirementDiagram
            direction TD
            requirement Native {
                id: REQ-001
                text: 原生渲染
                risk: medium
                verifymethod: test
            }
            requirement Export {
                id: REQ-002
                text: 矢量导出
                risk: low
                verifymethod: test
            }
            requirement Layout {
                id: REQ-003
                text: 自适应布局
                risk: high
                verifymethod: demonstration
            }
            element Engine {
                type: software
            }
            element SVG {
                type: software
            }
            element Tests {
                type: test
            }
            Native - contains -> Layout
            Native - contains -> Export
            Engine - satisfies -> Native
            SVG - satisfies -> Export
            Tests - verifies -> Native
            Tests - verifies -> Layout
        """),
        .init(.c4, "人物、系统边界和服务增加后，跨边界关系和卡片布局更复杂。", source: """
        C4Container
            title 订单平台
            Person(customer, "客户", "创建与查询订单")
            System_Boundary(platform, "订单平台") {
                Container(web, "用户界面", "Swift", "订单操作入口")
                Container(api, "订单服务", "Swift", "处理订单请求")
                Container(stock, "库存服务", "Swift", "预留与扣减商品")
                Container(payment, "支付服务", "Swift", "创建与确认支付")
                ContainerDb(database, "订单数据", "SQLite", "保存订单与状态")
            }
            System_Ext(logistics, "配送平台", "追踪运输状态")
            Rel(customer, web, "操作")
            Rel(web, api, "提交订单")
            Rel(api, stock, "预留库存")
            Rel(api, payment, "确认支付")
            Rel(stock, database, "记录库存")
            Rel(payment, database, "记录支付")
            Rel(database, logistics, "发送配送任务")
        """),
        .init(.sankey, "来源、流向与权重增加后，节点分层、条带宽度和流量分配随之变化。", source: """
        sankey-beta
        搜索,产品页,34
        搜索,文档页,16
        社区,产品页,22
        社区,文档页,18
        推荐,产品页,28
        推荐,文档页,12
        产品页,注册,54
        产品页,离开,30
        文档页,注册,28
        文档页,离开,18
        注册,个人版,50
        注册,团队版,32
        """),
        .init(.block, "块数量增加后会换行，跨列块与多行连接形成更丰富的网格。", source: """
        block-beta
            columns 3
            Input[输入数据]:3
            A[文本输入] B[文件导入] C[模板选择]
            D[解析] E[校验] F[布局]
            G[原生预览] H[矢量导出] I[图片导出]
            Output[结果归档]:3
            Input --> A
            Input --> B
            Input --> C
            A --> D
            B --> E
            C --> F
            D --> G
            E --> H
            F --> I
            G --> Output
            H --> Output
            I --> Output
        """),
        .init(.packet, "字段和位宽增加后，字段跨越更多行，窄字段的标签显示也会变化。", source: """
        packet-beta
            title 扩展消息协议
            0-3: "Version"
            4-7: "Type"
            8-15: "Flags"
            16-31: "Length"
            32-63: "Request ID"
            64-95: "Source"
            96-127: "Destination"
            128-191: "Timestamp"
            192-223: "Sequence"
            224-239: "Format"
            240-255: "Checksum"
            256-351: "Payload"
            352-383: "Trailer"
        """),
        .init(.kanban, "列与卡片增加后，列宽、卡片换行和看板高度需要适应容器。", source: """
        kanban
            backlog[需求池]
                a[跨平台渲染接口]
                b[更多主题配置]
                c[大图性能分析]
            ready[待开始]
                d[扩展关系语法]
                e[完善错误定位]
                f[整理文档示例]
            doing[进行中]
                g[复杂数据布局]
                h[原生画布交互]
                i[导出质量检查]
                j[无障碍体验]
            review[待评审]
                k[示例对照页面]
                l[系统外观适配]
            done[已完成]
                m[基础解析器]
                n[流程与子图]
                o[系统字体测量]
        """),
        .init(.architecture, "服务与分组增加后，跨组连接、分支端口与图形中心对齐更加明显。", source: """
        architecture-beta
            service web(internet)[客户端]
            group app[应用服务]
            service api(server)[API 网关] in app
            service orders(server)[订单服务] in app
            service payments(server)[支付服务] in app
            group data[数据服务]
            service ordersDB(database)[订单数据] in data
            service paymentDB(database)[支付数据] in data
            service backup(disk)[备份] in data
            web:R --> L:api
            api:R --> L:orders
            api:R --> L:payments
            orders:R --> L:ordersDB
            payments:R --> L:paymentDB
            ordersDB:R --> L:backup
        """),
        .init(.radar, "维度与数据系列增加后，网格角度、曲线密度和图例布局随之变化。", source: """
        radar-beta
            title 多版本能力对比
            axis 解析, 布局, 绘制, 导出, 交互, 性能, 易用, 无障碍
            curve stable["稳定版"]{8,7,9,8,9,7,8,8}
            curve preview["预览版"]{9,8,9,9,9,8,8,9}
            curve target["目标"]{10,10,10,10,10,10,10,10}
            max 10
        """),
        .init(.treemap, "更多层级与不均匀权重会改变矩形切分，小面积区域会减少标签。", source: """
        treemap-beta
            "产品开发"
                "原生引擎"
                    "解析": 32
                    "分层布局": 42
                    "连线避障": 28
                    "文字测量": 16
                "应用体验"
                    "编辑器": 24
                    "画布": 26
                    "菜单": 8
                    "无障碍": 10
            "质量保证"
                "单元测试": 26
                "视觉回归": 22
                "性能测试": 14
                "边界用例": 3
            "交付"
                "文档": 12
                "示例": 10
                "发布": 6
                "其他": 1
        """),
        .init(.agentflow, "更多智能体和任务分支会增加并行路径、汇合点与层级跨度。", source: """
        agentflow-beta TD
            Request[用户请求] --> Plan[任务规划]
            Plan --> Route{选择处理路径}
            Route --> Research[研究智能体]
            Route --> Code[编码智能体]
            Route --> Data[数据智能体]
            Research --> Sources[整理资料]
            Code --> Implement[实现方案]
            Data --> Analyze[分析数据]
            Sources --> Review[交叉验证]
            Implement --> Review
            Analyze --> Review
            Review --> Quality{结果完整？}
            Quality -->|完整| Answer[汇总答复]
            Quality -->|需补充| FollowUp[补充任务]
            FollowUp --> Draft[生成修订稿]
            Draft --> Answer
        """),
        .init(.usecase, "更多人物、边界与用例会扩展关联通道，需要避让不同分组和人物名称。", source: """
        usecase-beta
            actor Customer[客户]
            actor Operator[运营人员]
            systemBoundary Store[客户服务]
                Browse(浏览商品)
                Order(创建订单)
                Track(追踪配送)
                Refund(申请退款)
            end
            systemBoundary Admin[运营服务]
                Review(审核退款)
                Manage(维护商品)
            end
            Customer --> Browse
            Customer --> Order
            Customer --> Track
            Customer --> Refund
            Operator --> Review
            Operator --> Manage
        """),
        .init(.railroad, "可选项、重复项与候选分支增加后，轨道会同时向横向和纵向展开。", source: """
        railroad-ebnf-beta
            document = header { statement } [ footer ] ;
            header = "diagram" ( "flow" | "sequence" | "state" | "class" ) ;
            statement = node | edge | group ;
            node = identifier [ "label" text ] [ "shape" ( "rect" | "circle" | "diamond" ) ] ;
            edge = identifier arrow identifier [ text ] ;
            arrow = "-->" | "-.->" | "==>" ;
            group = "group" identifier "{" { statement } "}" ;
            footer = "end" [ text ] ;
        """),
        .init(.treeView, "目录数量与嵌套深度增加后，缩进、分支线与画布高度随之扩展。", source: """
        treeView-beta
            NornaKit/
                Sources/
                    NornaKit/
                        Parsing/
                            FlowchartParser.swift
                            SequenceParser.swift
                        Layout/
                            LayeredLayout.swift
                            CompoundRouter.swift
                        Drawing/
                            ScenePainter.swift
                            SVGExporter.swift
                    NornaStudio/
                        Views/
                            StudioView.swift
                            SourceEditor.swift
                        Models/
                            StudioModel.swift
                Tests/
                    ParserTests/
                    LayoutTests/
                    DrawingTests/
                Resources/
                    Examples/
                    Baselines/
                Package.swift
                README.md
        """),
        .init(.venn, "从两个集合增加到三个集合后，圆的位置与多重交集区域会发生变化。", source: """
        venn-beta
            title 团队能力交集
            set Design[设计]: 60
            set Dev[开发]: 60
            set Product[产品]: 60
            union Design,Dev[协作]: 20
            union Design,Product[体验]: 20
            union Dev,Product[交付]: 20
            union Design,Dev,Product[共同目标]: 8
        """),
        .init(.swimlane, "泳道、步骤和交接增加后，泳道尺寸与跨泳道的连线路径都会变化。", source: """
        swimlane-beta LR
            subgraph Customer[客户]
                A[提交订单] --> B[确认支付]
                B --> C[接收商品]
            end
            subgraph Sales[订单服务]
                D[创建订单] --> E[确认库存]
                E --> F[更新状态]
            end
            subgraph Payment[支付服务]
                G[创建支付单] --> H[确认收款]
            end
            subgraph Delivery[配送服务]
                I[安排发货] --> J[追踪配送]
            end
            A --> D
            E --> G
            B --> H
            H --> F
            F --> I
            J --> C
        """),
        .init(.ishikawa, "主因和次因增加后，鱼骨数量、分支长度与画布高度会扩展。", source: """
        ishikawa-beta
            图表可读性下降
                数据
                    节点过多
                    层级过深
                    权重悬殊
                文字
                    标签过长
                    字号过大
                    换行不足
                布局
                    间距过小
                    分层不清
                    分组拥挤
                连线
                    路径交叉
                    转折过密
                    箭头重合
                外观
                    对比度不足
                    颜色过多
                    层级不明显
                验证
                    缺少复杂示例
                    缺少窄屏检查
                    缺少视觉回归
        """),
        .init(.eventmodeling, "事件帧和引用增加后，横向时间顺序扩展，并出现更多跨泳道依赖。", source: """
        eventmodeling
            title 订单事件流
            tf 01 ui 商品页面
            tf 02 cmd 创建订单
            tf 03 evt 订单已创建
            tf 04 rmo 待支付订单
            tf 05 ui 支付页面
            tf 06 cmd 确认支付
            tf 07 evt 支付已完成
            tf 08 rmo 待发货订单
            tf 09 pcr 配送处理
            tf 10 cmd 安排配送
            tf 11 evt 商品已发出
            tf 12 rmo 配送进度
            tf 13 ui 订单详情
        """),
    ]
}
