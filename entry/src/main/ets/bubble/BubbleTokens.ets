/**
 * BubbleTokens.ets
 * CopyBubble 悬浮气泡设计令牌。所有尺寸单位为 vp，时长单位为 ms。
 * 改这里就能改全局，不要在组件里写魔法数字。
 */

/* ---------------- 尺寸 ---------------- */
export class BubbleSize {
  /** 气泡光学直径 */
  static readonly BUBBLE: number = 48;
  /** 图形安全内圈直径，图形不得超出 */
  static readonly GLYPH_BOX: number = 22;
  /** 贴边常驻时露出屏幕的宽度（48 的 71%） */
  static readonly PEEK_DOCKED: number = 34;
  /** 休眠时露出屏幕的宽度（48 的 42%） */
  static readonly PEEK_DOZING: number = 20;
  /** 触控热区，恒定不随视觉露出收缩 */
  static readonly HIT_AREA: number = 48;
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
  static readonly PANEL_SUB: string = '#8A93B2';
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
  /** 图形描边宽度 = 实心块短边 / 5.8，保证灰度等重 */
  static readonly GLYPH_STROKE: number = 2.6;
  /** 图形矩形圆角 */
  static readonly GLYPH_RADIUS: number = 4.5;
  /** 气泡整圆半径 */
  static readonly BUBBLE_RADIUS: number = 24;
  /** 面板圆角 */
  static readonly PANEL_RADIUS: number = 20;
  /** 贴边后图形向屏幕内侧的补偿位移 */
  static readonly DOCK_GLYPH_SHIFT: number = 3;
}

/* ---------------- 动效 ---------------- */
export class BubbleMotion {
  /** 静置多久进入休眠 */
  static readonly DOZE_DELAY: number = 2500;
  /** 磁吸弹簧参数：velocity, mass, stiffness, damping */
  static readonly SPRING_VELOCITY: number = 0;
  static readonly SPRING_MASS: number = 1;
  static readonly SPRING_STIFFNESS: number = 340;
  static readonly SPRING_DAMPING: number = 30;
  /** 圆 → D 形形变 */
  static readonly MORPH_DURATION: number = 340;
  /** 进入休眠 */
  static readonly DOZE_DURATION: number = 300;
  /** 唤醒 */
  static readonly WAKE_DURATION: number = 160;
  /** 捕获波纹 */
  static readonly PULSE_DURATION: number = 700;
  /** 隐藏吸入 */
  static readonly DISMISS_DURATION: number = 300;

  static readonly OPACITY_DOCKED: number = 1.0;
  static readonly OPACITY_DOZING: number = 0.52;
  static readonly SCALE_DRAG: number = 0.92;
  static readonly SCALE_PULSE_TO: number = 2.1;
}
