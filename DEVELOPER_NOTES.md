# Elite Time Tracker: 開發者注意事項 (Developer Notes)

## 📌 黃金法則 (Golden Rule)
*   **外行人士友善溝通**: 面對非技術背景的用戶，必須詳細解釋所有「看不到的背後運作」（例如本地代碼與雲端發佈的區別）。**禁止省略任何細節**，確保用戶掌握進度。

## 🚨 平台核心差異 (Critical Platform Differences)

### 1. Flutter Web 的更新機制
*   **重點**: Flutter Web **不支援** 像 Android/iOS 那樣的自動 Hot Reload。
*   **行為**: 當修改了 `Provider`、`Notifier` 或 `UI` 邏輯時，Web 版必須點擊 **Hot Restart (大寫 R)** 或是手動重新整理網頁，新程式碼才會生效。
*   **症狀**: 如果 Web 端看起來同步失效或沒有出現新功能，通常是因為它還在跑舊版的實作。

### 2. 時區歸一化 (Timezone Normalization)
*   所有存向 Firestore 的時間戳記必須使用 `toUtc()`。
*   兩端讀取時再使用 `toLocal()` 或 delta 計算。

### 3. 熱同步 (Hot Sync) 結構
*   當前系統採用「單一事實來源 (Source of Truth)」模式。
*   主控權在雲端的 `settings/timer_state` 文件。

---

## 🚀 必備部署程序 (Required Deployment)
*   **重點**: 每當修改完 UI、Provider 或核心邏輯後，**必須** 更新 Web 版，否則用戶在網頁端會看到舊版行為。
*   **步驟**:
    1.  `flutter build web --release` (編譯最新程式碼)
    2.  `firebase deploy --only hosting` (發布至 Firebase Hosting)
*   **注意**: 即使在開發階段，也需確保 Web 端同步，避免出現「網頁版沒反應」的情況。

---

*最後更新日期: 2026-04-05*

## 📅 自定義區間分析里程碑 (Custom Date Range Milestone) - 2026-04-05
*   **當前版本**: `v3.UltraSync_CUSTOM_DATE_RANGE` (現已全面同步至 Web)
*   **深度數據透視**:
    *   **邏輯中台化 (Refactored FilterUtils)**: 將原本分散於「統計」與「歷史」二端的過濾邏輯統一抽離至 `lib/helpers/filter_utils.dart`。解決了數據異步顯示不一致的問題。
    *   **互動式「自定義區間」**: 整合 Flutter 原生 `showDateRangePicker`，支持用戶自由選定起止日期並聚合數據（如：特定專案週、連假）。
    *   **智慧標籤與同步**: 「時間機器」控制區現在能動態顯示選定區間（如：3/1 - 3/15），並支持點擊即改。
    *   **今日預設邏輯**: 確保每次啟動或重置皆回歸「今日」，保持核心視圖簡潔。
*   **穩定性提升**:
    *   修復了 `lib/pages/history_page.dart` 在代碼抽離過程中產生的類別重複定義報錯。
    *   各端（Web/Mobile）的自定義日期過濾數據同步已通過驗證。
*   **下一步建議**:
    *   增加「圖表下鑽 (Drill-down)」功能，點擊 Pie 區塊直接查看該區塊的歷史細節。
    *   整合「數據導出 (CSV/PDF)」分析報告。
