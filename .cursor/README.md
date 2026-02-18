# .cursor 目錄說明

本目錄存放 Cursor 專案層級的設定與擴充：**Agents**、**Commands**、**Skills**。用於引導 AI 行為、一鍵執行工作流程，以及依規格產出一致的文件與測試清單。

---

## 目錄結構

```
.cursor/
├── README.md                 # 本文件
├── agents/                  # Agent 定義（Instructions + Tools + User 對應）
│   ├── openapi-requirements-planner.md
│   ├── database-schema-designer.md
│   ├── figma-design-analyzer.md
│   └── frame0-wireframe-builder.md
├── commands/                # 斜線指令（/pr、/fix-issue 等）
│   ├── pr/
│   ├── fix-issue/
│   ├── review/
│   ├── update-deps/
│   └── docs/
└── skills/                  # 技能（依情境擴充 Agent 能力）
    ├── openapi-test-cases/
    │   ├── SKILL.md
    │   └── references/
    │       └── openspec-test-conventions.md
    └── swagger-json-test-cases/
        ├── SKILL.md
        └── references/
            └── openspec-test-conventions.md
```

---

## Agents（`.cursor/agents/`）

**目的**：每個 Markdown 檔案對應一個 Agent，用於特定領域的任務（規格規劃、Schema 設計、設計稿分析、Wireframe 建立等）。結構對齊 [Cursor Agent 文件](https://cursor.com/zh-Hant/docs/agent/overview)：Agent 由 **Instructions**、**Tools**、**User messages** 三部分組成。

| 組成 | 在檔案中的對應 | 說明 |
|------|----------------|------|
| **Instructions** | 角色定義、原則、步驟、輸出格式 | 引導 Agent 行為的 system prompt 與 rules |
| **Tools** | 「工具使用」一節 | 何時使用語意搜尋、讀檔、編輯、終端、MCP、提問等 Cursor 工具 |
| **User messages** | 「使用者互動」一節 | 使用者如何下指令、提供什麼、預期產出與確認時機 |

### 本專案 Agents 一覽

| 檔案 | 用途 |
|------|------|
| `openapi-requirements-planner.md` | 依需求整理 OpenAPI 規格；需求不明時先釐清再規劃 |
| `database-schema-designer.md` | 資料庫 Schema 與 Migration 設計（PostgreSQL / MySQL / Redis） |
| `figma-design-analyzer.md` | 從 Figma 設計稿萃取業務流程與 Style Guideline，產出 theme 檔 |
| `frame0-wireframe-builder.md` | 依需求透過 Frame0 MCP 建立 Wireframe；可選單純頁面草稿或含頁面流程與互動原型 |

### Frame0 Wireframe 能力摘要

`frame0-wireframe-builder` 透過 **Frame0 MCP Server** 在 Cursor 中建立 Wireframe，產出可二選一：

- **單純草稿**：多個頁面與版面區塊，不設定連結，適合快速討論版位與資訊架構。
- **頁面流程與互動原型**：頁面間設定連結，可簡報演示、匯出後保留互動。

**連結類型（互動原型）**：Link to Page、Link to Web、Go Back、No Link。設定了連結的元件在畫布上會顯示淡藍色外框；簡報模式下頁面載入時連結處會閃三次提示可點擊。

**簡報 / 匯出**：Presentation Mode（點擊跳轉、方向鍵、全螢幕）；匯出 HTML（保留互動）、互動式 PDF、.f0 原始檔（實際匯出在 Frame0 中執行）。**Mirror Frame**：可建立 master 頁面（如共用 Header），其他頁面放 mirror，修改 master 則所有 mirror 同步更新。

---

## Commands（`.cursor/commands/`）

**目的**：斜線指令讓 Agent 依預設步驟執行 Git、審查、文件等流程。在 Agent 輸入框輸入 `/` 可選擇指令。參考 [Cursor 常見 Agent 工作流程](https://cursor.com/zh-Hant/docs/cookbook/agent-workflows)。

| 指令 | 路徑 | 用途 |
|------|------|------|
| `/pr` | `commands/pr/COMMAND.md` | 為目前變更建立 Pull Request：git diff → 撰寫 commit 訊息 → commit & push → gh pr create，回傳 PR 網址 |
| `/fix-issue` | `commands/fix-issue/COMMAND.md` | 修復指定 GitHub issue：`/fix-issue <number>` → gh issue view → 搜尋相關程式碼 → 依現有模式修復 → 視情況撰寫測試 → 建立參照該 issue 的 PR |
| `/review` | `commands/review/COMMAND.md` | 執行程式碼審查：執行 linters、檢查常見問題（風格、潛在 bug、安全）、摘要需關注部分 |
| `/update-deps` | `commands/update-deps/COMMAND.md` | 更新過時 dependencies：檢查過時套件 → 逐一更新 → 每次更新後執行測試，確認無回歸再繼續 |
| `/docs` | `commands/docs/COMMAND.md` | 為最近變更產生或更新文件：git diff / git log 確認變更範圍 → 針對變更模組/API 產出或更新文件 → 維持現有文件風格 |

---

## Skills（`.cursor/skills/`）

**目的**：技能為 Markdown 套件，依情境擴充 Agent 能力（例如從 API 規格列舉測試案例）。Agent 會依描述判斷何時套用；也可在對話中輸入 `/` 搜尋技能名稱手動觸發。每個技能為一資料夾，內含 `SKILL.md`（必填）與選用 `references/`、`scripts/`、`assets/`。

### 本專案 Skills 一覽

| 技能 | 路徑 | 觸發情境 | 產出 |
|------|------|----------|------|
| **openapi-test-cases** | `skills/openapi-test-cases/SKILL.md` | 處理 openapi.yaml、需要 API 測試案例列舉或依 spec 撰寫測試 | 依 OpenAPI 規格逐 path/method 列舉測試案例；產出對齊 OpenSpec 兩層式架構與統一文件規範 |
| **swagger-json-test-cases** | `skills/swagger-json-test-cases/SKILL.md` | 提供 swagger.json / openapi.json 或 JSON 格式 API spec、需從 JSON spec 列舉測試案例 | 同上，但輸入為 JSON（支援 Swagger 2.0 與 OpenAPI 3.x）；產出格式與 openapi-test-cases 一致 |

### 測試案例技能與 OpenSpec 對齊

上述兩個測試案例技能產出均對齊 **OpenSpec 兩層式架構**：

- **變更層**：單次 change 的增量測試計畫 → `openspec/changes/<change-id>/test-plan.md`
- **持久層**：長期累積 → `tests/specs/<service>/<feature>.md`；歸檔前將 test-plan 案例合併到此
- **全局視圖**：`tests/coverage-matrix.md` 追蹤整體覆蓋

統一文件規範（案例 ID 格式 `{SERVICE}-{FEATURE}-{SEQ}`、Given/When/Then、P0/P1/P2、自動化標記、持久層對應、注意事項）見各技能內 **references/openspec-test-conventions.md**。不論使用 openapi-test-cases 或 swagger-json-test-cases，規格與文件格式一致。

---

## 新增與修改紀錄（摘要）

| 類型 | 項目 | 目的 |
|------|------|------|
| Commands | pr, fix-issue, review, update-deps, docs | 對齊 Cursor 文件中的 Git/審查/文件工作流程，一鍵執行多步驟 |
| Agents | openapi-requirements-planner, database-schema-designer, figma-design-analyzer, frame0-wireframe-builder | 依需求整理 OpenAPI、設計 DB/Redis、從 Figma 產 theme、用 Frame0 MCP 建 Wireframe；結構對齊 Instructions / Tools / User messages |
| Skills | openapi-test-cases, swagger-json-test-cases | 從 OpenAPI YAML 或 Swagger/OpenAPI JSON 列舉測試案例；產出對齊 OpenSpec 兩層架構與共用規範 |
| References | openspec-test-conventions.md（於兩測試技能內） | 統一測試清單格式、案例 ID、歸檔時同步持久層等注意事項，確保兩技能產出一致 |
| 文件 | 本 README | 集中記錄 .cursor 目錄的結構、各 Agents/Commands/Skills 的用途與使用方式；原 `.cursor/agents/README.md` 已整合於此並移除 |
