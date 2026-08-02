/**
 * DockEngine.ets
 * 贴边几何与状态机。纯逻辑，不依赖 UI，可单独做单测。
 *
 * 设计要点：
 *   1. 只吸左右两条边。顶部有状态栏与胶囊，底部有手势导航条，
 *      气泡贴上去等于主动制造误触。
 *   2. 吸附判定用中心点而非边界，避免气泡在边缘附近来回横跳。
 *   3. 展开方向是气泡当前位置的函数，不是配置项。
 */

import { BubbleSize } from './BubbleTokens';

export enum DockState {
  /** 手指按住，自由拖拽 */
  Free = 'free',
  /** 抬手瞬间，弹簧归位中 */
  Snapping = 'snapping',
  /** 贴边常驻，露出 71% */
  Docked = 'docked',
  /** 面板展开 */
  Expanded = 'expanded',
  /** 拖入底部吸入区后隐藏 */
  Hidden = 'hidden'
}

export enum DockSide {
  Left = 'L',
  Right = 'R'
}

export interface Point {
  x: number;
  y: number;
}

export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

/** 面板锚点结果：位置 + 缩放原点百分比 */
export interface PanelAnchor {
  x: number;
  y: number;
  w: number;
  h: number;
  /** 缩放原点，0 = 左/上，1 = 右/下 */
  originX: number;
  originY: number;
}

export class DockEngine {
  private screenW: number = 360;
  private screenH: number = 780;

  constructor(screenW: number, screenH: number) {
    this.screenW = screenW;
    this.screenH = screenH;
  }

  updateScreen(w: number, h: number): void {
    this.screenW = w;
    this.screenH = h;
  }

  getScreenW(): number {
    return this.screenW;
  }

  getScreenH(): number {
    return this.screenH;
  }

  /**
   * 依据气泡中心点决定吸附到哪一侧。
   * side = Left  当 xc < W/2
   * side = Right 当 xc >= W/2
   */
  resolveSide(x: number): DockSide {
    const centerX: number = x + BubbleSize.BUBBLE / 2;
    return centerX < this.screenW / 2 ? DockSide.Left : DockSide.Right;
  }

  /** 纵向安全区钳制：y = clamp(y, SAFE_TOP, H - d - SAFE_BOTTOM) */
  clampY(y: number): number {
    const min: number = BubbleSize.SAFE_TOP;
    const max: number = this.screenH - BubbleSize.BUBBLE - BubbleSize.SAFE_BOTTOM;
    if (max < min) {
      return min;
    }
    return Math.min(Math.max(y, min), max);
  }

  /** 拖拽期间的横向软边界，允许略微出屏但不脱手 */
  clampDragX(x: number): number {
    const half: number = BubbleSize.BUBBLE / 2;
    return Math.min(Math.max(x, -half), this.screenW - half);
  }

  clampDragY(y: number): number {
    return Math.min(Math.max(y, BubbleSize.SAFE_TOP - 14),
      this.screenH - BubbleSize.BUBBLE - 12);
  }

  /**
   * 贴边常驻位的横坐标。
   * 左侧为负值（气泡左半出屏），右侧为 W - PEEK_DOCKED。
   */
  restX(side: DockSide): number {
    return side === DockSide.Left
      ? BubbleSize.PEEK_DOCKED - BubbleSize.BUBBLE
      : this.screenW - BubbleSize.PEEK_DOCKED;
  }

  /** 是否落在底部隐藏吸入区内 */
  inDismissZone(x: number, y: number): boolean {
    const cx: number = x + BubbleSize.BUBBLE / 2;
    const cy: number = y + BubbleSize.BUBBLE / 2;
    const nearBottom: boolean = cy > this.screenH - BubbleSize.DISMISS_ZONE_H;
    const nearCenter: boolean = Math.abs(cx - this.screenW / 2) < BubbleSize.DISMISS_R;
    return nearBottom && nearCenter;
  }

  /**
   * 面板锚点。贴左往右开、贴右往左开；
   * 靠近下缘时锚点翻到面板底部，让卡片向上生长。
   * 缩放原点始终落在气泡圆心，形变读起来是「气泡长成了卡片」。
   */
  panelAnchor(side: DockSide, bubbleX: number, bubbleY: number, itemCount: number): PanelAnchor {
    const w: number = BubbleSize.PANEL_W;
    // 空状态（emptyState）渲染高度为 PANEL_EMPTY_H，不是单行 ITEM_H，
    // 必须按实际渲染高度算窗口，否则最后一行文案会被窗口下沿裁掉。
    const bodyH: number = itemCount === 0 ? BubbleSize.PANEL_EMPTY_H :
      BubbleSize.ITEM_H * itemCount;
    const h: number = BubbleSize.PANEL_HEAD_H + BubbleSize.PANEL_PAD * 2 + bodyH;

    // 展开时气泡先回到常驻位，避免从休眠位算出偏移
    const bx: number = this.restX(side);

    let px: number = side === DockSide.Left
      ? bx + BubbleSize.BUBBLE + BubbleSize.PANEL_GAP
      : bx - w - BubbleSize.PANEL_GAP;
    px = Math.min(Math.max(px, 8), this.screenW - w - 8);

    const bubbleCenterY: number = bubbleY + BubbleSize.BUBBLE / 2;
    let py: number = bubbleCenterY - h / 2;
    py = Math.min(Math.max(py, BubbleSize.SAFE_TOP - 6),
      this.screenH - h - BubbleSize.SAFE_BOTTOM);

    const originX: number = side === DockSide.Left ? 0 : 1;
    let originY: number = (bubbleCenterY - py) / h;
    originY = Math.min(Math.max(originY, 0), 1);

    return { x: px, y: py, w: w, h: h, originX: originX, originY: originY };
  }

  /** 横竖屏切换后按旧比例还原纵向位置，side 保持不变 */
  remapOnResize(oldY: number, oldH: number, newH: number): number {
    if (oldH <= 0) {
      return this.clampY(oldY);
    }
    const ratio: number = oldY / oldH;
    return this.clampY(ratio * newH);
  }
}
