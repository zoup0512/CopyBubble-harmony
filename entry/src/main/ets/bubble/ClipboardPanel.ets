/**
 * ClipboardPanel.ets
 * 展开后的剪贴板面板。
 *
 * 刻意不放关闭按钮：面板外任意点击或返回手势即可收起，
 * 少一个可点击目标，就少一次误触。
 */

import { curves } from '@kit.ArkUI';
import { BubbleColor, BubbleShape, BubbleSize } from './BubbleTokens';
import { ClipItem, ClipKind, ClipStyle, ClipUtil } from './ClipItem';

@Component
export struct ClipboardPanel {
  @Prop items: ClipItem[] = [];
  @Prop dark: boolean = false;
  /** 缩放原点，来自 DockEngine.panelAnchor */
  @Prop originX: number = 0;
  @Prop originY: number = 0.5;
  @Prop shown: boolean = false;

  onPick: (item: ClipItem) => void = () => {};
  onClear: () => void = () => {};

  @Builder
  itemRow(item: ClipItem) {
    Row({ space: 9 }) {
      Text(ClipUtil.styleOf(item.kind).tag)
        .fontSize(9)
        .fontWeight(FontWeight.Medium)
        .fontColor(ClipUtil.styleOf(item.kind).fg)
        .textAlign(TextAlign.Center)
        .width(22)
        .height(22)
        .borderRadius(7)
        .backgroundColor(ClipUtil.styleOf(item.kind).bg)

      Column({ space: 1 }) {
        Text(ClipUtil.preview(item.content))
          .fontSize(12)
          .fontColor(this.dark ? BubbleColor.PANEL_TEXT_DARK : BubbleColor.PANEL_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${ClipUtil.kindLabel(item.kind)} · ${ClipUtil.ago(item.time)}`)
          .fontSize(9.5)
          .fontColor(BubbleColor.PANEL_SUB)
          .maxLines(1)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(BubbleSize.ITEM_H)
    .padding({ left: 8, right: 8 })
    .borderRadius(12)
    .onClick(() => this.onPick(item))
  }

  @Builder
  emptyState() {
    Column({ space: 4 }) {
      Text('还没有复制过东西')
        .fontSize(12)
        .fontColor(this.dark ? BubbleColor.PANEL_TEXT_DARK : BubbleColor.PANEL_TEXT)
      Text('复制任意文本，它会出现在这里')
        .fontSize(10)
        .fontColor(BubbleColor.PANEL_SUB)
    }
    .width('100%')
    .height(BubbleSize.PANEL_EMPTY_H)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Row() {
        Text('剪贴板')
          .fontSize(10)
          .fontColor(BubbleColor.PANEL_SUB)
          .letterSpacing(1.2)
        Blank()
        Text(this.items.length > 0 ? `${this.items.length} 条` : '空')
          .fontSize(10)
          .fontColor(BubbleColor.PANEL_SUB)
          .onClick(() => {
            if (this.items.length > 0) {
              this.onClear();
            }
          })
      }
      .width('100%')
      .height(BubbleSize.PANEL_HEAD_H)
      .padding({ left: 6, right: 6 })

      if (this.items.length === 0) {
        this.emptyState()
      } else {
        ForEach(this.items, (item: ClipItem) => {
          this.itemRow(item)
        }, (item: ClipItem) => item.id)
      }
    }
    .width(BubbleSize.PANEL_W)
    .padding(BubbleSize.PANEL_PAD)
    .backgroundColor(this.dark ? BubbleColor.PANEL_BG_DARK : BubbleColor.PANEL_BG_LIGHT)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(BubbleShape.PANEL_RADIUS)
    .shadow({ radius: 44, color: '#40101440', offsetX: 0, offsetY: 22 })
    .scale({
      x: this.shown ? 1 : 0.5,
      y: this.shown ? 1 : 0.5,
      centerX: `${this.originX * 100}%`,
      centerY: `${this.originY * 100}%`
    })
    .opacity(this.shown ? 1 : 0)
    .animation({ duration: 340, curve: curves.cubicBezierCurve(0.2, 1.15, 0.35, 1) })
  }
}
