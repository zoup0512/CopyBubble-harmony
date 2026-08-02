# 增加剪贴板读取权限 + 授权后自动收录

## 设计决策（基于你的选择：权限独立，授予即自动收录）

权限申请与「自动收录」开关**解耦**：
- 首次冷启动时自动申请一次 `READ_PASTEBOARD` 权限（用偏好位避免反复弹窗）
- 授权后，**每次回到前台**都自动收录剪贴板（不再受 `KEY_AUTO_CAPTURE` 开关控制）
- 拒绝后不骚扰；用户日后可在「系统设置 > 隐私与安全」补授权，下次回前台即被 `hasPermission()` 检测到并恢复自动收录
- `PasteButton` 安全控件路径保留不变，作为兜底

> **由此连带移除「自动收录剪贴板」开关**：该开关此前因没申请权限而被系统静默拦截、从未真正生效；新行为下它已无作用，保留只会让用户困惑（开关开着却不收录 / 关着却收录）。移除后唯一真相源是「是否授权」。

---

## 改动清单

### 1. `entry/src/main/module.json5` — 声明权限
在 `requestPermissions` 末尾新增第 4 项：
```json5
{
  "name": "ohos.permission.READ_PASTEBOARD",
  "reason": "$string:reason_read_clipboard",
  "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
}
```

### 2. 三个 `string.json` — 新增权限说明
`base`/`en_US`: `"reason_read_clipboard"` → `"Read the system clipboard to capture copied content"`
`zh_CN`: → `"读取系统剪贴板，收录复制的内容"`

### 3. `manager/ClipboardKit.ets` — 新增权限方法（核心）
导入 `abilityAccessCtrl, bundleManager, common, Permissions`（来自 `@kit.AbilityKit`），镜像 `BubbleWindow_legacy.ets:56-89` 的成熟模式，新增：
- `private static readonly PERM: Permissions = 'ohos.permission.READ_PASTEBOARD'`
- `static hasPermission(): boolean` — 用 `checkAccessTokenSync` 同步判定（给 HomeView 前台门控用）
- `static async requestPermission(ctx): Promise<boolean>` — 已授权直接返回 true，否则拉起 `requestPermissionsFromUser`，全程 try/catch 兜底

> 放在 ClipboardKit 而非新文件：该类职责就是「系统剪贴板封装」，权限是其一部分，内聚更佳。

### 4. `entryability/EntryAbility.ets` — 冷启动申请一次
在 `onWindowStageCreate` 的 `loadContent` 回调里、`restoreBubbleIfNeeded()` 之后调用新方法 `ensureClipboardPermission()`：
- 读 `KEY_CLIP_PERM_PROMPTED`（默认 false）；已申请过则直接返回（避免每次冷启动弹窗骚扰）
- 否则置位为 true，调用 `ClipboardKit.requestPermission(this.context)`
- **不在 EntryAbility 里做一次性收录**：冷启动时 `onForeground` 会在 `onWindowStageCreate` 之后触发，只要此时已授权，现有的 `foregroundTick → HomeView.onAppForeground` 路径就会自然收录，无需重复代码

### 5. `pages/HomeView.ets` — 收录门控换条件（核心）
`captureIfEnabled()`（行 113-126）：把
```ts
const on = StorageManager.getInstance().getBool(Const.KEY_AUTO_CAPTURE, false);
if (!on) return;
```
改为
```ts
if (!ClipboardKit.hasPermission()) return;
```
其余（read + store.add + toast）不变。这样：授权后每次回前台/剪贴板变化都收录；未授权则静默跳过。

### 6. `pages/SettingsPage.ets` — 移除冗余开关
- 删除 `@State autoCapture`（行 17）
- 删除 `aboutToAppear` 中读 `KEY_AUTO_CAPTURE`（行 29）
- 删除「收录」分组里的 `auto_capture` SwitchRow（行 45-50）
- 删除 `setAutoCapture()` 方法（行 264-267）
- 保留「跳过重复内容」开关，所以「收录」SectionTitle 仍保留

### 7. `common/I18n.ets` — 清理废弃 key
从 `ZH` 和 `EN` 两张表删除 `auto_capture_title`、`auto_capture_desc`（已无引用）。其他文案不变。

### 8. `common/Theme.ets`（Const 类）— 新增偏好键
```ts
static readonly KEY_CLIP_PERM_PROMPTED: string = 'clip_perm_prompted';
```
（可顺便删除不再使用的 `KEY_AUTO_CAPTURE`，但保留它无害、且能兼容老版本用户的历史偏好；选择保留。）

---

## 不改动的部分
- `ClipboardKit.read()` 的 try/catch 静默兜底保留（双保险）
- `HomeView.captureFromButton()`（PasteButton 路径）不变——安全控件自带临时授权，不需要 READ_PASTEBOARD
- `ClipboardKit.observe()`（剪贴板变化监听）不变——它只触发 `captureIfEnabled`，门控已由 hasPermission 接管

---

## 验证方式
由于项目需 DevEco Studio 构建，改动完成后建议你：
1. 在 DevEco 里 Build > Build HAP(s) 确认编译通过（ArkTS 类型严格，新增的 import 和权限常量需过检）
2. 真机/模拟器跑：首次启动应弹剪贴板授权窗 → 授权 → 复制一段文字 → 切到后台再回前台 → 应自动出现新条目
3. 拒绝授权 → 底部「粘贴」按钮仍可手动收录
4. 设置页「收录」分组只剩「跳过重复内容」一项

> 说明：`READ_PASTEBOARD` 在 HarmonyOS NEXT 属受限权限，发布前可能需在 AGC 申请授权；这是上架流程事项，不影响代码正确性。本机无 hvigorw 编译环境，故不执行命令行编译检查。