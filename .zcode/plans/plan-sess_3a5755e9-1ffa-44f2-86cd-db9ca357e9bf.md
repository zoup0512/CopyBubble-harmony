## 目标
在悬浮球展开面板的 header 右侧加一个**开关(Toggle)**,打开面板时是 ON 状态,点一下变 OFF 即**彻底关闭**悬浮球(销毁双窗口 + 持久化关闭状态,等同于设置里关掉开关)。

## 关键设计决策
- **组件**:用 ArkUI 原生 `Toggle(ToggleType.Switch, true)`(初始 ON)。点击 → OFF → 触发回调 → 窗口销毁,开关从 ON 滑到 OFF 的瞬间窗口消失,动效自然。
- **位置**:header Row 右侧,紧挨现有「N 条」计数文本。开关小巧,header(高 30vp)放得下。
- **关闭语义 = 彻底关闭**:`destroy()` + `KEY_FLOAT_BUBBLE=false`(保持设置页状态一致)。
- **走 hook 链路保持 bubble/ 隔离**:沿用现有 `onPick`/`onHidden` 回调模式,新增 `onClose` hook。
- **不动几何**:开关挤进现有 header 内,不增加面板高度,`DockEngine.panelAnchor` 无需改。

## 逐文件改动

### 1. `bubble/ClipboardPanel.ets`
- header Row(78-92 行)右侧:在「N 条」文本后加 `Toggle({ type: ToggleType.Switch, isOn: true })`,挂 `.onChange((isOn) => { if (!isOn) this.onClose(); })`。用 `.scale` 缩到适配 30vp header 的尺寸(约 0.7)。开关默认 ON,点一下转 OFF 即触发。
- 新增回调属性 `onClose: () => void = () => {}`(与现有 `onPick`/`onClear` 同模式)
- 头部注释(5-6 行)从「刻意不放关闭按钮」改为说明:面板内提供开关用于彻底关闭悬浮球(开关是刻意手势,降低误触)

### 2. `bubble/FloatBubble.ets`
- 新增回调属性 `onClose: () => void = () => {}`(挨现有 `onHidden`,62 行附近)
- `ClipboardPanel({...})`(369 行)里加 `onClose: () => { this.onClose(); }`
- 第 361 行注释更新为同样的说明

### 3. `bubble/BubbleBridge.ets`
- `BubbleHooks` 接口加 `onClose: () => void`
- `DefaultHooks` 加空实现 `onClose(): void {}`

### 4. `entryability/EntryAbility.ets`
- hooks 对象(37-53 行)加 `onClose: (): void => { StorageManager.getInstance().put(Const.KEY_FLOAT_BUBBLE, false); }`(StorageManager/Const 已 import)

### 5. `pages/BubbleWindowPage.ets`
- `FloatBubble({...})`(73-93 行)加 `onClose: () => { this.mgr.destroy(); BubbleBridge.hooks.onClose(); }`(destroy 走已有 `this.mgr`,持久化走 hook)

## 不改 / 不碰
- 不新增令牌(开关用原生 Toggle,不引入新尺寸/颜色)
- 不动 DockEngine 几何(开关不增加面板高度)
- 不动 dismiss zone、休眠、双窗口移动逻辑
- 复用 `Const.KEY_FLOAT_BUBBLE`,不新增持久化 key

## 验证(你跑)
展开面板 → header 右侧看到 ON 开关 → 点一下开关转 OFF → 球消失 → 重进设置页开关显示关闭。重点:① 开关不被裁切、尺寸协调 ② 点非开关区域仍是收起面板(不误触发关闭)。