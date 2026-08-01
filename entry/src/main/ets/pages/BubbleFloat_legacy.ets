import { promptAction } from '@kit.ArkUI';
import { ClipItem } from '../model/ClipItem';
import { ClipStore } from '../manager/ClipStore';
import { ClipboardKit } from '../manager/ClipboardKit';
import { BubbleWindow } from '../manager/BubbleWindow_legacy';
import { Theme } from '../common/Theme';

const COLLAPSED: number = 64;
const PANEL_W: number = 300;
const PANEL_H: number = 400;

/**
 * 悬浮窗内容。收起时是一枚 64vp 的气泡，展开成一张最近记录面板，
 * 点任意一条即写回剪贴板并自动收起。
 */
@Entry
@Component
struct BubbleFloat {
  @State private expanded: boolean = false;
  @State private recent: ClipItem[] = [];

  private store: ClipStore = ClipStore.getInstance();
  private onStoreChange: () => void = () => { this.recent = this.store.recent(8); };

  // 拖动相关。originX/Y 记下手势开始时窗口的位置，dragged 标记是否真拖动了，
  // 用来在 Up 时区分「点一下展开」和「拖完松手」。
  private originX: number = 0;
  private originY: number = 0;
  private dragged: boolean = false;
  private readonly DRAG_SLOP: number = 8;

  aboutToAppear(): void {
    this.store.subscribe(this.onStoreChange);
    this.store.load();
    this.recent = this.store.recent(8);
  }

  aboutToDisappear(): void {
    this.store.unsubscribe(this.onStoreChange);
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.expanded) {
        this.Panel()
      } else {
        this.Pill()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  Pill() {
    Stack() {
      Column()
        .width(56)
        .height(56)
        .backgroundColor(Theme.BRAND)
        .borderRadius({ topLeft: 28, topRight: 28, bottomRight: 28, bottomLeft: 10 })
        .shadow({ radius: 18, color: '#334C5BD4', offsetY: 6 })
      Text('❝')
        .fontSize(22)
        .fontColor(Color.White)
        .offset({ y: 2 })
    }
    .width(COLLAPSED)
    .height(COLLAPSED)
    // 点击与拖动并存：轻点展开，按住拖动换位。
    .parallelGesture(
      PanGesture()
        .onActionStart(() => {
          this.originX = BubbleWindow.posX;
          this.originY = BubbleWindow.posY;
          this.dragged = false;
        })
        .onActionUpdate((e: GestureEvent) => {
          // offsetX/Y 是相对手势起点的累计偏移（单位 vp），换算成 px 加到起点上。
          if (Math.abs(e.offsetX) > this.DRAG_SLOP || Math.abs(e.offsetY) > this.DRAG_SLOP) {
            this.dragged = true;
          }
          BubbleWindow.moveTo(this.originX + vp2px(e.offsetX), this.originY + vp2px(e.offsetY));
        })
    )
    .onClick(() => {
      // 拖完之后的那次 Up 会被误判成点击，这里跳过。
      if (this.dragged) {
        this.dragged = false;
        return;
      }
      this.expand();
    })
  }

  @Builder
  Panel() {
    Column({ space: 0 }) {
      Row() {
        Text('最近复制')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_1)
          .layoutWeight(1)
        Text('✕')
          .fontSize(14)
          .fontColor(Theme.TEXT_3)
          .padding(8)
          .onClick(() => this.collapse())
      }
      .width('100%')
      .padding({ left: 14, right: 6, top: 10, bottom: 6 })

      Divider().color(Theme.DIVIDER)

      if (this.recent.length === 0) {
        Text('还没有记录')
          .fontSize(13)
          .fontColor(Theme.TEXT_3)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 40, bottom: 40 })
      } else {
        List({ space: 6 }) {
          ForEach(this.recent, (item: ClipItem) => {
            ListItem() {
              Row({ space: 8 }) {
                Column()
                  .width(3)
                  .height(30)
                  .backgroundColor(Theme.styleOf(item.type).tint)
                  .borderRadius(2)
                Text(item.preview)
                  .fontSize(13)
                  .fontColor(Theme.TEXT_1)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 10, right: 10, top: 8, bottom: 8 })
              .backgroundColor('#F7F7FC')
              .borderRadius(10)
              .onClick(() => this.pick(item))
            }
          }, (item: ClipItem) => item.id)
        }
        .layoutWeight(1)
        .padding({ left: 10, right: 10, top: 8, bottom: 10 })
        .scrollBar(BarState.Off)
      }
    }
    .width(PANEL_W)
    .height(PANEL_H)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(18)
    .shadow({ radius: 24, color: '#22141F1A', offsetY: 10 })
  }

  private async expand(): Promise<void> {
    // 以气泡为锚向左下生长并整体收进屏内，避免面板溢出右屏
    await BubbleWindow.expandTo(vp2px(PANEL_W), vp2px(PANEL_H));
    this.expanded = true;
  }

  private async collapse(): Promise<void> {
    this.expanded = false;
    await BubbleWindow.collapseTo(vp2px(COLLAPSED), vp2px(COLLAPSED));
  }

  private async pick(item: ClipItem): Promise<void> {
    const ok: boolean = await ClipboardKit.write(item.content);
    await this.store.markUsed(item.id);
    promptAction.showToast({ message: ok ? '已复制' : '复制失败' });
    await this.collapse();
  }
}
