## 1. 前置驗證

- [ ] 1.1 以測試帳號實測 mentions 通知中的 root_post 能否讀到他人貼文的 `text`（方案成立的關鍵前提，失敗則需重新評估整體可行性；唯一尚未拍板的前置事項，其餘已於 design.md Open Questions 以 PM 推薦選項拍板：wiki 命名以標籤為準、Ollama 模型 `qwen2.5:14b-instruct`、Laya 門檻 0.3、Flow A/B 皆用 n8n workflow、raw 封存而非刪除、webhook 用獨立子網域）

## 2. Threads App 與權限設定

- [ ] 2.1 建立收藏帳號，申請 Threads App 並設定開發模式
- [ ] 2.2 將收藏帳號與主帳號加入 App 測試者
- [ ] 2.3 設定 `threads_basic`、`threads_manage_mentions`、`threads_read_replies` 權限
- [ ] 2.4 設定 Mentions Webhook：verify token、App secret、訂閱端點

## 3. Webhook 接收（FR-01、FR-02、FR-03、FR-04）

- [ ] 3.1 實作 webhook 端點，完成 Meta 訂閱驗證（verify token）
- [ ] 3.2 實作每次通知的簽章驗證，拒絕簽章不符請求
- [ ] 3.3 實作收到通知後立即回應 200、非同步排入佇列
- [ ] 3.4 實作留言者 username 過濾（非主帳號直接丟棄並記錄略過紀錄）
- [ ] 3.5 實作以 root_post ID 判斷重複收藏，重複時僅合併標籤、不重跑流程
- [ ] 3.6 規劃 webhook 對外曝露方式（是否沿用既有 Cloudflare Tunnel 架構）

## 4. 留言解析（FR-05）

- [ ] 4.1 實作標籤解析（`#` 開頭、空白分隔、零到多個）
- [ ] 4.2 實作備註解析（標籤以外文字），移除收藏帳號標記

## 5. Threads 讀取（FR-06、FR-07）

- [ ] 5.1 實作以 root_post ID 取得原文 `text`、`username`、`permalink`、`timestamp`、`media_type`
- [ ] 5.2 實作以 `/conversation` 取得原作者接續貼文，依時間排序組成完整內文
- [ ] 5.3 實作讀不到 root_post 原文時改存 `/conversation` 可取得內容，並標記為部分內容
- [ ] 5.4 實作 Threads API 呼叫失敗的指數退避重試，重試仍失敗則標記失敗於該步驟

## 6. 連結偵測與 Laya 判斷（FR-08、FR-09、FR-10）

- [ ] 6.1 實作正規表示式抽取原文網址，排除 `threads.com`、`instagram.com` 等社群網域
- [ ] 6.2 串接 Laya（多語系版本），對含連結貼文提出是非題判斷
- [ ] 6.3 實作機率門檻判斷是否觸發抓取
- [ ] 6.4 實作 Laya 無法使用時視為需要抓取的 fallback
- [ ] 6.5 實作判斷紀錄留存（問題、機率、最終決定）寫入 frontmatter

## 7. 外部抓取（FR-11）

- [ ] 7.1 部署獨立的 Puppeteer 抓取服務（與 OpenClaw droplet 分開）
- [ ] 7.2 實作 Puppeteer 開啟網址、擷取主文、轉為 Markdown
- [ ] 7.3 實作遵守目標網站 `robots.txt`
- [ ] 7.4 實作抓取失敗或被 `robots.txt` 禁止時不中斷主流程，於 frontmatter 記錄原因

## 8. raw 寫入 Google Drive（FR-12、FR-14）

- [ ] 8.1 定義 `raw/threads/<收藏日期>_<shortcode>.md` 與 frontmatter 欄位（`source`、`media_id`、`shortcode`、`url`、`author`、`posted_at`、`collected_at`、`tags`、`note`、`media_urls`、`linked_raw`、`laya`）
- [ ] 8.2 定義 `raw/web/<抓取日期>_<網域>_<路徑slug>.md` 與 frontmatter 欄位（`source`、`url`、`title`、`fetched_at`、`from_raw`）
- [ ] 8.3 實作兩類 raw 檔的 frontmatter 互相引用（`linked_raw` ↔ `from_raw`）
- [ ] 8.4 實作以 `text/markdown` 原樣上傳至 Google Drive，不轉換為 Google 文件格式
- [ ] 8.5 實作 Drive 寫入失敗時重試，並於成功前暫存本地

## 9. Ollama 整理與 wiki 更新（FR-13，Flow B）

- [ ] 9.1 實作獨立排程流程（不依賴 TGBot 服務），定時掃描待整理的 `raw/` 內容
- [ ] 9.2 實作直連本機 Ollama API（不經三重備援閘道）產生摘要
- [ ] 9.3 實作依標籤新增或更新 `wiki/<主題>.md`，增量更新、不重編整本 wiki
- [ ] 9.4 實作 `wiki/index.md` 同步更新
- [ ] 9.5 實作整理完成且 wiki 已成功寫入 Drive 後，將已處理的 raw 檔搬移至 `raw/_archived/`（不直接刪除）
- [ ] 9.6 實作 Ollama 停機或逾時時，raw 視為已收藏成功、wiki 更新標記待處理，供下次排程重跑

## 10. 狀態紀錄與冪等性

- [ ] 10.1 實作每筆收藏的處理狀態紀錄（已接收、已讀取、已抓取、已寫入 raw、已整理 wiki、失敗於某步）
- [ ] 10.2 驗證每個步驟可依 root_post ID 單獨重跑且結果一致（冪等）

## 11. 安全性與憑證

- [ ] 11.1 設定 Threads 存取權杖、Drive 憑證以環境變數或密鑰管理注入
- [ ] 11.2 驗證程式碼與 raw/wiki 檔案內容不含明文權杖

## 12. 驗收驗證

- [ ] 12.1 主帳號在他人公開貼文留言標記收藏帳號後，驗證 `raw/threads` 出現對應檔案，內容與原文一致
- [ ] 12.2 驗證留言中的標籤與備註正確寫入 frontmatter
- [ ] 12.3 驗證多則串文貼文的原作者接續貼文依序併入同一個 raw 檔
- [ ] 12.4 驗證非主帳號標記收藏帳號時不產生任何檔案
- [ ] 12.5 驗證同一篇收藏兩次，只有一個 raw 檔，標籤為兩次合併結果
- [ ] 12.6 驗證含外部文章連結且 Laya 判斷需要抓取時，`raw/web` 出現對應檔案且兩檔互相引用
- [ ] 12.7 驗證外部網站抓取失敗時，`raw/threads` 仍正常寫入並記錄失敗原因
- [ ] 12.8 驗證 wiki 對應主題頁新增該篇摘要並連回 raw 檔，`index.md` 同步更新
- [ ] 12.9 驗證 Ollama 停機時收藏仍寫入 raw，恢復後可重跑補上 wiki
- [ ] 12.10 驗證 Drive 上的檔案為 `.md` 格式，下載後可直接以 Obsidian 開啟

## 13. 文件更新

- [ ] 13.1 更新 `api-specs/projects/knowledge-base/README.md`，新增 Threads 收集能力的現況說明
- [ ] 13.2 更新 `api-specs/projects/knowledge-base/CHANGELOG.md`，記錄本次新增能力
