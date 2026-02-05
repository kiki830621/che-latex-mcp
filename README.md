# che-latex-mcp

LaTeX 分頁分析 MCP Server（Swift 版本），讓 Claude 可以分析 LaTeX 編譯後的分頁狀況。

## 功能

### `analyze_pages`
分析 PDF 的頁面分布，從 .toc 檔案讀取章節對應頁碼。

### `get_page_content`
取得特定頁面的文字內容。

### `find_pagebreaks`
分析 .log 檔案，找出換頁發生的位置。

### `preview_page`
截圖特定頁面（用於視覺確認）。

## 系統需求

- macOS 14+
- Swift 6.0+ (Xcode 16+)

## 編譯

```bash
cd /Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/mcp/che-latex-mcp
swift build
```

## 註冊到 Claude Code

```bash
claude mcp add che-latex-mcp "/Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/mcp/che-latex-mcp/.build/debug/che-latex-mcp"
```

## 使用範例

```
# 分析頁面分布
analyze_pages("/path/to/latex/project", "main")

# 取得第 5 頁內容
get_page_content("/path/to/document.pdf", 5)

# 分析換頁位置
find_pagebreaks("/path/to/latex/project")

# 預覽第 10 頁
preview_page("/path/to/document.pdf", 10)
```
