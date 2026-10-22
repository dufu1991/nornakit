import AppKit
import XCTest
@testable import NornaKit

final class EmbeddedDiagramRegressionTests: XCTestCase {
    func testPastedExamplesRenderAtNaturalAndEmbeddedWidths() async throws {
        let renderer = NativeDiagramRenderer()
        XCTAssertEqual(Self.examples.count, 12)
        for (index, source) in Self.examples.enumerated() {
            for width: CGFloat? in [nil, 320, 640] {
                do {
                    let artifact = try await renderer.render(source, options: .init(maxWidth: width))
                    XCTAssertFalse(artifact.scene.nodes.isEmpty && artifact.scene.primitives.isEmpty)
                    for theme in [DiagramTheme.appleLight, .appleDark] {
                        XCTAssertTrue(XMLParser(data: Data(artifact.themedSVG(theme).utf8)).parse())
                        if let directory = ProcessInfo.processInfo.environment["NORNA_EMBEDDED_FIXTURE_DIR"], width == 640 {
                            let url = URL(fileURLWithPath: directory, isDirectory: true)
                            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                            for style in [DiagramColorStyle.neutral, .themed] {
                                let png = try DiagramExporter.data(for: artifact.scene, theme: theme, colorStyle: style, options: .init(format: .png, scale: 1))
                                let suffix = style == .neutral ? "" : "-themed"
                                try png.write(to: url.appendingPathComponent("example-\(index + 1)-\(theme.rawValue)\(suffix).png"))
                            }
                        }
                    }
                } catch {
                    XCTFail("Example \(index + 1), width \(String(describing: width)): \(error)")
                }
            }
        }
    }

    func testHorizontalChartsKeepOrderNegativeValuesAndGroupedSeries() async throws {
        let source = "xychart-beta horizontal\nx-axis [First, Second, Third]\ny-axis -10 --> 10\nbar [-5, 10, 0]\nbar [5, -10, 0]\nline [-10, 0, 10]"
        let scene = try await NativeDiagramRenderer().render(source, options: .init(maxWidth: 320)).scene
        let first = try XCTUnwrap(scene.primitives.first { $0.id == "bar-0-0" })
        let second = try XCTUnwrap(scene.primitives.first { $0.id == "bar-0-1" })
        let positive = try XCTUnwrap(scene.primitives.first { $0.id == "bar-1-0" })
        XCTAssertEqual(first.bounds.maxX, positive.bounds.minX, accuracy: 0.01)
        XCTAssertEqual(first.bounds.width, positive.bounds.width, accuracy: 0.01)
        XCTAssertEqual(second.bounds.width, first.bounds.width * 2, accuracy: 0.01)
        XCTAssertLessThan(first.bounds.midY, second.bounds.midY)
        XCTAssertFalse(first.bounds.intersects(positive.bounds))
        let points = (0...2).map { index in scene.primitives.first { $0.id == "point-2-\(index)" }!.bounds }
        XCTAssertLessThan(points[0].midX, points[1].midX)
        XCTAssertLessThan(points[1].midX, points[2].midX)
        XCTAssertLessThanOrEqual(scene.size.width, 320)
    }

    func testClassStylesSurviveCompoundLayoutAndNativeAndSVGExport() async throws {
        let source = """
        flowchart LR
        class A,B stage
        subgraph Group[Stage]
        A[Start] --> B[End]
        end
        classDef stage fill:#eff6ff,stroke:#3b82f6,color:#1e3a8a,stroke-width:2px;
        """
        let scene = try await NativeFlowchartRenderer().render(source, options: .init(maxWidth: 320)).scene
        XCTAssertEqual(scene.nodes.count, 2)
        for node in scene.nodes {
            XCTAssertEqual(node.appearance.fill, "#eff6ff")
            XCTAssertEqual(node.appearance.stroke, "#3b82f6")
            XCTAssertEqual(node.appearance.color, "#1e3a8a")
            XCTAssertEqual(node.appearance.lineWidth, 2)
        }
        for theme in [DiagramTheme.appleLight, .appleDark] {
            let svg = SVGExporter.export(scene, theme: theme)
            XCTAssertTrue(svg.contains("fill=\"#eff6ff\" stroke=\"#3b82f6\" stroke-width=\"2.00\""))
            let png = try DiagramExporter.data(for: scene, theme: theme, options: .init(scale: 1, padding: 0))
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: png))
            let node = scene.nodes[0]
            var pixel = [Int](repeating: 0, count: bitmap.samplesPerPixel)
            bitmap.getPixel(&pixel, atX: Int(node.frame.minX + 12), y: Int(node.frame.minY + 12))
            XCTAssertEqual(Array(pixel.prefix(3)), [239, 246, 255])
        }
        for style in ["fill:url(https://example.com)", "position:absolute", "stroke-width:999999px"] {
            XCTAssertThrowsError(try MermaidFlowchartParser.parse("flowchart TD\nA\nclassDef stage \(style)\nclass A stage"))
        }
    }

    func testGanttAxisFormatAndExcludedWeekendDependencyDates() async throws {
        let source = """
        gantt
        axisFormat %m/%d
        excludes weekends
        Friday :a, 2026-06-05, 1d
        Monday :b, after a, 1d
        Tuesday :c, after b, 1d
        """
        let scene = try await NativeDiagramRenderer().render(source).scene
        let a = try XCTUnwrap(scene.primitives.first { $0.id == "a" })
        let b = try XCTUnwrap(scene.primitives.first { $0.id == "b" })
        let c = try XCTUnwrap(scene.primitives.first { $0.id == "c" })
        XCTAssertEqual(b.bounds.minX - a.bounds.minX, a.bounds.width * 3, accuracy: 0.01)
        XCTAssertEqual(c.bounds.minX, b.bounds.maxX, accuracy: 0.01)
        let labels = scene.primitives.compactMap { primitive -> String? in
            if case .text(let text) = primitive.geometry { return text.text }
            return nil
        }
        XCTAssertTrue(labels.contains("06/05"))
        XCTAssertTrue(labels.contains("06/10"))
        for format in ["%Q", "%"] {
            do { _ = try await NativeDiagramRenderer().render("gantt\naxisFormat \(format)\nA :a, 2026-06-05, 1d"); XCTFail("Expected unsupported format") }
            catch let error as DiagramRenderError { XCTAssertEqual(error.line, 2) }
        }
    }

    func testEmbeddedTemporalDiagramsReflowAndSequenceFramesRetainTheirOutline() async throws {
        let renderer = NativeDiagramRenderer()
        for index in [7, 9, 11] {
            let scene = try await renderer.render(Self.examples[index], options: .init(maxWidth: 640)).scene
            XCTAssertLessThanOrEqual(scene.size.width, 640, "Example \(index + 1)")
            if index == 11 {
                XCTAssertTrue(scene.primitives.contains { $0.style.fill == .none && $0.style.stroke == .border && $0.style.opacity == 1 })
                XCTAssertTrue(scene.primitives.filter { $0.id?.hasPrefix("message-") == true }.allSatisfy { $0.style.lineWidth >= 1.5 })
            }
        }
    }

    static let examples: [String] = [
        """
        pie showData
            title 用户访问来源
            "搜索引擎" : 42
            "直接访问" : 25
            "社交媒体" : 18
            "外部链接" : 10
            "其他来源" : 5
        """,
        """
        xychart-beta
            title "各产品月度销量"
            x-axis ["产品A", "产品B", "产品C", "产品D", "产品E"]
            y-axis "销量（件）" 0 --> 1000
            bar [720, 950, 580, 830, 460]
        """,
        """
        xychart-beta horizontal
            title "热门 AI 功能使用次数"
            x-axis ["智能问答", "文案写作", "代码生成", "文档总结", "语言翻译"]
            y-axis "使用次数" 0 --> 5000
            bar [4600, 3800, 3100, 2500, 1800]
        """,
        """
        xychart-beta
            title "近七天日活跃用户"
            x-axis ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
            y-axis "活跃用户数" 0 --> 3000
            line [1200, 1450, 1380, 1800, 2100, 2500, 2350]
        """,
        """
        sankey-beta

        总访问,自然搜索,5000
        总访问,广告投放,3000
        总访问,社交媒体,2000
        自然搜索,已注册,1500
        自然搜索,未注册,3500
        广告投放,已注册,1200
        广告投放,未注册,1800
        社交媒体,已注册,800
        社交媒体,未注册,1200
        已注册,付费用户,700
        已注册,免费用户,2800
        """,
        """
        quadrantChart
            title 功能需求优先级
            x-axis 低实施成本 --> 高实施成本
            y-axis 低业务价值 --> 高业务价值
            quadrant-1 重点规划
            quadrant-2 优先实施
            quadrant-3 有空再做
            quadrant-4 谨慎投入
            消息搜索: [0.25, 0.85]
            快捷回复: [0.15, 0.65]
            多模态分析: [0.85, 0.90]
            主题换肤: [0.20, 0.25]
            复杂动画: [0.80, 0.20]
            团队权限: [0.65, 0.75]
        """,
        """
        gantt
            title AI 客服系统开发计划
            dateFormat YYYY-MM-DD
            axisFormat %m/%d
            excludes weekends

            section 需求与设计
            需求调研       :done, a1, 2026-06-01, 3d
            原型设计       :done, a2, after a1, 3d

            section 功能开发
            聊天界面开发   :active, b1, after a2, 5d
            知识库接入     :b2, after a2, 6d
            权限管理       :b3, after b1, 3d

            section 测试与上线
            集成测试       :crit, c1, after b2 b3, 4d
            上线发布       :milestone, m1, after c1, 0d
        """,
        """
        timeline
            title AI 产品版本演进

            section 起步阶段
                2025年第一季度 : 完成需求调研
                               : 发布内部原型
                2025年第二季度 : 上线基础对话
                               : 支持 Markdown 渲染

            section 能力扩展
                2025年第三季度 : 上线知识库问答
                               : 支持文件上传
                2025年第四季度 : 支持数学公式
                               : 支持 Mermaid 图表

            section 产品完善
                2026年第一季度 : 增加团队协作
                               : 完善权限管理
                2026年第二季度 : 优化响应速度
                               : 上线使用分析
        """,
        """
        flowchart TD
            A["访问用户<br/>10,000 人"]
            B["注册用户<br/>3,000 人"]
            C["完成体验<br/>1,800 人"]
            D["创建订单<br/>600 人"]
            E["完成支付<br/>420 人"]

            A -->|"注册转化率 30%"| B
            B -->|"体验完成率 60%"| C
            C -->|"下单转化率 33.3%"| D
            D -->|"支付完成率 70%"| E

            classDef stage fill:#eff6ff,stroke:#3b82f6,color:#1e3a8a;
            classDef success fill:#dcfce7,stroke:#22c55e,color:#14532d;

            class A,B,C,D stage;
            class E success;
        """,
        """
        journey
            title 用户首次使用 AI 助手的体验

            section 进入产品
                打开首页: 5: 用户
                了解产品能力: 4: 用户
                注册账号: 2: 用户

            section 首次体验
                输入第一个问题: 4: 用户
                等待生成结果: 3: 用户
                阅读回答: 5: 用户
                复制回答内容: 4: 用户

            section 持续使用
                查看历史记录: 4: 用户
                调整个人设置: 3: 用户
                再次发起提问: 5: 用户
        """,
        """
        erDiagram
            USER ||--o{ CONVERSATION : creates
            CONVERSATION ||--o{ MESSAGE : contains
            MESSAGE ||--o{ ATTACHMENT : includes

            USER {
                bigint id PK
                string username
                string email UK
                datetime created_at
            }

            CONVERSATION {
                bigint id PK
                bigint user_id FK
                string title
                datetime created_at
            }

            MESSAGE {
                bigint id PK
                bigint conversation_id FK
                string role
                text content
                int token_count
                datetime created_at
            }

            ATTACHMENT {
                bigint id PK
                bigint message_id FK
                string file_name
                string file_url
                bigint file_size
            }
        """,
        """
        sequenceDiagram
            autonumber
            actor U as 用户
            participant UI as 数据看板
            participant API as 统计接口
            participant Cache as 缓存
            participant DB as 数据库

            U->>UI: 选择统计时间范围
            UI->>API: 请求统计数据
            API->>Cache: 查询缓存

            alt 缓存命中
                Cache-->>API: 返回缓存结果
            else 缓存未命中
                Cache-->>API: 无可用缓存
                API->>DB: 查询并聚合数据
                DB-->>API: 返回统计结果
                API->>Cache: 写入缓存
                Cache-->>API: 写入成功
            end

            API-->>UI: 返回统计数据
            UI-->>U: 展示图表与指标
        """,
    ]
}
