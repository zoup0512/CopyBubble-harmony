# Copy Bubble

HarmonyOS NEXT 手机端剪贴板管理器。复制过的内容自动归档成一条条"气泡"，随时搜索、置顶、一键取回。

- **bundleName**：`com.razor.tools.copybubble`
- **targetSdkVersion**：`6.1.1(24)`
- **compatibleSdkVersion**：`5.0.5(17)`
- **模型**：Stage 模型 / ArkTS 声明式 UI
- **设备**：phone

## 打开工程

用 DevEco Studio（对应 HarmonyOS 6.0.2 / API 22 SDK）打开根目录，`File → Sync and Refresh Project`，然后 `Run entry`。

需要在 `build-profile.json5` 的 `signingConfigs` 里补自己的签名配置才能真机运行。

## 功能

| 模块 | 说明 |
| --- | --- |
| 收录 | 底部「粘贴」安全控件把当前剪贴板存入；也可手动新建一条 |
| 自动识别 | 链接 / 验证码 / 电话 / 邮箱 / 数字 / 地址 / 纯文本，七种类型各有色标 |
| 组织 | 置顶、搜索、按类型筛选，置顶项永不被容量清理 |
| 取回 | 卡片上一键复制；详情页可直接拨号、发邮件、浏览器打开、只取验证码数字 |
| 详情 | 查看全文、就地编辑、系统分享、删除 |
| 悬浮气泡 | 桌面级悬浮窗，点开显示最近 8 条，点一条即写回剪贴板 |
| 容量 | 10 / 50 / 100 条上限或无上限，超出时从最旧的非置顶记录开始清理 |
| 数据 | 全部存在本机 preferences，不联网 |

## 目录

```
entry/src/main/ets/
├─ entryability/EntryAbility.ets      入口，启动时初始化存储 + 沉浸式布局
├─ entrybackupability/                备份扩展
├─ model/ClipItem.ets                 数据模型、类型枚举、路由参数
├─ manager/
│  ├─ StorageManager.ets              preferences 封装
│  ├─ ClipStore.ets                   单一数据源：增删改查、去重、容量裁剪
│  ├─ ClipboardKit.ets                系统剪贴板读写 + 震动反馈
│  └─ BubbleWindow.ets                悬浮窗生命周期
├─ utils/
│  ├─ TypeDetector.ets                内容类型识别
│  └─ TimeUtil.ets                    相对时间
├─ common/
│  ├─ Theme.ets                       配色、圆角、存储键
│  └─ UiModels.ets                    @Builder 的引用型参数对象
├─ components/                        BubbleCard / SearchField / CategoryStrip / EmptyState
└─ pages/                             Index(导航) / HomeView / DetailPage / SettingsPage / BubbleFloat
```

## 两个平台限制，先说清楚

**剪贴板不能静默读取。** HarmonyOS NEXT 对后台和无用户操作的剪贴板读取有管控，`pasteboard.getData()` 在没有用户手势时会被拦下。所以主入口是 `PasteButton` 安全控件——用户点它，系统才放行读取。设置里的「自动收录」是尽力而为：应用回到前台时试一次，被拦下就安静跳过，不会弹错误。这是系统行为，不是可以绕过的实现问题。

**悬浮气泡需要 ACL 权限。** `ohos.permission.SYSTEM_FLOAT_WINDOW` 属于受限权限，要在 AGC 申请签名授权，未授权时 `window.createWindow` 会失败。`SettingsPage` 里的开关拿到失败结果会自动回滚成关闭并提示，不会留下一个开着但没生效的假状态。

## 设计说明

每条记录做成对话气泡的形状——左下角收成 6vp 尖角，其余三角 20vp，像剪贴板在跟你说话。左侧 4vp 竖条按内容类型着色（链接青、验证码紫、电话琥珀、邮箱品红……），滚动时不读字也能分辨种类。主色靛蓝 `#4C5BD4`，页面底色 `#F3F4FB`。

## ArkTS 上踩过的几个点

- `@Builder` 的参数必须整体打成对象传（见 `common/UiModels.ets`），按值传的 `boolean` / `string` 不会触发 builder 内部重渲染——设置页的开关就是这么写坏过的。
- `navDestination` 的 param 类型是 `object`，不能直接塞字符串，所以有 `NavParam`。
- `TextInput` / `TextArea` 的 `text` 要用 `$$this.x` 双向绑定，否则代码里清空输入框，UI 上不会跟着清。
- 子组件里会随父组件变化的成员必须是 `@Prop` / `@Link`，无装饰器的成员只在构造时赋值一次。
