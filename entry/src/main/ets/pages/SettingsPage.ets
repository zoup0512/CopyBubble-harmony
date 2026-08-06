import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ClipStore } from '../manager/ClipStore';
import { StorageManager } from '../manager/StorageManager';
import { BubbleWindow as BubbleWindowLegacy } from '../manager/BubbleWindow_legacy';
import { BubbleWindowManager } from '../bubble/BubbleWindowManager';
import { Theme, Const } from '../common/Theme';
import { KVParam } from '../common/UiModels';
import { SwitchRow } from '../components/SwitchRow';
import { AppKeys } from '../bubble/AppKeys';
import { I18n } from '../common/I18n';

@Component
export struct SettingsPage {
  @Consume('nav') pathStack: NavPathStack;
  @StorageLink('topInset') topInset: number = 0;

  // @StorageLink 绑 AppKeys.BUBBLE_RUNNING：气泡内拨开关关闭时写 AppStorage，
  // 设置页能实时收到 OFF；落盘值在 aboutToAppear 里灌进 AppStorage 作为初值。
  @StorageLink(AppKeys.BUBBLE_RUNNING) floatBubble: boolean = false;
  // 系统深浅色切换时重绘（Theme 色板按此取色）
  @StorageProp(Theme.KEY_DARK_MODE) darkMode: boolean = false;
  @State private dedupe: boolean = true;
  @State private haptic: boolean = true;
  @State private maxRecords: number = Const.DEFAULT_MAX;

  private sm: StorageManager = StorageManager.getInstance();
  private store: ClipStore = ClipStore.getInstance();

  aboutToAppear(): void {
    // 落盘值是唯一真相源：每次进设置页用偏好值刷新 AppStorage，覆盖上次进程残留。
    this.floatBubble = this.sm.getBool(Const.KEY_FLOAT_BUBBLE, true);
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
              this.SectionTitle(I18n.t('section_capture'))
              SwitchRow({
                title: I18n.t('dedupe_title'),
                desc: I18n.t('dedupe_desc'),
                value: this.dedupe,
                onChange: (v: boolean) => this.setBool(Const.KEY_DEDUPE, v)
              })
            }
            .width('100%')

            Column({ space: 0 }) {
              this.SectionTitle(I18n.t('section_bubble'))
              SwitchRow({
                title: I18n.t('float_bubble_title'),
                desc: I18n.t('float_bubble_desc'),
                value: this.floatBubble,
                onChange: (v: boolean) => this.setFloatBubble(v)
              })
              SwitchRow({
                title: I18n.t('haptic_title'),
                desc: I18n.t('haptic_desc'),
                value: this.haptic,
                onChange: (v: boolean) => this.setBool(Const.KEY_HAPTIC, v)
              })
            }
            .width('100%')

            this.SectionTitle(I18n.t('section_capacity'))
            this.CapacityCard()
            this.SectionTitle(I18n.t('section_data'))
            this.DataCard()

            this.SectionTitle(I18n.t('section_about'))
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
      Text(I18n.t('settings_title'))
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
  CapacityCard() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text(I18n.t('max_records_title'))
          .fontSize(15)
          .fontColor(Theme.TEXT_1)
        Text(I18n.t('max_records_desc'))
          .fontSize(12)
          .lineHeight(18)
          .fontColor(Theme.TEXT_2)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Row({ space: 8 }) {
        ForEach(Const.MAX_OPTIONS, (n: number) => {
          Text(n === Const.MAX_UNLIMITED ? I18n.t('unlimited') : `${n}`)
            .fontSize(14)
            .fontWeight(this.maxRecords === n ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.maxRecords === n ? Color.White : Theme.TEXT_2)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 10, bottom: 10 })
            .backgroundColor(this.maxRecords === n ? Theme.BRAND : Theme.CHIP_UNSEL_BG)
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
        Text(I18n.t('clear_unpinned'))
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
        Text(I18n.t('clear_all'))
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
      this.KV({ key: I18n.t('about_app'), value: `${I18n.t('app_name')} 1.0.0` })
      this.KV({ key: 'Harmony API', value: '6.1.0(23)' })
      this.KV({ key: I18n.t('about_storage'), value: I18n.t('about_storage_value') })
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

  private async setFloatBubble(v: boolean): Promise<void> {
    console.info(`CopyBubble/Settings setFloatBubble v=${v}`);
    if (!v) {
      this.floatBubble = false;
      await this.sm.put(Const.KEY_FLOAT_BUBBLE, false);
      await BubbleWindowManager.get().destroy();
      return;
    }
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    // SYSTEM_FLOAT_WINDOW 是受限权限，未授权时 createWindow 会被系统拦下。
    // 复用旧管理器的授权弹窗，拿到权限后再交给新管理器创建窗口。
    const granted: boolean = await BubbleWindowLegacy.requestPermission(ctx);
    console.info(`CopyBubble/Settings permission granted=${granted}`);
    if (!granted) {
      this.floatBubble = false;
      await this.sm.put(Const.KEY_FLOAT_BUBBLE, false);
      promptAction.showToast({
        message: I18n.t('float_permission_denied'),
        duration: 2400
      });
      return;
    }
    await BubbleWindowManager.get().create(ctx);
    const ok: boolean = BubbleWindowManager.get().isShown();
    console.info(`CopyBubble/Settings create done isShown=${ok}`);
    this.floatBubble = ok;
    await this.sm.put(Const.KEY_FLOAT_BUBBLE, ok);
    if (!ok) {
      promptAction.showToast({
        message: I18n.t('float_permission_denied'),
        duration: 2400
      });
    }
  }

  private confirmClear(all: boolean): void {
    promptAction.showDialog({
      title: all ? I18n.t('clear_all') : I18n.t('clear_unpinned'),
      message: all ? I18n.t('clear_all_msg') : I18n.t('clear_unpinned_msg'),
      buttons: [
        { text: I18n.t('btn_cancel'), color: Theme.TEXT_2 },
        { text: I18n.t('btn_clear'), color: Theme.DANGER }
      ]
    }).then(async (res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index !== 1) {
        return;
      }
      if (all) {
        await this.store.clearAll();
        promptAction.showToast({ message: I18n.t('toast_cleared') });
      } else {
        const n: number = await this.store.clearUnpinned();
        promptAction.showToast({ message: I18n.f('toast_deleted_n', `${n}`) });
      }
    });
  }
}
