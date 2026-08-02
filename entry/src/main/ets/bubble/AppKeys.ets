/**
 * AppKeys.ets
 * AppStorage 键名集中管理。悬浮窗和主界面是两个独立的 UI 实例，
 * 只能靠 AppStorage 通信，键名散落各处必然拼错。
 */

export class AppKeys {
  /** 自增计数，每 +1 触发一次气泡捕获波纹 */
  static readonly PULSE: string = 'cb_pulse';
  /** 气泡是否被用户拖到底部隐藏了 */
  static readonly BUBBLE_HIDDEN: string = 'cb_bubble_hidden';
  /** 悬浮窗是否已启动 */
  static readonly BUBBLE_RUNNING: string = 'cb_bubble_running';
  /** 下层应用是否深色，影响面板配色 */
  static readonly DARK_HOST: string = 'cb_dark_host';
  /** 气泡最后停靠的一侧，'L' / 'R'，持久化用 */
  static readonly LAST_SIDE: string = 'cb_last_side';
  /** 气泡最后停靠的纵向位置，vp */
  static readonly LAST_Y: string = 'cb_last_y';

  /* ---- 双窗口架构：交互层 → 视觉层的信号 ---- */
  // 悬浮窗拆成「视觉层」（全屏不可触摸，渲染外观）和「交互层」（48×48 可触摸，
  // 承载手势）两个窗口。交互层捕获手势后，通过下面的 AppStorage 键驱动视觉层
  // 渲染。两个窗口是独立 UI 实例，只能靠 AppStorage 通信。
  /** 气泡横坐标，vp。交互层拖拽时写，视觉层读以定位气泡 */
  static readonly BUBBLE_X: string = 'cb_bubble_x';
  /** 气泡纵坐标，vp */
  static readonly BUBBLE_Y: string = 'cb_bubble_y';
  /** 是否正在拖拽，视觉层据此切换阴影/缩放 */
  static readonly BUBBLE_DRAGGING: string = 'cb_bubble_dragging';
  /** 自增计数，每 +1 表示发生一次点击，视觉层消费（开/关面板） */
  static readonly BUBBLE_TAP: string = 'cb_bubble_tap';
  /** 交互层是否进入隐藏吸入区，拖拽结束时视觉层据此触发 hideBubble */
  static readonly BUBBLE_DISMISS_ARMED: string = 'cb_bubble_dismiss_armed';
  /** 气泡当前状态（free/docked/dozing/expanded/hidden），交互层据此渲染气泡外观 */
  static readonly BUBBLE_STATE: string = 'cb_bubble_state';
  /** 气泡停靠侧 'L'/'R'，交互层据此决定贴边形变方向 */
  static readonly BUBBLE_SIDE: string = 'cb_bubble_side';
  /** 记录条数，交互层据此渲染角标 */
  static readonly BUBBLE_ITEM_COUNT: string = 'cb_bubble_item_count';
}
