# Copy Bubble / 随手贴 — HarmonyOS

Clipboard manager with a draggable floating bubble. Built with ArkTS/ArkUI for HarmonyOS.

## Build

This project is built inside **DevEco Studio** (6.1+). No command-line build wrapper (hvigorw) is committed; open the project in DevEco Studio and use Build > Build HAP(s).

- SDK: HarmonyOS 6.1.1(24)
- `build-profile.json5` contains signing config (debug)

## Internationalization

- App name: **随手贴** (zh) / **Copy Bubble** (en), configured via `AppScope/resources/{base,zh_CN}/element/string.json`
- All UI strings go through `common/I18n.ets` — call `I18n.t('key')` for plain strings, `I18n.f('key', arg0, arg1)` for `{0}` `{1}` placeholders
- `I18n.init()` is called in `EntryAbility.onCreate()` to detect system locale via `@kit.LocalizationKit`
- System-facing strings (permission reasons, ability labels) use resource files in `entry/src/main/resources/{base,zh_CN,en_US}/element/string.json`
- `base` = English fallback, `zh_CN` = Chinese, `en_US` = English

## Architecture

- `pages/` — Index (Navigation host), HomeView, DetailPage, SettingsPage, BubbleWindowPage, BubbleTouchPage, BubblePreviewPage
- `bubble/` — Floating bubble system (FloatBubble, ClipboardPanel, DockEngine, BubbleWindowManager, BubbleBridge)
- `components/` — BubbleCard, CategoryStrip, EmptyState, SearchField
- `manager/` — ClipStore (data), ClipboardKit (system clipboard), StorageManager (preferences)
- `common/` — Theme (colors/type styles), I18n (translations), UiModels
- `model/ClipItem.ets` — data model + `getCategories()` (i18n-aware category list)
- `utils/` — TimeUtil (relative time), TypeDetector (content type detection)

## Key patterns

- `getCategories()` returns categories with labels resolved via I18n; call after `I18n.init()`
- `Theme.styleOf(type)` resolves type labels via I18n at call time (not at static init)
- Item `source` field stores the localized string at capture time (old data keeps its original language)
