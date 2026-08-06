/**
 * BubbleTouchPage.ets
 * 交互层悬浮窗的 UI 内容。渲染气泡本体 + 承载手势。
 *
 * 双窗口架构（见 BubbleWindowManager）：气泡外观渲染在这里（交互层窗口），
 * 而不是视觉层。原因：拖拽时每帧 moveWindowTo 移动交互层窗口，气泡跟着窗口
 * 原生移动（系统级同步，零延迟）；若气泡在视觉层靠 AppStorage 跨窗口同步坐标，
 * 同步频率跟不上 60fps，气泡会卡顿/闪烁。
 *
 * 低频状态（停靠侧、状态、条数）仍通过 AppStorage 从视觉层同步过来，
 * 它们更新不频繁，AppStorage 同步延迟无感知。
 * 注意：动画不能跨窗口同步，只能在本页本地 animateTo（见 onPulse）。
 */

import { curves } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BubbleWindowManager } from '../bubble/BubbleWindowManager';
import { DockEngine, DockSide, DockState, Rect } from '../bubble/DockEngine';
import { AppKeys } from '../bubble/AppKeys';
import { BubbleBadge, BubbleIcon } from '../bubble/BubbleIcon';
import { BubbleColor, BubbleMotion, BubbleShape, BubbleSize } from '../bubble/BubbleTokens';

const TAG: string = 'CopyBubble/Touch';
const DOMAIN: number = 0x1001;

@Entry
@Component
struct BubbleTouchPage {
  /** 气泡横坐标，vp。手势更新时写，驱动 moveTouchWindow */
  @StorageLink(AppKeys.BUBBLE_X) @Watch('onPosFromView') bubbleX: number = 0;
  /** 气泡纵坐标，vp */
  @StorageLink(AppKeys.BUBBLE_Y) @Watch('onPosFromView') bubbleY: number = 240;
  /** 拖拽中？拖拽结束时（true→false）触发视觉层吸附 */
  @StorageLink(AppKeys.BUBBLE_DRAGGING) dragging: boolean = false;
  /** 点击信号，每 +1 一次 */
  @StorageLink(AppKeys.BUBBLE_TAP) tapTick: number = 0;
  /** 是否进入隐藏吸入区 */
  @StorageLink(AppKeys.BUBBLE_DISMISS_ARMED) dismissArmed: boolean = false;
  /** 气泡状态（视觉层写，本组件读以渲染外观形变）。停靠/吸附/展开时窗口向屏外
   *  顶出（见 centerWindowOn），状态边沿必须重新定位窗口 */
  @StorageLink(AppKeys.BUBBLE_STATE) @Watch('onStateSideChange') state: string = DockState.Docked;
  /** 停靠侧 */
  @StorageLink(AppKeys.BUBBLE_SIDE) @Watch('onStateSideChange') side: string = DockSide.Right;
  /** 记录条数（角标用）*/
  @StorageLink(AppKeys.BUBBLE_ITEM_COUNT) itemCount: number = 0;
  /**
   * 捕获信号，每 +1 触发一次波纹。动画必须在本窗口本地跑：波纹圆是本页渲染的，
   * 若由视觉层 animateTo 再经 AppStorage 同步过来，跨窗口只会收到动画终值
   * （alpha=0），波纹等于永远看不见。
   */
  @StorageLink(AppKeys.PULSE) @Watch('onPulse') pulseTick: number = 0;
  @State private pulseScale: number = 1;
  @State private pulseAlpha: number = 0;

  private engine: DockEngine = new DockEngine(360, 780);
  private dragOriginX: number = 0;
  private dragOriginY: number = 0;
  private dragAccX: number = 0;
  private dragAccY: number = 0;
  private dragPrevOffX: number = 0;
  private dragPrevOffY: number = 0;
  private static readonly DRAG_STEP_LIMIT: number = 80;
  private mgr: BubbleWindowManager = BubbleWindowManager.get();
  /** 交互层窗口左上角的屏幕坐标 vp（气泡用 bubbleXY - winXY 得到窗口内偏移） */
  @State private winX: number = 0;
  @State private winY: number = 0;
  /** 窗口需要居中/顶出时，气泡距窗口边缘的最小留白 vp，小于此值才 moveWindowTo。
   *  16 ≈ 1 帧 @1000vp/s：异步追窗一帧内气泡不至于顶到窗口边缘（出窗即断触） */
  private static readonly RECENTER_MARGIN: number = 16;

  aboutToAppear(): void {
    // 交互层的拖拽钳制、底部吸入区判定全靠 engine，必须喂真实屏幕尺寸。
    // 用构造默认的 360×780 会让 clampDragY / inDismissZone 在真机上整体偏移。
    const s: Rect = this.mgr.screenSizeVp();
    this.engine.updateScreen(s.w, s.h);
    const savedSide: string = AppStorage.get<string>(AppKeys.LAST_SIDE) ?? 'R';
    const side: DockSide = savedSide === 'L' ? DockSide.Left : DockSide.Right;
    const savedY: number = AppStorage.get<number>(AppKeys.LAST_Y) ?? 240;
    this.bubbleY = this.engine.clampY(savedY);
    this.bubbleX = this.engine.restX(side);
    // 初始把窗口居中在气泡上
    this.centerWindowOn();
    hilog.info(DOMAIN, TAG,
      `aboutToAppear screen=${s.w}x${s.h} bubble=(${this.bubbleX},${this.bubbleY}) win=(${this.winX},${this.winY})`);
  }

  /** 捕获到一条新剪贴内容：在本窗口跑一次扩散波纹 */
  private onPulse(): void {
    if (this.pulseTick <= 0 || this.state === DockState.Hidden) {
      return;
    }
    this.pulseScale = 1;
    this.pulseAlpha = 0.9;
    this.getUIContext().animateTo({ duration: BubbleMotion.PULSE_DURATION, curve: Curve.EaseOut }, () => {
      this.pulseScale = BubbleMotion.SCALE_PULSE_TO;
      this.pulseAlpha = 0;
    });
  }

  /**
   * 定位交互层窗口。贴边态（Docked/Snapping/Expanded）窗口向屏外方向顶到底：
   * 气泡压到窗口内缘（局部坐标 = RECENTER_MARGIN 或 maxLocal），窗口伸出屏幕的
   * 部分不挡下层，把屏幕内遮挡压到最小（右贴边时 50×112，居中则是 66×112）。
   * 拖拽中（Free）必须居中：四周留白足够手指活动，追窗时才不会出窗断触。
   */
  private centerWindowOn(): void {
    const winHalf: number = BubbleSize.TOUCH_WIN / 2;
    const bubbleHalf: number = BubbleSize.HIT_AREA / 2;
    if (this.state === DockState.Docked || this.state === DockState.Snapping ||
      this.state === DockState.Expanded) {
      const maxLocal: number = BubbleSize.TOUCH_WIN - BubbleSize.HIT_AREA -
        BubbleTouchPage.RECENTER_MARGIN;
      // 右贴边窗口往右顶（气泡在局部左侧内缘），左贴边往左顶（气泡在右侧内缘）
      this.winX = this.side === DockSide.Right
        ? this.bubbleX - BubbleTouchPage.RECENTER_MARGIN
        : this.bubbleX - maxLocal;
    } else {
      this.winX = this.bubbleX + bubbleHalf - winHalf;
    }
    this.winY = this.bubbleY + bubbleHalf - winHalf;
    this.mgr.moveTouchWindow(this.winX, this.winY);
  }

  /** 停靠态/停靠侧变化（吸附完成、面板开关）：按新的贴边几何重新顶出窗口 */
  private onStateSideChange(): void {
    this.centerWindowOn();
  }

  /**
   * 气泡接近窗口边缘时才重新居中窗口（低频 moveWindowTo，避免高频振荡）。
   * 气泡在窗口内的位置 = bubbleXY - winXY，必须在 [RECENTER_MARGIN, winSize-bubbleSize-MARGIN] 内。
   */
  private recenterIfNeeded(): void {
    const localX: number = this.bubbleX - this.winX;
    const localY: number = this.bubbleY - this.winY;
    const maxLocal: number = BubbleSize.TOUCH_WIN - BubbleSize.HIT_AREA - BubbleTouchPage.RECENTER_MARGIN;
    if (localX < BubbleTouchPage.RECENTER_MARGIN || localX > maxLocal ||
      localY < BubbleTouchPage.RECENTER_MARGIN || localY > maxLocal) {
      this.centerWindowOn();
    }
  }

  /** 视觉层动画写 BUBBLE_X/Y 时跟随（非拖拽时，低频） */
  private onPosFromView(): void {
    if (!this.dragging) {
      this.centerWindowOn();
    }
  }

  private isDockedShape(): boolean {
    return this.state === DockState.Docked || this.state === DockState.Expanded;
  }

  build() {
    // 气泡本体 + 手势。气泡用 .position() 在 TOUCH_WIN 见方的窗口内移动（ArkUI 原生渲染），
    // 窗口只在气泡接近边缘时才 moveWindowTo 居中（低频，避免高频振荡）。
    Stack({ alignContent: Alignment.TopStart }) {
      // 捕获波纹
      Circle()
        .width(BubbleSize.BUBBLE)
        .height(BubbleSize.BUBBLE)
        .fill(Color.Transparent)
        .stroke(BubbleColor.PULSE)
        .strokeWidth(2)
        .scale({ x: this.pulseScale, y: this.pulseScale })
        .opacity(this.pulseAlpha)
        .hitTestBehavior(HitTestMode.None)

      // 气泡本体
      Stack({ alignContent: Alignment.Center }) {
        BubbleIcon({
          scaleRatio: BubbleSize.SCALE,
          ghostVisible: true,
          shiftX: this.isDockedShape()
            ? (this.side === DockSide.Left
              ? BubbleShape.DOCK_GLYPH_SHIFT
              : -BubbleShape.DOCK_GLYPH_SHIFT)
            : 0
        })
      }
      .width(BubbleSize.BUBBLE)
      .height(BubbleSize.BUBBLE)
      .linearGradient({
        angle: 150,
        colors: [[BubbleColor.GRAD_A, 0], [BubbleColor.GRAD_B, 0.52], [BubbleColor.GRAD_C, 1]]
      })
      .borderRadius(this.isDockedShape()
        ? (this.side === DockSide.Left
          ? {
              topLeft: 0, bottomLeft: 0,
              topRight: BubbleShape.BUBBLE_RADIUS, bottomRight: BubbleShape.BUBBLE_RADIUS
            }
          : {
              topLeft: BubbleShape.BUBBLE_RADIUS, bottomLeft: BubbleShape.BUBBLE_RADIUS,
              topRight: 0, bottomRight: 0
            })
        : BubbleShape.BUBBLE_RADIUS)
      .border({ width: 1, color: BubbleColor.RIM })
      .shadow(this.dragging
        ? { radius: 30, color: '#D90A0E32', offsetX: 0, offsetY: 16 }
        : { radius: 20, color: '#B8141A50', offsetX: 0, offsetY: 8 })
      .animation({
        duration: BubbleMotion.MORPH_DURATION,
        curve: curves.cubicBezierCurve(0.3, 0.9, 0.3, 1)
      })

      // 角标
      BubbleBadge({
        count: this.itemCount,
        onLeft: this.side === DockSide.Right,
        visible: this.itemCount > 0,
        scaleRatio: BubbleSize.BADGE_SCALE
      })
        // 挂角偏移跟气泡走（SCALE），角标自身大小跟 BADGE_SCALE 走（见 BubbleBadge）
        .position(this.side === DockSide.Right
          ? { x: -3 * BubbleSize.SCALE, y: -3 * BubbleSize.SCALE }
          : { x: BubbleSize.BUBBLE - 13 * BubbleSize.SCALE, y: -3 * BubbleSize.SCALE })
    }
    .width(BubbleSize.HIT_AREA)
    .height(BubbleSize.HIT_AREA)
    .scale(this.dragging
      ? { x: BubbleMotion.SCALE_DRAG, y: BubbleMotion.SCALE_DRAG }
      : { x: 1, y: 1 })
    // 气泡在窗口内的位置 = 屏幕坐标 - 窗口左上角。ArkUI 原生渲染，60fps 无振荡。
    .position({ x: this.bubbleX - this.winX, y: this.bubbleY - this.winY })
    .visibility(this.state === DockState.Hidden ? Visibility.Hidden : Visibility.Visible)
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        PanGesture({ fingers: 1, distance: 3 })
          .onActionStart((e: GestureEvent) => {
            this.dragOriginX = this.bubbleX;
            this.dragOriginY = this.bubbleY;
            this.dragAccX = 0;
            this.dragAccY = 0;
            this.dragPrevOffX = e.offsetX;
            this.dragPrevOffY = e.offsetY;
            this.dragging = true;
            hilog.info(DOMAIN, TAG,
              `drag START origin=(${this.dragOriginX},${this.dragOriginY}) off=(${e.offsetX},${e.offsetY})`);
          })
          .onActionUpdate((e: GestureEvent) => {
            const stepX: number = e.offsetX - this.dragPrevOffX;
            const stepY: number = e.offsetY - this.dragPrevOffY;
            if (Math.abs(stepX) < BubbleTouchPage.DRAG_STEP_LIMIT) {
              this.dragAccX += stepX;
            }
            if (Math.abs(stepY) < BubbleTouchPage.DRAG_STEP_LIMIT) {
              this.dragAccY += stepY;
            }
            this.dragPrevOffX = e.offsetX;
            this.dragPrevOffY = e.offsetY;
            this.bubbleX = this.engine.clampDragX(this.dragOriginX + this.dragAccX);
            this.bubbleY = this.engine.clampDragY(this.dragOriginY + this.dragAccY);
            // 只在气泡接近窗口边缘时才 moveWindowTo（低频），否则靠 position 移动
            this.recenterIfNeeded();
            this.dismissArmed = this.engine.inDismissZone(this.bubbleX, this.bubbleY);
          })
          .onActionEnd(() => {
            hilog.info(DOMAIN, TAG,
              `drag END at (${this.bubbleX},${this.bubbleY}) dismissArmed=${this.dismissArmed}`);
            this.dragging = false;
          }),
        TapGesture({ count: 1 })
          .onAction(() => {
            hilog.info(DOMAIN, TAG, 'tap');
            this.tapTick += 1;
          })
      )
    )
  }
}
