/**
 * DockEngine.test.ets
 * 贴边几何的单测。DockEngine 之所以抽成纯逻辑，就是为了能这样测。
 */

import { describe, expect, it } from '@ohos/hypium';
import { DockEngine, DockSide, DockState, PanelAnchor, Rect } from '../../../main/ets/bubble/DockEngine';
import { BubbleSize } from '../../../main/ets/bubble/BubbleTokens';

const W: number = 360;
const H: number = 780;

export default function dockEngineTest() {
  describe('DockEngineTest', () => {

    it('中心点落在左半屏时吸左边', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      // x=100 时中心为 124 < 180
      expect(e.resolveSide(100)).assertEqual(DockSide.Left);
    });

    it('中心点落在右半屏时吸右边', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      // x=200 时中心为 224 >= 180
      expect(e.resolveSide(200)).assertEqual(DockSide.Right);
    });

    it('恰好在中线时归右，不产生歧义', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      const xAtCenter: number = W / 2 - BubbleSize.BUBBLE / 2;
      expect(e.resolveSide(xAtCenter)).assertEqual(DockSide.Right);
    });

    it('左侧贴边后 x 为负值，气泡左半出屏', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      const x: number = e.restX(DockSide.Left);
      expect(x).assertEqual(BubbleSize.PEEK_DOCKED - BubbleSize.BUBBLE);
      expect(x < 0).assertTrue();
    });

    it('右侧贴边后露出宽度等于 PEEK_DOCKED', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      const x: number = e.restX(DockSide.Right);
      expect(W - x).assertEqual(BubbleSize.PEEK_DOCKED);
    });

    it('休眠位比常驻位更靠外', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      expect(e.dozeX(DockSide.Left) < e.restX(DockSide.Left)).assertTrue();
      expect(e.dozeX(DockSide.Right) > e.restX(DockSide.Right)).assertTrue();
    });

    it('纵向钳制在安全区内', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      expect(e.clampY(-100)).assertEqual(BubbleSize.SAFE_TOP);
      expect(e.clampY(9999))
        .assertEqual(H - BubbleSize.BUBBLE - BubbleSize.SAFE_BOTTOM);
      expect(e.clampY(300)).assertEqual(300);
    });

    it('贴左时面板向右开，贴右时向左开', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      const left: PanelAnchor = e.panelAnchor(DockSide.Left, e.restX(DockSide.Left), 300, 3);
      const right: PanelAnchor = e.panelAnchor(DockSide.Right, e.restX(DockSide.Right), 300, 3);
      expect(left.originX).assertEqual(0);
      expect(right.originX).assertEqual(1);
      expect(left.x < right.x).assertTrue();
    });

    it('面板不会溢出屏幕上下边界', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      const top: PanelAnchor = e.panelAnchor(DockSide.Right, 0, 0, 6);
      const bottom: PanelAnchor = e.panelAnchor(DockSide.Right, 0, H, 6);
      expect(top.y >= BubbleSize.SAFE_TOP - 6).assertTrue();
      expect(bottom.y + bottom.h <= H - BubbleSize.SAFE_BOTTOM).assertTrue();
    });

    it('收起时窗口保持展开态并集尺寸（不缩窗，避免 displayWindowRect 滞后闪烁）', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      const bx: number = e.restX(DockSide.Right);
      const docked: Rect = e.windowRect(DockState.Docked, DockSide.Right, bx, 300, 3);
      const expanded: Rect = e.windowRect(DockState.Expanded, DockSide.Right, bx, 300, 3);
      // 收起与展开共用同一矩形：窗口尺寸跨状态不变 → ArkUI displayWindowRect
      // 不滞后 → 气泡坐标恒定，关闭面板不闪（代价：收起态窗口区域拦截触摸）。
      expect(docked.w).assertEqual(expanded.w);
      expect(docked.h).assertEqual(expanded.h);
      expect(docked.x).assertEqual(expanded.x);
      expect(docked.y).assertEqual(expanded.y);
    });

    it('拖拽时窗口铺满，避免手指移出小窗断触', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      const r: Rect = e.windowRect(DockState.Free, DockSide.Right, 120, 300, 3);
      expect(r.w).assertEqual(W);
      expect(r.h).assertEqual(H);
    });

    it('展开时窗口覆盖气泡与面板的并集', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      const bx: number = e.restX(DockSide.Right);
      const a: PanelAnchor = e.panelAnchor(DockSide.Right, bx, 300, 3);
      const r: Rect = e.windowRect(DockState.Expanded, DockSide.Right, bx, 300, 3);
      expect(r.x <= a.x).assertTrue();
      expect(r.x + r.w >= bx + BubbleSize.BUBBLE).assertTrue();
    });

    it('底部中央为隐藏吸入区，其他位置不触发', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      const cx: number = W / 2 - BubbleSize.BUBBLE / 2;
      expect(e.inDismissZone(cx, H - 60)).assertTrue();
      expect(e.inDismissZone(cx, 300)).assertFalse();
      expect(e.inDismissZone(0, H - 60)).assertFalse();
    });

    it('横竖屏切换按旧比例还原纵向位置', 0, () => {
      const e: DockEngine = new DockEngine(W, 400);
      // 原本在 780 高度的一半，切到 400 后应仍在中间附近
      const y: number = e.remapOnResize(390, 780, 400);
      expect(Math.abs(y - 200) < 1).assertTrue();
    });
  });
}
