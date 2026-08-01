import { ClipItem } from '../model/ClipItem';
import { Theme, Const } from '../common/Theme';
import { TimeUtil } from '../utils/TimeUtil';
import { I18n } from '../common/I18n';

/**
 * 一条剪贴记录。
 * 造型上是一枚对话气泡——左下角收成尖角，像剪贴板在跟你说话；
 * 左侧竖条用内容类型的色相着色，滚动时不读字也能分辨种类。
 */
@Component
export struct BubbleCard {
  @ObjectLink item: ClipItem;
  onCopy: (item: ClipItem) => void = () => {};
  onPin: (item: ClipItem) => void = () => {};
  onOpen: (item: ClipItem) => void = () => {};

  @State private pressed: boolean = false;

  build() {
    Column({ space: 10 }) {
      this.Header()
      this.Body()
      this.Footer()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 12 })
    .backgroundColor(Theme.CARD_BG)
    .border({
      width: { left: 4 },
      color: { left: Theme.styleOf(this.item.type).tint }
    })
    .borderRadius({ topLeft: 20, topRight: 20, bottomRight: 20, bottomLeft: 6 })
    .clip(true)
    .shadow({
      radius: this.pressed ? 6 : 14,
      color: '#14141F14',
      offsetX: 0,
      offsetY: this.pressed ? 2 : 6
    })
    .scale({ x: this.pressed ? 0.985 : 1, y: this.pressed ? 0.985 : 1 })
    .animation({ duration: 140, curve: Curve.FastOutSlowIn })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick(() => this.onOpen(this.item))
  }

  @Builder
  Header() {
    Row({ space: 8 }) {
      Row({ space: 4 }) {
        Text(Theme.styleOf(this.item.type).glyph)
          .fontSize(11)
          .fontColor(Theme.styleOf(this.item.type).tint)
        Text(Theme.styleOf(this.item.type).label)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.styleOf(this.item.type).tint)
      }
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor(Theme.styleOf(this.item.type).wash)
      .borderRadius(Theme.RADIUS_CHIP)

      if (this.item.pinned) {
        Text(I18n.t('pinned_tag'))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.PIN)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor('#FDF3E0')
          .borderRadius(Theme.RADIUS_CHIP)
      }

      Blank()

      Text(TimeUtil.relative(this.item.updateTime))
        .fontSize(11)
        .fontColor(Theme.TEXT_3)
    }
    .width('100%')
  }

  @Builder
  Body() {
    Text(this.item.preview.length > Const.PREVIEW_LIMIT
      ? `${this.item.preview.substring(0, Const.PREVIEW_LIMIT)}…`
      : this.item.preview)
      .fontSize(15)
      .lineHeight(23)
      .fontColor(Theme.TEXT_1)
      .maxLines(4)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
      .textAlign(TextAlign.Start)
  }

  @Builder
  Footer() {
    Row({ space: 8 }) {
      Text(I18n.f('char_count', `${this.item.charCount}`))
        .fontSize(11)
        .fontColor(Theme.TEXT_3)

      if (this.item.useCount > 0) {
        Text(I18n.f('used_count', `${this.item.useCount}`))
          .fontSize(11)
          .fontColor(Theme.TEXT_3)
      }

      Blank()

      Text(this.item.pinned ? I18n.t('unpin_action') : I18n.t('pin_action'))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.item.pinned ? Theme.PIN : Theme.TEXT_2)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(Theme.RADIUS_CHIP)
        .backgroundColor('#F5F5FA')
        .onClick(() => this.onPin(this.item))

      Text(I18n.t('copy_action'))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.BRAND)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(Theme.RADIUS_CHIP)
        .backgroundColor('#ECEEFF')
        .onClick(() => this.onCopy(this.item))
    }
    .width('100%')
  }
}
