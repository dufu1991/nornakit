import Foundation
import NornaKit

extension DiagramExample {
    public static let advanced: [DiagramExample] = [
        .init(id: "flow-advanced", title: "扩展节点与双向连线", symbol: "arrow.left.arrow.right", source: """
        flowchart LR
            subgraph Client[客户端]
                direction TD
                A@{ shape: stadium, label: "用户操作" } <--> B{{校验请求}}
                B --> C[/请求数据/]
            end
            C <-->|HTTPS| D@{ shape: cyl, label: "服务存储" }
            D --o E>消息通知]
            E --x F(((终止任务)))
            B -.->|失败| F
            D ~~~ F
        """),
        .init(id: "sequence-sf-symbols", title: "SF Symbols 消息", symbol: "bubble.left.and.bubble.right", source: """
        sequenceDiagram
            actor User as 用户 :sf:person.fill:
            participant App as 应用 :sf:app:
            participant Cloud as 云端 :sf:icloud:
            User->>App: 选择 :sf:doc.text: 文件
            Note over App,Cloud: 原生 :sf:sparkles: 图标与文字<br/>共享字号、颜色和基线
            App->>+Cloud: 上传 :sf:icloud.and.arrow.up: 文件
            Cloud-->>-App: 保存 :sf:checkmark.circle.fill: 成功
            App-->>User: 展示 :sf:photo: 预览
        """),
        .init(id: "sequence-lifecycle", title: "参与者生命周期", symbol: "person.crop.rectangle.badge.plus", source: """
        sequenceDiagram
            autonumber
            actor User as 用户
            participant API@{ "type": "control", "alias": "服务" }
            User->>+API: 提交任务
            create participant Worker as 临时工作进程
            API->>Worker: 创建并执行
            loop 处理批次
                Worker->>Worker: 处理数据
            end
            note over API,Worker
                任务结束后释放工作进程
                生命线在销毁消息处结束
            end note
            Worker-->>API: 返回结果
            destroy Worker
            API-xWorker: 释放资源
            API-->>-User: 返回结果
        """),
        .init(id: "class-advanced", title: "接口、基数与注释", symbol: "rectangle.3.group", source: """
        classDiagram
            direction LR
            namespace Domain["业务模型"] {
                class Customer {
                    +String name
                    +placeOrder() Order
                }
                class Order {
                    +String id
                    +total() Money
                }
                class Payment <<interface>>
                Payment : +authorize() bool
                Customer "1" --> "0..*" Order : 创建
                Order --> Payment : 支付
            }
            note for Payment "通过接口隔离支付实现<br>调用方只依赖支付协议"
            note "属性和方法分区显示"
        """),
        .init(id: "state-parallel", title: "分叉、汇合与并发区域", symbol: "arrow.triangle.branch", source: """
        stateDiagram-v2
            [*] --> Ready
            state Ready <<fork>>
            Ready --> Loading
            Ready --> Connecting
            Loading --> Joined
            Connecting --> Joined
            state Joined <<join>>
            Joined --> Active
            state "运行中" as Active {
                [*] --> Idle
                Idle --> Busy : 接收任务
                Busy --> Idle : 完成
                --
                [*] --> Offline
                Offline --> Online : 建立连接
                Online --> Offline : 断开
            }
            note right of Active
                两个区域并行运行
                各自保留初始状态
            end note
            Active --> [*] : 退出
        """)
    ]
}
