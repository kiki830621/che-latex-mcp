# che-latex-mcp

LaTeX 專案管理 MCP Server（Swift 版本），讓 Claude 可以編譯、分析、檢查 LaTeX 專案。

## 功能

### 編譯與檢查

| Tool | 功能 |
|------|------|
| `compile_latex` | 編譯 LaTeX 專案（支援 xelatex、pdflatex、lualatex） |
| `check_errors` | 檢查 .log 檔案中的錯誤和警告 |
| `get_document_info` | 取得文件基本資訊（頁數、章節數、使用的套件等） |

### 頁面分析

| Tool | 功能 |
|------|------|
| `analyze_pages` | 分析頁面分布，從 .toc 讀取章節對應頁碼 |
| `get_page_content` | 取得 PDF 特定頁面的文字內容 |
| `find_pagebreaks` | 分析 .log 找出換頁發生的位置 |
| `preview_page` | 將 PDF 頁面轉為 PNG 截圖 |

## 系統需求

- macOS 14+
- Swift 6.0+ (Xcode 16+)
- TeX Live 或 MacTeX（編譯功能需要）

## 編譯

```bash
git clone https://github.com/kiki830621/che-latex-mcp.git
cd che-latex-mcp
swift build
```

## 註冊到 Claude Code

```bash
claude mcp add che-latex-mcp "/path/to/che-latex-mcp/.build/debug/che-latex-mcp"
```

## 使用範例

```
# 編譯 LaTeX 專案
compile_latex("/path/to/project", "main", "xelatex", true)

# 檢查錯誤（含警告）
check_errors("/path/to/project", "main", true)

# 取得文件資訊
get_document_info("/path/to/project", "main")

# 分析頁面分布
analyze_pages("/path/to/project", "main")

# 取得第 5 頁內容
get_page_content("/path/to/document.pdf", 5)

# 預覽第 10 頁
preview_page("/path/to/document.pdf", 10)
```

## License

MIT
