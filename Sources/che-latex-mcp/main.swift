import Foundation
import MCP
import PDFKit
import UniformTypeIdentifiers

// MARK: - Tool Definitions

let analyzePagesTool = Tool(
    name: "analyze_pages",
    description: "分析 LaTeX 專案的頁面分布，從 .toc 檔案讀取章節對應頁碼",
    inputSchema: [
        "type": "object",
        "properties": [
            "project_path": [
                "type": "string",
                "description": "LaTeX 專案目錄路徑"
            ],
            "main_file": [
                "type": "string",
                "description": "主檔案名（不含副檔名），預設為 main"
            ]
        ],
        "required": ["project_path"]
    ]
)

let getPageContentTool = Tool(
    name: "get_page_content",
    description: "取得 PDF 特定頁面的文字內容",
    inputSchema: [
        "type": "object",
        "properties": [
            "pdf_path": [
                "type": "string",
                "description": "PDF 檔案路徑"
            ],
            "page_number": [
                "type": "integer",
                "description": "頁碼（1-based）"
            ]
        ],
        "required": ["pdf_path", "page_number"]
    ]
)

let findPagebreaksTool = Tool(
    name: "find_pagebreaks",
    description: "分析 LaTeX log 檔案，找出換頁發生的位置",
    inputSchema: [
        "type": "object",
        "properties": [
            "project_path": [
                "type": "string",
                "description": "LaTeX 專案目錄路徑"
            ],
            "main_file": [
                "type": "string",
                "description": "主檔案名（不含副檔名），預設為 main"
            ]
        ],
        "required": ["project_path"]
    ]
)

let previewPageTool = Tool(
    name: "preview_page",
    description: "將 PDF 特定頁面轉為 PNG 圖片",
    inputSchema: [
        "type": "object",
        "properties": [
            "pdf_path": [
                "type": "string",
                "description": "PDF 檔案路徑"
            ],
            "page_number": [
                "type": "integer",
                "description": "頁碼（1-based）"
            ],
            "output_path": [
                "type": "string",
                "description": "輸出圖片路徑（可選，預設放在 /tmp）"
            ]
        ],
        "required": ["pdf_path", "page_number"]
    ]
)

// MARK: - Tool Implementations

func analyzePages(projectPath: String, mainFile: String) -> String {
    let tocPath = URL(fileURLWithPath: projectPath).appendingPathComponent("\(mainFile).toc")

    guard FileManager.default.fileExists(atPath: tocPath.path) else {
        return "找不到 \(tocPath.path)，請先編譯 LaTeX"
    }

    guard let content = try? String(contentsOf: tocPath, encoding: .utf8) else {
        return "無法讀取 .toc 檔案"
    }

    var result = ["# 頁面分布分析\n"]

    // 匹配 \contentsline {type}{title}{page}
    let pattern = #"\\contentsline\s*\{(part|section|subsection)\}\{([^}]+(?:\{[^}]*\}[^}]*)*)\}\{(\d+)\}"#

    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)

        for match in matches {
            guard match.numberOfRanges >= 4,
                  let levelRange = Range(match.range(at: 1), in: content),
                  let titleRange = Range(match.range(at: 2), in: content),
                  let pageRange = Range(match.range(at: 3), in: content) else { continue }

            let level = String(content[levelRange])
            var title = String(content[titleRange])
            let page = String(content[pageRange])

            // 清理標題
            title = title.replacingOccurrences(of: #"\\numberline\s*\{[^}]*\}"#, with: "", options: .regularExpression)
            title = title.replacingOccurrences(of: #"\\[a-zA-Z]+\s*"#, with: "", options: .regularExpression)
            title = title.trimmingCharacters(in: .whitespaces)

            switch level {
            case "part":
                result.append("\n## \(title) (p.\(page))")
            case "section":
                result.append("- **\(title)** ... p.\(page)")
            case "subsection":
                result.append("  - \(title) ... p.\(page)")
            default:
                break
            }
        }
    }

    // 讀取 PDF 總頁數
    let pdfPath = URL(fileURLWithPath: projectPath).appendingPathComponent("\(mainFile).pdf")
    if let pdfDoc = PDFDocument(url: pdfPath) {
        result.append("\n---\n總頁數：\(pdfDoc.pageCount) 頁")
    }

    return result.joined(separator: "\n")
}

func getPageContent(pdfPath: String, pageNumber: Int) -> String {
    let url = URL(fileURLWithPath: pdfPath)

    guard FileManager.default.fileExists(atPath: pdfPath) else {
        return "找不到 PDF 檔案：\(pdfPath)"
    }

    guard let pdfDoc = PDFDocument(url: url) else {
        return "無法開啟 PDF 檔案"
    }

    guard pageNumber >= 1 && pageNumber <= pdfDoc.pageCount else {
        return "頁碼超出範圍（總共 \(pdfDoc.pageCount) 頁）"
    }

    guard let page = pdfDoc.page(at: pageNumber - 1) else {
        return "無法讀取第 \(pageNumber) 頁"
    }

    var text = page.string ?? ""

    // 限制長度
    if text.count > 2000 {
        let index = text.index(text.startIndex, offsetBy: 2000)
        text = String(text[..<index]) + "\n\n[... 內容截斷 ...]"
    }

    return "# 第 \(pageNumber) 頁內容\n\n\(text)"
}

func findPagebreaks(projectPath: String, mainFile: String) -> String {
    let logPath = URL(fileURLWithPath: projectPath).appendingPathComponent("\(mainFile).log")

    guard FileManager.default.fileExists(atPath: logPath.path) else {
        return "找不到 \(logPath.path)，請先編譯 LaTeX"
    }

    guard let content = try? String(contentsOf: logPath, encoding: .utf8) else {
        return "無法讀取 .log 檔案"
    }

    var result = ["# 換頁位置分析\n"]
    var currentFile = "\(mainFile).tex"
    var fileStack = [currentFile]
    var pageInfo: [Int: String] = [:]

    let lines = content.components(separatedBy: .newlines)

    for line in lines {
        // 偵測檔案載入
        if let regex = try? NSRegularExpression(pattern: #"\(\.?/?([^()\s]+\.tex)"#, options: []) {
            let range = NSRange(line.startIndex..., in: line)
            let matches = regex.matches(in: line, options: [], range: range)
            for match in matches {
                if let fileRange = Range(match.range(at: 1), in: line) {
                    let fileName = String(line[fileRange])
                    fileStack.append(fileName)
                    currentFile = fileName
                }
            }
        }

        // 偵測檔案關閉
        let closeCount = line.filter { $0 == ")" }.count
        for _ in 0..<closeCount {
            if fileStack.count > 1 {
                fileStack.removeLast()
                currentFile = fileStack.last ?? "\(mainFile).tex"
            }
        }

        // 偵測頁碼輸出 [1] [2] [3]
        if let regex = try? NSRegularExpression(pattern: #"\[(\d+)\]"#, options: []) {
            let range = NSRange(line.startIndex..., in: line)
            let matches = regex.matches(in: line, options: [], range: range)
            for match in matches {
                if let pageRange = Range(match.range(at: 1), in: line),
                   let page = Int(line[pageRange]) {
                    if pageInfo[page] == nil {
                        pageInfo[page] = currentFile
                    }
                }
            }
        }
    }

    // 整理輸出
    for page in pageInfo.keys.sorted() {
        result.append("- p.\(page): \(pageInfo[page]!)")
    }

    return result.joined(separator: "\n")
}

func previewPage(pdfPath: String, pageNumber: Int, outputPath: String?) -> String {
    let url = URL(fileURLWithPath: pdfPath)

    guard FileManager.default.fileExists(atPath: pdfPath) else {
        return "找不到 PDF 檔案：\(pdfPath)"
    }

    guard let pdfDoc = PDFDocument(url: url) else {
        return "無法開啟 PDF 檔案"
    }

    guard pageNumber >= 1 && pageNumber <= pdfDoc.pageCount else {
        return "頁碼超出範圍（總共 \(pdfDoc.pageCount) 頁）"
    }

    guard let page = pdfDoc.page(at: pageNumber - 1) else {
        return "無法讀取第 \(pageNumber) 頁"
    }

    // 取得頁面尺寸，2x 解析度
    let bounds = page.bounds(for: .mediaBox)
    let scale: CGFloat = 2.0
    let width = Int(bounds.width * scale)
    let height = Int(bounds.height * scale)

    // 建立 CGContext
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        return "無法建立圖形 context"
    }

    // 設定白色背景
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // 縮放並繪製 PDF 頁面
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: context)

    // 建立 CGImage
    guard let cgImage = context.makeImage() else {
        return "無法建立圖片"
    }

    // 轉換為 PNG
    let finalPath = outputPath ?? "/tmp/latex_page_\(pageNumber).png"
    let outputURL = URL(fileURLWithPath: finalPath)

    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        return "無法建立圖片檔案"
    }

    CGImageDestinationAddImage(destination, cgImage, nil)

    guard CGImageDestinationFinalize(destination) else {
        return "無法儲存圖片"
    }

    return "已儲存頁面截圖：\(finalPath)"
}

// MARK: - Main

@main
struct LatexMCP {
    static func main() async throws {
        let server = Server(
            name: "che-latex-mcp",
            version: "0.1.0",
            capabilities: .init(tools: .init(listChanged: false))
        )

        // 列出所有 tools
        await server.withMethodHandler(ListTools.self) { _ in
            return .init(tools: [
                analyzePagesTool,
                getPageContentTool,
                findPagebreaksTool,
                previewPageTool
            ])
        }

        // 處理 tool 呼叫
        await server.withMethodHandler(CallTool.self) { params in
            switch params.name {
            case "analyze_pages":
                let projectPath = params.arguments?["project_path"]?.stringValue ?? ""
                let mainFile = params.arguments?["main_file"]?.stringValue ?? "main"
                let result = analyzePages(projectPath: projectPath, mainFile: mainFile)
                return .init(content: [.text(result)], isError: false)

            case "get_page_content":
                let pdfPath = params.arguments?["pdf_path"]?.stringValue ?? ""
                let pageNumber = Int(params.arguments?["page_number"] ?? .int(1), strict: false) ?? 1
                let result = getPageContent(pdfPath: pdfPath, pageNumber: pageNumber)
                return .init(content: [.text(result)], isError: false)

            case "find_pagebreaks":
                let projectPath = params.arguments?["project_path"]?.stringValue ?? ""
                let mainFile = params.arguments?["main_file"]?.stringValue ?? "main"
                let result = findPagebreaks(projectPath: projectPath, mainFile: mainFile)
                return .init(content: [.text(result)], isError: false)

            case "preview_page":
                let pdfPath = params.arguments?["pdf_path"]?.stringValue ?? ""
                let pageNumber = Int(params.arguments?["page_number"] ?? .int(1), strict: false) ?? 1
                let outputPath = params.arguments?["output_path"]?.stringValue
                let result = previewPage(pdfPath: pdfPath, pageNumber: pageNumber, outputPath: outputPath)
                return .init(content: [.text(result)], isError: false)

            default:
                return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
            }
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
    }
}
