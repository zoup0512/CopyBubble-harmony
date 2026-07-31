import { Theme } from '../common/Theme';

@Component
export struct EmptyState {
  @Prop title: string = '还没有记录';
  @Prop hint: string = '复制点什么，然后回到这里';

  build() {
    Column({ space: 10 }) {
      Stack() {
        Column()
          .width(84).height(84)
          .backgroundColor('#ECEEFF')
          .borderRadius({ topLeft: 30, topRight: 30, bottomRight: 30, bottomLeft: 8 })
        Text('❝')
          .fontSize(34)
          .fontColor(Theme.BRAND)
          .offset({ y: 4 })
      }
      .margin({ bottom: 6 })

      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_1)

      Text(this.hint)
        .fontSize(13)
        .fontColor(Theme.TEXT_2)
        .textAlign(TextAlign.Center)
        .width('72%')
    }
    .width('100%')
    .padding({ top: 72, bottom: 72 })
    .alignItems(HorizontalAlign.Center)
  }
}
