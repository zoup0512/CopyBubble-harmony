/**
 * BubbleIcon.ets
 * 「叠影」图形：描边那张是原文，实心那张是刚被拷出来的副本。
 *
 * 为什么不用 SVG 资源：图形只有两个圆角矩形，用 ArkUI 原生绘制可以
 * 单独对「原文」那一层做透明度动画（休眠态要把它隐去），
 * 换成图片资源就只能整块淡出。
 *
 * 构图（以 48 为基准，1 单位 = 1vp @ 48vp 气泡）：
 *   原文  x13 y17 w15 h17 r4.5 stroke 2.6
 *   副本  x20 y14 w15 h17 r4.5 fill
 *   并集  x13..35 (22)  y14..34 (20)  → 恰好落在 22vp 安全内圈里
 */

import { curves } from '@kit.ArkUI';
import { BubbleColor, BubbleShape } from './BubbleTokens';

@Component
export struct BubbleIcon {
  /** 图形整体缩放，1 对应 48vp 气泡 */
  @Prop scaleRatio: number = 1;
  /** 休眠态：隐去「原文」层，只留副本轮廓 */
  @Prop ghostVisible: boolean = true;
  /** 贴边后向屏幕内侧的补偿位移，负值表示向左 */
  @Prop shiftX: number = 0;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 原文：描边层
      Row()
        .width(15 * this.scaleRatio)
        .height(17 * this.scaleRatio)
        .borderRadius(BubbleShape.GLYPH_RADIUS * this.scaleRatio)
        .border({
          width: BubbleShape.GLYPH_STROKE * this.scaleRatio,
          color: BubbleColor.GLYPH_GHOST
        })
        .position({ x: 0, y: 3 * this.scaleRatio })
        .opacity(this.ghostVisible ? 1 : 0)
        .animation({ duration: 300, curve: Curve.EaseOut })

      // 副本：实心层
      Row()
        .width(15 * this.scaleRatio)
        .height(17 * this.scaleRatio)
        .borderRadius(BubbleShape.GLYPH_RADIUS * this.scaleRatio)
        .backgroundColor(BubbleColor.GLYPH)
        .position({ x: 7 * this.scaleRatio, y: 0 })
    }
    .width(22 * this.scaleRatio)
    .height(20 * this.scaleRatio)
    .translate({ x: this.shiftX })
    .animation({ duration: 300, curve: Curve.EaseOut })
  }
}

/**
 * 计数角标。贴右边时自动移到左上角，
 * 否则数字会被气泡自己藏进屏幕外 —— 这是唯一一处随 side 镜像的装饰。
 */
@Component
export struct BubbleBadge {
  @Prop count: number = 0;
  @Prop onLeft: boolean = false;
  @Prop visible: boolean = true;

  private label(): string {
    if (this.count > 99) {
      return '99+';
    }
    return this.count.toString();
  }

  build() {
    Text(this.label())
      .fontSize(10)
      .fontWeight(FontWeight.Medium)
      .fontColor(BubbleColor.BADGE_FG)
      .textAlign(TextAlign.Center)
      .constraintSize({ minWidth: 16 })
      .height(16)
      .padding({ left: 4, right: 4 })
      .backgroundColor(BubbleColor.BADGE_BG)
      .borderRadius(8)
      .border({ width: 2, color: '#E6FFFFFF' })
      .scale({ x: this.visible ? 1 : 0, y: this.visible ? 1 : 0 })
      .opacity(this.visible ? 1 : 0)
      .animation({ duration: 300, curve: curves.springMotion(0.3, 0.9) })
  }
}
