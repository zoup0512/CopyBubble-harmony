/**
 * ClipboardPanel.ets
 * 展开后的剪贴板面板。
 *
 * 面板外任意点击或返回手势即可收起；header 右侧的开关用于彻底关闭悬浮球，
 * 开关是刻意手势，误触概率比按钮低。
 */

import { curves } from '@kit.ArkUI';
import { BubbleColor, BubbleShape, BubbleSize } from './BubbleTokens';
import { ClipItem, ClipKind, ClipStyle, ClipUtil } from './ClipItem';
import { I18n } from '../common/I18n';

@Component
export struct ClipboardPanel {
  @Prop items: ClipItem[] = [];
  @Prop dark: boolean = false;
  /** 缩放原点，来自 DockEngine.panelAnchor */
  @Prop originX: number = 0;
  @Prop originY: number = 0.5;
  @Prop shown: boolean = false;

  onPick: (item: ClipItem) => void = () => {};
  /** header 右侧开关转 OFF 时彻底关闭悬浮球 */
  onClose: () => void = () => {};

  /** 最近一次点选的记录 id，用于高亮选中行 */
  @State private selectedId: string = '';

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
    .backgroundColor(this.selectedId === item.id
      ? (this.dark ? BubbleColor.PANEL_ROW_SEL_DARK : BubbleColor.PANEL_ROW_SEL_LIGHT)
      : Color.Transparent)
    .onClick(() => {
      this.selectedId = item.id;
      this.onPick(item);
    })
  }

  @Builder
  emptyState() {
    Column({ space: 4 }) {
      Text(I18n.t('panel_empty_title'))
        .fontSize(12)
        .fontColor(this.dark ? BubbleColor.PANEL_TEXT_DARK : BubbleColor.PANEL_TEXT)
      Text(I18n.t('panel_empty_hint'))
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
        Text(I18n.t('panel_header'))
          .fontSize(10)
          .fontColor(BubbleColor.PANEL_SUB)
          .letterSpacing(1.2)
        Blank()
        Row({ space: 5 }) {
          Text(I18n.t('panel_close_bubble'))
            .fontSize(10)
            .fontColor(BubbleColor.PANEL_SUB)
          // 彻底关闭悬浮球。打开时 ON，拨到 OFF 即销毁双窗口。
          Toggle({ type: ToggleType.Switch, isOn: true })
            .selectedColor(BubbleColor.GRAD_A)
            .scale({ x: 0.85, y: 0.85 })
            .onChange((isOn: boolean) => {
              if (!isOn) {
                this.onClose();
              }
            })
        }
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
