修復使用者指定的 GitHub issue。

用法：`/fix-issue <issue_number>`（例如 `/fix-issue 123`）

1. 使用 `gh issue view <number>` 取得 issue 詳細資訊
2. 搜尋程式碼庫找出相關程式碼
3. 依循現有模式實作修復
4. 視情況撰寫測試
5. 建立參照該 issue 的 PR
