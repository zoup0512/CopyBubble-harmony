import { Category } from '../model/ClipItem';
import { Theme } from '../common/Theme';

@Component
export struct CategoryStrip {
  @Prop categories: Category[];
  @Link selected: string;
  @Prop counts: Map<string, number>;

  build() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.categories, (c: Category) => {
          this.Chip(c)
        }, (c: Category) => c.key)
      }
      .padding({ left: Theme.PAGE_PAD, right: Theme.PAGE_PAD })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .align(Alignment.Start)
  }

  @Builder
  Chip(c: Category) {
    Row({ space: 5 }) {
      Text(c.label)
        .fontSize(13)
        .fontWeight(this.selected === c.key ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selected === c.key ? Color.White : Theme.TEXT_2)
      Text(`${this.counts.get(c.key) ?? 0}`)
        .fontSize(11)
        .fontColor(this.selected === c.key ? '#D8DCFF' : Theme.TEXT_3)
    }
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .backgroundColor(this.selected === c.key ? Theme.BRAND : Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CHIP)
    .border({ width: 1, color: this.selected === c.key ? Theme.BRAND : Theme.DIVIDER })
    .animation({ duration: 160, curve: Curve.Smooth })
    .onClick(() => { this.selected = c.key; })
  }
}
