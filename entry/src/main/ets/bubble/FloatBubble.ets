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
import { BubbleColor, BubbleMotion, BubbleSize } from './BubbleTokens';
import { DockEngine, DockSide, DockState, PanelAnchor, Rect } from './DockEngine';
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

  /* ---- 交互层 → 视觉层信号（双窗口架构）---- */
  // 交互层窗口（BubbleTouchPage）捕获手势后，把气泡坐标/手势状态写进 AppStorage，
  // 视觉层（本组件）读这些值渲染气泡。两个窗口是独立 UI 实例，只能靠 AppStorage 通信。
  /** 气泡横坐标 vp。交互层拖拽时写，本组件读以定位气泡 */
  @StorageLink(AppKeys.BUBBLE_X) @Watch('onBubblePos') sigX: number = 0;
  /** 气泡纵坐标 vp */
  @StorageLink(AppKeys.BUBBLE_Y) @Watch('onBubblePos') sigY: number = 240;
  /** 拖拽中？拖拽结束时（true→false）触发吸附归位 settle() */
  @StorageLink(AppKeys.BUBBLE_DRAGGING) @Watch('onDraggingChange') sigDragging: boolean = false;
  /** 点击信号，每 +1 一次，触发 handleTap（开/关面板）*/
  @StorageLink(AppKeys.BUBBLE_TAP) @Watch('onTapSignal') sigTap: number = 0;
  /** 是否进入隐藏吸入区（视觉层高亮提示用）*/
  @StorageLink(AppKeys.BUBBLE_DISMISS_ARMED) sigDismissArmed: boolean = false;
  /** 是否显示底部吸入区提示 */
  @StorageLink(AppKeys.BUBBLE_DISMISS_VISIBLE) sigDismissVisible: boolean = false;

  /** 窗口矩形变化回调，宿主据此 resize / move 悬浮窗 */
  onWindowRectChange: (r: Rect) => void = () => {};
  /** 视觉层可触摸性切换回调：面板展开时需临时开触摸接收行点击 */
  onViewTouchableChange: (touchable: boolean) => void = () => {};
  onPick: (item: ClipItem) => void = () => {};
  onHidden: () => void = () => {};
  /** 面板开关拨到 OFF：彻底关闭悬浮球（销毁双窗口） */
  onClose: () => void = () => {};
  onDockChange: (side: DockSide, y: number) => void = () => {};

  @State private state: DockState = DockState.Docked;
  @State private side: DockSide = DockSide.Right;
  @State private x: number = 0;
  @State private y: number = 240;
  @State private dragging: boolean = false;
  @State private pulseScale: number = 1;
  @State private pulseAlpha: number = 0;
  @State private panelShown: boolean = false;
  @State private anchor: PanelAnchor =
    { x: 0, y: 0, w: BubbleSize.PANEL_W, h: 120, originX: 1, originY: 0.5 };
  // 气泡外观渲染在交互层窗口（BubbleTouchPage）。视觉层不再渲染气泡本体，
  // 只渲染面板和 dismissZone。低频状态（停靠侧、状态、条数、波纹）通过
  // syncBubbleVisual() 写 AppStorage 同步给交互层渲染气泡外观。
  // 视觉层窗口常驻全屏（见 DockEngine.windowRect），左上角恒为屏幕原点 (0,0)，
  // 气泡/面板直接用屏幕绝对坐标定位，无需窗口原点换算。

  private engine: DockEngine = new DockEngine(360, 780);
  private dozeTimer: number = -1;
  private panelTimer: number = -1;
  // 视觉层主动写 sigX/sigY（吸附/唤醒/休眠动画）时置 true，阻止 onBubblePos 把
  // 刚写的值又回写到 this.x，与正在进行的动画互相覆盖导致闪烁。
  private syncingToTouch: boolean = false;

  aboutToAppear(): void {
    this.engine.updateScreen(this.hostW, this.hostH);
    // 恢复上次停靠位置
    const savedSide: string = AppStorage.get<string>(AppKeys.LAST_SIDE) ?? 'R';
    this.side = savedSide === 'L' ? DockSide.Left : DockSide.Right;
    const savedY: number = AppStorage.get<number>(AppKeys.LAST_Y) ?? 240;
    this.y = this.engine.clampY(savedY);
    this.x = this.engine.restX(this.side);
    // 同步给交互层（BubbleTouchPage 也读 AppKeys.BUBBLE_X/Y 定位自身窗口）
    this.sigX = this.x;
    this.sigY = this.y;
    // 初始化交互层渲染气泡所需的状态信号
    AppStorage.setOrCreate(AppKeys.BUBBLE_DARK, this.dark);
    this.syncBubbleVisual();
    hilog.info(DOMAIN, TAG,
      `aboutToAppear host=${this.hostW}x${this.hostH} screen=${this.engine.getScreenW()}x${this.engine.getScreenH()} ` +
      `side=${this.side} x=${this.x} y=${this.y}`);
    this.emitRect();
    this.scheduleDoze();
  }

  /** 把气泡外观相关状态同步给交互层（BubbleTouchPage 据此渲染气泡） */
  private syncBubbleVisual(): void {
    AppStorage.setOrCreate(AppKeys.BUBBLE_STATE, this.state);
    AppStorage.setOrCreate(AppKeys.BUBBLE_SIDE, this.side);
    AppStorage.setOrCreate(AppKeys.BUBBLE_ITEM_COUNT, this.items.length);
    AppStorage.setOrCreate(AppKeys.BUBBLE_PULSE_SCALE, this.pulseScale);
    AppStorage.setOrCreate(AppKeys.BUBBLE_PULSE_ALPHA, this.pulseAlpha);
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
    this.syncBubbleVisual();
  }

  private onHiddenFlag(): void {
    if (!this.hiddenFlag && this.state === DockState.Hidden) {
      this.state = DockState.Docked;
      this.settle();
    }
  }

  /* ---- 交互层 → 视觉层 信号响应（双窗口架构）---- */

  /**
   * 交互层拖拽时把气泡坐标写进 AppStorage。视觉层跟踪 this.x/y 用于面板锚点
   * 计算和 settle，但不再据此渲染气泡（气泡外观在交互层窗口，跟窗口原生移动）。
   * syncingToTouch 守卫：视觉层动画主动写 sigX/sigY 时跳过回写。
   */
  private onBubblePos(): void {
    if (this.syncingToTouch) {
      return;
    }
    this.x = this.sigX;
    this.y = this.sigY;
  }

  /** 拖拽开始（true）/ 结束（false） */
  private onDraggingChange(): void {
    if (this.sigDragging) {
      // 拖拽开始：进入自由态，面板收起
      clearTimeout(this.dozeTimer);
      this.state = DockState.Free;
      this.panelShown = false;
      this.dragging = true;
      this.syncBubbleVisual();
      hilog.info(DOMAIN, TAG, `drag START (signal) pos=(${this.sigX},${this.sigY})`);
    } else if (this.state === DockState.Free) {
      // 拖拽结束：吸附归位
      this.dragging = false;
      this.x = this.sigX;
      this.y = this.sigY;
      this.syncBubbleVisual();
      hilog.info(DOMAIN, TAG, `drag END (signal) pos=(${this.x},${this.y}) dismissArmed=${this.sigDismissArmed}`);
      if (this.sigDismissArmed) {
        this.hideBubble();
        return;
      }
      this.settle();
    }
  }

  /** 点击信号：交互层 TapGesture 每 +1 一次 */
  private onTapSignal(): void {
    if (this.sigTap <= 0) {
      return;
    }
    if (this.dragging || this.state === DockState.Free) {
      return; // 拖拽中的 up 不算点击
    }
    hilog.info(DOMAIN, TAG, `tap (signal) state=${this.state}`);
    this.handleTap();
  }

  /* ---------------- 状态机 ---------------- */

  /** 抬手后决定吸附侧并弹簧归位 */
  private settle(): void {
    this.side = this.engine.resolveSide(this.x);
    this.y = this.engine.clampY(this.y);
    this.state = DockState.Snapping;
    hilog.info(DOMAIN, TAG,
      `settle from=(${this.x},${this.y}) -> side=${this.side} restX=${this.engine.restX(this.side)} y=${this.y}`);
    // 动画期间主动写 sigX/sigY 同步给交互层，置 syncingToTouch 阻止 onBubblePos
    // 回写 this.x（否则动画值与信号值互相覆盖 = 闪烁）。动画结束后复位。
    this.syncingToTouch = true;
    animateTo({
      curve: curves.interpolatingSpring(
        BubbleMotion.SPRING_VELOCITY, BubbleMotion.SPRING_MASS,
        BubbleMotion.SPRING_STIFFNESS, BubbleMotion.SPRING_DAMPING)
    }, () => {
      this.x = this.engine.restX(this.side);
      this.sigX = this.x;
      this.state = DockState.Docked;
    });
    AppStorage.setOrCreate(AppKeys.LAST_SIDE, this.side === DockSide.Left ? 'L' : 'R');
    AppStorage.setOrCreate(AppKeys.LAST_Y, this.y);
    this.onDockChange(this.side, this.y);
    this.emitRect();
    this.scheduleDoze();
    this.syncingToTouch = false;
    this.syncBubbleVisual();
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
      this.syncingToTouch = true;
      animateTo({ duration: BubbleMotion.DOZE_DURATION, curve: Curve.EaseOut }, () => {
        this.x = this.engine.dozeX(this.side);
        this.sigX = this.x;
        this.state = DockState.Dozing;
      });
      this.syncingToTouch = false;
      this.syncBubbleVisual();
      hilog.info(DOMAIN, TAG, `scheduleDoze: -> Dozing x=${this.engine.dozeX(this.side)}`);
      this.emitRect();
    }, BubbleMotion.DOZE_DELAY);
  }

  private wake(): void {
    if (this.state === DockState.Dozing) {
      this.syncingToTouch = true;
      animateTo({ duration: BubbleMotion.WAKE_DURATION, curve: Curve.EaseOut }, () => {
        this.x = this.engine.restX(this.side);
        this.sigX = this.x;
        this.state = DockState.Docked;
      });
      this.syncingToTouch = false;
      this.syncBubbleVisual();
      this.emitRect();
    }
    this.scheduleDoze();
  }

  private openPanel(): void {
    clearTimeout(this.dozeTimer);
    this.anchor = this.engine.panelAnchor(this.side, this.x, this.y, this.items.length);
    this.state = DockState.Expanded;
    this.syncingToTouch = true;
    this.x = this.engine.restX(this.side);
    this.sigX = this.x;
    this.syncingToTouch = false;
    this.syncBubbleVisual();
    this.emitRect();
    // 面板展开期间，视觉层需临时可触摸以接收面板行点击（此前不可触摸以便下层穿透）。
    // 面板是短暂模态，此期间不要求下层可点，可接受。
    this.onViewTouchableChange(true);
    clearTimeout(this.panelTimer);
    this.panelTimer = setTimeout(() => {
      this.panelShown = true;
    }, 16);
  }

  private closePanel(): void {
    this.panelShown = false;
    this.onViewTouchableChange(false);
    clearTimeout(this.panelTimer);
    this.panelTimer = setTimeout(() => {
      // 双窗口架构：视觉层恒全屏不 resize，这里只切 state 移除面板。
      this.state = DockState.Docked;
      this.syncBubbleVisual();
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
    this.syncBubbleVisual();
    AppStorage.setOrCreate(AppKeys.BUBBLE_HIDDEN, true);
    this.onHidden();
  }

  private emitRect(): void {
    const r: Rect = this.engine.windowRect(
      this.state, this.side, this.x, this.y, this.items.length);
    // 视觉层窗口常驻全屏，r 恒为 (0,0,screenW,screenH)；applyRect 内部会去重跳过。
    hilog.info(DOMAIN, TAG,
      `emitRect state=${this.state} side=${this.side} bubble=(${this.x},${this.y}) -> rect=(${r.x},${r.y},${r.w}x${r.h})`);
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

  /* ---------------- 视图 ---------------- */

  // 气泡本体（bubbleView）已移到交互层窗口（BubbleTouchPage）渲染。
  // 视觉层只保留面板和 dismissZone。

  @Builder
  dismissZone() {
    Row({ space: 8 }) {
    }
    .padding({ left: 16, right: 16, top: 9, bottom: 9 })
    .borderRadius(100)
    .backgroundColor(this.sigDismissArmed ? BubbleColor.DISMISS : '#DB080C1B')
    .border({ width: 1, color: '#59FF6B7A' })
    .scale({ x: this.sigDismissArmed ? 1.1 : 1, y: this.sigDismissArmed ? 1.1 : 1 })
    .opacity(this.sigDismissVisible ? 1 : 0)
    .animation({ duration: 220, curve: curves.cubicBezierCurve(0.2, 0.9, 0.3, 1.2) })
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 面板外任意点击即收起。header 右侧开关用于彻底关闭悬浮球。
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
          },
          onClose: () => {
            this.onClose();
          }
        })
          .position({ x: this.anchor.x, y: this.anchor.y })
      }

      // 气泡本体不在这里渲染——它在交互层窗口（BubbleTouchPage）里，跟窗口原生移动。
      // 视觉层只渲染面板和 dismissZone（低频更新的内容）。

      if (this.sigDismissVisible) {
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
