import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ClipStore } from '../manager/ClipStore';
import { StorageManager } from '../manager/StorageManager';
import { BubbleWindow } from '../manager/BubbleWindow';
import { Theme, Const } from '../common/Theme';
import { SwitchRowParam, KVParam } from '../common/UiModels';

@Component
export struct SettingsPage {
  @Consume('nav') pathStack: NavPathStack;
  @StorageLink('topInset') topInset: number = 0;

  @State private autoCapture: boolean = false;
  @State private floatBubble: boolean = false;
  @State private dedupe: boolean = true;
  @State private haptic: boolean = true;
  @State private maxRecords: number = Const.DEFAULT_MAX;

  private sm: StorageManager = StorageManager.getInstance();
  private store: ClipStore = ClipStore.getInstance();

  aboutToAppear(): void {
    this.autoCapture = this.sm.getBool(Const.KEY_AUTO_CAPTURE, false);
    this.floatBubble = this.sm.getBool(Const.KEY_FLOAT_BUBBLE, false);
    this.dedupe = this.sm.getBool(Const.KEY_DEDUPE, true);
    this.haptic = this.sm.getBool(Const.KEY_HAPTIC, true);
    this.maxRecords = this.sm.getNumber(Const.KEY_MAX, Const.DEFAULT_MAX);
  }

  build() {
    NavDestination() {
      Column() {
        this.Bar()
        Scroll() {
          Column({ space: 18 }) {
            Column({ space: 0 }) {
              this.SectionTitle('收录')
              this.SwitchRow({
                title: '自动收录剪贴板',
                desc: '回到应用时把新复制的内容存下来。系统可能因隐私管控拦下这个动作，那时请用底部的「粘贴」按钮。',
                value: this.autoCapture,
                onToggle: (v: boolean) => this.setAutoCapture(v)
              })
              this.SwitchRow({
                title: '跳过重复内容',
                desc: '相同文本只保留一条，时间刷新到最新。',
                value: this.dedupe,
                onToggle: (v: boolean) => this.setBool(Const.KEY_DEDUPE, v)
              })
            }
            .width('100%')

            Column({ space: 0 }) {
              this.SectionTitle('气泡')
              this.SwitchRow({
                title: '桌面悬浮气泡',
                desc: '在其他应用之上显示一枚可拖动的气泡，随手取用最近几条。需要悬浮窗权限。',
                value: this.floatBubble,
                onToggle: (v: boolean) => this.setFloatBubble(v)
              })
              this.SwitchRow({
                title: '复制震动反馈',
                desc: '复制成功时给一次轻震动。',
                value: this.haptic,
                onToggle: (v: boolean) => this.setBool(Const.KEY_HAPTIC, v)
              })
            }
            .width('100%')

            this.SectionTitle('容量')
            this.CapacityCard()
            this.SectionTitle('数据')
            this.DataCard()

            this.SectionTitle('关于')
            this.AboutCard()
          }
          .padding({ left: Theme.PAGE_PAD, right: Theme.PAGE_PAD, bottom: 48 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.TopStart)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.PAGE_BG)
    }
    .hideTitleBar(true)
    .backgroundColor(Theme.PAGE_BG)
  }

  // ---------- UI ----------

  @Builder
  Bar() {
    Row({ space: 8 }) {
      Text('‹')
        .fontSize(28)
        .fontColor(Theme.TEXT_1)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => this.pathStack.pop())
      Text('设置')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_1)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 8, right: 12, top: this.topInset + 8, bottom: 8 })
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(Theme.TEXT_3)
      .width('100%')
      .padding({ left: 4, bottom: 8 })
  }

  @Builder
  SwitchRow($$: SwitchRowParam) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text($$.title)
          .fontSize(15)
          .fontColor(Theme.TEXT_1)
        Text($$.desc)
          .fontSize(12)
          .lineHeight(18)
          .fontColor(Theme.TEXT_2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: $$.value })
        .selectedColor(Theme.BRAND)
        .onChange((v: boolean) => $$.onToggle(v))
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(16)
    .margin({ bottom: 8 })
  }

  @Builder
  CapacityCard() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text('保留条数上限')
          .fontSize(15)
          .fontColor(Theme.TEXT_1)
        Text('超出后从最旧的非置顶记录开始清理，置顶内容永远保留。')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(Theme.TEXT_2)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Row({ space: 8 }) {
        ForEach(Const.MAX_OPTIONS, (n: number) => {
          Text(`${n}`)
            .fontSize(14)
            .fontWeight(this.maxRecords === n ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.maxRecords === n ? Color.White : Theme.TEXT_2)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 10, bottom: 10 })
            .backgroundColor(this.maxRecords === n ? Theme.BRAND : '#F2F2F8')
            .borderRadius(12)
            .onClick(() => {
              this.maxRecords = n;
              this.sm.put(Const.KEY_MAX, n);
            })
        }, (n: number) => `${n}`)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(16)
  }

  @Builder
  DataCard() {
    Column({ space: 0 }) {
      Row() {
        Text('清空非置顶记录')
          .fontSize(15)
          .fontColor(Theme.TEXT_1)
          .layoutWeight(1)
        Text('›').fontSize(18).fontColor(Theme.TEXT_3)
      }
      .width('100%')
      .padding(16)
      .onClick(() => this.confirmClear(false))

      Divider().color(Theme.DIVIDER).margin({ left: 16, right: 16 })

      Row() {
        Text('清空全部记录')
          .fontSize(15)
          .fontColor(Theme.DANGER)
          .layoutWeight(1)
        Text('›').fontSize(18).fontColor(Theme.TEXT_3)
      }
      .width('100%')
      .padding(16)
      .onClick(() => this.confirmClear(true))
    }
    .width('100%')
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(16)
  }

  @Builder
  AboutCard() {
    Column({ space: 8 }) {
      this.KV({ key: '应用', value: 'Copy Bubble 1.0.0' })
      this.KV({ key: 'Harmony API', value: '6.1.1(24)' })
      this.KV({ key: '数据存放', value: '仅在本机，不联网上传' })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(16)
  }

  @Builder
  KV($$: KVParam) {
    Row() {
      Text($$.key).fontSize(13).fontColor(Theme.TEXT_2)
      Blank()
      Text($$.value).fontSize(13).fontColor(Theme.TEXT_1)
    }
    .width('100%')
  }

  // ---------- 行为 ----------

  private setBool(key: string, v: boolean): void {
    if (key === Const.KEY_DEDUPE) {
      this.dedupe = v;
    } else if (key === Const.KEY_HAPTIC) {
      this.haptic = v;
    }
    this.sm.put(key, v);
  }

  private setAutoCapture(v: boolean): void {
    this.autoCapture = v;
    this.sm.put(Const.KEY_AUTO_CAPTURE, v);
  }

  private async setFloatBubble(v: boolean): Promise<void> {
    if (!v) {
      this.floatBubble = false;
      await this.sm.put(Const.KEY_FLOAT_BUBBLE, false);
      await BubbleWindow.hide();
      return;
    }
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const ok: boolean = await BubbleWindow.show(ctx);
    this.floatBubble = ok;
    await this.sm.put(Const.KEY_FLOAT_BUBBLE, ok);
    if (!ok) {
      promptAction.showToast({
        message: '打不开悬浮窗，需要先授予悬浮窗权限',
        duration: 2400
      });
    }
  }

  private confirmClear(all: boolean): void {
    promptAction.showDialog({
      title: all ? '清空全部记录' : '清空非置顶记录',
      message: all ? '包括置顶在内的所有内容都会消失，无法恢复。' : '置顶的内容会留下，其余全部删除。',
      buttons: [
        { text: '取消', color: Theme.TEXT_2 },
        { text: '清空', color: Theme.DANGER }
      ]
    }).then(async (res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index !== 1) {
        return;
      }
      if (all) {
        await this.store.clearAll();
        promptAction.showToast({ message: '已清空' });
      } else {
        const n: number = await this.store.clearUnpinned();
        promptAction.showToast({ message: `已删除 ${n} 条` });
      }
    });
  }
}
