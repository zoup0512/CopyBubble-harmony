import { bundleManager, common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ClipItem, Category, getCategories, NavParam } from '../model/ClipItem';
import { ClipStore, StoreStats } from '../manager/ClipStore';
import { ClipboardKit } from '../manager/ClipboardKit';
import { StorageManager } from '../manager/StorageManager';
import { Theme, Const } from '../common/Theme';
import { BubbleCard } from '../components/BubbleCard';
import { SearchField } from '../components/SearchField';
import { CategoryStrip } from '../components/CategoryStrip';
import { EmptyState } from '../components/EmptyState';
import { FeedbackDialog } from '../components/FeedbackDialog';
import { CategoryCounts } from '../common/UiModels';
import { I18n } from '../common/I18n';

const TAG: string = 'CopyBubble/Home';
const DOMAIN: number = 0x1001;

@Component
export struct HomeView {
  @Consume('nav') pathStack: NavPathStack;
  @StorageLink('foregroundTick') @Watch('onAppForeground') tick: number = 0;
  @StorageLink('topInset') topInset: number = 0;
  @StorageLink('bottomInset') bottomInset: number = 0;
  // 系统深浅色切换时重绘（Theme 色板按此取色）
  @StorageProp(Theme.KEY_DARK_MODE) darkMode: boolean = false;

  @State private list: ClipItem[] = [];
  // 切分类/搜索词必须立即重查列表：否则只在 store 变化时才 refresh，
  // 列表会卡在上一次的筛选结果上——选「链接」再加一条非链接内容，
  // 回到「全部」会看到过期（甚至空）的列表。
  @State @Watch('onFilterChange') private keyword: string = '';
  @State @Watch('onFilterChange') private category: string = 'all';
  @State private counts: CategoryCounts = new CategoryCounts();
  @State private stats: StoreStats = new StoreStats();
  @State private showCompose: boolean = false;
  @State private draft: string = '';
  @State private showFeedbackDialog: boolean = false;

  private store: ClipStore = ClipStore.getInstance();
  private categories: Category[] = [];
  private onStoreChange: () => void = () => this.refresh();

  aboutToAppear(): void {
    this.categories = getCategories();
    this.store.subscribe(this.onStoreChange);
    this.store.load();
    this.refresh();
    ClipboardKit.observe(() => this.captureIfEnabled(I18n.t('source_clipboard')));
    this.checkAndShowFeedback();
  }

  aboutToDisappear(): void {
    this.store.unsubscribe(this.onStoreChange);
    ClipboardKit.unobserve();
  }

  onAppForeground(): void {
    this.captureIfEnabled(I18n.t('source_clipboard'));
  }

  /** 累计启动达到阈值且未评价过时，弹出评分引导弹窗；debug 构建下不弹 */
  private async checkAndShowFeedback(): Promise<void> {
    if (this.isDebugBuild()) {
      return;
    }
    const prefs: StorageManager = StorageManager.getInstance();
    if (prefs.getBool(Const.KEY_FEEDBACK_DONE, false)) {
      return;
    }
    const count: number = prefs.getNumber(Const.KEY_FEEDBACK_LAUNCH_COUNT, 0) + 1;
    if (count >= Const.FEEDBACK_LAUNCH_THRESHOLD) {
      await prefs.put(Const.KEY_FEEDBACK_LAUNCH_COUNT, 0);
      this.showFeedbackDialog = true;
    } else {
      await prefs.put(Const.KEY_FEEDBACK_LAUNCH_COUNT, count);
    }
  }

  /** 当前是否为 debug 构建：通过 ApplicationInfo.debug 判定，出错时按 release 处理 */
  private isDebugBuild(): boolean {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      return info.appInfo.debug;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'isDebugBuild check failed');
      return false;
    }
  }

  /** 跳转到应用市场详情页，让用户给好评 */
  private openAppMarket(): void {
    try {
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.appdetail',
        uri: 'market://details?id=com.razor.tools.copybubble',
      };
      ctx.startAbility(want).catch((e: BusinessError) => {
        hilog.error(DOMAIN, TAG, `openAppMarket failed ${e.code} ${e.message}`);
      });
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `openAppMarket error ${err.code} ${err.message}`);
    }
  }

  /** 分类或搜索词变化时，立即用新条件重查列表（不计入 store 计数，仅过滤） */
  private onFilterChange(): void {
    this.list = this.store.query(this.category, this.keyword);
  }

  // ---------- 数据 ----------

  private refresh(): void {
    this.list = this.store.query(this.category, this.keyword);
    // 必须整体换引用，而不是对旧对象做 map.set：CategoryCounts 内部用 Map，
    // 而 @Observed 只能感知一级属性的赋值变化，Map.set() 的改动不会通知到
    // @ObjectLink 的 CategoryStrip，分类按钮上的数字会卡住不刷新（清空后尤为明显）。
    const next: CategoryCounts = new CategoryCounts();
    this.categories.forEach((c: Category) => next.set(c.key, this.store.countOf(c.key)));
    this.counts = next;
    this.stats = this.store.stats();
  }

  /** 自动收录：已获剪贴板权限才尝试，未授权时静默跳过（仍可用底部「粘贴」安全控件） */
  private async captureIfEnabled(source: string): Promise<void> {
    if (!ClipboardKit.hasPermission()) {
      return;
    }
    const text: string = await ClipboardKit.read();
    if (text.length === 0) {
      return;
    }
    const added: ClipItem | null = await this.store.add(text, source);
    if (added !== null) {
      this.toast(I18n.t('toast_captured_1'));
    }
  }

  private async copyItem(item: ClipItem): Promise<void> {
    const ok: boolean = await ClipboardKit.write(item.content);
    if (ok) {
      await this.store.markUsed(item.id);
      this.toast(I18n.t('toast_copied'));
    } else {
      this.toast(I18n.t('toast_copy_failed'));
    }
  }

  private async pinItem(item: ClipItem): Promise<void> {
    const pinned: boolean = await this.store.togglePin(item.id);
    this.toast(pinned ? I18n.t('toast_pinned') : I18n.t('toast_unpinned'));
  }

  private async captureFromButton(): Promise<void> {
    const text: string = await ClipboardKit.read();
    if (text.length === 0) {
      this.toast(I18n.t('toast_clipboard_empty'));
      return;
    }
    const added: ClipItem | null = await this.store.add(text, I18n.t('source_paste'));
    this.toast(added !== null ? I18n.t('toast_captured') : I18n.t('toast_already_exists'));
  }

  private async saveDraft(): Promise<void> {
    const text: string = this.draft;
    this.draft = '';
    this.showCompose = false;
    if (text.trim().length === 0) {
      return;
    }
    const added: ClipItem | null = await this.store.add(text, I18n.t('source_manual'));
    this.toast(added !== null ? I18n.t('toast_saved') : I18n.t('toast_already_exists'));
  }

  private async deleteItem(id: string): Promise<void> {
    await this.store.remove(id);
    this.toast(I18n.t('toast_deleted'));
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600, bottom: 120 });
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.warn(DOMAIN, TAG, `toast failed ${err.code}`);
    }
  }

  // ---------- UI ----------

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 0 }) {
        this.TopBar()

        Column({ space: 12 }) {
          SearchField({ keyword: this.keyword })
            .margin({ left: Theme.PAGE_PAD, right: Theme.PAGE_PAD })
          CategoryStrip({
            categories: this.categories,
            selected: this.category,
            counts: this.counts
          })
        }
        .padding({ bottom: 12 })

        this.ListArea()
      }
      .width('100%')
      .height('100%')

      this.ActionDock()

      if (this.showFeedbackDialog) {
        Column() {
          FeedbackDialog({
            onLater: () => { this.showFeedbackDialog = false; },
            onRate: () => {
              this.showFeedbackDialog = false;
              StorageManager.getInstance().put(Const.KEY_FEEDBACK_DONE, true);
              this.openAppMarket();
            },
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#99000000')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.PAGE_BG)
    .onAppear(() => this.refresh())
    .bindSheet($$this.showCompose, this.ComposeSheet(), {
      height: 340,
      dragBar: true,
      backgroundColor: Theme.CARD_BG,
      title: { title: I18n.t('compose_title') }
    })
  }

  @Builder
  TopBar() {
    Column({ space: 10 }) {
      Row() {
        Text(I18n.t('app_title'))
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_1)
          .letterSpacing(-0.3)
          .layoutWeight(1)

        Text('⚙')
          .fontSize(20)
          .fontColor(Theme.TEXT_2)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => this.pathStack.pushPathByName('settings', new NavParam('')))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(I18n.f('stats_summary', `${this.stats.total}`, `${this.stats.today}`, `${this.stats.pinned}`))
        .fontSize(12)
        .fontColor(Theme.TEXT_2)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: Theme.PAGE_PAD,
      right: Theme.PAGE_PAD,
      top: this.topInset + 12,
      bottom: 6
    })
  }

  @Builder
  ListArea() {
    if (this.list.length === 0) {
      Column() {
        EmptyState({
          title: this.keyword.length > 0 ? I18n.t('empty_no_match_title') : I18n.t('empty_quiet_title'),
          hint: this.keyword.length > 0
            ? I18n.t('empty_no_match_hint')
            : I18n.t('empty_quiet_hint')
        })
      }
      .layoutWeight(1)
    } else {
      List({ space: 12 }) {
        ForEach(this.list, (item: ClipItem) => {
          ListItem() {
            BubbleCard({
              item: item,
              onCopy: (i: ClipItem) => this.copyItem(i),
              onPin: (i: ClipItem) => this.pinItem(i),
              onOpen: (i: ClipItem) => this.pathStack.pushPathByName('detail', new NavParam(i.id))
            })
          }
          .swipeAction({ end: this.SwipeDelete(item) })
        }, (item: ClipItem) => `${item.id}_${item.updateTime}_${item.pinned}`)

        ListItem() {
          Text(I18n.f('list_end', `${this.list.length}`))
            .fontSize(12)
            .fontColor(Theme.TEXT_3)
            .width('100%')
            .textAlign(TextAlign.Center)
            // 底部留白需随安全区动态计算，确保「到底了」不被悬浮操作坞遮挡：
            // 操作坞高度 = 按钮高 52 + 坞内边距 20 + bottomInset，再加 16 间隙
            .padding({ top: 8, bottom: this.bottomInset + 88 })
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: Theme.PAGE_PAD, right: Theme.PAGE_PAD })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }

  @Builder
  SwipeDelete(item: ClipItem) {
    Row() {
      Text(I18n.t('btn_delete'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
    }
    .width(84)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.DANGER)
    .borderRadius({ topRight: 20, bottomRight: 20, topLeft: 6, bottomLeft: 6 })
    .margin({ left: 10 })
    .onClick(() => {
      this.deleteItem(item.id);
    })
  }

  /** 底部操作坞：左边安全控件读剪贴板，右边手动新建 */
  @Builder
  ActionDock() {
    Row({ space: 10 }) {
      PasteButton({
        icon: PasteIconStyle.LINES,
        text: PasteDescription.PASTE,
        buttonType: ButtonType.Capsule
      })
        .iconSize(18)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .iconColor(Color.White)
        .backgroundColor(Theme.BRAND)
        .padding({ left: 22, right: 22, top: 13, bottom: 13 })
        .borderRadius(26)
        .onClick((event: ClickEvent, result: PasteButtonOnClickResult) => {
          if (result !== PasteButtonOnClickResult.SUCCESS) {
            this.toast(I18n.t('toast_paste_failed'));
            return;
          }
          this.captureFromButton();
        })

      Text('＋')
        .fontSize(22)
        .fontColor(Theme.BRAND)
        .width(52)
        .height(52)
        .textAlign(TextAlign.Center)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(26)
        .shadow({ radius: 16, color: '#1A141F1A', offsetY: 6 })
        .onClick(() => {
          this.draft = '';
          this.showCompose = true;
        })
    }
    .padding({ bottom: this.bottomInset + 20 })
  }

  @Builder
  ComposeSheet() {
    Column({ space: 14 }) {
      TextArea({ text: $$this.draft, placeholder: I18n.t('compose_placeholder') })
        .placeholderColor(Theme.TEXT_3)
        .fontSize(15)
        .fontColor(Theme.TEXT_1)
        .height(160)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(14)
        .padding(12)

      Row({ space: 10 }) {
        Button(I18n.t('btn_cancel'))
          .fontSize(15)
          .fontColor(Theme.TEXT_2)
          .backgroundColor(Theme.CANCEL_BG)
          .height(46)
          .layoutWeight(1)
          .onClick(() => { this.showCompose = false; })

        Button(I18n.t('btn_save'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(Theme.BRAND)
          .height(46)
          .layoutWeight(2)
          .enabled(this.draft.trim().length > 0)
          .onClick(() => this.saveDraft())
      }
      .width('100%')
    }
    .padding({ left: 20, right: 20, top: 8, bottom: 20 })
    .width('100%')
  }
}
