# Knowledge Base API Changelog

## [未發布]
### Added
- 新增 Threads 資料收集子系統規格（`openspec/changes/knowledge-base-threads-collection`）：Flow A 以 Threads mentions 留言觸發收藏、寫入 Google Drive `raw/`；Flow B 獨立排程直連本機 Ollama（不經三重備援閘道）將 `raw/` 整理進 `wiki/`。目前僅有規格，尚未實作
### Changed
- 專案更名：`llm-fallback-gateway` → `knowledge-base`，定位調整為「個人知識庫服務」，涵蓋 TGBot 筆記整理、LLM Fallback 閘道、Threads 資料收集三個子系統
### Status
- TGBot 對話流程（n8n workflow，DigitalOcean droplet 部署）已完成：可收發訊息並取得 AI 回覆，目前直接呼叫外部 LLM，尚未串接本閘道
- 閘道服務本身仍未實作，僅有 OpenAPI 規格；與 n8n 的串接列為後續版本待辦
- Threads 資料收集子系統尚未實作，僅有 openspec 規格；前置驗證待辦（root_post 能否讀到他人貼文內容）尚未執行

## [1.0.0] - 未定
### Added
- 初始規格：統一 chat/completions、providers、fallback 順序
- 三重備援供應商：nvidia-kimi, openrouter-pony, local-ollama
