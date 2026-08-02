## 目标

在剪贴板列表里植入一条「简短使用说明」，归类为**文本**，并**置顶**。因数据只存在用户设备本地偏好（key `clip_items`），无法从开发机直接写入，唯一可行的做法是让 App 在首次启动时自播种（seed）一次。

## 改动文件（4 个，均贴合现有模式）

### 1. `entry/src/main/ets/common/I18n.ets`
在 ZH / EN 两个 Map 各新增 2 个 key：
- `source_help` → `'内置'` / `'Built-in'`（作为这条记录的来源标签）
- `help_guide` → 简短使用说明正文（6 行左右）。用反引号模板串保持可读多行，例如：

中文：
```
随手贴 · 使用说明

1. 复制任意文本，回到这里会自动收录
2. 点击卡片即可复制回剪贴板
3. 长按可置顶常用内容，置顶内容不会被清空
4. 顶部可按类型筛选（链接 / 验证码 / 电话 / 邮箱 / 文本）
5. 在「设置」开启桌面悬浮气泡，可在其他应用上方随手取用最近几条
6. 所有数据仅保存在本机，不会上传
```

英文等价版本。

### 2. `entry/src/main/ets/common/Theme.ets`
在 `Const` 类加一行：
```ts
static readonly KEY_HELP_SEEDED: string = 'help_seeded';
```
（沿用 `KEY_CLIP_PERM_PROMPTED` / `KEY_FEEDBACK_DONE` 这类一次性偏好位命名风格）

### 3. `entry/src/main/ets/manager/ClipStore.ets`
新增方法（放在 `load()` 之后或业务区）：
```ts
/** 首次启动植入一条内置使用说明，归类文本并置顶；只播种一次 */
async seedHelp(): Promise<void> {
  const sm = StorageManager.getInstance();
  if (sm.getBool(Const.KEY_HELP_SEEDED, false)) return;
  const item = new ClipItem(I18n.t('help_guide'), ClipType.TEXT, I18n.t('source_help'));
  item.pinned = true;            // 构造函数不带 pinned，需后置赋值
  this.items.unshift(item);
  this.sort();
  await this.persist();
  await sm.put(Const.KEY_HELP_SEEDED, true);
  this.emit();
}
```
- 用偏好位保证幂等（不会每次启动重复插入）。
- `sort()` 自动把置顶项排到最前。
- 用户若手动删除或「清空全部」，条目消失后**不会**再自动回来——尊重用户操作（与现有 `clearAll`/`remove` 行为一致）。

### 4. `entry/src/main/ets/entryability/EntryAbility.ets`
在 `onWindowStageCreate` 的 bootstrap 段，紧跟 `ClipStore.getInstance().load()` 之后加一行：
```ts
await ClipStore.getInstance().seedHelp();
```
此时 `I18n.init()` 已在 `onCreate()` 跑过，文案会按当前系统语言落地。

## 验证

由于无法在此环境跑真机，我会用 hvigorw 做一次 ArkTS 编译检查（按 AGENTS.md 给出的 `DEVECO_SDK_HOME` 设置方式），确认无类型/语法错误。

## 设计取舍说明

- **语言固定 vs 跟随系统**：按项目既有约定「source 在收录时存当时的本地化文案」，这条说明会在首次启动时按当时的系统语言固化（zh→中文、en→英文）。后续切语言不回填，与历史数据行为一致。
- **删除后是否重生**：不重生。偏好位 `help_seeded` 一次性置 true，用户删了就尊重删除。这符合 App「数据由用户掌控」的整体风格。