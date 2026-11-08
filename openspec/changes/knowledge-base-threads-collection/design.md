## Context

使用者目前在 Threads 上瀏覽到想保存的公開文章時，沒有自動化的收集流程。官方 Threads API 無法以網址直接讀取他人文章，oEmbed 條款禁止用於展示以外的用途，網頁本身也以 `robots.txt` 禁止自動化讀取；因此 Mentions webhook（使用者在貼文下留言標記收藏帳號）是目前唯一合規且可全自動觸發的路徑。

知識庫採兩層結構：`raw/` 保存未經改寫的原始資料作為權威來源，`wiki/` 由 AI 維護並反向連結回 `raw/`，呼應 Karpathy 筆記流的設計。

`knowledge-base` 專案目前已有「TGBot 對話整理」（n8n workflow，已完成，部署於 OpenClaw droplet）與「LLM Fallback 閘道」（`knowledge-base-gateway`，規格已定義、尚未實作，三重備援 nvidia-kimi → openrouter-pony → local-ollama）兩個子系統。本次新增的 Threads 收集能力是第三個子系統，與前兩者不互相呼叫，只共用專案命名空間與 Google Drive 資料夾。

## Goals / Non-Goals

**Goals:**
- 從留言到檔案寫入 Drive，全程不需人工介入。
- 原文、作者串文、外部文章完整保存於 `raw/`，可追溯來源。
- 每篇收藏都會更新對應的 wiki 主題頁與 `index.md`。
- 任一後段步驟失敗都不影響原文寫入 `raw/`（先保住原文的原則）。
- Flow A（收集）與 Flow B（整理）為獨立流程，互不阻塞；Flow B 也不依賴既有 TGBot 服務。

**Non-Goals:**
- 不處理貼文圖片、影片內容分析（v1 僅記錄媒體網址）。
- 不做查詢結果回存 wiki（留待 v2）。
- 不做 wiki 定期健康檢查（留待 v2）。
- 不做 Laya 微調與機率校準（v1 只累積判斷紀錄）。
- 不送 Meta App Review 正式審核（開發模式驗證可行後再評估）。
- 不透過 `knowledge-base-gateway` 三重備援閘道呼叫 Ollama（見下方決策 3）。
- 不處理非主帳號觸發的留言（直接丟棄）。

## Decisions

### 1. 觸發機制：Threads Mentions Webhook，而非網址讀取或 oEmbed
官方 API 無法以網址讀取他人文章、oEmbed 條款限制、`robots.txt` 禁止自動化讀取，三者皆排除直接讀取方案。Mentions webhook（使用者在貼文下留言標記收藏帳號）是唯一合規且可全自動的路徑。
- **考慮過的替代方案**：定期爬蟲掃描使用者自己瀏覽紀錄——放棄，違反 `robots.txt` 且無法全自動辨識「哪些文章使用者想收藏」。

### 2. Flow A / Flow B 拆成兩個獨立流程
Flow A（webhook 觸發 → 寫入 `raw/`）與 Flow B（排程讀取 `raw/` → 整理進 `wiki/` → 移除 raw）各自是獨立的 n8n workflow，彼此不呼叫，也不依賴既有 TGBot workflow。
- **原因**：Flow A 要求低延遲回應 webhook（Meta 要求快速回 200），Flow B 是批次整理，屬於不同的執行節奏與失敗處理策略；拆開可讓兩者獨立重跑、獨立監控，且 Flow A 的任何後段失敗（Laya、Puppeteer、Ollama）都不影響 `raw/` 已寫入的事實。
- **考慮過的替代方案**：單一流程內用同步步驟從收到留言一路做到 wiki 更新——放棄，會讓 webhook 回應時間拉長（可能超過 Meta 的逾時要求），且任一步驟失敗會讓整條流程難以局部重跑。

### 3. Flow B 直連本機 Ollama API，不透過 `knowledge-base-gateway` 三重備援閘道
Flow B 的 Ollama 呼叫採直連本機 `http://localhost:11434`，不經過既有的三重備援閘道。
- **原因一（合規）**：閘道的 fallback 順序是 `nvidia-kimi → openrouter-pony → local-ollama`，local-ollama 只是最後底牌。若 local-ollama 忙碌或不可用，閘道會把原文與外部文章全文送往 NVIDIA / OpenRouter 等第三方雲端 API，直接違反本能力「Laya、Puppeteer、Ollama 皆自架，資料不經第三方服務」的非功能需求。
- **原因二（context 處理）**：閘道現有的 fallback 邏輯只把「錯誤或逾時」視為失敗並換下一順位，沒有針對 context 超過（例如 400 `context_length_exceeded`）設計處理機制；且三個供應商的 context window 不同，換下一順位不保證能解決原本就過長的請求，可能三者皆失敗、整理直接中斷。長文超出 context 的風險改由 Flow B 自身以分段處理因應。
- **考慮過的替代方案**：透過閘道呼叫、但限制 Flow B 只能使用 `local-ollama` 順位（不允許 fallback 到雲端）——放棄，因為這等於閘道的備援能力對 Flow B 名存實亡，卻仍背負多一層網路跳轉、bearer auth 與閘道可用性的額外依賴，相較直連沒有實質好處。

### 4. Puppeteer 獨立部署，Laya / Ollama 沿用既有機器
Puppeteer（headless Chrome，用於抓取外部文章）部署在獨立機器/環境；Laya 判斷服務與 local Ollama 沿用既有的 OpenClaw droplet（與 `knowledge-base-gateway` 的 local-ollama 同機）。
- **原因**：OpenClaw droplet 資源有限（規格待確認，但 `knowledge-base-v1-fallback-gateway` 的 design.md 已標記資源疑慮），headless Chrome 的記憶體與 CPU 消耗較高，與既有服務（OpenClaw、jev、閘道、local-ollama）同機風險較大，故另外部署；Laya、Ollama 相對輕量或已有既定部署位置，沿用現有機器。

### 5. 留言規則：以 root_post 為收藏對象、標籤與備註解析
回覆在串文中某則貼文時，以 root_post 為收藏對象；標籤以 `#` 開頭、空白分隔，可有零到多個，無標籤時交由 Ollama 歸類；標籤以外的文字視為使用者備註，存入 `raw` 的 frontmatter。
- **原因**：避免同一篇文章因為使用者在不同樓層留言而被拆成多筆收藏；標籤驅動的 wiki 主題頁命名方式簡單、可預期（AI 歸納主題 vs. 標籤為準，列為待決事項）。

### 6. 資料結構：raw 唯讀、wiki 可變，兩者以 frontmatter 互相追溯
`raw/` 由系統寫入後不再修改；`wiki/` 只由 Ollama 維護。`raw/threads/<收藏日期>_<shortcode>.md`、`raw/web/<抓取日期>_<網域>_<路徑 slug>.md`、`wiki/<主題名稱>.md`。
- **原因**：`raw/` 作為權威來源需要穩定不變，才能讓 Flow B 重跑時保持冪等；`wiki/` 作為衍生內容則允許持續被 AI 改寫更新。

## Risks / Trade-offs

- **[風險] Mentions 通知中的 root_post 可能讀不到他人原文的完整內容**（Threads API 權限限制）→ 緩解：退而以 `/conversation` 取得可得內容，並標記為部分內容；此為待優先實測項（見 Open Questions）。
- **[風險] 留言公開可見，原作者會收到通知，可能造成使用體驗或社交觀感疑慮** → 緩解：留言內容保持簡短（僅標籤），接受此取捨。
- **[風險] Laya 未微調前判斷接近隨機，可能漏抓或多抓外部文章** → 緩解：v1 門檻偏低（寧可多抓），並記錄每次判斷的問題、機率與決定，累積資料後供後續微調。
- **[風險] 長文超出 Laya 或 Ollama 的 context window，導致判斷或整理失準** → 緩解：分段處理；Laya 使用多語系版本的較長 context；Flow B 直連 Ollama 需自行處理分段，不依賴閘道的 fallback。
- **[風險] Puppeteer 抓取外部文章可能被目標網站 `robots.txt` 禁止或抓取失敗** → 緩解：遵守目標網站 `robots.txt`；抓取失敗時仍正常寫入 `raw/threads`，於 frontmatter 記錄該連結未抓取及原因，不阻斷主流程。
- **[風險] Ollama 停機或逾時導致 Flow B 整理失敗** → 緩解：`raw/` 已寫入即視為收藏成功；wiki 更新標記為待處理，Flow B 下次排程重跑時可補上，且因 `raw/` 未被移除、重跑具冪等性。
- **[風險] Flow B 整理完成後移除 raw 檔，若整理結果有誤（例如摘要錯誤、wiki 寫壞）則難以回溯原始內容** → 緩解：移除前需確認 wiki 更新已成功寫入 Drive；可評估是否需要保留短期備份或先搬移到 `raw/_archived/` 而非直接刪除（留待實作階段決定，見 Open Questions）。
- **[取捨] Puppeteer 獨立部署增加一個額外的部署目標與維運成本** → 換取避免拖垮 OpenClaw droplet 既有服務的穩定性，判斷利大於弊。

## Migration Plan

1. 先以測試帳號驗證 root_post 能否讀到他人貼文的 `text`（待決事項第一項，決定整個方案是否成立）。
2. 實作 Flow A：webhook 接收與驗證 → 留言解析 → Threads 讀取 → 連結偵測與 Laya 判斷 → Puppeteer 抓取 → `raw/` 寫入，在開發模式下以兩個測試者帳號（收藏帳號、主帳號）驗證端到端。
3. 部署 Puppeteer 於獨立環境；部署 Laya 於既有 OpenClaw droplet。
4. 實作 Flow B：排程讀取 `raw/` → 直連本機 Ollama 產生摘要 → 更新 `wiki/` → 移除已處理的 raw 檔，先以少量測試資料驗證冪等性與 wiki 更新正確性。
5. 兩條流程皆驗證通過後，正式啟用 Mentions webhook 訂閱。
6. **Rollback**：Flow A 與 Flow B 皆可獨立停用（停用 webhook 訂閱 / 停用排程），不影響既有 TGBot workflow 與 `knowledge-base-gateway`；已寫入 `raw/` 的資料不受影響，可於問題排除後重新啟用 Flow B 補跑整理。

## Open Questions

- **以測試帳號實測：mentions 通知中的 `root_post` 能否讀到他人貼文的 `text`（決定方案是否成立的關鍵前提）。** 這是唯一真正無法由 PM 拍板的項目——需要實際呼叫 Threads API 驗證，不是設計決策。v1 實作前必須優先完成此驗證（見 tasks.md 前置驗證）。
- ~~wiki 主題頁命名方式~~ **已決策（2026-10-02，PM 推薦選項）**：採用「以使用者標籤為準，無標籤時才由 Ollama 歸類」（沿用原始規格的建議）。
- ~~Flow B 使用的 Ollama 模型~~ **已決策（2026-10-02，PM 推薦選項）**：預設採用 `qwen2.5:14b-instruct`（中文能力佳、支援長 context、可在單機 Ollama 運行）；若實際部署機器資源不足，降級為 `qwen2.5:7b-instruct`。此為 v1 預設值，待實測後可調整。
- ~~流程編排方式~~ **已決策（2026-10-02，PM 推薦選項，沿用原設計）**：Flow A、Flow B 皆以 n8n workflow 實作，不另寫自訂服務，與 design.md 既有的 Decision 2（拆成兩條獨立 n8n workflow）一致。
- ~~Laya 判斷門檻的初始值~~ **已決策（2026-10-02，PM 推薦選項）**：初始門檻設為 `0.3`（機率高於 0.3 即觸發抓取），偏低、寧可多抓，符合原始規格建議；後續依累積的判斷紀錄（見 Laya 判斷紀錄留存需求）校準調整。
- ~~Flow B 整理完成後是否直接刪除 raw 原始檔~~ **已決策（2026-10-02，PM 推薦選項）**：改為搬移至 `raw/_archived/`（不直接刪除），保留可回溯性；相較直接刪除，額外成本僅是搬移路徑而非真正刪除 API，風險可控。
- ~~Threads mentions webhook 的對外曝露方式~~ **已決策（2026-10-02，PM 推薦選項）**：沿用既有 `knowledge-base-gateway` 的 Cloudflare Tunnel 架構，但新增**獨立子網域**（而非與閘道共用同一子網域下的 path），避免 webhook 的簽章驗證與閘道的 bearer auth 驗證邏輯混用同一入口造成混淆；實際子網域命名待使用者於部署階段提供。
