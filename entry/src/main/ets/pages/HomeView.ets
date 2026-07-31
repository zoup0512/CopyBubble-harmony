import { promptAction } from '@kit.ArkUI';
import { ClipItem, Category, CATEGORIES, NavParam } from '../model/ClipItem';
import { ClipStore, StoreStats } from '../manager/ClipStore';
import { ClipboardKit } from '../manager/ClipboardKit';
import { StorageManager } from '../manager/StorageManager';
import { Theme, Const } from '../common/Theme';
import { BubbleCard } from '../components/BubbleCard';
import { SearchField } from '../components/SearchField';
import { CategoryStrip } from '../components/CategoryStrip';
import { EmptyState } from '../components/EmptyState';

@Component
export struct HomeView {
  @Consume('nav') pathStack: NavPathStack;
  @StorageLink('foregroundTick') @Watch('onAppForeground') tick: number = 0;
  @StorageLink('topInset') topInset: number = 0;
  @StorageLink('bottomInset') bottomInset: number = 0;

  @State private list: ClipItem[] = [];
  @State private keyword: string = '';
  @State private category: string = 'all';
  @State private counts: Map<string, number> = new Map<string, number>();
  @State private stats: StoreStats = new StoreStats();
  @State private showCompose: boolean = false;
  @State private draft: string = '';

  private store: ClipStore = ClipStore.getInstance();
  private categories: Category[] = CATEGORIES;
  private onStoreChange: () => void = () => this.refresh();

  aboutToAppear(): void {
    this.store.subscribe(this.onStoreChange);
    this.store.load();
    this.refresh();
    ClipboardKit.observe(() => this.captureIfEnabled('剪贴板'));
  }

  aboutToDisappear(): void {
    this.store.unsubscribe(this.onStoreChange);
    ClipboardKit.unobserve();
  }

  onAppForeground(): void {
    this.captureIfEnabled('剪贴板');
  }

  // ---------- 数据 ----------

  private refresh(): void {
    this.list = this.store.query(this.category, this.keyword);
    const map: Map<string, number> = new Map<string, number>();
    this.categories.forEach((c: Category) => map.set(c.key, this.store.countOf(c.key)));
    this.counts = map;
    this.stats = this.store.stats();
  }

  /** 自动收录：只在用户开启后尝试，被系统拒绝时静默跳过 */
  private async captureIfEnabled(source: string): Promise<void> {
    const on: boolean = StorageManager.getInstance().getBool(Const.KEY_AUTO_CAPTURE, false);
    if (!on) {
      return;
    }
    const text: string = await ClipboardKit.read();
    if (text.length === 0) {
      return;
    }
    const added: ClipItem | null = await this.store.add(text, source);
    if (added !== null) {
      this.toast('已收录 1 条');
    }
  }

  private async copyItem(item: ClipItem): Promise<void> {
    const ok: boolean = await ClipboardKit.write(item.content);
    if (ok) {
      await this.store.markUsed(item.id);
      this.toast('已复制到剪贴板');
    } else {
      this.toast('复制失败，请重试');
    }
  }

  private async pinItem(item: ClipItem): Promise<void> {
    const pinned: boolean = await this.store.togglePin(item.id);
    this.toast(pinned ? '已置顶' : '已取消置顶');
  }

  private async captureFromButton(): Promise<void> {
    const text: string = await ClipboardKit.read();
    if (text.length === 0) {
      this.toast('剪贴板是空的');
      return;
    }
    const added: ClipItem | null = await this.store.add(text, '粘贴按钮');
    this.toast(added !== null ? '已收录' : '这条已经在列表里了');
  }

  private async saveDraft(): Promise<void> {
    const text: string = this.draft;
    this.draft = '';
    this.showCompose = false;
    if (text.trim().length === 0) {
      return;
    }
    const added: ClipItem | null = await this.store.add(text, '手动输入');
    this.toast(added !== null ? '已保存' : '这条已经在列表里了');
  }

  private async deleteItem(id: string): Promise<void> {
    await this.store.remove(id);
    this.toast('已删除');
  }

  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 1600, bottom: 120 });
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.PAGE_BG)
    .onAppear(() => this.refresh())
    .bindSheet($$this.showCompose, this.ComposeSheet(), {
      height: 340,
      dragBar: true,
      backgroundColor: Theme.CARD_BG,
      title: { title: '新建一条' }
    })
  }

  @Builder
  TopBar() {
    Column({ space: 4 }) {
      Row() {
        Column({ space: 2 }) {
          Text('Copy Bubble')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_1)
            .letterSpacing(-0.3)
          Text(`共 ${this.stats.total} 条 · 今天新增 ${this.stats.today} · 置顶 ${this.stats.pinned}`)
            .fontSize(12)
            .fontColor(Theme.TEXT_2)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('⚙')
          .fontSize(20)
          .fontColor(Theme.TEXT_2)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .backgroundColor(Theme.CARD_BG)
          .borderRadius(14)
          .onClick(() => this.pathStack.pushPathByName('settings', new NavParam('')))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      left: Theme.PAGE_PAD,
      right: Theme.PAGE_PAD,
      top: this.topInset + 12,
      bottom: 14
    })
  }

  @Builder
  ListArea() {
    if (this.list.length === 0) {
      Column() {
        EmptyState({
          title: this.keyword.length > 0 ? '没有匹配的内容' : '剪贴板还很安静',
          hint: this.keyword.length > 0
            ? '换个关键词试试，或者清空搜索框'
            : '点下面的「粘贴」把当前剪贴板存进来，也可以手动新建一条'
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
          Text(`到底了 · ${this.list.length} 条`)
            .fontSize(12)
            .fontColor(Theme.TEXT_3)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 8, bottom: 120 })
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
      Text('删除')
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
            this.toast('没能读取剪贴板');
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
      TextArea({ text: $$this.draft, placeholder: '粘贴或输入要保存的内容' })
        .placeholderColor(Theme.TEXT_3)
        .fontSize(15)
        .height(160)
        .backgroundColor('#F5F5FA')
        .borderRadius(14)
        .padding(12)

      Row({ space: 10 }) {
        Button('取消')
          .fontSize(15)
          .fontColor(Theme.TEXT_2)
          .backgroundColor('#F0F0F6')
          .height(46)
          .layoutWeight(1)
          .onClick(() => { this.showCompose = false; })

        Button('保存')
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
