# OpenSpec 測試案例統一規範

本文件為 **openapi-test-cases** 與 **swagger-json-test-cases** 共用。不論由哪個技能產出，測試清單的規格與文件格式必須一致。

---

## 兩層式架構

| 層級 | 位置 | 用途 |
|------|------|------|
| **變更層** | `openspec/changes/<change-id>/test-plan.md` | 單次功能變更的**增量**測試計畫；隨 change 歸檔。 |
| **持久層** | `tests/specs/<service>/<feature>.md`、`tests/checklists/`、`tests/automation/` | 長期累積、跨功能；歸檔前將 test-plan 中的案例**合併**到此。 |

**工作流程**：列舉產出 → 寫入 change 的 `test-plan.md` → 開發與測試完成 → **歸檔前**把案例合併到 `tests/specs/` 對應檔案 → 歸檔。

**全局視圖**：`tests/coverage-matrix.md` 追蹤「整個服務目前有多少測試案例、覆蓋率」；定期更新（可腳本掃描 `tests/specs/` 與 `*_test.go`）。

---

## 產出位置約定

- **本次變更的 test-plan**：`openspec/changes/<change-id>/test-plan.md`（若使用者未指定則產出到對話，由使用者貼入）。
- **持久層合併目標**：`tests/specs/<service>/<feature>.md`（例如 `tests/specs/wallet/deposit.md`）；產出時標註「持久層對應」供歸檔時合併。

---

## 案例 ID 與優先級

- **案例 ID 格式**：`{SERVICE}-{FEATURE}-{SEQ}`（三位數）。例如：`WAL-DEP-001`、`API-AUTH-002`。一開始就統一命名，便於在 test-plan、持久層、自動化程式碼註解間對應。
- **優先級**：P0（必須通過）、P1（應該通過）、P2（有空再測）。

---

## 情境格式

- 使用 **Given / When / Then** 描述情境；不重複寫 specs 已定義的需求，**引用 specs** 即可。
- 每個案例可含多個 Scenario；每個 Scenario 一組 Given/When/Then。

---

## 自動化標記

- 每個案例標記：`[Auto]`（已自動化）、`[Manual]`（手動）、`[TODO]`（待自動化）。
- 產出表格：**案例 ID \| 自動化狀態 \| 測試檔案**（如 `wallet_deposit_test.go`）。

---

## 必須涵蓋的維度

1. Happy path  
2. 邊界條件  
3. 異常與錯誤情境  
4. 併發情境（如適用）  
5. 冪等性驗證（如適用）  

---

## 注意事項

- **案例 ID 命名要一開始就統一**，避免後續無法與持久層、自動化程式對應。
- **歸檔時養成習慣同步持久層**：將 test-plan 中的案例合併到 `tests/specs/` 對應檔案；建議在 tasks 最後一項加上「合併測試案例到 tests/ 持久層」，以便 `/opsx:apply` 時提醒。
- **持久層的 coverage-matrix.md 定期更新**；可寫腳本掃描 `tests/specs/` 與 `*_test.go` 產出覆蓋對應表。
- **不要在 test-plan 裡重複寫 specs 已定義的情境**；test-plan 聚焦「怎麼測」與「測試數據」，引用 specs 就好。
