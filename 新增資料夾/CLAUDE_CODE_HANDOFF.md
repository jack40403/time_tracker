# Me Time — 開機動畫 + 多主題系統實作交接

## 任務總覽
為現有 Flutter App `time_tracker/` 加入:
1. **開機動畫** (Splash Screen):笑臉時鐘 App Icon pop-in + 招手 + 泡泡飛散,~1.8 秒
2. **5 種主題切換系統**:Cartoon (原版,預設) / Dark / Retro 卡其 / Pastel / Minimal
3. **主題選擇 UI** 放在設定頁,使用者點 swatch 即時切換,並用 SharedPreferences 持久化

完整視覺參考:本專案 `Me Time Themes.html` (用瀏覽器打開,點底部 nav 切頁,進入「設定」可看主題切換)

---

## 一、現有專案結構 (請先讀)

```
time_tracker/
├── lib/
│   ├── main.dart                    ← MaterialApp 進入點,要包 ThemeData
│   ├── theme/cartoon_theme.dart     ← 現有主題常數,要重構成多主題
│   ├── pages/
│   │   ├── main_screen.dart         ← 底部 nav 容器
│   │   ├── home_page.dart           ← 計時主頁
│   │   ├── statistics_page.dart
│   │   ├── goals_page.dart
│   │   ├── history_page.dart
│   │   └── settings_page.dart       ← 要加主題選擇 UI
│   ├── widgets/
│   │   └── background_wrapper.dart  ← 藍色漸層背景,要改成主題感知
│   └── providers/
│       ├── theme_provider.dart      ← 現有,只有 light/dark mode
│       └── background_provider.dart ← 現有,客製化背景色
├── assets/icon/app_icon.png         ← 開機動畫用此圖
└── pubspec.yaml
```

**重要既有依賴(在 `pubspec.yaml`):**
- `flutter_riverpod` (狀態管理)
- `google_fonts` (字體 — 已用 Fredoka, Outfit)
- `shared_preferences` (持久化)
- `firebase_*` (請勿動 firebase_options.dart)

---

## 二、五種主題 Token 規格

每個主題的完整設計值。**請在 `lib/theme/app_themes.dart` 新建一個 `AppTheme` class,放這 5 個常數。**

### Theme 1: Cartoon (預設,id='cartoon')
- 背景: linear-gradient 135° `#48CAE4` → `#0077B6`
- 卡片: `#FFFDE7` (奶黃) + 3.5px 黑邊 `#1A1A2E` + 5px 硬陰影
- 主色 (accent): `#FF8F00` 金橘
- Play 按鈕: `#FFD60A` 亮黃 + 黑邊圓形
- 字體: Fredoka (display/timer), Outfit (body)
- 圓角: 28px (卡片), 14px (chip)
- AppBar 文字: `rgba(255,255,255,0.92)` 白
- BottomNav: `#FFFDE7` 底 + `#1A1A2E` 黑邊頂線
- 計時頁標籤: "ME TIME ⏱" / 跑步時 "GO GO GO! 🎯"
- 背景泡泡: 半透明白色圓圈散佈

### Theme 2: Dark Cartoon (id='dark')
- 背景: linear-gradient 160° `#0B1020` → `#1A1A2E` → `#06070D`
- 卡片: `#1E1F36` + 3px `#F4F2E7` 白邊 + 5px `#48CAE4` 藍陰影
- 主色: `#FFD166` 暖黃
- Play 按鈕: `#FFD166` + 白邊
- 字體: Fredoka / Outfit
- 圓角同 Cartoon
- AppBar 文字: `#F4F2E7`
- BottomNav: `#0B1020` 底 + `#48CAE4` 頂線
- 標籤: "ME TIME ⏱" / "GO GO GO! 🌙"
- 計時器跑步時要有 glow halo (`accentSoft: rgba(255,209,102,0.45)` 放射 blur)
- 背景泡泡: 半透明深色圓圈

### Theme 3: Retro 卡其 (id='retro')
- 背景: 純色 `#D4C4A0` 卡其
- 卡片: `#EADFC4` + 3px 深棕邊 `#3D2F1F` + 4px 硬陰影
- 主色: `#8B4513` 棕褐 (Saddle Brown)
- Play 按鈕: `#A0522D` (Sienna) + 深棕邊 + 方角!圓角只 4px
- 字體: **Press Start 2P** (display/timer 像素字), **VT323** (body 復古等寬)
- 圓角: 4px (卡片), 2px (chip) — 幾乎方角
- BottomNav: `#8B6F3A` 深棕底 + 深棕頂線
- 標籤: "ME TIME" / "GO! GO! GO!"
- 背景: 點陣像素點 + CRT 掃描線紋理 (faint horizontal repeating-linear-gradient)
- 像素 dot 顏色: `rgba(61,47,31,0.07)`
- Heatmap/進度條也要方角,邊框 2px

### Theme 4: Pastel (id='pastel')
- 背景: linear-gradient 160° `#FFE5EC` → `#FFC9DE` → `#C8B6FF`
- 卡片: 純白 `#FFFFFF` + **無邊框** + 軟陰影 `rgba(200,150,180,0.35)` offset(0,12)
- 主色: `#FF8FA3` 蜜桃粉
- Play 按鈕: `#FFB3C6` 粉紅
- Active chip: `#C8B6FF` 紫
- 字體: **Quicksand** 全部
- 圓角: 32px (卡片大圓), 22px (chip)
- BottomNav: 半透明白 `rgba(255,255,255,0.7)` + 粉紅頂線
- 標籤: "me time" / "focus mode" (全小寫)
- 背景裝飾: 大塊放射狀粉紫色 blob (3 顆,radial-gradient)

### Theme 5: Minimal (id='minimal')
- 背景: 純色 `#FAFAF7` 米白
- 卡片: 純白 `#FFFFFF` + **無邊框、無陰影**
- 主色: `#111111` 純黑
- Play 按鈕: `#111111` 黑底 + 白 icon
- 字體: **Inter** (display/body), **JetBrains Mono** (timer 等寬)
- 圓角: 16px (卡片), 10px (chip)
- BottomNav: 純白 + 淺灰 `#EEEEEA` 頂線
- 標籤: "me time" / "focus"
- 背景: **無任何裝飾**

### 共用 Token 結構建議
```dart
class AppTheme {
  final String id;
  final String displayName;     // 中文 "卡通原版"
  final Color bgColor1, bgColor2, bgColor3; // gradient stops, 純色就只用 bgColor1
  final bool bgIsGradient;
  final Color surface;          // 卡片色
  final Color surfaceAlt;       // 嵌套淺色
  final Color ink;              // 主文字
  final Color mute;             // 次文字
  final Color accent;           // 主強調 (計時器數字)
  final Color accentSoft;       // glow 用
  final Color action;           // play 按鈕
  final Color actionInk;        // play 按鈕內 icon
  final Color active;           // 選取 chip
  final Color border;
  final double borderW;
  final Color shadowColor;
  final Offset shadowOffset;
  final double cardRadius;
  final double chipRadius;
  final String fontDisplay;     // GoogleFonts 名稱
  final String fontBody;
  final String fontTimer;
  final Color navBg;
  final Color navInk;
  final Color navBorder;
  final Color appBarInk;
  final String timerLabel;      // "ME TIME ⏱"
  final String runningLabel;    // "GO GO GO! 🎯"
  final bool timerHaloOn;       // 跑步時 glow
  final String bubbleStyle;     // 'cartoon' | 'cartoon-dark' | 'pixel' | 'pastel' | 'none'

  const AppTheme({ required this.id, ... });
}
```

---

## 三、實作步驟

### Step 1: 新增 `lib/theme/app_themes.dart`
- 定義 `AppTheme` class
- 定義 5 個 const `AppTheme cartoonTheme = AppTheme(...)` 等等
- export 一個 `Map<String, AppTheme> kAppThemes = { 'cartoon': cartoonTheme, ... }`
- 加 helper: `BoxDecoration cardDecoration(AppTheme t)`, `BoxDecoration buttonDecoration(AppTheme t)`, `BoxDecoration chipDecoration(AppTheme t, bool selected)` — 對應 `CartoonTheme` 現有 helper 介面

### Step 2: 新增 `lib/providers/app_theme_provider.dart`
```dart
final appThemeIdProvider = StateNotifierProvider<AppThemeIdNotifier, String>(...)
// 預設 'cartoon'
// 從 SharedPreferences 讀寫 key 'app_theme_id'

final currentAppThemeProvider = Provider<AppTheme>((ref) {
  final id = ref.watch(appThemeIdProvider);
  return kAppThemes[id] ?? kAppThemes['cartoon']!;
});
```

### Step 3: 重構現有頁面 — 把寫死 `CartoonTheme.xxx` 改成讀 provider
受影響檔案 (請逐一檢查並改):
- `lib/pages/home_page.dart`
- `lib/pages/statistics_page.dart`
- `lib/pages/goals_page.dart`
- `lib/pages/history_page.dart`
- `lib/pages/settings_page.dart`
- `lib/pages/main_screen.dart`
- `lib/widgets/background_wrapper.dart` ← 重要!背景漸層要跟著主題變
- `lib/widgets/category_dialogs.dart`
- `lib/widgets/goal_progress_card.dart`
- `lib/theme/cartoon_theme.dart` ← `CartoonAppBar`, `CartoonBubbles` 改成讀目前主題

**改寫原則:**
- ConsumerWidget 用 `ref.watch(currentAppThemeProvider)` 拿主題
- `CartoonTheme.skyBlue` → `t.bgColor1`
- `CartoonTheme.inkBlack` → `t.ink`
- `CartoonTheme.creamWhite` → `t.surface`
- `CartoonTheme.cardDecoration()` → 用新的 `cardDecoration(t)`
- 字體: `GoogleFonts.fredoka(...)` → `GoogleFonts.getFont(t.fontDisplay, ...)`
- **保留** `CartoonTheme` class 本身,讓舊程式碼還能跑;新程式碼用 `AppTheme`

### Step 4: 設定頁加主題選擇 UI
在 `settings_page.dart` 的 `build` 最上方 (或現有「客製化外觀」區塊上方),加一個新區塊:

```
🎨 外觀主題
[Card]
  [水平 ListView with 5 個 swatch]
  每個 swatch:
    - 72×88 圓角縮圖,顯示該主題的 bg + 一張小卡片 + 一個圓 dot
    - 標題: 中文名 (卡通原版, 深色卡通, ...)
    - 已選的有 accent border + ✓ icon
    - 點擊: ref.read(appThemeIdProvider.notifier).set(id)
  目前: <accent color> 卡通原版
[/Card]
```

視覺參考:本專案的 `Me Time Themes.html` → 點底部 nav 設定 → 最上方那塊。

### Step 5: 開機動畫 (Splash Screen)
新建 `lib/widgets/splash_screen.dart`:
- StatefulWidget,進入 `initState` 啟動 AnimationController(duration: 1900ms)
- 整體背景:讀「使用者上次選的主題」(從 SharedPreferences 同步讀,避免閃白) 的 `bg`
- 中央元素:
  - `Image.asset('assets/icon/app_icon.png')` 放在 220×220 容器
  - 用 `Tween` + `Curves.elasticOut` 從 scale 0 + rotate -25deg → scale 1.12 → scale 0.95 → scale 1.0 (1 秒內完成)
  - 完成後接 idle 上下浮動 (translateY 0 ↔ -5px,1.6s 循環)
- 外圈:
  - 兩個擴散圓環 (黃色 + 白色),從 scale 0.7 opacity 0.6 → scale 1.6 opacity 0,delay 350ms 和 650ms
- 上方火花:
  - 用 CustomPainter 或 3 個 Positioned SVG,在 850ms 後出現,200ms 內 fade in+up,然後 fade out
- 周圍泡泡:
  - 6-7 個白色小圓點 (radius 4-9px),從各邊緣外飛入再飛出,每顆 delay 不同 (950-1250ms)
  - 用 Stack + Positioned + Tween
- 動畫結束後 (約 2.0 秒) `Navigator.pushReplacement` 進 `MainScreen`

**動畫實作細節參考本專案 `lib/splash.jsx` 的 keyframes 段:**
- `splash-pop-loop`: 0% scale(0) rot(-25), 14% scale(1.12) rot(6), 25% scale(1), 之後 35%/55% translateY(-5px) 做 bob
- `splash-ring-loop`: scale 0.7→1.6, opacity 0.6→0
- `splash-spark-loop`: 上下移動 + opacity 0→1→0
- `splash-bubble-loop`: 從原點 translate 到 (ex, ey),scale 0→1,opacity 0→1→0

### Step 6: 整合 Splash 到 main.dart
- `MaterialApp.home` 改成 `SplashScreen()`,而不是直接 `MainScreen()`
- 或用 `flutter_native_splash` package 處理 native splash (圖示),再進 Flutter splash widget 做動畫
- 結束後 `Navigator.pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()))`

### Step 7: 字體
`pubspec.yaml` 不需要改 (用 google_fonts 動態下載),但需要在程式碼用:
```dart
GoogleFonts.getFont(t.fontDisplay) // 而不是 GoogleFonts.fredoka()
```
新主題用到的字體:
- Fredoka, Outfit (現有)
- Press Start 2P, VT323 (Retro)
- Quicksand (Pastel)
- Inter, JetBrains Mono (Minimal)

google_fonts 套件**全部都支援**,首次使用會自動下載並 cache。

---

## 四、Definition of Done (驗收標準)

1. ✅ App 啟動時播放 1.8 秒開機動畫 (用實際 app_icon.png),動畫結束自動進入計時頁
2. ✅ 進入設定頁,最上方看得到「🎨 外觀主題」區塊,5 個 swatch 橫向排列
3. ✅ 點任一 swatch,整個 App 立即換色 (計時頁 / 統計頁 / 目標頁 / 歷史頁 / 設定頁 / 底部 nav 全部跟著變)
4. ✅ 重啟 App,主題選擇記得 (SharedPreferences)
5. ✅ 預設主題是「Cartoon 原版」,跟現在視覺一致
6. ✅ Retro 主題真的是卡其色 (不是綠色 GameBoy),字體變像素字
7. ✅ Minimal 主題真的乾淨 (無邊框、無陰影、純黑白)
8. ✅ Dark 主題深色,計時器跑步時有 glow halo
9. ✅ Pastel 主題粉嫩、圓潤
10. ✅ 編譯通過、`flutter run` 跑得起來、沒有 deprecation warning
11. ✅ 既有功能 (計時、記錄、目標、Firebase 同步、深色模式 switch、自定義背景色) 都還能用

---

## 五、注意事項 / 雷區

- **不要修改** `lib/firebase_options.dart`
- **不要修改** `android/app/google-services.json`
- 既有的 `themeModeProvider` (light/dark) 和新的 `appThemeIdProvider` 是**不同層次的東西**,讓使用者選 Dark 主題時,可以順便把 themeMode 設成 dark,反之亦然。或乾淨點:廢棄 `themeModeProvider`,改成只看 `appThemeIdProvider`
- 既有的 `backgroundProvider` 和 `timerColorProvider` 是「使用者額外客製化的疊加」,新主題系統不要蓋掉它們,讓它們繼續工作 (覆蓋在主題上方)
- `CartoonBubbles` widget 要改成 `ThemedBubbles(theme: t)`,根據 `t.bubbleStyle` 決定畫什麼:
  - `cartoon`: 半透明白圓圈
  - `cartoon-dark`: 深色半透明圓圈
  - `pixel`: 卡其方塊 + CRT 掃描線
  - `pastel`: 粉紫 blob (RadialGradient)
  - `none`: 不畫
- 加完所有改動後,跑 `flutter analyze` 確認沒有錯誤

---

## 六、設計參考檔案

請在動工前,瀏覽器打開 `Me Time Themes.html`(本專案根目錄)實際看一下:
- 開機動畫長相
- 5 種主題的計時頁外觀
- 進入設定頁,看主題挑選器 UI

或讀本專案的 jsx 檔案找對應實作邏輯:
- `lib/themes.jsx` — 完整 5 主題 token (對照上面 Step 1)
- `lib/splash.jsx` — 開機動畫 keyframes
- `lib/bubbles.jsx` — 各主題背景裝飾
- `lib/screen-settings.jsx` — 主題挑選器 UI 結構
- `lib/home-screen.jsx`, `lib/screen-statistics.jsx` 等 — 各頁面套主題的方式

---

## 七、建議實作順序

1. 先做 **Step 1+2** (AppTheme class + provider) → flutter run 確認沒壞
2. 做 **Step 4** (設定頁 swatch UI) → 即使主題還沒生效,UI 先出來
3. 做 **Step 3** (頁面套主題) → 先改 home_page 確認可以切換,再依序改其他頁
4. 做 **Step 5+6** (Splash 動畫) — 可以最後做,獨立性最高
5. 最後 **Step 7** 跑 `flutter analyze`、實機測試

完成!
