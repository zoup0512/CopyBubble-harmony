# Copy Bubble / 随手贴

HarmonyOS 剪贴板管理器。把每次复制的内容归档成一条条「气泡」，可搜索、置顶、按类型筛选、一键取回；另带一枚可在其他应用之上拖动的悬浮气泡，随手取用最近几条。

- **bundleName**：`com.razor.tools.copybubble`
- **版本**：1.0.0（versionCode `1000000`）
- **SDK**：compile / target / compatible 均为 `6.1.0(23)`（HarmonyOS 6.1）
- **模型**：Stage 模型 / ArkTS 声明式 UI
- **设备**：phone
- **License**：Apache-2.0

## 构建

工程通常在 **DevEco Studio 6.1+** 里打开根目录，`File → Sync and Refresh Project`，然后 `Run entry` 或 `Build > Build HAP(s)`。`build-profile.json5` 已带一份 debug 签名配置，真机运行前换成自己的签名即可。

命令行做一次编译检查（不开 IDE 验证 ArkTS 改动）可以用 DevEco 自带的 hvigorw，但必须显式设 `DEVECO_SDK_HOME`，否则报 `00303217 Configuration Error`：

```powershell
$env:DEVECO_SDK_HOME = "C:\Program Files\Huawei\DevEco Studio\sdk"
& "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" assembleHap --no-daemon
```

hvigor 把真正的错误文本写到 stderr，PowerShell 会截断——用 `cmd /c "... > log 2>&1"` 重定向后读 log 才能看到失败原因。

## 权限

`entry/src/main/module.json5` 声明了四项运行时权限：

| 权限 | 类型 | 用途 |
| --- | --- | --- |
| `ohos.permission.SYSTEM_FLOAT_WINDOW` | 受限（需 AGC ACL 授权） | 悬浮气泡窗口 |
| `ohos.permission.READ_PASTEBOARD` | user_grant | 读取系统剪贴板（自动收录） |
| `ohos.permission.VIBRATE` | inuse | 复制成功时的轻震动反馈 |
| `ohos.permission.KEEP_BACKGROUND_RUNNING` | inuse | 后台保活 |

另含一个 `EntryBackupAbility`（backup 扩展），用于系统备份/恢复本应用数据。

## 功能

### 收录
- **底部「粘贴」安全控件**（`PasteButton`）是主入口：点击即视为系统临时授权，读取当前剪贴板并存入。
- **自动收录**：已获 `READ_PASTEBOARD` 权限时，应用回到前台（`onForeground`）会静默试读一次剪贴板；被系统拦下就安静跳过，不弹错误。
- **手动新建**：底部「＋」打开输入面板，粘贴或键入内容保存。
- **去重**：默认开启，相同文本只保留一条并把时间刷新到最新；可在设置里关掉。

### 识别与组织
- **七种内容类型**自动识别（`TypeDetector`，按「越具体越优先」匹配）：链接 / 邮箱 / 电话（国内+国际）/ 验证码（纯数字或带「验证码/校验码/OTP」上下文）/ 数字 / 地址 / 纯文本。
- **分类筛选**：顶部横向芯片条，按类型 + 置顶过滤，每个分类带实时计数。
- **搜索**：全文关键词搜索，与分类可叠加。
- **置顶**：置顶项永远排在最前，且不受容量清理影响。
- **左滑删除**：列表项左滑露出删除按钮。

### 取回与详情
- **卡片一键复制**：写回系统剪贴板，记录使用次数 +1，触发轻震动。
- **详情页**按类型提供快捷动作：
  - 链接 → 浏览器打开（`ohos.want.action.viewData`）
  - 电话 → 拨号（`tel:`）
  - 邮箱 → 写邮件（`mailto:`）
  - 验证码 → 只复制其中的数字串
  - 任意类型 → 系统分享面板（`systemShare.ShareController`）
  - 全文可就地编辑、删除（带二次确认）。

### 悬浮气泡
桌面级悬浮窗，在其他应用之上显示一枚可拖动的气泡：

- **双窗口架构**（`BubbleWindowManager`）：
  - **视觉层**（`copy_bubble_view`）：全屏、不可触摸、不可聚焦，渲染气泡外观、面板、波纹。`setWindowTouchable(false)` 让触摸整窗穿透到下层 app，全屏也不挡下层；永不 resize → 永不闪。
  - **交互层**（`copy_bubble_touch`）：144×144、可触摸的透明手势热区，承载 `PanGesture` / `TapGesture`。只 `moveWindowTo` 跟随气泡（不 resize）→ 不闪；只挡气泡那块，下层 app 在气泡之外完全可点。
  - 两个窗口是独立 UI 实例，只能靠 `AppStorage` 通信（键名集中在 `AppKeys`）。
- **五态状态机**（`DockEngine` + `FloatBubble`）：`Free`（拖拽中）→ `Snapping`（弹簧归位）→ `Docked`（贴边常驻，露出 71%）→ `Expanded`（展开面板）→ `Hidden`（拖进底部吸入区隐藏）。
- **贴边逻辑**：只吸左右两条边（顶部状态栏/胶囊、底部手势导航条不贴），吸附判定用气泡中心点而非边界，避免边缘横跳。
- **面板**（`ClipboardPanel`）：展开后显示最近 8 条记录，每条带类型标签 + 单行预览 + 相对时间；点一条即写回剪贴板。面板配色跟随下层应用深浅（`BubbleBridge.setDarkHost`）。面板 header 右侧的开关用于彻底关闭悬浮球。
- **捕获波纹**：`ClipStore.add` 真正新增时会调 `BubbleBridge.notifyCaptured()`，气泡跑一次扩散波纹动画并唤醒。
- **键盘避让**：输入法弹起时压缩可用高度，气泡被钳到键盘上方。
- **停靠位置记忆**：上次停靠侧（L/R）和纵向位置持久化在 `AppStorage`，下次恢复。
- **生命周期**：冷启动按落盘偏好自动重建（`restoreBubbleIfNeeded`）；设置页开关、面板内开关均可关闭；权限被拒时自动回滚成关闭并保持偏好与实际状态一致。

### 容量与数据
- **容量上限**：10 / 50 / 100 条或无上限，超出时从最旧的非置顶记录开始清理，置顶内容永远保留。
- **清空**：可单独清空非置顶记录，或清空全部（含置顶，带二次确认）。
- **存储**：全部数据存在本机 `preferences`（`copy_bubble_store`），不联网上传。

### 评分引导
累计启动达到 3 次（`FEEDBACK_LAUNCH_THRESHOLD`）且未评价过时，弹出评分引导弹窗，跳转应用市场详情页。**debug 构建下不弹**（通过 `ApplicationInfo.debug` 判定）。

## 目录结构

```
entry/src/main/ets/
├─ entryability/EntryAbility.ets        入口：初始化存储/剪贴板权限/沉浸式布局/气泡恢复
├─ entrybackupability/                  系统备份扩展
├─ model/ClipItem.ets                   数据模型、ClipType 枚举、分类列表、NavParam
├─ manager/
│  ├─ ClipStore.ets                     单一数据源：增删改查、去重、容量裁剪、订阅刷新
│  ├─ ClipboardKit.ets                  系统剪贴板读写、权限申请、震动反馈、变化监听
│  ├─ StorageManager.ets                preferences 薄封装（单例）
│  └─ BubbleWindow_legacy.ets           旧版悬浮窗，现仅保留 requestPermission 助手
├─ bubble/                              悬浮气泡系统（不 import 业务模块，数据走 BubbleBridge）
│  ├─ FloatBubble.ets                   气泡主组件 + 五态状态机
│  ├─ ClipboardPanel.ets                展开后的剪贴板面板
│  ├─ DockEngine.ets                    贴边几何与状态机（纯逻辑，可单测）
│  ├─ BubbleWindowManager.ets           双窗口宿主（视觉层 + 交互层）
│  ├─ BubbleBridge.ets                  气泡与业务的唯一接触面（hooks）
│  ├─ BubbleIcon.ets                    「叠影」图形 + 计数角标
│  ├─ BubbleTokens.ets                  设计令牌（尺寸/色彩/圆角/动效）
│  ├─ ClipItem.ets                      气泡内简化模型（Code/Link/Text 三档）
│  └─ AppKeys.ets                       AppStorage 跨窗口通信键名
├─ components/
│  ├─ BubbleCard.ets                    对话气泡造型卡片
│  ├─ CategoryStrip.ets                 横向分类芯片条
│  ├─ SearchField.ets                   搜索输入框
│  ├─ EmptyState.ets                    空状态占位
│  └─ FeedbackDialog.ets                评分引导弹窗
├─ pages/
│  ├─ Index.ets                         @Entry，Navigation 宿主
│  ├─ HomeView.ets                      首页：列表/搜索/分类/操作坞/评分弹窗
│  ├─ DetailPage.ets                    详情：元信息/编辑/快捷动作/分享/删除
│  ├─ SettingsPage.ets                  设置：收录/气泡/容量/数据/关于
│  ├─ BubbleWindowPage.ets              悬浮窗视觉层 UI
│  └─ BubbleTouchPage.ets               悬浮窗交互层 UI（手势 + 气泡外观）
├─ common/
│  ├─ Theme.ets                         配色、类型样式、存储键与常量
│  ├─ I18n.ets                          中英文双表，t()/f() 取文案
│  └─ UiModels.ets                      @Builder 引用型参数对象
└─ utils/
   ├─ TypeDetector.ets                  内容类型识别 + 链接/验证码抽取
   └─ TimeUtil.ets                      相对时间与完整时间格式化
```

注册的页面（`main_pages.json`）：`pages/Index`、`pages/BubbleWindowPage`、`pages/BubbleTouchPage`。

## 国际化

- 应用名：**随手贴**（zh）/ **Copy Bubble**（en），由 `AppScope/resources/{base,zh_CN}/element/string.json` 配置。
- 所有 UI 文案走 `common/I18n.ets`：`I18n.t('key')` 取纯文本，`I18n.f('key', arg0, arg1)` 填 `{0}` `{1}` 占位符。
- `I18n.init()` 在 `EntryAbility.onCreate()` 调用，通过 `@kit.LocalizationKit` 检测系统语言；找不到 key 时原样返回 key。
- 系统级文案（权限理由、Ability 标签）用 `entry/src/main/resources/{base,zh_CN,en_US}/element/string.json`，`base` 为英文兜底。
- 记录的 `source` 字段在收录时存当时语言的本地化字符串，旧数据保留原语言。

## 设计说明

- **卡片造型**：对话气泡形状——左下角收成 6vp 尖角，其余三角 20vp，像剪贴板在跟你说话。左侧 4vp 竖条按内容类型着色，滚动时不读字也能分辨种类。
- **类型色相**：文本靛蓝 `#4C5BD4`、链接青 `#0F9D8F`、电话琥珀 `#D97706`、邮箱品红 `#DB2777`、验证码紫 `#7A5CE8`、数字蓝 `#2563EB`、地址绿 `#059669`。主色靛蓝，页面底色 `#F3F4FB`。
- **气泡图形**：「叠影」——描边那张是原文，实心那张是刚被拷出来的副本，用 ArkUI 原生绘制（非 SVG）以便单独对原文层做透明度动画。

## 两个平台限制

**剪贴板不能静默读取。** HarmonyOS 对后台和无用户操作的剪贴板读取有管控，`pasteboard.getData()` 在没有用户手势时会被拦下。所以主入口是 `PasteButton` 安全控件——用户点它，系统才放行读取。设置里的「自动收录」是尽力而为：应用回到前台时试一次，被拦下就安静跳过。这是系统行为，不是可以绕过的实现问题。

**悬浮气泡需要 ACL 权限。** `ohos.permission.SYSTEM_FLOAT_WINDOW` 属于受限权限，要在 AGC 申请签名授权，未授权时 `window.createWindow` 会失败。设置页的开关拿到失败结果会自动回滚成关闭并提示，不会留下一个开着但没生效的假状态。

## ArkTS 上踩过的几个点

- `@Builder` 的参数必须整体打成对象传（见 `common/UiModels.ets`），按值传的 `boolean` / `string` 不会触发 builder 内部重渲染——设置页的开关就是这么写坏过的。
- `navDestination` 的 param 类型是 `object`，不能直接塞字符串，所以有 `NavParam`。
- `TextInput` / `TextArea` 的 `text` 要用 `$$this.x` 双向绑定，否则代码里清空输入框，UI 上不会跟着清。
- `@Observed` 只能感知一级属性的赋值，无法感知 `Map.set()` 这类内部改动——`CategoryCounts` 刷新计数时必须整体换新实例赋给 `@State`，否则分类芯片上的数字会卡住。
- 子组件里会随父组件变化的成员必须是 `@Prop` / `@Link` / `@ObjectLink`，无装饰器的成员只在构造时赋值一次。

## 测试

`entry/src/ohosTest/` 下有基于 `@ohos/hypium` 的单元测试，覆盖 `DockEngine`（贴边几何/状态机纯逻辑）等模块。
