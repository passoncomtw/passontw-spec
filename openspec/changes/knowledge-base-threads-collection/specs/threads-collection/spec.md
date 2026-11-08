## ADDED Requirements

### Requirement: Webhook 訂閱驗證與簽章驗證
系統 SHALL 完成 Meta 的 webhook 訂閱驗證（verify token），並對每一次收到的通知驗證簽章，拒絕簽章不符的請求。

#### Scenario: 訂閱驗證成功
- **WHEN** Meta 以正確的 verify token 發送訂閱驗證請求
- **THEN** 系統回傳對應的 challenge 完成訂閱

#### Scenario: 通知簽章不符
- **WHEN** 收到的 webhook 通知簽章與 App secret 計算結果不符
- **THEN** 系統拒絕該通知，不進入後續處理流程

### Requirement: Webhook 即時回應與非同步處理
系統 SHALL 在收到合法 webhook 通知後立即回應 200，並將實際處理邏輯非同步排入佇列執行。

#### Scenario: 立即回應
- **WHEN** 系統收到一筆通過簽章驗證的 mentions 通知
- **THEN** 系統立即回傳 200，並將該通知排入佇列，不在回應前完成讀取、抓取、寫入等步驟

### Requirement: 僅接受主帳號觸發
系統 SHALL 僅處理留言者 username 為主帳號的 mentions 通知，非主帳號觸發時直接丟棄並記錄一筆略過紀錄。

#### Scenario: 主帳號留言
- **WHEN** mentions 通知的留言者 username 為主帳號
- **THEN** 系統繼續後續收藏流程

#### Scenario: 非主帳號留言
- **WHEN** mentions 通知的留言者 username 不是主帳號
- **THEN** 系統丟棄該通知，不進入後續流程，並記錄一筆略過紀錄

### Requirement: 以 root_post 判斷重複並合併標籤
系統 SHALL 以 root_post ID 判斷是否為重複收藏；已收藏過的 root_post 僅合併新標籤到既有 raw 檔，不重新執行讀取、抓取與整理流程。

#### Scenario: 首次收藏
- **WHEN** 收到的 root_post ID 尚無對應的 `raw/threads` 檔案
- **THEN** 系統執行完整收藏流程並建立新的 raw 檔

#### Scenario: 重複收藏
- **WHEN** 收到的 root_post ID 已有對應的 `raw/threads` 檔案
- **THEN** 系統將本次留言的標籤合併進既有 raw 檔的 `tags`，不重新讀取原文或重新抓取外部連結

### Requirement: 留言標籤與備註解析
系統 SHALL 從留言文字中取出以 `#` 開頭、空白分隔的標籤清單（可為零到多個），移除收藏帳號的標記，並將標籤以外的文字視為使用者備註。

#### Scenario: 含標籤留言
- **WHEN** 留言內容為 `@收藏帳號 #支付 #架構`
- **THEN** 系統解析出標籤 `[支付, 架構]`，備註為空

#### Scenario: 無標籤留言
- **WHEN** 留言內容僅為 `@收藏帳號` 或含有標籤以外的文字但無任何 `#標籤`
- **THEN** 系統解析出空標籤清單，並將標籤以外的文字存入備註，供後續 Ollama 歸類使用

### Requirement: 以 root_post 取得原文
系統 SHALL 以 root_post ID 取得原文的 `text`、`username`、`permalink`、`timestamp`、`media_type`。

#### Scenario: 正常回覆於貼文底下
- **WHEN** 留言回覆在欲收藏的貼文底下
- **THEN** 系統以該貼文作為 root_post 讀取原文欄位

#### Scenario: 回覆在串文中的某則
- **WHEN** 留言回覆在某篇串文中的某一則貼文
- **THEN** 系統以該串文的 root_post 作為收藏對象，讀取 root_post 的原文欄位

### Requirement: 讀取作者接續貼文組成完整內文
系統 SHALL 以 `/conversation` 取得同一串文中原作者本人的接續貼文，依時間排序組成完整內文。

#### Scenario: 作者有接續貼文
- **WHEN** root_post 所在串文中，原作者本人有後續貼文
- **THEN** 系統依時間排序將這些貼文併入同一份原文內容

### Requirement: 外部連結偵測
系統 SHALL 以正規表示式從原文中抽出網址，並排除 `threads.com`、`instagram.com` 等社群網域。

#### Scenario: 含外部連結
- **WHEN** 原文中包含非社群網域的網址
- **THEN** 系統將該網址列為待判斷的外部連結

#### Scenario: 僅含社群網域連結
- **WHEN** 原文中的網址全部屬於排除的社群網域
- **THEN** 系統不產生任何待判斷的外部連結

### Requirement: Laya 抓取判斷
系統 SHALL 對含有外部連結的貼文，以 Laya 提出是非題判斷主要內容是否依賴外部文章；機率高於門檻才觸發抓取。

#### Scenario: 機率高於門檻
- **WHEN** Laya 判斷「主要內容依賴外部文章」的機率高於設定門檻
- **THEN** 系統觸發 Puppeteer 抓取該外部連結

#### Scenario: 機率低於門檻
- **WHEN** Laya 判斷的機率低於設定門檻
- **THEN** 系統不抓取該外部連結，原文仍正常寫入 raw

#### Scenario: Laya 無法使用
- **WHEN** Laya 服務無法呼叫或逾時
- **THEN** 系統視為需要抓取，照常觸發 Puppeteer

### Requirement: Laya 判斷紀錄留存
系統 SHALL 記錄每次 Laya 判斷的問題、機率與最終決定，供日後微調與校準使用。

#### Scenario: 記錄判斷結果
- **WHEN** 系統完成一次 Laya 判斷（無論觸發抓取與否）
- **THEN** 系統將問題、機率、是否抓取的決定寫入 raw 檔的 `laya` frontmatter 欄位

### Requirement: 外部文章抓取與轉換
系統 SHALL 以 Puppeteer 開啟判定需要抓取的外部網址，擷取主文並轉為 Markdown，且遵守目標網站的 `robots.txt`。

#### Scenario: 抓取成功
- **WHEN** 外部網址允許抓取（未被 `robots.txt` 禁止）且 Puppeteer 成功取得主文
- **THEN** 系統將主文轉為 Markdown，寫入 `raw/web/` 對應檔案

#### Scenario: robots.txt 禁止或抓取失敗
- **WHEN** 外部網站的 `robots.txt` 禁止抓取，或 Puppeteer 抓取過程失敗
- **THEN** 系統不中斷主流程，`raw/threads` 仍正常寫入，並於 frontmatter 記錄該連結未抓取及原因

### Requirement: raw 寫入 Google Drive
系統 SHALL 將原文與每篇外部文章各存為一個 Markdown 檔，寫入 Google Drive 的 `knowledge-base/raw/threads/` 與 `knowledge-base/raw/web/`，兩者以 frontmatter 互相引用；raw 一經寫入不再修改（除合併標籤外）。

#### Scenario: 無外部文章
- **WHEN** 貼文沒有需要抓取的外部連結
- **THEN** 系統僅寫入 `raw/threads/<收藏日期>_<shortcode>.md`，不產生 `raw/web` 檔案

#### Scenario: 含外部文章
- **WHEN** 貼文有已抓取成功的外部文章
- **THEN** 系統寫入 `raw/threads/<收藏日期>_<shortcode>.md` 與對應的 `raw/web/<抓取日期>_<網域>_<路徑slug>.md`，前者的 `linked_raw` 指向後者、後者的 `from_raw` 指回前者

#### Scenario: 讀不到 root_post 原文
- **WHEN** 系統無法透過 root_post ID 讀到原文
- **THEN** 系統改存 `/conversation` 可取得的內容，並於 frontmatter 標記為部分內容

### Requirement: Drive 以 Markdown 原樣上傳
系統 SHALL 以 `text/markdown` 原樣上傳檔案至 Google Drive，不轉換為 Google 文件格式。

#### Scenario: 上傳檔案
- **WHEN** 系統寫入 `raw/` 或 `wiki/` 任一檔案至 Google Drive
- **THEN** 檔案格式為 `.md`，下載後可直接以一般 Markdown 編輯器（例如 Obsidian）開啟

#### Scenario: Drive 寫入失敗
- **WHEN** 上傳 Google Drive 失敗
- **THEN** 系統重試上傳；檔案先暫存本地，成功後才移除本地暫存

### Requirement: 排程整理 raw 進 wiki
系統 SHALL 以獨立排程流程（不依賴 TGBot 服務）定時讀取 `raw/` 內容，呼叫本機 local Ollama API（直連，不經三重備援閘道）產生摘要，依標籤新增或更新對應的 `wiki/<主題>.md` 與 `wiki/index.md`，並以增量方式更新、不重編整本 wiki。

#### Scenario: 新主題
- **WHEN** 待整理的 raw 標籤尚無對應的 wiki 主題頁
- **THEN** 系統建立新的 `wiki/<主題>.md`，內容包含該篇摘要並連結回對應的 raw 檔，同時更新 `wiki/index.md`

#### Scenario: 既有主題
- **WHEN** 待整理的 raw 標籤已有對應的 wiki 主題頁
- **THEN** 系統以增量方式在既有主題頁新增該篇摘要與回連 raw 檔的連結，不重寫整頁既有內容

#### Scenario: 整理完成後封存 raw
- **WHEN** 某筆 raw 的 wiki 更新已成功寫入 Google Drive
- **THEN** 系統將該筆已處理完成的 raw 檔搬移至 `raw/_archived/`，不直接刪除，保留回溯能力

#### Scenario: Ollama 停機或逾時
- **WHEN** 排程整理時本機 Ollama 無法呼叫或逾時
- **THEN** 系統不搬移對應的 raw 檔，該筆收藏仍視為已成功寫入 raw，wiki 更新標記為待處理，等待下次排程重跑

### Requirement: 處理狀態紀錄與可重跑
系統 SHALL 為每筆收藏維護處理狀態紀錄（已接收、已讀取、已抓取、已寫入 raw、已整理 wiki、失敗於某步），且每個步驟可依 root_post ID 單獨重跑並得到相同結果（冪等）。

#### Scenario: 查詢處理狀態
- **WHEN** 查詢某個 root_post ID 的處理紀錄
- **THEN** 系統回傳該筆收藏目前所處的狀態階段

#### Scenario: 單步重跑冪等
- **WHEN** 針對某個已部分失敗的 root_post ID 重新執行其中一個步驟
- **THEN** 該步驟的執行結果與首次執行相同，不產生重複或不一致的 raw/wiki 內容

### Requirement: Threads API 呼叫失敗重試
系統 SHALL 在呼叫 Threads API 失敗時採指數退避重試，仍失敗則標記該筆收藏失敗，等待後續重跑。

#### Scenario: 暫時性失敗
- **WHEN** 呼叫 Threads API 失敗（例如限流或暫時性錯誤）
- **THEN** 系統依指數退避策略重試

#### Scenario: 重試仍失敗
- **WHEN** 指數退避重試後仍然失敗
- **THEN** 系統將該筆收藏標記為失敗於該步驟，等待後續重跑，不中斷其他收藏的處理

### Requirement: 憑證與權杖安全管理
系統 SHALL 以環境變數或密鑰管理機制注入存取權杖與 Drive 憑證，不得寫入程式碼或 raw 檔。

#### Scenario: 權杖注入
- **WHEN** 系統啟動並需要呼叫 Threads API 或 Google Drive API
- **THEN** 權杖與憑證由環境變數或密鑰管理機制提供，程式碼與任何 raw/wiki 檔案內容中不包含明文權杖
