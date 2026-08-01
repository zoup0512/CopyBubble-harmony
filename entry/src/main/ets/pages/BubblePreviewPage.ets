/**
 * BubblePreviewPage.ets
 * 应用内预览页。不需要悬浮窗权限就能跑通贴边、休眠、展开、隐藏全流程，
 * 改视觉的时候用它比反复授权快得多。
 */

import { router } from '@kit.ArkUI';
import { FloatBubble } from '../bubble/FloatBubble';
import { DockSide, Rect } from '../bubble/DockEngine';
import { ClipItem, ClipKind, ClipUtil } from '../bubble/ClipItem';
import { AppKeys } from '../bubble/AppKeys';

@Entry
@Component
struct BubblePreviewPage {
  @State private items: ClipItem[] = ClipUtil.mock();
  @State private dark: boolean = false;
  @State private rectLabel: string = '—';
  @State private dockLabel: string = 'R · 240';
  @StorageLink(AppKeys.PULSE) pulse: number = 0;
  @StorageLink(AppKeys.BUBBLE_HIDDEN) hidden: boolean = false;

  private lineWidths: number[] = [88, 100, 62, 88, 100, 62, 88, 100, 62, 88, 100, 62, 88, 100, 62];

  @Builder
  fakeApp() {
    Column({ space: 11 }) {
      Text('某篇正在阅读的长文')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.dark ? '#C4CBE4' : '#2A3050')
        .width('100%')
      ForEach(this.lineWidths, (w: number, i: number) => {
        Row()
          .width(`${w}%`)
          .height(9)
          .borderRadius(5)
          .backgroundColor(this.dark ? '#232842' : '#DCE1EE')
      }, (w: number, i: number) => `line_${i}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20, top: 60 })
  }

  @Builder
  debugBar() {
    Column({ space: 10 }) {
      Row({ space: 14 }) {
        Text(`rect  ${this.rectLabel}`)
          .fontSize(11)
          .fontColor('#8D97BE')
        Text(`dock  ${this.dockLabel}`)
          .fontSize(11)
          .fontColor('#8D97BE')
      }
      .width('100%')

      Row({ space: 8 }) {
        Button('模拟一次复制')
          .fontSize(12)
          .height(32)
          .backgroundColor('#5B6CF6')
          .onClick(() => {
            const text: string = `${Math.floor(Math.random() * 900000 + 100000)}`;
            const fresh: ClipItem =
              new ClipItem(`${Date.now()}`, text, ClipKind.Code, Date.now());
            const next: ClipItem[] = [fresh];
            for (let i = 0; i < this.items.length && i < 5; i++) {
              next.push(this.items[i]);
            }
            this.items = next;
            this.pulse = this.pulse + 1;
          })

        Button(this.dark ? '浅色应用底' : '深色应用底')
          .fontSize(12)
          .height(32)
          .backgroundColor('#2A31A8')
          .onClick(() => {
            this.dark = !this.dark;
          })

        if (this.hidden) {
          Button('召回')
            .fontSize(12)
            .height(32)
            .backgroundColor('#0F8D79')
            .onClick(() => {
              this.hidden = false;
            })
        }
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor(this.dark ? '#CC0A0E20' : '#E6FFFFFF')
    .borderRadius({ topLeft: 18, topRight: 18 })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 模拟下层应用
      Column() {
        this.fakeApp()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.dark ? '#101322' : '#F3F5FA')

      // 返回入口
      Row() {
        Text('返回')
          .fontSize(14)
          .fontColor(this.dark ? '#8D97BE' : '#5F6A94')
          .onClick(() => router.back())
      }
      .width('100%')
      .padding({ left: 20, top: 20 })
      .position({ x: 0, y: 0 })

      // 被测组件
      FloatBubble({
        hostW: 360,
        hostH: 720,
        dark: this.dark,
        items: this.items,
        onWindowRectChange: (r: Rect) => {
          this.rectLabel =
            `${Math.round(r.x)},${Math.round(r.y)} ${Math.round(r.w)}×${Math.round(r.h)}`;
        },
        onPick: (item: ClipItem) => {
          console.info(`preview picked: ${item.content}`);
        },
        onHidden: () => {
          console.info('preview: bubble hidden');
        },
        onDockChange: (side: DockSide, y: number) => {
          this.dockLabel = `${side} · ${Math.round(y)}`;
        }
      })

      this.debugBar()
    }
    .width('100%')
    .height('100%')
  }
}
