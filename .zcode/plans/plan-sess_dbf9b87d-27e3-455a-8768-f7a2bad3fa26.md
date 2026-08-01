# CopyBubble 悬浮气泡重设计 · 实施计划

## 背景与关键判断

规格 `md/CopyBubble-Bubble-Redesign-Spec.md` 是按「项目尚无气泡」写的（§0.1 限定只能改 3 处既有文件）。但本项目**已有一套可用的旧气泡**，且与新实现**窗口名冲突**（都用 `'copy_bubble_float'`），两者无法并存。规格 §0.4 明确预见了这种情况并要求：**旧实现重命名为 `*_legacy` 保留，0 删除，不混用坐标系**。

故按 §0.4 处理旧气泡，并把规格 §5「启动气泡」落到项目实际的启动点（`SettingsPage` 的开关）。权限与 string 已存在，无需改 manifest。

> 用户未就下方三个选项作答，按推荐项执行：(1) 重命名旧气泡+重接开关；(2) 跳过 SVG；(3) 创建单测。实施时若你想改，随时打断。

---

## A. 新增 11 个 ArkTS 文件（内容全部取自规格，逐字创建）

依赖顺序创建到 `entry/src/main/ets/bubble/`（目录已存在、为空，无重名）：

1. `bubble/BubbleTokens.ets` — 设计令牌
2. `bubble/AppKeys.ets` — AppStorage 键名
3. `bubble/DockEngine.ets` — 贴边几何与状态机（核心，纯逻辑）
4. `bubble/ClipItem.ets` — 气泡内部记录模型（**注意：与项目既有 `model/ClipItem.ets` 是两个不同类**，用 BubbleAdapter 转换，不动 model 版）
5. `bubble/BubbleIcon.ets` — 叠影图形 + 计数角标
6. `bubble/ClipboardPanel.ets` — 展开面板
7. `bubble/BubbleBridge.ets` — 气泡与业务的唯一接触面
8. `bubble/FloatBubble.ets` — 气泡主组件（六态状态机）
9. `bubble/BubbleWindowManager.ets` — 悬浮窗宿主

页面（`entry/src/main/ets/pages/`，无重名）：

10. `pages/BubbleWindowPage.ets` — 悬浮窗 UI 承载页
11. `pages/BubblePreviewPage.ets` — 免权限调试页

---

## B. 处理旧气泡（遵循 §0.4，0 删除）

用 `git mv` 重命名两个旧文件（保留历史）：

- `manager/BubbleWindow.ets` → `manager/BubbleWindow_legacy.ets`（内容不变）
- `pages/BubbleFloat.ets` → `pages/BubbleFloat_legacy.ets`，并修正其内部 import：`../manager/BubbleWindow` → `../manager/BubbleWindow_legacy`

这两份旧代码作为参考保留、不再被调用。

---

## C. 修改既有文件（4 处，最小改动）

**1. `entry/src/main/resources/base/profile/main_pages.json`**
- `src` 数组移除 `"pages/BubbleFloat"`（已重命名，留着会编译报错）
- 追加 `"pages/BubbleWindowPage"`、`"pages/BubblePreviewPage"`

**2. `entry/src/main/ets/pages/SettingsPage.ets`** —— 把「桌面悬浮气泡」开关重接到新管理器（规格 §5 情况 A 的落地）
- import 改为 `BubbleWindowManager`（保留对旧类的引用仅用于权限申请）
- `setFloatBubble(v)`：
  - 关 → `await BubbleWindowManager.get().destroy()`
  - 开 → 先用既有 `BubbleWindow_legacy.requestPermission(ctx)` 走授权弹窗；拒绝则回滚开关 + toast；授权后 `await BubbleWindowManager.get().create(ctx)`，再用 `isShown()` 确认是否成功

**3. `entry/src/main/ets/entryability/EntryAbility.ets`** —— 挂接钩子（规格 §4.2）+ 修正 onDestroy
- `onWindowStageCreate` 在 `ClipStore.load()` 之后追加 `BubbleBridge.hooks = {...}`，**填实两个 TODO**（项目代码已确认）：
  - `getItems` → `ClipStore.getInstance().recent(8).map(r => BubbleAdapter.of(r.id, r.content, r.updateTime))`
  - `onPick` → `ClipboardKit.write(item.content)`
  - `onHidden` → 留空 TODO（召回入口，后续可接通知）
  - `onDockChange` → 留空实现
- `onDestroy` 里 `BubbleWindow.hide()` → `BubbleWindowManager.get().destroy()`

**4. `entry/src/main/ets/manager/ClipStore.ets`** —— 新记录写入通知气泡（规格 §4.3）
- `add()` 在真正新增成功（`added !== null` 分支）后追加 `BubbleBridge.notifyCaptured()`
- 选这里而非 UI 层，是因为 `add()` 是**唯一**收录入口，自动收录/粘贴按钮/手动输入三条路径都能覆盖，只追加一行

---

## D. 资源文件 —— 跳过（推荐项）

不拷入三个 SVG，不改 `layered_image.json`。气泡图形由 `BubbleIcon.ets` 代码绘制，不依赖图片；应用图标保持现状。

---

## E. 单元测试（推荐项，创建）

新建 `entry/src/ohosTest/ets/test/List.test.ets` 与 `DockEngine.test.ets`（规格 §7 原文，13 个断言）。`ohosTest` 目录现为空，无 `List.test.ets`，故新建入口文件并调用 `dockEngineTest()`。

---

## 不做的事

- 不改 `module.json5`（权限 `SYSTEM_FLOAT_WINDOW` 已存在）
- 不改 `string.json`（`reason_float_window` 已存在）
- 不删除任何文件（旧实现重命名保留）
- 不动 `BubbleWindowManager.ets` 的窗口名（旧管理器不再被调用，无冲突）
- 不碰规格未列出的任何文件

---

## 验收要点（实施后自查）

- 工程可编译、无 ArkTS 类型报错
- `bubble/` 目录除 `BubbleBridge.ets` 外不 import 项目业务模块
- 设置开关打开 → 新气泡出现，可拖拽吸附、休眠、展开、底部隐藏
- 复制新内容 → 气泡捕获波纹（经 ClipStore.add → notifyCaptured）
- 点面板某条 → 写回系统剪贴板（ClipboardKit.write）