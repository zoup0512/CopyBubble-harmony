import { Theme } from '../common/Theme';
import { I18n } from '../common/I18n';

@Component
export struct SearchField {
  @Link keyword: string;
  @State private focused: boolean = false;
  // 系统深浅色切换时重绘（Theme 色板按此取色）
  @StorageProp(Theme.KEY_DARK_MODE) darkMode: boolean = false;
  private controller: TextInputController = new TextInputController();
  private placeholder: string = I18n.t('search_placeholder');

  build() {
    Row({ space: 8 }) {
      Text('⌕')
        .fontSize(22)
        .fontColor(this.focused ? Theme.BRAND : Theme.TEXT_3)
        .height(40)
        .lineHeight(40)

      TextInput({ text: $$this.keyword, placeholder: this.placeholder, controller: this.controller })
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
