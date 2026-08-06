/**
 * SwitchRow.ets
 * 通用开关行。
 *
 * 必须是独立 @Component 而不能用 @Builder：@Builder 按值传参时，基础类型（boolean）
 * 会被冻结成首次构建的快照，Toggle.isOn 不再随数据源变化刷新——这会让受控 Toggle
 * 在 onChange 后被 ArkUI 强制弹回旧值，表现为「开关关不掉」。@Prop 建立真正的数据
 * 绑定，父组件状态变化能正确驱动 Toggle 刷新。
 */

import { Theme } from '../common/Theme';

@Component
export struct SwitchRow {
  @Prop title: string = '';
  @Prop desc: string = '';
  @Prop value: boolean = false;
  // 系统深浅色切换时重绘（Theme 色板按此取色）
  @StorageProp(Theme.KEY_DARK_MODE) darkMode: boolean = false;
  onChange: (v: boolean) => void = () => {};

  build() {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.title)
          .fontSize(15)
          .fontColor(Theme.TEXT_1)
        Text(this.desc)
          .fontSize(12)
          .lineHeight(18)
          .fontColor(Theme.TEXT_2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .selectedColor(Theme.BRAND)
        .onChange((v: boolean) => this.onChange(v))
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(16)
    .margin({ bottom: 8 })
  }
}
