## ADDED Requirements

### Requirement: 統一 Chat Completions 入口
系統 SHALL 提供 `POST /v1/chat/completions`，請求格式與 OpenAI Chat Completions API 相容，回應格式統一（不因實際使用的供應商而不同），並於回應中標註 `providerId` 表示實際回應的供應商。

#### Scenario: 成功取得回應
- **WHEN** 呼叫方以合法 bearer token、OpenAI 相容格式呼叫 `POST /v1/chat/completions`
- **THEN** 系統回傳統一格式的 `ChatCompletionResponse`，內含 `choices[0].message.content` 與實際回應的 `providerId`

### Requirement: 三重備援依序嘗試
系統 SHALL 依序嘗試供應商 `nvidia-kimi` → `openrouter-pony` → `local-ollama`，遇到錯誤或逾時視為該供應商不可用並嘗試下一順位，直到某一供應商成功回應或全部供應商皆失敗。

#### Scenario: 第一順位成功
- **WHEN** `nvidia-kimi` 於逾時時間內成功回應
- **THEN** 系統直接回傳該回應，不嘗試 `openrouter-pony` 或 `local-ollama`

#### Scenario: 第一順位失敗，第二順位成功
- **WHEN** `nvidia-kimi` 回傳錯誤或逾時，且 `openrouter-pony` 成功回應
- **THEN** 系統回傳 `openrouter-pony` 的回應，`providerId` 標註為 `openrouter-pony`

#### Scenario: 全部供應商失敗
- **WHEN** `nvidia-kimi`、`openrouter-pony`、`local-ollama` 皆回傳錯誤或逾時
- **THEN** 系統回傳 503，且不遺漏任何一個已嘗試的供應商（供實作階段記錄於 log）

### Requirement: 呼叫方必須通過 Bearer Auth 驗證
系統 SHALL 要求所有呼叫 `POST /v1/chat/completions` 的請求帶有合法的 `Authorization: Bearer <token>`，未帶或帶錯 token 的請求 SHALL 被拒絕，不觸發任何供應商呼叫。

#### Scenario: 缺少或錯誤 token
- **WHEN** 請求未帶 `Authorization` header，或帶入的 token 不正確
- **THEN** 系統回傳 401，不呼叫任何供應商

#### Scenario: 合法 token
- **WHEN** 請求帶入正確的 `Authorization: Bearer <token>`
- **THEN** 系統依三重備援邏輯處理該請求

### Requirement: 供應商金鑰不外流
系統 SHALL 將各供應商（nvidia-kimi、openrouter-pony）的 API 金鑰只保存在閘道服務端（環境變數或設定檔），不透過任何 API 回應或錯誤訊息洩漏給呼叫方。

#### Scenario: 錯誤回應不含金鑰
- **WHEN** 某供應商呼叫失敗（例如 401/429），系統嘗試下一順位或回傳 503
- **THEN** 回應內容不包含任何供應商的 API 金鑰或其片段
