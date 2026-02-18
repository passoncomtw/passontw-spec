---
name: openapi-test-cases
description: 從 OpenAPI 規格為每個 API 列舉測試案例，產出測試清單或依規格撰寫測試。當使用者處理 openapi.yaml、需要 API 測試案例列舉、或依 spec 撰寫測試時使用。
---

# 依 OpenAPI 規格列舉 API 測試案例

根據給定的 OpenAPI 規格（openapi.yaml 或相容檔案），逐一路徑、逐操作列舉出可執行的測試案例。產出對齊 **OpenSpec 兩層式架構**（變更層 test-plan + 持久層 tests/），與 [統一文件規範](references/openspec-test-conventions.md) 一致。

## OpenSpec 兩層式架構與產出

- **變更層**：單次 change 的增量測試計畫 → `openspec/changes/<change-id>/test-plan.md`（或由使用者指定）。
- **持久層**：長期累積的案例 → `tests/specs/<service>/<feature>.md`；產出時標註「持久層對應」，供歸檔時合併。
- **全局視圖**：`tests/coverage-matrix.md` 追蹤整體覆蓋；歸檔時合併到 tests/specs/ 後可更新此檔。

不論產出寫入變更層或直接建議持久層路徑，**文件格式須與統一規範一致**（案例 ID、Given/When/Then、P0/P1/P2、自動化標記、持久層對應）。詳見 [references/openspec-test-conventions.md](references/openspec-test-conventions.md)。

## 觸發時機

- 使用者要求「從 OpenAPI 列舉測試案例」「為每個 API 寫測試案例」「根據 spec 產出測試清單」
- 指定某個專案或某支 `openapi.yaml` 時，僅處理該規格

## 輸入

- **規格位置**：預設為 `api-specs/projects/<project>/openapi.yaml`；若使用者指定路徑則以該路徑為準。
- 若未指定專案，可掃描 `api-specs/projects/*/openapi.yaml` 並逐專案產出，或先詢問要處理哪一個。
- 規格路徑、專案範圍或輸出細度不明時，先使用問答釐清需求再執行列舉。

## 處理流程

1. **讀取規格**：解析 OpenAPI 3.x YAML（必要時解析 `$ref` 以取得 request/response schema）。
2. **遍歷 API**：對 `paths` 下每個 path，對每個 HTTP method（get, post, put, patch, delete 等）視為一個「API 功能」。
3. **列舉維度**：對每個 API 依下列維度列舉測試案例（可依專案需求取子集）：
   - **成功回應**：規格中定義的每個 2xx（如 200、201）至少一筆「正常參數／body」案例。
   - **錯誤回應**：規格中定義的每個 4xx、5xx（如 400、401、403、404、503）至少一筆對應情境。
   - **路徑／查詢／標頭參數**：
     - 必填：有提供且合法、未提供（預期 400 或 422）。
     - 選填：不送、送合法值、送非法值（型別錯誤或 enum 不符）。
   - **Request body**（若有）：
     - 合法 body 對應 2xx。
     - 缺少必填欄位、型別錯誤、違反 format/pattern/enum 等，預期 400 或 422。
   - **安全**：若 `security` 或 operation 層級有定義（如 Bearer）：有 token 且合法、無 token、token 無效或過期，對應 200 與 401/403。

4. **輸出格式**：依統一規範產出，可寫入 change 的 test-plan 或標註持久層對應路徑。

## 輸出範本（與 OpenSpec test-plan 一致）

產出須符合 [統一文件規範](references/openspec-test-conventions.md)。對每個 API（或整份規格）使用以下結構：

```markdown
# Test Plan: {change-name 或 規格名稱}

## 測試範圍
<!-- 此次影響的 API、服務 -->

## 新增/修改的測試案例

### P0 — 必須通過
| 案例 ID | 情境摘要 | Given / When / Then | 預期狀態 |
|---------|----------|---------------------|----------|
| {SERVICE}-{FEATURE}-001 | ... | Given ... When ... Then ... | 200 |

### P1 — 應該通過
<!-- 同上格式 -->

### P2 — 有空再測
<!-- 同上格式 -->

## QA 驗收 Checklist
- [ ] ...

## 自動化標記
| 案例 ID | 自動化狀態 | 測試檔案 |
|---------|-------------|----------|
| | [Auto] / [Manual] / [TODO] | |

## 持久層對應
<!-- 歸檔時合併目標 -->
- {SERVICE}-{FEATURE}-001 → `tests/specs/<service>/<feature>.md`
```

- **案例 ID**：`{SERVICE}-{FEATURE}-{SEQ}`（如 `API-WAL-001`），從一開始統一以便與持久層、自動化程式對應。
- **情境**：用 Given/When/Then；不重複 specs 內容，引用即可。
- **預期狀態**：規格中定義的 HTTP status。

## 注意事項

- 僅依規格列舉「應有」的測試情境，不假設實作細節；若規格未定義某 4xx，可不列或標註「規格未定義」。
- 若 `$ref` 指向外部檔案（如 `./schemas/foo.yaml`），需在同一專案內解析；若無法解析，可列出「需依 schema 補齊」的案例類型。
- 列舉時保持術語一致：路徑參數／查詢參數／request body／回應狀態。
- **OpenSpec 注意事項**（見 [統一規範](references/openspec-test-conventions.md)）：案例 ID 統一、歸檔時同步持久層（建議 tasks 最後一項「合併測試案例到 tests/ 持久層」）、coverage-matrix 定期更新、不在 test-plan 重複寫 specs 已定義情境。

---

## 技能目錄：scripts / references / assets

技能可選用以下目錄擴充能力；引用時使用**相對於技能根目錄**的路徑（例如 `scripts/parse-refs.py`）。

| 目錄 | 功用與目的 | 你該如何使用 |
|------|------------|--------------|
| **scripts/** | 放 Agent **可執行的程式碼**（如 shell、Python、Node）。用來做重複性、易出錯或需一致結果的步驟（解析 $ref、驗證 YAML、產出檔案），而不是只靠自然語言描述。 | 在 SKILL.md 裡寫明「執行 `scripts/xxx.sh` 或 `python scripts/xxx.py`」；腳本需可獨立執行、錯誤訊息清楚。Agent 觸發技能時會依指示執行這些腳本。 |
| **references/** | 放**依需載入的補充文件**（詳盡規則、範例、對照表）。SKILL.md 保持精簡，細節放到這裡，Agent 只在需要時讀取，以節省 context。 | 在 SKILL.md 用連結指向，例如「詳見 [references/列舉維度.md](references/列舉維度.md)」。只做一層引用，避免 references 裡再連到其他 references。 |
| **assets/** | 放**靜態資源**：範本檔、範例 JSON/YAML、圖片、設定檔。不執行，只當輸入或輸出範本。 | 在 SKILL.md 說明「使用 `assets/test-case-template.md` 作為輸出範本」或「參考 `assets/example-output.md`」；Agent 會讀取並依內容產出。 |

**使用建議**

- 此技能目前以「流程＋範本」為主，可不放 scripts；若日後要自動解析 `$ref` 或產出檔案，再在 `scripts/` 加腳本並在 SKILL.md 註明執行方式。
- 若列舉維度、邊界值規則等說明變多，可移到 `references/`，SKILL.md 只保留流程與輸出範本。
- 若有多種輸出格式（如 Markdown / CSV），可把範本放到 `assets/`，在輸出範本一節指名選用哪個檔案。
