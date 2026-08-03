/**
 * BubbleWindowManager.ets
 * 悬浮窗宿主。把吸附计算留在 DockEngine，这里只负责搬窗口。
 *
 * 双窗口架构（根治 resize 闪烁 + 保留下层触摸穿透）：
 *   视觉层（viewWin，copy_bubble_view）：常驻全屏、不可触摸。渲染气泡外观、
 *     面板、波纹等所有纯视觉内容。setWindowTouchable(false) 让触摸整窗穿透到
 *     下层 app，全屏也不挡下层。永不 resize（创建时铺满一次）→ 永不闪。
 *   交互层（touchWin，copy_bubble_touch）：112×112、可触摸。透明的手势热区，
 *     承载 PanGesture/TapGesture。只 moveWindowTo 跟随气泡（不 resize）→ 不闪；
 *     贴边时窗口向屏外顶出，屏幕内只挡气泡附近 50×112 的小块，下层 app 在
 *     气泡之外完全可点。
 *
 * 为什么不能单窗口：窗口 resize 会让 WMS 重建 surface，中间帧覆盖整屏 = 桌面闪
 * （应用层无法消除）；而 PanGesture 手指出窗会断触、TYPE_FLOAT 无法局部触摸穿透，
 * 所以「全屏单窗口」和「缩放单窗口」都不可行。两个职责分离的窗口各只 move 不
 * resize，才能同时满足「不闪 + 不挡下层 + 不断触」。
 *
 * 需要在 module.json5 声明：
 *   "requestPermissions": [{ "name": "ohos.permission.SYSTEM_FLOAT_WINDOW" }]
 */

import { common } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppKeys } from './AppKeys';
import { BubbleSize } from './BubbleTokens';
import { Rect } from './DockEngine';

const TAG: string = 'CopyBubble/Window';
const DOMAIN: number = 0x1001;
const VIEW_WINDOW_NAME: string = 'copy_bubble_view';
const TOUCH_WINDOW_NAME: string = 'copy_bubble_touch';

export class BubbleWindowManager {
  private static instance: BubbleWindowManager | undefined = undefined;
  /** 视觉层：全屏、不可触摸，纯渲染 */
  private viewWin: window.Window | undefined = undefined;
  /** 交互层：48×48、可触摸，承载手势 */
  private touchWin: window.Window | undefined = undefined;
  private ctx: common.UIAbilityContext | undefined = undefined;
  /** moveTouchWindow 去重：上一次 moveWindowTo 未完成时只记最新目标，完成后补一次 */
  private touchMoving: boolean = false;
  private touchPendingX: number = 0;
  private touchPendingY: number = 0;
  private touchHasPending: boolean = false;
  private shown: boolean = false;

  static get(): BubbleWindowManager {
    if (!BubbleWindowManager.instance) {
      BubbleWindowManager.instance = new BubbleWindowManager();
    }
    return BubbleWindowManager.instance;
  }

  /** 屏幕逻辑尺寸，vp */
  screenSizeVp(): Rect {
    const d: display.Display = display.getDefaultDisplaySync();
    return { x: 0, y: 0, w: px2vp(d.width), h: px2vp(d.height) };
  }

  async create(ctx: common.UIAbilityContext): Promise<void> {
    // 只有双层都在才算已就绪。只剩视觉层是残废态（有外观、点不动），
    // 必须先 destroy 清干净再重建，否则永远卡在"气泡在但没反应"。
    if (this.viewWin && this.touchWin) {
      hilog.info(DOMAIN, TAG, 'create: already exists, skip');
      return;
    }
    if (this.viewWin || this.touchWin) {
      hilog.warn(DOMAIN, TAG, 'create: partial windows found, reset before recreate');
      await this.destroy();
    }
    this.ctx = ctx;
    hilog.info(DOMAIN, TAG, 'create: start');
    try {
      const s: Rect = this.screenSizeVp();
      hilog.info(DOMAIN, TAG, `create: screenSizeVp=${JSON.stringify(s)}`);

      // ---- 视觉层：全屏、不可触摸 ----
      const viewCfg: window.Configuration = {
        name: VIEW_WINDOW_NAME,
        windowType: window.WindowType.TYPE_FLOAT,
        ctx: ctx
      };
      const vw: window.Window = await window.createWindow(viewCfg);
      this.viewWin = vw;
      await vw.setUIContent('pages/BubbleWindowPage');
      vw.setWindowBackgroundColor('#00000000');
      await vw.setWindowLayoutFullScreen(false);
      // 不可触摸：触摸整窗穿透到下层 app。全屏也不挡下层。
      vw.setWindowTouchable(false);
      // 不可聚焦：避免触摸触发焦点/高亮级联导致桌面闪（见 setWindowFocusable 说明）。
      await vw.setWindowFocusable(false);
      // 视觉层铺满全屏一次，之后永不 resize
      await vw.moveWindowTo(vp2px(s.x), vp2px(s.y));
      await vw.resize(vp2px(s.w), vp2px(s.h));
      await vw.showWindow();

      // ---- 交互层：112×112、可触摸、跟随气泡 ----
      // 必须在视觉层之后创建：后创建的 TYPE_FLOAT 默认 z-order 更高，交互层要
      // 在视觉层之上才能收到触摸。
      const touchCfg: window.Configuration = {
        name: TOUCH_WINDOW_NAME,
        windowType: window.WindowType.TYPE_FLOAT,
        ctx: ctx
      };
      const tw: window.Window = await window.createWindow(touchCfg);
      this.touchWin = tw;
      // 交互层窗口尺寸：气泡 48 + 两侧留白 16×2 + 行程余量 32（见 BubbleSize.TOUCH_WIN）。
      // 气泡在窗口内用 .position() 移动（ArkUI 原生渲染，无 WMS 异步振荡），
      // 只在气泡接近窗口边缘时才 moveWindowTo 重新居中/顶出——从每帧 60+ 次降到
      // 整个拖拽过程数次，消除高频 moveWindowTo 振荡。
      await tw.resize(vp2px(BubbleSize.TOUCH_WIN), vp2px(BubbleSize.TOUCH_WIN));
      await tw.moveWindowTo(vp2px(s.w), vp2px(0));
      await tw.setUIContent('pages/BubbleTouchPage');
      tw.setWindowBackgroundColor('#00000000');
      await tw.setWindowLayoutFullScreen(false);
      // 可触摸：承载 Pan/Tap 手势。窗口 112×112，贴边时一半伸出屏幕、屏幕内只挡
      // 气泡附近的小块，下层大部分可点。
      tw.setWindowTouchable(true);
      await tw.setWindowFocusable(false);
      await tw.showWindow();

      this.shown = true;
      // 同步给 AppStorage：设置页 @StorageLink(BUBBLE_RUNNING) 据此显示开关状态
      AppStorage.setOrCreate(AppKeys.BUBBLE_RUNNING, true);
      hilog.info(DOMAIN, TAG, 'create: done, shown=true');
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `create failed ${err.code} ${err.message}`);
      // 半成品窗口留着只会挡住下层又不响应手势，整体回滚让调用方能干净重试
      await this.destroy();
    }
  }

  /**
   * 移动交互层窗口左上角到指定屏幕坐标（单位 vp）。
   * 拖拽期间只在气泡接近窗口边缘时调（recenterIfNeeded），低频调用避免 WMS 振荡。
   * 去重：上一次 moveWindowTo 未完成时只记最新目标，完成后补一次。
   */
  moveTouchWindow(x: number, y: number): void {
    const win: window.Window | undefined = this.touchWin;
    if (!win) {
      return;
    }
    if (this.touchMoving) {
      this.touchPendingX = x;
      this.touchPendingY = y;
      this.touchHasPending = true;
      return;
    }
    this.doMoveTouch(win, x, y);
  }

  private async doMoveTouch(win: window.Window, x: number, y: number): Promise<void> {
    this.touchMoving = true;
    try {
      await win.moveWindowTo(vp2px(x), vp2px(y));
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `moveTouchWindow failed ${err.code} ${err.message}`);
    }
    this.touchMoving = false;
    // 执行期间若有更新的目标，补一次（只补最新的）
    if (this.touchHasPending) {
      const px: number = this.touchPendingX;
      const py: number = this.touchPendingY;
      this.touchHasPending = false;
      this.doMoveTouch(win, px, py);
    }
  }

  /**
   * 面板展开期间，视觉层需要短暂可触摸以接收面板行的点击。
   * 面板是偶发、短暂的模态，此期间不要求下层可点，所以临时开触摸是可接受的。
   */
  async setViewTouchable(touchable: boolean): Promise<void> {
    const win: window.Window | undefined = this.viewWin;
    if (!win) {
      return;
    }
    try {
      await win.setWindowTouchable(touchable);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `setViewTouchable failed ${err.code} ${err.message}`);
    }
  }

  async show(): Promise<void> {
    if (this.viewWin && !this.shown) {
      await this.viewWin.showWindow();
      if (this.touchWin) {
        await this.touchWin.showWindow();
      }
      this.shown = true;
    }
  }

  /**
   * HarmonyOS 的 TYPE_FLOAT 窗口没有"隐藏但不销毁"的 API，
   * 隐藏即销毁（与旧实现 BubbleWindow_legacy.hide() 走 destroyWindow 一致）。
   * 需要重新出现时调用 create() 重建。
   */
  async hide(): Promise<void> {
    await this.destroy();
  }

  async destroy(): Promise<void> {
    if (!this.viewWin && !this.touchWin) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'destroy: start');
    // 先销毁交互层，再销毁视觉层
    if (this.touchWin) {
      try {
        await this.touchWin.destroyWindow();
      } catch (e) {
        const err: BusinessError = e as BusinessError;
        hilog.error(DOMAIN, TAG, `destroy touch failed ${err.code} ${err.message}`);
      }
      this.touchWin = undefined;
      this.touchMoving = false;
      this.touchHasPending = false;
    }
    if (this.viewWin) {
      try {
        await this.viewWin.destroyWindow();
        hilog.info(DOMAIN, TAG, 'destroy: done');
      } catch (e) {
        const err: BusinessError = e as BusinessError;
        hilog.error(DOMAIN, TAG, `destroy view failed ${err.code} ${err.message}`);
      }
      this.viewWin = undefined;
    }
    this.shown = false;
    // 销毁后同步：设置页开关据此变 OFF（与 onClose hook 的写入互补，覆盖所有销毁入口）
    AppStorage.setOrCreate(AppKeys.BUBBLE_RUNNING, false);
  }

  isShown(): boolean {
    return this.shown;
  }
}
