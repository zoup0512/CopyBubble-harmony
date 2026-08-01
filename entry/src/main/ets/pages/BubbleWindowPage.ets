/**
 * BubbleWindowPage.ets
 * 悬浮窗的 UI 内容。这是一个新增页面，不会覆盖你现有的任何页面。
 *
 * 它只依赖 bubble/ 目录，所有业务数据从 BubbleBridge.hooks 取，
 * 不 import 你项目里的任何模块。
 */

import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { FloatBubble } from '../bubble/FloatBubble';
import { BubbleWindowManager } from '../bubble/BubbleWindowManager';
import { BubbleBridge } from '../bubble/BubbleBridge';
import { DockSide, Rect } from '../bubble/DockEngine';
import { ClipItem } from '../bubble/ClipItem';
import { AppKeys } from '../bubble/AppKeys';
import { BubbleSize } from '../bubble/BubbleTokens';

@Entry
@Component
struct BubbleWindowPage {
  @StorageLink(AppKeys.DARK_HOST) darkHost: boolean = false;
  /** 数据变更信号。业务侧调 BubbleBridge.notifyCaptured() 后这里会重新拉取。 */
  @StorageLink(AppKeys.PULSE) @Watch('reload') pulse: number = 0;

  @State private items: ClipItem[] = [];
  @State private hostW: number = 360;
  @State private hostH: number = 780;
  @State private keyboardH: number = 0;

  private mgr: BubbleWindowManager = BubbleWindowManager.get();

  aboutToAppear(): void {
    const s: Rect = this.mgr.screenSizeVp();
    this.hostW = s.w;
    this.hostH = s.h;
    console.info(`CopyBubble/Host aboutToAppear screen=${s.w}x${s.h}`);
    this.reload();
    this.watchKeyboard();
  }

  private reload(): void {
    this.items = BubbleBridge.hooks.getItems();
  }

  /**
   * 输入法弹起时压缩可用高度，气泡会被 clampY 顶到键盘上方。
   * 不做的话，用户在聊天框打字时气泡正好压在候选词条上。
   */
  private watchKeyboard(): void {
    try {
      window.getLastWindow(getContext(this)).then((win: window.Window) => {
        win.on('keyboardHeightChange', (h: number) => {
          this.keyboardH = px2vp(h);
        });
      }).catch((e: BusinessError) => {
        console.error(`CopyBubble keyboard watch failed ${e.code}`);
      });
    } catch (e) {
      console.error('CopyBubble keyboard watch threw');
    }
  }

  private availableH(): number {
    if (this.keyboardH <= 0) {
      return this.hostH;
    }
    return Math.max(this.hostH - this.keyboardH - 16, BubbleSize.BUBBLE * 4);
  }

  build() {
    Stack() {
      FloatBubble({
        hostW: this.hostW,
        hostH: this.availableH(),
        dark: this.darkHost,
        items: this.items,
        onWindowRectChange: (r: Rect) => {
          this.mgr.applyRect(r);
        },
        onPick: (item: ClipItem) => {
          BubbleBridge.hooks.onPick(item);
        },
        onHidden: () => {
          BubbleBridge.hooks.onHidden();
        },
        onDockChange: (side: DockSide, y: number) => {
          BubbleBridge.hooks.onDockChange(side, y);
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}
