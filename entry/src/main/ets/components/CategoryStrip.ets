import { Category } from '../model/ClipItem';
import { Theme } from '../common/Theme';
import { CategoryCounts } from '../common/UiModels';

@Component
export struct CategoryStrip {
  @Prop categories: Category[];
  @Link selected: string;
  // @ObjectLink 监听 @Observed 对象的属性级变化，配合父组件「改 value 而非换引用」，
  // 计数变化才能可靠地传进来。原来用 @Prop Map 时 value 变化不会触发重渲染。
  @ObjectLink counts: CategoryCounts;
  // 系统深浅色切换时重绘（Theme 色板按此取色）
  @StorageProp(Theme.KEY_DARK_MODE) darkMode: boolean = false;

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
      Text(`${this.counts.get(c.key)}`)
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
