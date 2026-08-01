/**
 * AppKeys.ets
 * AppStorage 键名集中管理。悬浮窗和主界面是两个独立的 UI 实例，
 * 只能靠 AppStorage 通信，键名散落各处必然拼错。
 */

export class AppKeys {
  /** ClipItem[] 的 JSON 字符串，跨 UI 实例传递用 */
  static readonly ITEMS: string = 'cb_items_json';
  /** 记录条数，主界面和角标都读它 */
  static readonly COUNT: string = 'cb_count';
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
}
