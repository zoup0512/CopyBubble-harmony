/**
 * FloatBubble.ets
 * 悬浮气泡主组件。把「贴边」当默认状态而不是收尾动作。
 *
 * 六态：
 *   Free ──抬手──> Snapping ──> Docked ──静置 2.5s──> Dozing
 *                                 │ 单击
 *                                 ↓
 *                              Expanded
 *   拖入底部吸入区 ──> Hidden
 *
 * 该组件不关心自己被放在悬浮窗里还是普通页面里，位置全部相对父容器左上角。
 * 窗口层的搬运通过 onWindowRectChange 回调交给宿主。
 */

import { curves } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BubbleColor, BubbleMotion, BubbleShape, BubbleSize } from './BubbleTokens';
import { DockEngine, DockSide, DockState, PanelAnchor, Rect } from './DockEngine';
import { BubbleBadge, BubbleIcon } from './BubbleIcon';
import { ClipboardPanel } from './ClipboardPanel';
import { ClipItem } from './ClipItem';
import { AppKeys } from './AppKeys';

const TAG: string = 'CopyBubble/Float';
const DOMAIN: number = 0x1001;

@Component
export struct FloatBubble {
  /** 宿主容器尺寸，vp */
  @Prop hostW: number = 360;
  @Prop hostH: number = 780;
  /** 面板配色跟随下层应用 */
  @Prop dark: boolean = false;
  @Prop items: ClipItem[] = [];

  /** 每次 +1 触发一次捕获波纹，业务侧调 BubbleBridge.notifyCaptured() 写入 */
  @StorageLink(AppKeys.PULSE) @Watch('onPulse') pulseTick: number = 0;
  /** 外部召回：置 false 即让隐藏的气泡回来 */
  @StorageLink(AppKeys.BUBBLE_HIDDEN) @Watch('onHiddenFlag') hiddenFlag: boolean = false;

  /** 窗口矩形变化回调，宿主据此 resize / move 悬浮窗 */
  onWindowRectChange: (r: Rect) => void = () => {};
  onPick: (item: ClipItem) => void = () => {};
  onHidden: () => void = () => {};
  onDockChange: (side: DockSide, y: number) => void = () => {};

  @State private state: DockState = DockState.Docked;
  @State private side: DockSide = DockSide.Right;
  @State private x: number = 0;
  @State private y: number = 240;
  @State private dragging: boolean = false;
  @State private pulseScale: number = 1;
  @State private pulseAlpha: number = 0;
  @State private dismissArmed: boolean = false;
  @State private dismissVisible: boolean = false;
  @State private panelShown: boolean = false;
  @State private anchor: PanelAnchor =
    { x: 0, y: 0, w: BubbleSize.PANEL_W, h: 120, originX: 1, originY: 0.5 };
  // 当前悬浮窗左上角的屏幕坐标。组件内部用「屏幕坐标 - 窗口原点」得到
  // 相对父容器的偏移。
  // 设计：收起与展开共用同一「并集矩形」（见 DockEngine.windowRect），原点
  // 恒为并集左上角（贴右时约 (92,193)），气泡相对坐标恒为 (restX-92, …)，
  // 窗口不 resize → ArkUI displayWindowRect 不滞后 → 气泡坐标永不跳变。
  // 拖拽态窗口铺满全屏，原点恒为 (0,0)，气泡用绝对屏幕坐标。
  @State private winX: number = 0;
  @State private winY: number = 0;

  private engine: DockEngine = new DockEngine(360, 780);
  private dozeTimer: number = -1;
  private panelTimer: number = -1;
  private dragOriginX: number = 0;
  private dragOriginY: number = 0;
  // 拖拽位移用「逐帧增量累加」计算，并丢弃单帧巨变。
  // 原因：拖拽开始时窗口从并集（~282×142）扩到全屏，窗口原点搬动会让
  // PanGesture 的 offsetX/offsetY 在某一帧瞬间跳变（正好等于原点位移）。
  // 真实手指每帧只有几到几十 vp，用阈值过滤掉这一帧跳变即可。
  private dragAccX: number = 0;
  private dragAccY: number = 0;
  private dragPrevOffX: number = 0;
  private dragPrevOffY: number = 0;
  // 单帧位移超过此值视为窗口 resize 跳变，丢弃。真实手指单帧位移远小于此。
  private static readonly DRAG_STEP_LIMIT: number = 80;

  aboutToAppear(): void {
    this.engine.updateScreen(this.hostW, this.hostH);
    // 恢复上次停靠位置
    const savedSide: string = AppStorage.get<string>(AppKeys.LAST_SIDE) ?? 'R';
    this.side = savedSide === 'L' ? DockSide.Left : DockSide.Right;
    const savedY: number = AppStorage.get<number>(AppKeys.LAST_Y) ?? 240;
    this.y = this.engine.clampY(savedY);
    this.x = this.engine.restX(this.side);
    hilog.info(DOMAIN, TAG,
      `aboutToAppear host=${this.hostW}x${this.hostH} screen=${this.engine.getScreenW()}x${this.engine.getScreenH()} ` +
      `side=${this.side} x=${this.x} y=${this.y}`);
    this.emitRect();
    this.scheduleDoze();
  }

  aboutToDisappear(): void {
    clearTimeout(this.dozeTimer);
    clearTimeout(this.panelTimer);
  }

  /* ---------------- 外部信号 ---------------- */

  /** 捕获到一条新剪贴内容：唤醒 + 波纹 */
  private onPulse(): void {
    if (this.pulseTick <= 0) {
      return;
    }
    if (this.state === DockState.Hidden) {
      // 隐藏状态下不自作主张跳出来，只静默累计
      return;
    }
    this.wake();
    this.pulseScale = 1;
    this.pulseAlpha = 0.9;
    animateTo({ duration: BubbleMotion.PULSE_DURATION, curve: Curve.EaseOut }, () => {
      this.pulseScale = BubbleMotion.SCALE_PULSE_TO;
      this.pulseAlpha = 0;
    });
  }

  private onHiddenFlag(): void {
    if (!this.hiddenFlag && this.state === DockState.Hidden) {
      this.state = DockState.Docked;
      this.settle();
    }
  }

  /* ---------------- 状态机 ---------------- */

  private isDockedShape(): boolean {
    return this.state === DockState.Docked ||
      this.state === DockState.Dozing ||
      this.state === DockState.Expanded;
  }

  /** 抬手后决定吸附侧并弹簧归位 */
  private settle(): void {
    this.side = this.engine.resolveSide(this.x);
    this.y = this.engine.clampY(this.y);
    this.state = DockState.Snapping;
    hilog.info(DOMAIN, TAG,
      `settle from=(${this.x},${this.y}) -> side=${this.side} restX=${this.engine.restX(this.side)} y=${this.y}`);
    animateTo({
      curve: curves.interpolatingSpring(
        BubbleMotion.SPRING_VELOCITY, BubbleMotion.SPRING_MASS,
        BubbleMotion.SPRING_STIFFNESS, BubbleMotion.SPRING_DAMPING)
    }, () => {
      this.x = this.engine.restX(this.side);
      this.state = DockState.Docked;
    });
    AppStorage.setOrCreate(AppKeys.LAST_SIDE, this.side === DockSide.Left ? 'L' : 'R');
    AppStorage.setOrCreate(AppKeys.LAST_Y, this.y);
    this.onDockChange(this.side, this.y);
    this.emitRect();
    this.scheduleDoze();
  }

  private scheduleDoze(): void {
    clearTimeout(this.dozeTimer);
    // [DEBUG] 暂时关闭休眠，便于确认气泡是否稳定显示在桌面上。
    // 确认无误后删掉这个 return 即可恢复"静置 2.5s 进入休眠"行为。
    hilog.info(DOMAIN, TAG, 'scheduleDoze: [DEBUG] doze disabled, stay Docked');
    return;
    this.dozeTimer = setTimeout(() => {
      if (this.state !== DockState.Docked) {
        return;
      }
      animateTo({ duration: BubbleMotion.DOZE_DURATION, curve: Curve.EaseOut }, () => {
        this.x = this.engine.dozeX(this.side);
        this.state = DockState.Dozing;
      });
      hilog.info(DOMAIN, TAG, `scheduleDoze: -> Dozing x=${this.engine.dozeX(this.side)}`);
      this.emitRect();
    }, BubbleMotion.DOZE_DELAY);
  }

  private wake(): void {
    if (this.state === DockState.Dozing) {
      animateTo({ duration: BubbleMotion.WAKE_DURATION, curve: Curve.EaseOut }, () => {
        this.x = this.engine.restX(this.side);
        this.state = DockState.Docked;
      });
      this.emitRect();
    }
    this.scheduleDoze();
  }

  private openPanel(): void {
    clearTimeout(this.dozeTimer);
    this.anchor = this.engine.panelAnchor(this.side, this.x, this.y, this.items.length);
    this.state = DockState.Expanded;
    this.x = this.engine.restX(this.side);
    this.emitRect();
    // 窗口先扩，下一帧再播动画，否则面板会被旧窗口边界裁掉
    clearTimeout(this.panelTimer);
    this.panelTimer = setTimeout(() => {
      this.panelShown = true;
    }, 16);
  }

  private closePanel(): void {
    this.panelShown = false;
    clearTimeout(this.panelTimer);
    this.panelTimer = setTimeout(() => {
      // 收起与展开共用同一窗口矩形（见 DockEngine.windowRect），这里只切
      // state 移除面板。窗口不 resize，displayWindowRect 不滞后，气泡坐标
      // 恒定 → 不闪。
      this.state = DockState.Docked;
      this.emitRect();
      this.scheduleDoze();
    }, BubbleMotion.MORPH_DURATION);
  }

  private hideBubble(): void {
    clearTimeout(this.dozeTimer);
    animateTo({
      duration: BubbleMotion.DISMISS_DURATION,
      curve: curves.springMotion(0.3, 0.9)
    }, () => {
      this.state = DockState.Hidden;
    });
    AppStorage.setOrCreate(AppKeys.BUBBLE_HIDDEN, true);
    this.onHidden();
  }

  private emitRect(): void {
    const r: Rect = this.engine.windowRect(
      this.state, this.side, this.x, this.y, this.items.length);
    // 记下窗口原点，build() 里把气泡/面板的屏幕坐标换算成相对窗口的坐标。
    // 收起态窗口原点 = 气泡左上角，所以 (x - winX, y - winY) = (0,0)。
    this.winX = r.x;
    this.winY = r.y;
    hilog.info(DOMAIN, TAG,
      `emitRect state=${this.state} side=${this.side} bubble=(${this.x},${this.y}) -> rect=(${r.x},${r.y},${r.w}x${r.h}) win=(${this.winX},${this.winY}) rel=(${this.x - this.winX},${this.y - this.winY})`);
    this.onWindowRectChange(r);
  }

  private handleTap(): void {
    if (this.state === DockState.Expanded) {
      this.closePanel();
    } else if (this.state === DockState.Dozing) {
      // 休眠态首次点击只负责唤醒。用户看到的是一个 42% 露出的模糊色块，
      // 他点它多半只是想看清那是什么，直接展开面板会很突兀。
      this.wake();
    } else {
      this.openPanel();
    }
  }

  private accessibilityLabel(): string {
    return `剪贴板，${this.items.length} 条记录`;
  }

  /* ---------------- 视图 ---------------- */

  @Builder
  bubbleView() {
    Stack({ alignContent: Alignment.Center }) {
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
          scaleRatio: 1,
          ghostVisible: this.state !== DockState.Dozing,
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
      // 贴边即形变：只保留朝向屏幕内侧的圆角
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
      // 深色应用底上靠 1vp 内描边保住轮廓
      .border({ width: 1, color: BubbleColor.RIM })
      // 拖拽期间换成静态阴影，不参与动画，避免掉帧
      .shadow(this.dragging
        ? { radius: 30, color: '#D90A0E32', offsetX: 0, offsetY: 16 }
        : { radius: 20, color: '#B8141A50', offsetX: 0, offsetY: 8 })
      .animation({
        duration: BubbleMotion.MORPH_DURATION,
        curve: curves.cubicBezierCurve(0.3, 0.9, 0.3, 1)
      })

      // 角标：贴右侧时移到左上角，否则数字会被藏进屏幕外
      BubbleBadge({
        count: this.items.length,
        onLeft: this.side === DockSide.Right,
        visible: this.state !== DockState.Dozing && this.items.length > 0
      })
        .position(this.side === DockSide.Right
          ? { x: -3, y: -3 }
          : { x: BubbleSize.BUBBLE - 13, y: -3 })
    }
    // 触控热区恒为 48×48，不随视觉露出收缩
    .width(BubbleSize.HIT_AREA)
    .height(BubbleSize.HIT_AREA)
    .opacity(this.state === DockState.Dozing
      ? BubbleMotion.OPACITY_DOZING : BubbleMotion.OPACITY_DOCKED)
    .scale(this.dragging
      ? { x: BubbleMotion.SCALE_DRAG, y: BubbleMotion.SCALE_DRAG }
      : { x: 1, y: 1 })
    .position({ x: this.x - this.winX, y: this.y - this.winY })
    .visibility(this.state === DockState.Hidden ? Visibility.Hidden : Visibility.Visible)
    // 贴边与休眠只是视觉状态，读屏文案恒定
    .accessibilityLevel('yes')
    .accessibilityText(this.accessibilityLabel())
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        PanGesture({ fingers: 1, distance: 3 })
          .onActionStart((e: GestureEvent) => {
            clearTimeout(this.dozeTimer);
            this.dragOriginX = this.x;
            this.dragOriginY = this.y;
            this.dragAccX = 0;
            this.dragAccY = 0;
            this.dragPrevOffX = e.offsetX;
            this.dragPrevOffY = e.offsetY;
            this.dragging = true;
            this.state = DockState.Free;
            this.panelShown = false;
            hilog.info(DOMAIN, TAG,
              `drag START origin=(${this.dragOriginX},${this.dragOriginY}) off=(${e.offsetX},${e.offsetY}) screen=${this.engine.getScreenW()}x${this.engine.getScreenH()}`);
            this.emitRect();
          })
          .onActionUpdate((e: GestureEvent) => {
            // 逐帧增量累加位移。onActionStart 里 emitRect 把窗口从 48×48 扩到全屏，
            // 窗口原点搬动会让本帧的 offsetX/Y 瞬间跳变 ~300vp。真实手指单帧位移小，
            // 用 DRAG_STEP_LIMIT 阈值丢弃这一帧跳变，累加值就不会被污染。
            const stepX: number = e.offsetX - this.dragPrevOffX;
            const stepY: number = e.offsetY - this.dragPrevOffY;
            if (Math.abs(stepX) < FloatBubble.DRAG_STEP_LIMIT) {
              this.dragAccX += stepX;
            }
            if (Math.abs(stepY) < FloatBubble.DRAG_STEP_LIMIT) {
              this.dragAccY += stepY;
            }
            this.dragPrevOffX = e.offsetX;
            this.dragPrevOffY = e.offsetY;
            this.x = this.engine.clampDragX(this.dragOriginX + this.dragAccX);
            this.y = this.engine.clampDragY(this.dragOriginY + this.dragAccY);
            this.dismissVisible = true;
            this.dismissArmed = this.engine.inDismissZone(this.x, this.y);
            hilog.info(DOMAIN, TAG,
              `drag UPDATE step=(${stepX},${stepY}) acc=(${this.dragAccX},${this.dragAccY}) -> (${this.x},${this.y}) dismiss=${this.dismissArmed}`);
          })
          .onActionEnd(() => {
            hilog.info(DOMAIN, TAG,
              `drag END at (${this.x},${this.y}) acc=(${this.dragAccX},${this.dragAccY}) dismissArmed=${this.dismissArmed}`);
            this.dragging = false;
            this.dismissVisible = false;
            if (this.dismissArmed) {
              this.dismissArmed = false;
              this.hideBubble();
              return;
            }
            this.settle();
          }),
        TapGesture({ count: 1 })
          .onAction(() => this.handleTap())
      )
    )
  }

  @Builder
  dismissZone() {
    Row({ space: 8 }) {
      Text('松手隐藏气泡')
        .fontSize(12)
        .fontColor('#EEF1FA')
    }
    .padding({ left: 16, right: 16, top: 9, bottom: 9 })
    .borderRadius(100)
    .backgroundColor(this.dismissArmed ? BubbleColor.DISMISS : '#DB080C1B')
    .border({ width: 1, color: '#59FF6B7A' })
    .scale({ x: this.dismissArmed ? 1.1 : 1, y: this.dismissArmed ? 1.1 : 1 })
    .opacity(this.dismissVisible ? 1 : 0)
    .animation({ duration: 220, curve: curves.cubicBezierCurve(0.2, 0.9, 0.3, 1.2) })
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 面板外任意点击即收起。不放关闭按钮，少一个可点击目标就少一次误触。
      if (this.state === DockState.Expanded) {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .onClick(() => this.closePanel())

        ClipboardPanel({
          items: this.items,
          dark: this.dark,
          originX: this.anchor.originX,
          originY: this.anchor.originY,
          shown: this.panelShown,
          onPick: (item: ClipItem) => {
            this.onPick(item);
            this.closePanel();
          }
        })
          .position({ x: this.anchor.x - this.winX, y: this.anchor.y - this.winY })
      }

      this.bubbleView()

      if (this.dismissVisible) {
        Column() {
          this.dismissZone()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .padding({ bottom: 26 })
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((oldArea: Area, newArea: Area) => {
      // 窗口尺寸会随气泡状态收缩（收起时只有 48×48），这里不能拿窗口尺寸当
      // 屏幕尺寸喂给 engine，否则窗口一缩就把"屏幕"缩成 48 宽，气泡会瞬间
      // 跳到错误位置、窗口也跟着错位，看起来就是闪一下消失。
      // 屏幕尺寸由宿主通过 hostW/hostH 传入，aboutToAppear 里已更新过。
      // 此处仅做尺寸变更兜底：若宿主容器比当前记录的屏幕大得多（横竖屏切换
      // 或窗口被外部拉大），才按宿主比例重算位置。
      const w: number = Number(newArea.width);
      const h: number = Number(newArea.height);
      if (w <= 0 || h <= 0) {
        return;
      }
      const curW: number = this.engine.getScreenW();
      const curH: number = this.engine.getScreenH();
      hilog.info(DOMAIN, TAG,
        `onAreaChange area=${w}x${h} curScreen=${curW}x${curH} state=${this.state}`);
      // 只有在容器明显大于当前记录的屏幕尺寸时才认为"屏幕变了"
      if (w <= curW + 1 && h <= curH + 1) {
        hilog.info(DOMAIN, TAG, 'onAreaChange: shrink/no-change, skip engine update');
        return;
      }
      const oldH: number = curH;
      this.engine.updateScreen(w, h);
      // 横竖屏切换：按旧比例还原纵向位置，side 保持不变
      this.y = this.engine.remapOnResize(this.y, oldH, h);
      if (this.state !== DockState.Free && this.state !== DockState.Hidden) {
        this.x = this.state === DockState.Dozing
          ? this.engine.dozeX(this.side)
          : this.engine.restX(this.side);
      }
      hilog.info(DOMAIN, TAG, `onAreaChange: screen grew -> resync x=${this.x} y=${this.y}`);
      this.emitRect();
    })
  }
}
