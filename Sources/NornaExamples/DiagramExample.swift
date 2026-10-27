import Foundation
import NornaKit

public struct DiagramExample: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String
    public let source: String
    public var declaredKind: DiagramKind? = nil
    public var originURL: String? = nil

    public var kind: DiagramKind { declaredKind ?? DiagramKind.detect(source)! }
    public static let official: [DiagramExample] = { OfficialExampleCatalog.snapshot.examples.enumerated().map { index, item in
        DiagramExample(id: item.id, title: "\(item.kind.title) · \(index + 1)", symbol: "doc.text", source: item.source,
                       declaredKind: item.kind, originURL: item.origins[0].url)
    } }()
    public static let library: [DiagramExample] = all + official
    public static var all: [DiagramExample] { catalog + flowcharts + advanced + comparisons.map(\.complex) }
    public static let starters: [DiagramKind: DiagramExample] = Dictionary(grouping: all, by: \.kind).mapValues { $0[0] }
    public static let flowcharts: [DiagramExample] = [
        .init(id: "flowchart", title: "输入与验证", symbol: "point.3.connected.trianglepath.dotted", source: """
        flowchart TD
            A([用户输入]) --> B{验证通过？}
            B -->|通过| C[调用 API]
            B -->|失败| D[显示错误]
            C --> E[处理响应]
            E --> F([输出结果])
            D --> A
        """),
        .init(id: "sf-symbols", title: "SF Symbols 图标", symbol: "sparkles", source: """
        flowchart TB
            subgraph App["SF Symbols :sf:sparkles: 原生图标"]
                A["选择 :sf:doc.text: 文件"]
                B["上传 :sf:icloud.and.arrow.up: 到云端"]
                C["完成 :sf:checkmark.circle.fill: 同步"]
                A -->|"读取 :sf:externaldrive: 内容"| B
                B -->|"确认 :sf:checkmark.seal: 结果"| C
            end
        """),
        .init(id: "sf-symbols-wrapping", title: "SF Symbols 换行", symbol: "text.aligncenter", source: """
        flowchart TB
            A["文字前 :sf:icloud.and.arrow.up: 文字后"]
            B["第一行 :sf:person.fill: 用户<br/>第二行 :sf:checkmark.circle.fill: 完成<br/>第三行 :sf:arrow.right: 继续"]
            C["这是一段用于观察自动换行的较长文本，其中的 :sf:externaldrive: 图标会作为整体参与排版，并继续显示后面的文字。"]
            A -->|"显式 :sf:text.aligncenter: 换行"| B
            B -->|"自动 :sf:arrow.turn.down.left: 换行"| C
        """),
        .init(id: "sf-symbols-color", title: "SF Symbols 多色", symbol: "paintpalette", source: """
        flowchart TB
            A["单色 :sf:cloud.sun.fill: 跟随文字"]
            B["原生多色 :sf:cloud.sun.fill@multicolor: 天气"]
            C["分层 :sf:cloud.sun.fill@hierarchical: 明暗层次"]
            D["调色板 :sf:cloud.sun.fill@palette(#2563eb,#f59e0b): 自定义颜色"]
            A --> B --> C --> D
        """),
        .init(id: "rich-text", title: "原生富文本", symbol: "textformat", source: """
        flowchart TB
            A["[b]粗体重点[/b] 与 [i]斜体说明[/i]"]
            B["调用 [code]render(source)[/code] 方法"]
            C["[u]下划线[/u] 与 [s]已取消[/s] 状态"]
            D["[color=#2563eb][b]这是一段带有颜色和粗体的长标签，自动换行后仍然保留文字样式。[/b][/color]"]
            A -->|"[b]保留[/b] :sf:checkmark.circle.fill: 样式"| B
            B --> C --> D
        """),
        .init(id: "subgraphs", title: "子图与跨组", symbol: "rectangle.3.group", source: """
        flowchart LR
            subgraph Client[客户端]
                direction TD
                A[用户操作] --> B{校验输入}
                B -->|通过| C[发起请求]
                B -->|失败| D[提示错误]
                D -.-> A
            end
            subgraph Server[服务端]
                direction TD
                E[API 网关] --> F[业务服务]
                F --> G[(数据存储)]
            end
            C -->|HTTPS| E
            F --> H([展示结果])
        """),
        .init(id: "nested", title: "嵌套子图", symbol: "square.3.layers.3d", source: """
        flowchart TD
            Start([开始]) --> A
            subgraph App[应用流水线]
                direction LR
                subgraph Input[输入层]
                    direction TD
                    A[读取文件] --> B[校验格式]
                end
                subgraph Process[处理层]
                    direction TD
                    C[解析内容] --> D[生成场景]
                end
                subgraph Output[输出层]
                    direction TD
                    E[原生画布] --> F[导出 SVG]
                end
                B --> C
                D --> E
            end
            F --> Done([完成])
        """),
        .init(id: "groupLinks", title: "分组连接", symbol: "rectangle.connected.to.line.below", source: """
        flowchart LR
            User([用户]) --> API
            API --> Storage
            subgraph API[接口服务]
                direction TD
                A[鉴权] --> B[业务逻辑]
            end
            subgraph Storage[存储服务]
                direction TD
                C[(数据库)] --> D[更新索引]
            end
            B -.->|写入| C
        """),
        .init(id: "shapes", title: "节点形状", symbol: "square.on.circle", source: """
        flowchart LR
            A[矩形] --> B(圆角矩形)
            B --> C([起止节点])
            C --> D{条件判断}
            D --> E((圆形))
            D --> F[(数据库)]
            E --> G[[子程序]]
            F --> G
        """),
        .init(id: "pipeline", title: "并行与汇合", symbol: "arrow.triangle.branch", source: """
        flowchart TD
            A([开始]) --> B[读取配置]
            B --> C[处理文本] & D[加载图片] & E[提取元数据]
            C & D & E --> F[合并结果]
            F --> G([完成])
        """),
        .init(id: "cycle", title: "循环与重试", symbol: "arrow.clockwise", source: """
        flowchart TD
            A([提交任务]) --> B[执行请求]
            B --> C{请求成功？}
            C -->|是| D([完成])
            C -->|否| E[等待重试]
            E -.-> B
            D --> D
        """),
        .init(id: "edges", title: "连线与标签", symbol: "line.diagonal", source: """
        flowchart LR
            A[客户端] -->|请求| B[网关]
            B ==> C[主服务]
            B -.->|异步| D[消息队列]
            C --- E[(数据库)]
            D --> F[消费者]
        """),
        .init(id: "unicode", title: "中文与多行", symbol: "textformat", source: """
        graph TD
            A["Swift 原生渲染<br/>无需 JavaScript"]
            A --> B["CoreText 测量<br/>中文、English 与 emoji 🌋"]
            B --> C["CoreGraphics 绘制"]
            C --> D["导出 SVG<br/>保留矢量路径与文字"]
        """)
    ]
}
