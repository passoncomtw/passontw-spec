## Why

`knowledge-base` 專案目前只涵蓋「TGBot 對話整理」與「LLM Fallback 閘道」兩塊規格，尚未有任何自動化的個人知識收集來源。使用者在 Threads 上瀏覽到想保存的公開文章時，目前完全依賴手動複製貼上，沒有一致的保存格式、也沒有串接到知識庫的整理流程。本次提案新增「Threads 資料收集」能力：使用者只需在想收藏的 Threads 貼文下留言標記收藏帳號，系統即可全自動把原文（含外部連結內容）存進 Google Drive 的 `raw/`，並定期由本機 Ollama 將 `raw/` 內容整理進 `wiki/`，讓知識庫得以持續、低摩擦地累積。

## What Changes

- 新增 Flow A（Threads 收藏）：Threads mentions webhook 接收主帳號的收藏留言 → 驗證簽章與留言者身分 → 以 root_post ID 讀取原文與作者接續貼文 → 解析留言中的標籤與備註 → 偵測外部連結、以 Laya 判斷是否需要抓取 → 需要時以 Puppeteer 抓取外部文章並轉為 Markdown → 寫入 Google Drive 的 `raw/threads/` 與 `raw/web/`（frontmatter 互相引用）。
- 新增 Flow B（知識庫整理）：獨立的排程流程，定時讀取 `raw/` 內容，呼叫**本機 local Ollama API（直連）**產生摘要、依標籤新增或更新 `wiki/<主題>.md` 與 `wiki/index.md`；整理完成後移除已處理的 raw 檔。
- **架構決策**：Flow B 不透過既有的 `knowledge-base-gateway` 三重備援閘道呼叫 Ollama，而是直連本機 Ollama API。原因詳見 design.md，核心考量是閘道的 fallback 順序（nvidia-kimi → openrouter-pony → local-ollama）會在 local-ollama 不可用時把原文與外部文章全文送往第三方雲端供應商，違反本能力「資料不經第三方服務」的非功能需求。
- Flow A、Flow B、既有的 TGBot 對話流程（n8n workflow）三者為同一個 `knowledge-base` 專案下彼此獨立、互不呼叫的子系統，僅共用「knowledge-base」此一專案與 Google Drive 資料夾命名空間。
- 新增 Puppeteer 抓取服務的獨立部署（與 OpenClaw droplet 分開，因該機器資源有限）；Laya 判斷服務與 local Ollama 沿用既有的 OpenClaw droplet。
- v1 範圍只處理文字內容，且只接受主帳號觸發；貼文圖片、影片內容分析，查詢結果回存 wiki，wiki 定期健康檢查，Laya 微調與機率校準，Meta App Review 正式送審，均不在本次範圍內（詳見 design.md Non-Goals）。

## Capabilities

### New Capabilities
- `threads-collection`：Threads mentions 留言觸發的自動收藏能力，涵蓋 webhook 接收與驗證、留言解析、Threads 原文與串文讀取、外部連結偵測與 Laya 抓取判斷、Puppeteer 外部文章抓取、raw 寫入 Google Drive，以及排程讀取 raw 以本機 Ollama 整理進 wiki 的知識庫維護流程。

### Modified Capabilities
（無。`knowledge-base-gateway` 的既有需求不變，`threads-collection` 明確選擇不依賴它。）

## Impact

- 新增 Google Drive 目錄結構 `knowledge-base/raw/threads/`、`knowledge-base/raw/web/`、`knowledge-base/wiki/`。
- 新增一個公開 HTTPS webhook 端點（Threads mentions），需規劃對外曝露方式（例如沿用既有 Cloudflare Tunnel 架構，另開子網域或 path）。
- 新增 Puppeteer 抓取服務的部署環境（獨立於 OpenClaw droplet）。
- 在既有 OpenClaw droplet 上新增 Laya 推論服務；local Ollama 服務沿用既有部署，但新增 Flow B 的直連呼叫方（需評估併發與資源影響）。
- 不修改 `api-specs/projects/knowledge-base/openapi.yaml` 中既有的 `/v1/chat/completions`、`/v1/providers`、`/v1/fallback`；`threads-collection` 為新能力，不經過閘道。
- 不影響 `pos-systems`、`p2p-exchange-service`、`games-system`、`staff-scheduling`。
- 不影響既有的 TGBot n8n workflow（`3Amdvkf1TpWv8iRu`）。

## 本次不含（留給後續版本）

- 貼文圖片、影片內容分析（v1 僅記錄媒體網址）
- 查詢結果回存 wiki
- wiki 定期健康檢查
- Laya 微調與機率校準（v1 只累積判斷紀錄）
- Meta App Review 正式送審（開發模式驗證可行後再評估）
