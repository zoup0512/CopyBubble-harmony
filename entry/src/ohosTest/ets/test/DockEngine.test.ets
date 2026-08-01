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

    it('视觉层窗口所有状态都铺满全屏（双窗口架构：永不 resize 避免桌面闪烁）', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      const bx: number = e.restX(DockSide.Right);
      const states: DockState[] = [
        DockState.Free, DockState.Snapping, DockState.Docked, DockState.Dozing, DockState.Expanded
      ];
      // 双窗口架构：视觉层全屏、不可触摸（触摸穿透），永不 resize（resize 会让 WMS
      // 重建 surface，中间帧覆盖整屏 = 桌面闪）。所有状态都返回整屏矩形。
      for (const s of states) {
        const r: Rect = e.windowRect(s, DockSide.Right, bx, 300, 3);
        expect(r.x).assertEqual(0);
        expect(r.y).assertEqual(0);
        expect(r.w).assertEqual(W);
        expect(r.h).assertEqual(H);
      }
    });

    it('交互层窗口覆盖气泡触控热区，跟随气泡移动', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      // 交互层只 move 不 resize，恒为 HIT_AREA×HIT_AREA，左上角对齐气泡
      const r: Rect = e.touchRect(120, 300);
      expect(r.x).assertEqual(120);
      expect(r.y).assertEqual(300);
      expect(r.w).assertEqual(BubbleSize.HIT_AREA);
      expect(r.h).assertEqual(BubbleSize.HIT_AREA);
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
