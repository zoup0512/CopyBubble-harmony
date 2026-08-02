/**
 * FloatBubble.ets
 * 悬浮气泡主组件。把「贴边」当默认状态而不是收尾动作。
 *
 * 五态：
 *   Free ──抬手──> Snapping ──> Docked
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
import { DockEngine, DockSide, DockState, PanelAnchor } from './DockEngine';
import { ClipboardPanel } from './ClipboardPanel';
import { ClipItem } from './ClipItem';
import { AppKeys } from './AppKeys';

const TAG: string = 'CopyBubble/Float';
const DOMAIN: number = 0x1001;

@Component
export struct FloatBubble {
  /** 宿主容器尺寸，vp。键盘弹起时 hostH 会缩小，必须回灌给 engine 重算钳制边界 */
  @Prop @Watch('onHostSizeChange') hostW: number = 360;
  @Prop @Watch('onHostSizeChange') hostH: number = 780;
  /** 面板配色跟随下层应用 */
  @Prop dark: boolean = false;
  @Prop items: ClipItem[] = [];

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
  /** 是否进入隐藏吸入区（拖拽结束时据此触发 hideBubble）*/
  @StorageLink(AppKeys.BUBBLE_DISMISS_ARMED) sigDismissArmed: boolean = false;

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
  @State private panelShown: boolean = false;
  @State private anchor: PanelAnchor =
    { x: 0, y: 0, w: BubbleSize.PANEL_W, h: 120, originX: 1, originY: 0.5 };
  // 气泡外观渲染在交互层窗口（BubbleTouchPage）。视觉层不再渲染气泡本体，
  // 只渲染面板。低频状态（停靠侧、状态、条数）通过
  // syncBubbleVisual() 写 AppStorage 同步给交互层渲染气泡外观。
  // 动画不同步：跨窗口只能传到终值，波纹这类动画必须由交互层本地跑。
  // 视觉层窗口常驻全屏（见 DockEngine.windowRect），左上角恒为屏幕原点 (0,0)，
  // 气泡/面板直接用屏幕绝对坐标定位，无需窗口原点换算。

  private engine: DockEngine = new DockEngine(360, 780);
  private panelTimer: number = -1;
  // 视觉层主动写 sigX/sigY（吸附动画、尺寸变更重算）时置 true，阻止 onBubblePos 把
  // 刚写的值又回写到 this.x，与正在进行的动画互相覆盖导致闪烁。
  private syncingToTouch: boolean = false;

  aboutToAppear(): void {
    this.engine.updateScreen(this.hostW, this.hostH);
    // 上一轮气泡被拖进吸入区隐藏过：BUBBLE_HIDDEN 会残留 true，导致本轮
    // onHiddenFlag 收不到"召回"边沿。新实例总是从 Docked 起步，这里同步清掉。
    // TODO: 接常驻通知做召回入口后，改为按通知动作驱动 BUBBLE_HIDDEN。
    if (this.hiddenFlag) {
      this.hiddenFlag = false;
    }
    // 恢复上次停靠位置
    const savedSide: string = AppStorage.get<string>(AppKeys.LAST_SIDE) ?? 'R';
    this.side = savedSide === 'L' ? DockSide.Left : DockSide.Right;
    const savedY: number = AppStorage.get<number>(AppKeys.LAST_Y) ?? 240;
    this.y = this.engine.clampY(savedY);
    this.x = this.engine.restX(this.side);
    // 同步给交互层（BubbleTouchPage 也读 AppKeys.BUBBLE_X/Y 定位自身窗口）
    this.sigX = this.x;
    this.sigY = this.y;
    this.syncBubbleVisual();
    hilog.info(DOMAIN, TAG,
      `aboutToAppear host=${this.hostW}x${this.hostH} screen=${this.engine.getScreenW()}x${this.engine.getScreenH()} ` +
      `side=${this.side} x=${this.x} y=${this.y}`);
  }

  /** 把气泡外观相关状态同步给交互层（BubbleTouchPage 据此渲染气泡） */
  private syncBubbleVisual(): void {
    AppStorage.setOrCreate(AppKeys.BUBBLE_STATE, this.state);
    AppStorage.setOrCreate(AppKeys.BUBBLE_SIDE, this.side);
    AppStorage.setOrCreate(AppKeys.BUBBLE_ITEM_COUNT, this.items.length);
  }

  aboutToDisappear(): void {
    clearTimeout(this.panelTimer);
  }

  /* ---------------- 外部信号 ---------------- */

  /**
   * 宿主可用尺寸变化（键盘弹起/收起、横竖屏切换）。
   * 只更新 engine 并把气泡重新钳进新边界；拖拽中不打断用户。
   */
  private onHostSizeChange(): void {
    if (this.hostW <= 0 || this.hostH <= 0 || this.state === DockState.Free) {
      return;
    }
    this.engine.updateScreen(this.hostW, this.hostH);
    // 只做钳制、不按比例重映射：键盘弹起是临时收缩可用区，气泡应被顶到键盘上方
    // 而不是整体等比上移，否则收起键盘后位置会一路漂移。
    this.y = this.engine.clampY(this.y);
    if (this.state !== DockState.Hidden) {
      this.x = this.engine.restX(this.side);
    }
    this.syncingToTouch = true;
    this.sigX = this.x;
    this.sigY = this.y;
    this.syncingToTouch = false;
    hilog.info(DOMAIN, TAG,
      `onHostSizeChange host=${this.hostW}x${this.hostH} -> x=${this.x} y=${this.y}`);
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
    this.syncingToTouch = false;
    this.syncBubbleVisual();
  }

  private openPanel(): void {
    this.anchor = this.engine.panelAnchor(this.side, this.x, this.y, this.items.length);
    this.state = DockState.Expanded;
    this.syncingToTouch = true;
    this.x = this.engine.restX(this.side);
    this.sigX = this.x;
    this.syncingToTouch = false;
    this.syncBubbleVisual();
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
      this.state = DockState.Docked;
      this.syncBubbleVisual();
    }, BubbleMotion.MORPH_DURATION);
  }

  private hideBubble(): void {
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

  private handleTap(): void {
    if (this.state === DockState.Expanded) {
      this.closePanel();
    } else {
      this.openPanel();
    }
  }

  /* ---------------- 视图 ---------------- */

  // 气泡本体（bubbleView）已移到交互层窗口（BubbleTouchPage）渲染。
  // 视觉层只保留面板。

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
      // 视觉层只渲染面板（低频更新的内容）。
    }
    .width('100%')
    .height('100%')
    .onAreaChange((oldArea: Area, newArea: Area) => {
      // 视觉层窗口恒为全屏，正常情况下 onAreaChange 不会触发。这里只做横竖屏
      // 切换兜底：系统旋转后 TYPE_FLOAT 窗口可能被 WMS 重建 surface，area 变化
      // 反映新屏幕尺寸。hostW/hostH 由宿主在 aboutToAppear 设一次，旋转时未必
      // 更新，所以这里按 area 兜底重算 engine 并把新坐标推给交互层。
      const w: number = Number(newArea.width);
      const h: number = Number(newArea.height);
      if (w <= 0 || h <= 0) {
        return;
      }
      const curW: number = this.engine.getScreenW();
      const curH: number = this.engine.getScreenH();
      if (w <= curW + 1 && h <= curH + 1) {
        return;
      }
      const oldH: number = curH;
      this.engine.updateScreen(w, h);
      this.y = this.engine.remapOnResize(this.y, oldH, h);
      if (this.state !== DockState.Free && this.state !== DockState.Hidden) {
        this.x = this.engine.restX(this.side);
      }
      this.syncingToTouch = true;
      this.sigX = this.x;
      this.sigY = this.y;
      this.syncingToTouch = false;
      hilog.info(DOMAIN, TAG, `onAreaChange: screen grew -> resync x=${this.x} y=${this.y}`);
    })
  }
}
