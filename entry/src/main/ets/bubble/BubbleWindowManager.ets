/**
 * BubbleWindowManager.ets
 * 悬浮窗宿主。把吸附计算留在 DockEngine，这里只负责搬窗口。
 *
 * 窗口尺寸策略：
 *   收起时窗口只有气泡那么大 → 窗口以外区域完全不拦截下层应用触摸；
 *   拖拽时铺满全屏 → 手指移出小窗不会断触；
 *   展开时扩到气泡 + 面板的并集。
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
const WINDOW_NAME: string = 'copy_bubble_float';

export class BubbleWindowManager {
  private static instance: BubbleWindowManager | undefined = undefined;
  private win: window.Window | undefined = undefined;
  private ctx: common.UIAbilityContext | undefined = undefined;
  private shown: boolean = false;
  /** 上一次已应用的目标矩形（vp）。相同目标直接跳过，避免拖拽每帧重复搬窗。 */
  private lastRect: Rect = { x: 0, y: 0, w: 0, h: 0 };

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
    if (this.win) {
      hilog.info(DOMAIN, TAG, 'create: already exists, skip');
      return;
    }
    this.ctx = ctx;
    hilog.info(DOMAIN, TAG, 'create: start');
    try {
      const cfg: window.Configuration = {
        name: WINDOW_NAME,
        windowType: window.WindowType.TYPE_FLOAT,
        ctx: ctx
      };
      const w: window.Window = await window.createWindow(cfg);
      this.win = w;
      hilog.info(DOMAIN, TAG, 'create: window created');
      await w.setUIContent('pages/BubbleWindowPage');
      w.setWindowBackgroundColor('#00000000');
      await w.setWindowLayoutFullScreen(false);
      // TYPE_FLOAT 默认不接收触摸，必须显式打开，否则气泡的点按/拖拽手势全都不响应。
      // 收起后窗口会被 applyRect 收缩到只有气泡大小，窗口外的区域自然不拦截下层触摸。
      w.setWindowTouchable(true);
      // 初始铺满，组件挂载后会立刻回调 onWindowRectChange 收缩
      const s: Rect = this.screenSizeVp();
      hilog.info(DOMAIN, TAG, `create: screenSizeVp=${JSON.stringify(s)}`);
      await this.applyRect(s);
      await w.showWindow();
      this.shown = true;
      hilog.info(DOMAIN, TAG, 'create: done, shown=true');
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `create failed ${err.code} ${err.message}`);
    }
  }

  /**
   * 组件回调过来的目标矩形，单位 vp。
   *
   * 设计约束：收起/展开共用同一窗口矩形（见 DockEngine.windowRect），窗口
   * 只在拖拽/屏幕变化时改变。因此这里主要是 moveWindowTo 搬位置；resize 仅
   * 在拖拽开始/结束（铺满 ↔ 并集）时发生。
   */
  async applyRect(r: Rect): Promise<void> {
    const win: window.Window | undefined = this.win;
    if (!win) {
      hilog.warn(DOMAIN, TAG, `applyRect: no window, drop ${JSON.stringify(r)}`);
      return;
    }
    // 与上次目标完全一致就跳过：拖拽每帧 emitRect 出的全屏矩形内容不变，
    // 重复合规地跳过既省性能，也避免无谓的窗口操作。
    if (r.x === this.lastRect.x && r.y === this.lastRect.y &&
      r.w === this.lastRect.w && r.h === this.lastRect.h) {
      hilog.info(DOMAIN, TAG, `applyRect vp x=${r.x} y=${r.y} w=${r.w} h=${r.h} | unchanged, skip`);
      return;
    }
    this.lastRect = { x: r.x, y: r.y, w: r.w, h: r.h };
    hilog.info(DOMAIN, TAG, `applyRect vp x=${r.x} y=${r.y} w=${r.w} h=${r.h}`);
    try {
      await win.moveWindowTo(vp2px(r.x), vp2px(r.y));
      await win.resize(vp2px(r.w), vp2px(r.h));
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `applyRect failed ${err.code} ${err.message}`);
    }
  }

  async show(): Promise<void> {
    if (this.win && !this.shown) {
      await this.win.showWindow();
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
    if (!this.win) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'destroy: start');
    try {
      await this.win.destroyWindow();
      hilog.info(DOMAIN, TAG, 'destroy: done');
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `destroy failed ${err.code} ${err.message}`);
    }
    this.win = undefined;
    this.shown = false;
  }

  isShown(): boolean {
    return this.shown;
  }
}
