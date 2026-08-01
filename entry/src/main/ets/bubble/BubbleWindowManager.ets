/**
 * BubbleWindowManager.ets
 * 悬浮窗宿主。把吸附计算留在 DockEngine，这里只负责搬窗口。
 *
 * 双窗口架构（根治 resize 闪烁 + 保留下层触摸穿透）：
 *   视觉层（viewWin，copy_bubble_view）：常驻全屏、不可触摸。渲染气泡外观、
 *     面板、波纹等所有纯视觉内容。setWindowTouchable(false) 让触摸整窗穿透到
 *     下层 app，全屏也不挡下层。永不 resize（创建时铺满一次）→ 永不闪。
 *   交互层（touchWin，copy_bubble_touch）：48×48、可触摸。透明的手势热区，
 *     承载 PanGesture/TapGesture。只 moveWindowTo 跟随气泡（不 resize）→ 不闪；
 *     只挡气泡那 48×48，下层 app 在气泡之外完全可点。
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
  /** 视觉层上一次已应用的目标矩形（vp）。恒为全屏，去重跳过用。 */
  private lastViewRect: Rect = { x: 0, y: 0, w: 0, h: 0 };

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
    if (this.viewWin) {
      hilog.info(DOMAIN, TAG, 'create: already exists, skip');
      return;
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
      this.lastViewRect = s;
      await vw.showWindow();

      // ---- 交互层：48×48、可触摸、跟随气泡 ----
      // 必须在视觉层之后创建：后创建的 TYPE_FLOAT 默认 z-order 更高，交互层要
      // 在视觉层之上才能收到触摸。
      const touchCfg: window.Configuration = {
        name: TOUCH_WINDOW_NAME,
        windowType: window.WindowType.TYPE_FLOAT,
        ctx: ctx
      };
      const tw: window.Window = await window.createWindow(touchCfg);
      this.touchWin = tw;
      // 交互层窗口尺寸：3×3 气泡热区（144×144 vp）。气泡在窗口内用 .position() 移动
      // （ArkUI 原生渲染，无 WMS 异步振荡），只在气泡接近窗口边缘时才 moveWindowTo
      // 重新居中——从每帧 60+ 次降到整个拖拽过程数次，消除高频 moveWindowTo 振荡。
      await tw.resize(vp2px(144), vp2px(144));
      await tw.moveWindowTo(vp2px(s.w), vp2px(0));
      await tw.setUIContent('pages/BubbleTouchPage');
      tw.setWindowBackgroundColor('#00000000');
      await tw.setWindowLayoutFullScreen(false);
      // 可触摸：承载 Pan/Tap 手势。窗口 144×144，比气泡大但远小于全屏，下层大部分可点。
      tw.setWindowTouchable(true);
      await tw.setWindowFocusable(false);
      await tw.showWindow();

      this.shown = true;
      hilog.info(DOMAIN, TAG, 'create: done, shown=true');
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `create failed ${err.code} ${err.message}`);
    }
  }

  /**
   * 视觉层目标矩形回调（单位 vp）。
   * 视觉层恒为全屏（见 DockEngine.windowRect），运行期 emitRect 回调的矩形与
   * 创建时一致，下面的去重会跳过，零窗口操作。
   */
  async applyRect(r: Rect): Promise<void> {
    const win: window.Window | undefined = this.viewWin;
    if (!win) {
      hilog.warn(DOMAIN, TAG, `applyRect: no view window, drop ${JSON.stringify(r)}`);
      return;
    }
    if (r.x === this.lastViewRect.x && r.y === this.lastViewRect.y &&
      r.w === this.lastViewRect.w && r.h === this.lastViewRect.h) {
      return;
    }
    this.lastViewRect = { x: r.x, y: r.y, w: r.w, h: r.h };
    hilog.info(DOMAIN, TAG, `applyRect(view) vp x=${r.x} y=${r.y} w=${r.w} h=${r.h}`);
    try {
      await win.moveWindowTo(vp2px(r.x), vp2px(r.y));
      await win.resize(vp2px(r.w), vp2px(r.h));
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `applyRect failed ${err.code} ${err.message}`);
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
  }

  isShown(): boolean {
    return this.shown;
  }
}
