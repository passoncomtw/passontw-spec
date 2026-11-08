## 1. 規格更新（api-specs repo）

- [ ] 1.1 更新 `api-specs/projects/knowledge-base/openapi.yaml`：`/chat/completions` path 新增 `security: [{bearerAuth: []}]` 要求
- [ ] 1.2 標註或移除 `/fallback` PUT 為非 V1 範圍（於 description 註明「V1 不提供，順序寫死於設定檔」）
- [ ] 1.3 更新 `api-specs/projects/knowledge-base/README.md`、`CHANGELOG.md`：反映「閘道已實作、已與 n8n 串接」現況

## 2. 閘道服務實作

- [ ] 2.1 選定實作語言/框架（Go/Node/Python 擇一），初始化專案骨架
- [ ] 2.2 實作 `POST /v1/chat/completions`：接收 OpenAI 相容請求，依序呼叫 nvidia-kimi → openrouter-pony → local-ollama
- [ ] 2.3 實作 bearer auth 中介層：驗證 `Authorization: Bearer <token>`，未帶或錯誤 token 回傳 401 且不觸發供應商呼叫
- [ ] 2.4 實作供應商呼叫逾時與錯誤處理：單一供應商逾時/錯誤視為失敗並嘗試下一順位，全部失敗回傳 503
- [ ] 2.5 統一回應格式：組裝 `ChatCompletionResponse`（含 `providerId`），確保不因供應商不同而格式不一致
- [ ] 2.6 確保供應商 API 金鑰只從環境變數讀取，任何錯誤回應/log 不得洩漏金鑰內容
- [ ] 2.7 加入結構化 log：記錄每次請求嘗試的供應商順序、成功/失敗、耗時（供後續排查用，取代 V1 不做的 `/providers` 監控）

## 3. 部署與對外曝露

- [ ] 3.1 確認 OpenClaw droplet 規格（vCPU/RAM）是否足以同時運行 OpenClaw、jev、閘道服務、local-ollama
- [ ] 3.2 在 droplet 上安裝並設定 `local-ollama`（若尚未安裝）
- [ ] 3.3 將閘道服務部署到 droplet（容器化或直接執行），設定環境變數（供應商 API keys、bearer token）
- [ ] 3.4 安裝並設定 `cloudflared`，建立 Cloudflare Tunnel，指定子網域對外曝露閘道
- [ ] 3.5 驗證 droplet 未開放任何對外 inbound port（閘道僅可透過 Cloudflare Tunnel 存取）

## 4. n8n 串接

- [ ] 4.1 複製現有 workflow `3Amdvkf1TpWv8iRu` 建立測試版本，避免直接修改生產 workflow
- [ ] 4.2 於測試版本修改自訂 HTTP Request node：URL 改為閘道子網域 `/v1/chat/completions`，Authorization header 改為閘道 bearer token
- [ ] 4.3 測試版本端到端驗證通過後，套用修改至正式 workflow `3Amdvkf1TpWv8iRu`

## 5. 驗證

- [ ] 5.1 驗證正常路徑：Telegram 傳訊息 → n8n → 閘道（nvidia-kimi 成功）→ 回覆 → 檔案照常存到 Google Drive
- [ ] 5.2 驗證備援路徑：手動讓 nvidia-kimi 失效（例如改錯 API key），確認流程透過 openrouter-pony 成功完成
- [ ] 5.3 驗證認證：以缺少或錯誤 bearer token 呼叫閘道，確認回傳 401 且未呼叫任何供應商
- [ ] 5.4 驗證全部供應商失敗情境：模擬三個供應商皆不可用，確認閘道回傳 503
- [ ] 5.5 確認錯誤回應與 log 不含任何供應商 API 金鑰
