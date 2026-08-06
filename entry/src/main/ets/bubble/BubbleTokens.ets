/**
 * BubbleTokens.ets
 * CopyBubble 悬浮气泡设计令牌。所有尺寸单位为 vp，时长单位为 ms。
 * 改这里就能改全局，不要在组件里写魔法数字。
 */

/* ---------------- 大小配置（改这里即可全局生效） ---------------- */
/**
 * 悬浮球外观缩放配置。所有气泡/角标几何尺寸均由这两个系数派生，
 * 改动此处即可调整大小，无需修改任何组件代码。
 *
 * BUBBLE_SCALE: 气泡整体缩放系数，1 = 原始 48vp 直径。
 *   气泡直径、触控热区、交互窗口、贴边露出量、整圆半径、图形位移等均按此缩放。
 * BADGE_SCALE:  计数角标整体缩放系数，1 = 原始角标尺寸。
 *   与气泡独立，可单独微调（例如气泡缩小但希望角标仍清晰可读时调大此值）。
 *
 * 原始基准（BUBBLE_SCALE = 1 时）：气泡 48vp、热区 48vp、交互窗 112vp、
 * 整圆半径 24vp、图形位移 3vp；角标字号 10vp、高 16vp、圆角 8vp、描边 2vp。
 */
const BUBBLE_SCALE: number = 2 / 3;
const BADGE_SCALE: number = 2 / 3;

/* ---------------- 尺寸 ---------------- */
export class BubbleSize {
  /** 气泡整体缩放系数（供 BubbleIcon 等组件读取以缩放图形） */
  static readonly SCALE: number = BUBBLE_SCALE;
  /** 角标整体缩放系数（供 BubbleBadge 读取以缩放角标，独立于气泡） */
  static readonly BADGE_SCALE: number = BADGE_SCALE;
  /** 气泡光学直径（基准 48 × BUBBLE_SCALE） */
  static readonly BUBBLE: number = 48 * BUBBLE_SCALE;
  /** 图形安全内圈直径，图形不得超出（基准 22 × BUBBLE_SCALE） */
  static readonly GLYPH_BOX: number = 22 * BUBBLE_SCALE;
  /** 贴边常驻时露出屏幕的宽度（基准 34 × BUBBLE_SCALE，约为 BUBBLE 的 71%） */
  static readonly PEEK_DOCKED: number = 34 * BUBBLE_SCALE;
  /** 触控热区，恒定不随视觉露出收缩（基准 48 × BUBBLE_SCALE） */
  static readonly HIT_AREA: number = 48 * BUBBLE_SCALE;
  /** 交互层窗口边长。气泡在窗口内用 position 移动（ArkUI 原生渲染），
   *  只在气泡接近窗口边缘时才 moveWindowTo 重新居中，以此压掉高频 WMS 振荡。
   *  尺寸权衡：越大拖拽越稳（手指不易出窗断触），越小遮挡下层点击越少。
   *  基准 112 = 气泡 48 + 两侧边缘留白 16×2 + 行程余量 32，按 BUBBLE_SCALE 缩放。
   *  贴边时窗口向屏外顶出，屏幕内遮挡进一步缩小；普通拖拽
   *  （<1000vp/s）下异步追窗 1-2 帧手指仍不出窗。
   *  BubbleWindowManager 建窗与 BubbleTouchPage 定位共用此值，不可各写一份。 */
  static readonly TOUCH_WIN: number = 112 * BUBBLE_SCALE;
  /** 展开面板宽度，约 13 个汉字 */
  static readonly PANEL_W: number = 226;
  /** 面板与气泡间距 */
  static readonly PANEL_GAP: number = 8;
  /** 面板单条记录高度 */
  static readonly ITEM_H: number = 44;
  /** 空状态内容体高度（DockEngine 算窗口高度与 emptyState 渲染高度共用，
   *  单一处定义避免二者错位导致窗口裁切文案） */
  static readonly PANEL_EMPTY_H: number = 88;
  /** 面板头部高度 */
  static readonly PANEL_HEAD_H: number = 30;
  /** 面板内边距 */
  static readonly PANEL_PAD: number = 12;
  /** 顶部安全区（状态栏 + 胶囊） */
  static readonly SAFE_TOP: number = 48;
  /** 底部安全区（手势导航条） */
  static readonly SAFE_BOTTOM: number = 24;
  /** 底部隐藏吸入区的判定半径 */
  static readonly DISMISS_R: number = 90;
  /** 底部隐藏吸入区距屏幕底部的高度 */
  static readonly DISMISS_ZONE_H: number = 96;
}

/* ---------------- 色彩 ---------------- */
export class BubbleColor {
  static readonly GRAD_A: string = '#6E7CFF';
  static readonly GRAD_B: string = '#3D45D8';
  static readonly GRAD_C: string = '#232B92';
  /** 图形前景（副本） */
  static readonly GLYPH: string = '#EEF1FA';
  /** 图形描边（原文），55% 不透明 */
  static readonly GLYPH_GHOST: string = '#8CEEF1FA';
  /** 角标底色 */
  static readonly BADGE_BG: string = '#FFC978';
  static readonly BADGE_FG: string = '#3A2600';
  /** 捕获波纹 */
  static readonly PULSE: string = '#34E0C4';
  /** 深色应用底上的保轮廓内描边 */
  static readonly RIM: string = '#24FFFFFF';
  /** 隐藏吸入区 */
  static readonly DISMISS: string = '#FF6B7A';

  static readonly PANEL_BG_LIGHT: string = '#DBFFFFFF';
  static readonly PANEL_BG_DARK: string = '#E0161B36';
  static readonly PANEL_TEXT: string = '#242A48';
  static readonly PANEL_TEXT_DARK: string = '#DCE1F2';
  /** 次级文字：浅色面板用深灰、深色面板用浅灰，各自保证对比度 */
  static readonly PANEL_SUB_LIGHT: string = '#6F7699';
  static readonly PANEL_SUB_DARK: string = '#9AA4C8';
  /** 选中行背景（浅色面板） */
  static readonly PANEL_ROW_SEL_LIGHT: string = '#295B6CF6';
  /** 选中行背景（深色面板） */
  static readonly PANEL_ROW_SEL_DARK: string = '#3D5B6CF6';

  static readonly TAG_LINK_BG: string = '#295B6CF6';
  static readonly TAG_LINK_FG: string = '#3E4BD4';
  static readonly TAG_CODE_BG: string = '#38FFC978';
  static readonly TAG_CODE_FG: string = '#8A5A00';
  static readonly TAG_TEXT_BG: string = '#2E34E0C4';
  static readonly TAG_TEXT_FG: string = '#0F8D79';
}

/* ---------------- 描边与圆角 ---------------- */
export class BubbleShape {
  /** 图形描边宽度 = 实心块短边 / 5.8，保证灰度等重。
   *  注意：此值在 BubbleIcon 里会再乘 scaleRatio，故此处保留原始基准，
   *  由 BubbleTouchPage 传入 scaleRatio = BubbleSize.SCALE 完成缩放。 */
  static readonly GLYPH_STROKE: number = 2.6;
  /** 图形矩形圆角（同上，乘 scaleRatio 缩放） */
  static readonly GLYPH_RADIUS: number = 4.5;
  /** 气泡整圆半径（基准 24 × BUBBLE_SCALE） */
  static readonly BUBBLE_RADIUS: number = 24 * BUBBLE_SCALE;
  /** 面板圆角 */
  static readonly PANEL_RADIUS: number = 20;
  /** 贴边后图形向屏幕内侧的补偿位移（基准 3 × BUBBLE_SCALE） */
  static readonly DOCK_GLYPH_SHIFT: number = 3 * BUBBLE_SCALE;
}

/* ---------------- 动效 ---------------- */
export class BubbleMotion {
  /** 磁吸弹簧参数：velocity, mass, stiffness, damping */
  static readonly SPRING_VELOCITY: number = 0;
  static readonly SPRING_MASS: number = 1;
  static readonly SPRING_STIFFNESS: number = 340;
  static readonly SPRING_DAMPING: number = 30;
  /** 圆 → D 形形变 */
  static readonly MORPH_DURATION: number = 340;
  /** 捕获波纹 */
  static readonly PULSE_DURATION: number = 700;
  /** 隐藏吸入 */
  static readonly DISMISS_DURATION: number = 300;

  static readonly SCALE_DRAG: number = 0.92;
  static readonly SCALE_PULSE_TO: number = 2.1;
}
