---
name: swagger-json-test-cases
description: 從 Swagger/OpenAPI 的 JSON 規格為每個 API 列舉測試案例，產出測試清單。當使用者提供 swagger.json、openapi.json 或 JSON 格式的 API spec、需要從 JSON spec 列舉測試案例時使用。
---

# 依 Swagger JSON 規格列舉 API 測試案例

根據給定的 Swagger 或 OpenAPI 規格（JSON 格式），逐一路徑、逐操作列舉出可執行的測試案例。產出對齊 **OpenSpec 兩層式架構**（變更層 test-plan + 持久層 tests/），與 [統一文件規範](references/openspec-test-conventions.md) 一致。

## OpenSpec 兩層式架構與產出

- **變更層**：單次 change 的增量測試計畫 → `openspec/changes/<change-id>/test-plan.md`（或由使用者指定）。
- **持久層**：長期累積的案例 → `tests/specs/<service>/<feature>.md`；產出時標註「持久層對應」，供歸檔時合併。
- **全局視圖**：`tests/coverage-matrix.md` 追蹤整體覆蓋；歸檔時合併到 tests/specs/ 後可更新此檔。

不論產出寫入變更層或直接建議持久層路徑，**文件格式須與統一規範一致**（案例 ID、Given/When/Then、P0/P1/P2、自動化標記、持久層對應）。詳見 [references/openspec-test-conventions.md](references/openspec-test-conventions.md)。

## 觸發時機

- 使用者要求「從 Swagger JSON 列舉測試案例」「根據 swagger.json 產出測試清單」「用 openapi.json 列舉每個 API 的測試」
- 提供或指定 `.json` 規格檔（如 `swagger.json`、`openapi.json`）時

## 輸入

- **規格來源**：使用者指定的 JSON 檔案路徑，或貼上的 JSON 規格內容。常見檔名：`swagger.json`、`openapi.json`、`api-spec.json`。
- **規格版本**：Swagger 2.0（`"swagger": "2.0"`）或 OpenAPI 3.x（`"openapi": "3.0.x"`）皆可；列舉時依對應結構解析（見下方差異說明）。
- 規格路徑或內容不明時，先使用問答釐清再執行列舉。

## 規格結構差異（解析時注意）

| 項目 | Swagger 2.0 (JSON) | OpenAPI 3.x (JSON) |
|------|--------------------|---------------------|
| 版號欄位 | `swagger: "2.0"` | `openapi: "3.0.x"` |
| Schema 定義 | `definitions` | `components.schemas` |
| $ref 路徑 | `#/definitions/ModelName` | `#/components/schemas/ModelName` 或相對路徑 |
| Request body | 單一 `parameters` 內 `in: "body"` + schema | `requestBody.content.*.schema` |
| 回應 | `responses` 同 OpenAPI 3 | `responses` |
| 安全定義 | `securityDefinitions` | `components.securitySchemes` |

遍歷時：以 `paths` 為準，每個 path 下每個 HTTP method 視為一個 API；參數與 body 依上述對應位置讀取。

## 處理流程

1. **讀取規格**：解析 JSON（從檔案或使用者提供內容）；辨識 `swagger` 或 `openapi` 版號以決定結構。
2. **遍歷 API**：對 `paths` 下每個 path、每個 method（get, post, put, patch, delete 等）視為一個 API 功能。
3. **列舉維度**：與 OpenAPI YAML 技能一致，對每個 API 依下列維度列舉測試案例：
   - **成功回應**：規格中定義的每個 2xx 至少一筆正常參數／body 案例。
   - **錯誤回應**：規格中定義的每個 4xx、5xx 至少一筆對應情境。
   - **路徑／查詢／標頭參數**：必填（有且合法、未提供→400/422）、選填（不送、合法、非法）。
   - **Request body**：合法→2xx；缺必填、型別錯誤、format/enum 違反→400/422。
   - **安全**：若有 security/securityDefinitions，有 token、無 token、無效 token 對應 200 與 401/403。
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

- 僅依規格列舉「應有」的測試情境，不假設實作細節；未定義的 4xx/5xx 可不列或標註「規格未定義」。
- JSON 內 `$ref` 若指向同文件（如 `#/definitions/Foo`），在列舉時解析該定義；若指向外部且無法取得，可列出「需依 schema 補齊」的案例類型。
- 列舉時保持術語一致：路徑參數／查詢參數／request body／回應狀態。
- **OpenSpec 注意事項**（見 [統一規範](references/openspec-test-conventions.md)）：案例 ID 統一、歸檔時同步持久層（建議 tasks 最後一項「合併測試案例到 tests/ 持久層」）、coverage-matrix 定期更新、不在 test-plan 重複寫 specs 已定義情境。
