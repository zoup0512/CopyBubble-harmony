import { Theme } from '../common/Theme';
import { I18n } from '../common/I18n';

/**
 * 评分反馈弹窗：累计启动若干次后弹出，引导用户去应用市场给好评。
 * 「以后再说」仅关闭弹窗并重置计数，下次达到阈值还会再弹；
 * 「去评价」会落库标记 feedback_done，之后不再弹出。
 */
@Component
export struct FeedbackDialog {
  onLater: () => void = () => {};
  onRate: () => void = () => {};

  build(): void {
    Column() {
      Text(I18n.t('dialog_feedback_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_1)
        .width('100%')
        .padding({ top: 24, left: 24, right: 24 })

      Text(I18n.t('dialog_feedback_message'))
        .fontSize(14)
        .fontColor(Theme.TEXT_2)
        .width('100%')
        .padding({ left: 24, right: 24, top: 12 })

      Divider()
        .color(Theme.DIVIDER)
        .margin({ top: 20 })

      Row() {
        Text(I18n.t('dialog_feedback_later'))
          .fontSize(16)
          .fontColor(Theme.TEXT_2)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 16, bottom: 16 })
          .onClick(() => this.onLater())

        Divider()
          .vertical(true)
          .color(Theme.DIVIDER)
          .height(48)

        Text(I18n.t('dialog_feedback_rate'))
          .fontSize(16)
          .fontColor(Theme.BRAND)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 16, bottom: 16 })
          .onClick(() => this.onRate())
      }
      .width('100%')
    }
    .width('80%')
    .borderRadius(20)
    .backgroundColor(Theme.CARD_BG)
  }
}
