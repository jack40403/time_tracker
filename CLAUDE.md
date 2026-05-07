# Me Time - Flutter App (time_tracker)

## 專案概述
Flutter 時間追蹤 App，支援 Android / iOS / Web。
Firebase Hosting 部署，APK 也放在 Firebase Hosting 上供下載。

## 技術架構
- **State Management**: Riverpod
- **Backend**: Firebase (Firestore + Hosting + Auth)
- **字體**: Fredoka（展示用）、Outfit（內文）
- **UI 風格**: 卡通風格，對應 App Icon（天藍色背景、金黃色、粗黑邊框）

## 關鍵檔案
| 路徑 | 說明 |
|------|------|
| `lib/theme/cartoon_theme.dart` | 共用卡通主題常數、CartoonAppBar、CartoonBubbles |
| `lib/main.dart` | App 進入點、全域 MaterialApp 主題 |
| `lib/pages/home_page.dart` | 計時器主頁 |
| `lib/pages/main_screen.dart` | 底部導覽列 |
| `lib/widgets/background_wrapper.dart` | 藍色漸層背景 + 泡泡裝飾 |
| `lib/providers/timer_provider.dart` | 計時器核心邏輯 |
| `lib/services/update_service.dart` | APK 更新檢查（從 version.json） |
| `.github/workflows/deploy.yml` | GitHub Actions：build APK + web → Firebase |

## 設計規範（卡通風格）
- **背景**: `CartoonTheme.backgroundGradient`（天藍 → 深藍）
- **卡片**: `CartoonTheme.cardDecoration()`，奶黃色 `#FFFDE7`，粗黑邊框 4px，硬陰影 6px
- **主色**: `#0077B6`（藍）、`#FFD60A`（黃）、`#FF8F00`（金橘）
- **黑色**: `#1A1A2E`（inkBlack）

## 部署流程
```
git push → GitHub Actions 自動執行：
  1. flutter build apk --release
  2. flutter build web --release
  3. 產生 version.json（含 buildNumber）
  4. firebase deploy → metimegoalgoal.web.app
```

## 注意事項
- **不要修改** `lib/firebase_options.dart`（Firebase 設定，自動產生）
- **不要修改** `android/app/google-services.json`
- APK 簽名目前用 debug key（`build.gradle.kts` 第 47 行）
- Widget 更新用 `qualifiedAndroidName`，不用 `androidName`

## 目前版本
`1.1.0+85`（pubspec.yaml）

---
*兩個 Claude session 共用此檔案，請在做重大變更前先讀這裡。*
