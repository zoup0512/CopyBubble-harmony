import { Theme } from '../common/Theme';

@Component
export struct SearchField {
  @Link keyword: string;
  @State private focused: boolean = false;
  private controller: TextInputController = new TextInputController();

  build() {
    Row({ space: 8 }) {
      Text('⌕')
        .fontSize(18)
        .fontColor(this.focused ? Theme.BRAND : Theme.TEXT_3)

      TextInput({ text: $$this.keyword, placeholder: '搜索剪贴内容', controller: this.controller })
        .placeholderColor(Theme.TEXT_3)
        .placeholderFont({ size: 14 })
        .fontSize(14)
        .fontColor(Theme.TEXT_1)
        .backgroundColor(Color.Transparent)
        .padding(0)
        .height(40)
        .layoutWeight(1)
        .enterKeyType(EnterKeyType.Search)
        .onFocus(() => { this.focused = true; })
        .onBlur(() => { this.focused = false; })

      if (this.keyword.length > 0) {
        Text('✕')
          .fontSize(14)
          .fontColor(Theme.TEXT_3)
          .padding(6)
          .onClick(() => { this.keyword = ''; })
      }
    }
    .width('100%')
    .padding({ left: 14, right: 8 })
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(14)
    .border({ width: 1, color: this.focused ? Theme.BRAND : Theme.DIVIDER })
    .animation({ duration: 150, curve: Curve.Smooth })
  }
}
