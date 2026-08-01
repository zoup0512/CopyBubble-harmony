# CopyBubble 悬浮气泡重设计 · 实施规格

> 这份文档是给编码助手执行的完整规格。所有代码均为最终内容，直接创建即可，无需推断或补全。

---

## 0. 给执行者的硬性约束

**请在开始前完整读完本节。**

1. **本次改动只涉及悬浮气泡的图标与贴边展示。** 除第 4 节明确列出的三处外，不得修改、删除、重命名项目中任何既有文件。
2. **第 1、2 节的文件全部是新增。** 文件名经过检查，不与常见的鸿蒙工程文件重名。若发现同名文件已存在，**停止并向用户报告**，不要覆盖。
3. **第 4 节的三处改动全部是「追加」，不是「替换」。** 尤其 `main_pages.json`，必须保留原有的全部页面条目。
4. 项目中若已存在旧的气泡实现（常见于 `bubble/`、`float/`、`floatball/` 等目录），**不要删除**，重命名为 `*_legacy` 保留。新旧坐标约定不同：**新实现在左侧贴边时 `x` 为负值**（气泡左半出屏），混用会错位。
5. 不要「顺手」优化、格式化或重构任何未列出的文件。
6. 代码为 ArkTS（HarmonyOS NEXT，API 12+）。ArkTS 禁用 `any`、禁用无类型的对象字面量，本文档中的代码已符合规范，请勿改写类型声明。

---

## 1. 变更总览

| 类别 | 数量 | 说明 |
| --- | --- | --- |
| 新增 ArkTS 文件 | 11 | `bubble/` 目录 9 个 + `pages/` 目录 2 个 |
| 新增资源文件 | 3 | SVG 图标，可选 |
| 修改既有文件 | 3 | 全部为追加内容 |
| 删除文件 | **0** | 本次改动不删除任何文件 |

### 设计意图（供理解，不需实现推断）

悬浮气泡的核心矛盾是：它必须一直在，又必须一直不碍事。本次改动把「贴边」从拖拽结束后的收尾动作，升级为气泡的默认生存状态，图标形态、透明度、展开方向全部由它所依附的那条屏幕边缘推导。

| 项 | 值 | 理由 |
| --- | --- | --- |
| 气泡光学直径 | 48vp | 图形只占 22vp，留白是悬浮元素不显脏的唯一办法 |
| 贴边常驻露出 | 34vp（71%） | 圆形变 D 形，外侧圆内侧直 |
| 休眠露出 | 20vp（42%） | 静置 2500ms 触发，不透明度降至 0.52，描边层隐去 |
| 图形补偿位移 | 3vp | 贴边形变后图形须向屏幕内侧推，否则视觉重心偏 |
| 触控热区 | 48×48vp **恒定** | 不随视觉露出收缩，休眠态尤其关键 |
| 面板宽度 | 226vp | 约 13 个汉字，一条剪贴记录的可读下限 |
| 吸附曲线 | `interpolatingSpring(0, 1, 340, 30)` | 磁吸是唯一带物理隐喻的动作，只有它用弹簧 |

三条不可动摇的规则：

- **只吸左右两条边。** 顶部有状态栏与胶囊，底部有手势导航条，气泡贴上去等于主动制造误触。
- **吸附判定用中心点而非边界。** `xc < W/2` 归左，否则归右。用边界判定会导致气泡在屏幕中线附近来回横跳。
- **展开方向是气泡位置的函数，不是配置项。** 贴左往右开，贴右往左开；靠近下缘时锚点翻到面板底部向上生长。

---

## 2. 新增 ArkTS 文件

按下列顺序创建，依赖关系已排序。

### `entry/src/main/ets/bubble/BubbleTokens.ets`

设计令牌。所有尺寸、颜色、时长的唯一来源，其余文件不得写死数值。

```typescript
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
```

### `entry/src/main/ets/bubble/AppKeys.ets`

AppStorage 键名常量。悬浮窗与主界面是两个独立 UI 实例，只能靠 AppStorage 通信。

```typescript
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
```

### `entry/src/main/ets/bubble/DockEngine.ets`

贴边几何与状态机。纯逻辑，不 import 任何 UI 模块，可单测。这是整个改动的核心。

```typescript
/**
 * DockEngine.ets
 * 贴边几何与状态机。纯逻辑，不依赖 UI，可单独做单测。
 *
 * 设计要点：
 *   1. 只吸左右两条边。顶部有状态栏与胶囊，底部有手势导航条，
 *      气泡贴上去等于主动制造误触。
 *   2. 吸附判定用中心点而非边界，避免气泡在边缘附近来回横跳。
 *   3. 展开方向是气泡当前位置的函数，不是配置项。
 */

import { BubbleSize } from './BubbleTokens';

export enum DockState {
  /** 手指按住，自由拖拽 */
  Free = 'free',
  /** 抬手瞬间，弹簧归位中 */
  Snapping = 'snapping',
  /** 贴边常驻，露出 71% */
  Docked = 'docked',
  /** 静置 2.5s 后休眠，露出 42%，不透明度 0.52 */
  Dozing = 'dozing',
  /** 面板展开 */
  Expanded = 'expanded',
  /** 拖入底部吸入区后隐藏 */
  Hidden = 'hidden'
}

export enum DockSide {
  Left = 'L',
  Right = 'R'
}

export interface Point {
  x: number;
  y: number;
}

export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

/** 面板锚点结果：位置 + 缩放原点百分比 */
export interface PanelAnchor {
  x: number;
  y: number;
  w: number;
  h: number;
  /** 缩放原点，0 = 左/上，1 = 右/下 */
  originX: number;
  originY: number;
}

export class DockEngine {
  private screenW: number = 360;
  private screenH: number = 780;

  constructor(screenW: number, screenH: number) {
    this.screenW = screenW;
    this.screenH = screenH;
  }

  updateScreen(w: number, h: number): void {
    this.screenW = w;
    this.screenH = h;
  }

  getScreenW(): number {
    return this.screenW;
  }

  getScreenH(): number {
    return this.screenH;
  }

  /**
   * 依据气泡中心点决定吸附到哪一侧。
   * side = Left  当 xc < W/2
   * side = Right 当 xc >= W/2
   */
  resolveSide(x: number): DockSide {
    const centerX: number = x + BubbleSize.BUBBLE / 2;
    return centerX < this.screenW / 2 ? DockSide.Left : DockSide.Right;
  }

  /** 纵向安全区钳制：y = clamp(y, SAFE_TOP, H - d - SAFE_BOTTOM) */
  clampY(y: number): number {
    const min: number = BubbleSize.SAFE_TOP;
    const max: number = this.screenH - BubbleSize.BUBBLE - BubbleSize.SAFE_BOTTOM;
    if (max < min) {
      return min;
    }
    return Math.min(Math.max(y, min), max);
  }

  /** 拖拽期间的横向软边界，允许略微出屏但不脱手 */
  clampDragX(x: number): number {
    const half: number = BubbleSize.BUBBLE / 2;
    return Math.min(Math.max(x, -half), this.screenW - half);
  }

  clampDragY(y: number): number {
    return Math.min(Math.max(y, BubbleSize.SAFE_TOP - 14),
      this.screenH - BubbleSize.BUBBLE - 12);
  }

  /**
   * 贴边后的横坐标。
   * 左侧为负值（气泡左半出屏），右侧为 W - peek。
   */
  dockedX(side: DockSide, peek: number): number {
    return side === DockSide.Left
      ? peek - BubbleSize.BUBBLE
      : this.screenW - peek;
  }

  /** 常驻位 */
  restX(side: DockSide): number {
    return this.dockedX(side, BubbleSize.PEEK_DOCKED);
  }

  /** 休眠位 */
  dozeX(side: DockSide): number {
    return this.dockedX(side, BubbleSize.PEEK_DOZING);
  }

  /** 是否落在底部隐藏吸入区内 */
  inDismissZone(x: number, y: number): boolean {
    const cx: number = x + BubbleSize.BUBBLE / 2;
    const cy: number = y + BubbleSize.BUBBLE / 2;
    const nearBottom: boolean = cy > this.screenH - BubbleSize.DISMISS_ZONE_H;
    const nearCenter: boolean = Math.abs(cx - this.screenW / 2) < BubbleSize.DISMISS_R;
    return nearBottom && nearCenter;
  }

  /**
   * 面板锚点。贴左往右开、贴右往左开；
   * 靠近下缘时锚点翻到面板底部，让卡片向上生长。
   * 缩放原点始终落在气泡圆心，形变读起来是「气泡长成了卡片」。
   */
  panelAnchor(side: DockSide, bubbleX: number, bubbleY: number, itemCount: number): PanelAnchor {
    const w: number = BubbleSize.PANEL_W;
    const h: number = BubbleSize.PANEL_HEAD_H + BubbleSize.PANEL_PAD * 2 +
      BubbleSize.ITEM_H * Math.max(itemCount, 1);

    // 展开时气泡先回到常驻位，避免从休眠位算出偏移
    const bx: number = this.restX(side);

    let px: number = side === DockSide.Left
      ? bx + BubbleSize.BUBBLE + BubbleSize.PANEL_GAP
      : bx - w - BubbleSize.PANEL_GAP;
    px = Math.min(Math.max(px, 8), this.screenW - w - 8);

    const bubbleCenterY: number = bubbleY + BubbleSize.BUBBLE / 2;
    let py: number = bubbleCenterY - h / 2;
    py = Math.min(Math.max(py, BubbleSize.SAFE_TOP - 6),
      this.screenH - h - BubbleSize.SAFE_BOTTOM);

    const originX: number = side === DockSide.Left ? 0 : 1;
    let originY: number = (bubbleCenterY - py) / h;
    originY = Math.min(Math.max(originY, 0), 1);

    return { x: px, y: py, w: w, h: h, originX: originX, originY: originY };
  }

  /**
   * 悬浮窗需要覆盖的矩形。
   * 收起时窗口只有气泡那么大，展开时扩到气泡 + 面板的并集，
   * 这样窗口以外的区域完全不拦截触摸。
   */
  windowRect(state: DockState, side: DockSide, bubbleX: number, bubbleY: number,
    itemCount: number): Rect {
    if (state === DockState.Expanded) {
      const a: PanelAnchor = this.panelAnchor(side, bubbleX, bubbleY, itemCount);
      const bx: number = this.restX(side);
      const left: number = Math.min(a.x, bx);
      const top: number = Math.min(a.y, bubbleY);
      const right: number = Math.max(a.x + a.w, bx + BubbleSize.BUBBLE);
      const bottom: number = Math.max(a.y + a.h, bubbleY + BubbleSize.BUBBLE);
      return { x: left, y: top, w: right - left, h: bottom - top };
    }
    if (state === DockState.Free || state === DockState.Snapping) {
      // 拖拽期间窗口铺满，否则手指移出小窗就断触
      return { x: 0, y: 0, w: this.screenW, h: this.screenH };
    }
    return {
      x: bubbleX,
      y: bubbleY,
      w: BubbleSize.BUBBLE,
      h: BubbleSize.BUBBLE
    };
  }

  /** 横竖屏切换后按旧比例还原纵向位置，side 保持不变 */
  remapOnResize(oldY: number, oldH: number, newH: number): number {
    if (oldH <= 0) {
      return this.clampY(oldY);
    }
    const ratio: number = oldY / oldH;
    return this.clampY(ratio * newH);
  }
}
```

### `entry/src/main/ets/bubble/ClipItem.ets`

气泡内部使用的记录模型与类型识别。若项目已有同类模型，用 BubbleAdapter 转换，不要改这个文件。

```typescript
/**
 * ClipItem.ets
 * 剪贴记录模型。类型识别只做三档：验证码、链接、文本。
 * 分得再细，用户在 226vp 宽的面板里也认不出差别。
 */

import { BubbleColor } from './BubbleTokens';

export enum ClipKind {
  Code = 'code',
  Link = 'link',
  Text = 'text'
}

export class ClipItem {
  id: string = '';
  content: string = '';
  kind: ClipKind = ClipKind.Text;
  /** 毫秒时间戳 */
  time: number = 0;

  constructor(id: string, content: string, kind: ClipKind, time: number) {
    this.id = id;
    this.content = content;
    this.kind = kind;
    this.time = time;
  }
}

export class ClipStyle {
  bg: string = '';
  fg: string = '';
  tag: string = '';

  constructor(bg: string, fg: string, tag: string) {
    this.bg = bg;
    this.fg = fg;
    this.tag = tag;
  }
}

export class ClipUtil {
  private static readonly CODE_RE: RegExp = /^\s*\d[\d\s-]{3,11}\s*$/;
  private static readonly LINK_RE: RegExp = /^(https?:\/\/|www\.|[\w-]+\.(com|cn|org|net|io|dev)\b)/i;

  /** 内容类型识别。顺序有意义：验证码优先于链接。 */
  static detect(content: string): ClipKind {
    const s: string = content.trim();
    if (ClipUtil.CODE_RE.test(s)) {
      return ClipKind.Code;
    }
    if (ClipUtil.LINK_RE.test(s)) {
      return ClipKind.Link;
    }
    return ClipKind.Text;
  }

  static styleOf(kind: ClipKind): ClipStyle {
    if (kind === ClipKind.Link) {
      return new ClipStyle(BubbleColor.TAG_LINK_BG, BubbleColor.TAG_LINK_FG, '链');
    }
    if (kind === ClipKind.Code) {
      return new ClipStyle(BubbleColor.TAG_CODE_BG, BubbleColor.TAG_CODE_FG, '码');
    }
    return new ClipStyle(BubbleColor.TAG_TEXT_BG, BubbleColor.TAG_TEXT_FG, '文');
  }

  static kindLabel(kind: ClipKind): string {
    if (kind === ClipKind.Link) {
      return '链接';
    }
    if (kind === ClipKind.Code) {
      return '验证码';
    }
    return '文本';
  }

  /** 相对时间。超过一天只说「昨天 / N 天前」，不显示具体时刻。 */
  static ago(time: number): string {
    const d: number = Date.now() - time;
    if (d < 60000) {
      return `${Math.max(Math.floor(d / 1000), 1)} 秒前`;
    }
    if (d < 3600000) {
      return `${Math.floor(d / 60000)} 分钟前`;
    }
    if (d < 86400000) {
      return `${Math.floor(d / 3600000)} 小时前`;
    }
    if (d < 172800000) {
      return '昨天';
    }
    return `${Math.floor(d / 86400000)} 天前`;
  }

  /** 单行摘要，去掉换行与多余空白，面板里靠省略号收尾 */
  static preview(content: string): string {
    return content.replace(/\s+/g, ' ').trim();
  }

  static mock(): ClipItem[] {
    const now: number = Date.now();
    return [
      new ClipItem('1', '738 291', ClipKind.Code, now - 12000),
      new ClipItem('2', 'gitee.com/openharmony/docs', ClipKind.Link, now - 240000),
      new ClipItem('3', '周四 15:00 三号会议室复盘', ClipKind.Text, now - 90000000)
    ];
  }
}
```

### `entry/src/main/ets/bubble/BubbleIcon.ets`

「叠影」图形与计数角标。图形用 ArkUI 原生绘制而非 SVG 资源，因为休眠态需要单独隐去描边层。

```typescript
/**
 * BubbleIcon.ets
 * 「叠影」图形：描边那张是原文，实心那张是刚被拷出来的副本。
 *
 * 为什么不用 SVG 资源：图形只有两个圆角矩形，用 ArkUI 原生绘制可以
 * 单独对「原文」那一层做透明度动画（休眠态要把它隐去），
 * 换成图片资源就只能整块淡出。
 *
 * 构图（以 48 为基准，1 单位 = 1vp @ 48vp 气泡）：
 *   原文  x13 y17 w15 h17 r4.5 stroke 2.6
 *   副本  x20 y14 w15 h17 r4.5 fill
 *   并集  x13..35 (22)  y14..34 (20)  → 恰好落在 22vp 安全内圈里
 */

import { BubbleColor, BubbleShape } from './BubbleTokens';

@Component
export struct BubbleIcon {
  /** 图形整体缩放，1 对应 48vp 气泡 */
  @Prop scaleRatio: number = 1;
  /** 休眠态：隐去「原文」层，只留副本轮廓 */
  @Prop ghostVisible: boolean = true;
  /** 贴边后向屏幕内侧的补偿位移，负值表示向左 */
  @Prop shiftX: number = 0;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 原文：描边层
      Row()
        .width(15 * this.scaleRatio)
        .height(17 * this.scaleRatio)
        .borderRadius(BubbleShape.GLYPH_RADIUS * this.scaleRatio)
        .border({
          width: BubbleShape.GLYPH_STROKE * this.scaleRatio,
          color: BubbleColor.GLYPH_GHOST
        })
        .position({ x: 0, y: 3 * this.scaleRatio })
        .opacity(this.ghostVisible ? 1 : 0)
        .animation({ duration: 300, curve: Curve.EaseOut })

      // 副本：实心层
      Row()
        .width(15 * this.scaleRatio)
        .height(17 * this.scaleRatio)
        .borderRadius(BubbleShape.GLYPH_RADIUS * this.scaleRatio)
        .backgroundColor(BubbleColor.GLYPH)
        .position({ x: 7 * this.scaleRatio, y: 0 })
    }
    .width(22 * this.scaleRatio)
    .height(20 * this.scaleRatio)
    .translate({ x: this.shiftX })
    .animation({ duration: 300, curve: Curve.EaseOut })
  }
}

/**
 * 计数角标。贴右边时自动移到左上角，
 * 否则数字会被气泡自己藏进屏幕外 —— 这是唯一一处随 side 镜像的装饰。
 */
@Component
export struct BubbleBadge {
  @Prop count: number = 0;
  @Prop onLeft: boolean = false;
  @Prop visible: boolean = true;

  private label(): string {
    if (this.count > 99) {
      return '99+';
    }
    return this.count.toString();
  }

  build() {
    Text(this.label())
      .fontSize(10)
      .fontWeight(FontWeight.Medium)
      .fontColor(BubbleColor.BADGE_FG)
      .textAlign(TextAlign.Center)
      .constraintSize({ minWidth: 16 })
      .height(16)
      .padding({ left: 4, right: 4 })
      .backgroundColor(BubbleColor.BADGE_BG)
      .borderRadius(8)
      .border({ width: 2, color: '#E6FFFFFF' })
      .scale({ x: this.visible ? 1 : 0, y: this.visible ? 1 : 0 })
      .opacity(this.visible ? 1 : 0)
      .animation({ duration: 300, curve: curves.springMotion(0.3, 0.9) })
  }
}
```

### `entry/src/main/ets/bubble/ClipboardPanel.ets`

展开面板。刻意不含关闭按钮。

```typescript
/**
 * ClipboardPanel.ets
 * 展开后的剪贴板面板。
 *
 * 刻意不放关闭按钮：面板外任意点击或返回手势即可收起，
 * 少一个可点击目标，就少一次误触。
 */

import { BubbleColor, BubbleShape, BubbleSize } from './BubbleTokens';
import { ClipItem, ClipKind, ClipStyle, ClipUtil } from './ClipItem';

@Component
export struct ClipboardPanel {
  @Prop items: ClipItem[] = [];
  @Prop dark: boolean = false;
  /** 缩放原点，来自 DockEngine.panelAnchor */
  @Prop originX: number = 0;
  @Prop originY: number = 0.5;
  @Prop shown: boolean = false;

  onPick: (item: ClipItem) => void = () => {};
  onClear: () => void = () => {};

  @Builder
  itemRow(item: ClipItem) {
    Row({ space: 9 }) {
      Text(ClipUtil.styleOf(item.kind).tag)
        .fontSize(9)
        .fontWeight(FontWeight.Medium)
        .fontColor(ClipUtil.styleOf(item.kind).fg)
        .textAlign(TextAlign.Center)
        .width(22)
        .height(22)
        .borderRadius(7)
        .backgroundColor(ClipUtil.styleOf(item.kind).bg)

      Column({ space: 1 }) {
        Text(ClipUtil.preview(item.content))
          .fontSize(12)
          .fontColor(this.dark ? BubbleColor.PANEL_TEXT_DARK : BubbleColor.PANEL_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${ClipUtil.kindLabel(item.kind)} · ${ClipUtil.ago(item.time)}`)
          .fontSize(9.5)
          .fontColor(BubbleColor.PANEL_SUB)
          .maxLines(1)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(BubbleSize.ITEM_H)
    .padding({ left: 8, right: 8 })
    .borderRadius(12)
    .onClick(() => this.onPick(item))
  }

  @Builder
  emptyState() {
    Column({ space: 4 }) {
      Text('还没有复制过东西')
        .fontSize(12)
        .fontColor(this.dark ? BubbleColor.PANEL_TEXT_DARK : BubbleColor.PANEL_TEXT)
      Text('复制任意文本，它会出现在这里')
        .fontSize(10)
        .fontColor(BubbleColor.PANEL_SUB)
    }
    .width('100%')
    .height(BubbleSize.ITEM_H * 2)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Row() {
        Text('剪贴板')
          .fontSize(10)
          .fontColor(BubbleColor.PANEL_SUB)
          .letterSpacing(1.2)
        Blank()
        Text(this.items.length > 0 ? `${this.items.length} 条` : '空')
          .fontSize(10)
          .fontColor(BubbleColor.PANEL_SUB)
          .onClick(() => {
            if (this.items.length > 0) {
              this.onClear();
            }
          })
      }
      .width('100%')
      .height(BubbleSize.PANEL_HEAD_H)
      .padding({ left: 6, right: 6 })

      if (this.items.length === 0) {
        this.emptyState()
      } else {
        ForEach(this.items, (item: ClipItem) => {
          this.itemRow(item)
        }, (item: ClipItem) => item.id)
      }
    }
    .width(BubbleSize.PANEL_W)
    .padding(BubbleSize.PANEL_PAD)
    .backgroundColor(this.dark ? BubbleColor.PANEL_BG_DARK : BubbleColor.PANEL_BG_LIGHT)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(BubbleShape.PANEL_RADIUS)
    .shadow({ radius: 44, color: '#40101440', offsetX: 0, offsetY: 22 })
    .scale({
      x: this.shown ? 1 : 0.5,
      y: this.shown ? 1 : 0.5,
      centerX: `${this.originX * 100}%`,
      centerY: `${this.originY * 100}%`
    })
    .opacity(this.shown ? 1 : 0)
    .animation({ duration: 340, curve: curves.cubicBezierCurve(0.2, 1.15, 0.35, 1) })
  }
}
```

### `entry/src/main/ets/bubble/BubbleBridge.ets`

气泡与既有业务代码之间的唯一接触面。**这是本次唯一需要项目方填写实现的文件。**

```typescript
/**
 * BubbleBridge.ets
 * 气泡与你现有业务代码之间的唯一接触面。
 *
 * 气泡本体（bubble/ 目录下其余文件）不 import 你的任何模块，
 * 所有数据进出都走这里的四个钩子。你在自己原来的初始化位置
 * 挂上这些钩子即可，不需要改动气泡内部一行代码。
 *
 * 挂载示例（放在你原来创建悬浮窗的地方）：
 *
 *   import { BubbleBridge } from '../bubble/BubbleBridge';
 *   import { BubbleAdapter } from '../bubble/BubbleBridge';
 *
 *   BubbleBridge.hooks = {
 *     getItems: () => MyClipRepo.get().list().map(BubbleAdapter.from),
 *     onPick: (item) => MyClipRepo.get().copyToPasteboard(item.content),
 *     onHidden: () => MyNotify.showRecall(),
 *     onDockChange: (side, y) => MySettings.saveDock(side, y)
 *   };
 */

import { ClipItem, ClipKind, ClipUtil } from './ClipItem';
import { DockSide } from './DockEngine';

export interface BubbleHooks {
  /** 气泡展开时向你要数据。返回空数组会显示空状态。 */
  getItems: () => ClipItem[];
  /** 用户点了面板里某条记录。通常是写回系统剪贴板。 */
  onPick: (item: ClipItem) => void;
  /** 用户把气泡拖进底部吸入区隐藏了。你需要提供一个召回入口。 */
  onHidden: () => void;
  /** 气泡停靠位置变了，可用于持久化。 */
  onDockChange: (side: DockSide, y: number) => void;
}

class DefaultHooks implements BubbleHooks {
  getItems(): ClipItem[] {
    return [];
  }

  onPick(item: ClipItem): void {
    console.info(`CopyBubble picked: ${item.content}`);
  }

  onHidden(): void {
    console.info('CopyBubble hidden');
  }

  onDockChange(side: DockSide, y: number): void {
    console.info(`CopyBubble docked ${side} at ${y}`);
  }
}

export class BubbleBridge {
  static hooks: BubbleHooks = new DefaultHooks();

  /**
   * 通知气泡有新内容进来，触发捕获波纹与唤醒。
   * 在你原来写入剪贴记录的地方调一次即可。
   */
  static notifyCaptured(): void {
    const cur: number = AppStorage.get<number>('cb_pulse') ?? 0;
    AppStorage.setOrCreate('cb_pulse', cur + 1);
  }

  /** 从你的通知栏或应用内入口召回被隐藏的气泡 */
  static recall(): void {
    AppStorage.setOrCreate('cb_bubble_hidden', false);
  }

  /** 下层应用是深色时传 true，只影响展开面板的配色 */
  static setDarkHost(dark: boolean): void {
    AppStorage.setOrCreate('cb_dark_host', dark);
  }
}

/**
 * 把你自己的记录模型转成气泡认识的 ClipItem。
 * 如果你原来的模型字段名不同，改这里就够了。
 */
export class BubbleAdapter {
  /** 从最少的字段构造，类型自动识别 */
  static of(id: string, content: string, time: number): ClipItem {
    return new ClipItem(id, content, ClipUtil.detect(content), time);
  }

  /** 显式指定类型 */
  static ofKind(id: string, content: string, kind: ClipKind, time: number): ClipItem {
    return new ClipItem(id, content, kind, time);
  }
}
```

### `entry/src/main/ets/bubble/FloatBubble.ets`

气泡主组件，六态状态机与手势。

```typescript
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

import { BubbleColor, BubbleMotion, BubbleShape, BubbleSize } from './BubbleTokens';
import { DockEngine, DockSide, DockState, PanelAnchor, Rect } from './DockEngine';
import { BubbleBadge, BubbleIcon } from './BubbleIcon';
import { ClipboardPanel } from './ClipboardPanel';
import { ClipItem } from './ClipItem';
import { AppKeys } from './AppKeys';

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

  private engine: DockEngine = new DockEngine(360, 780);
  private dozeTimer: number = -1;
  private panelTimer: number = -1;
  private dragOriginX: number = 0;
  private dragOriginY: number = 0;

  aboutToAppear(): void {
    this.engine.updateScreen(this.hostW, this.hostH);
    // 恢复上次停靠位置
    const savedSide: string = AppStorage.get<string>(AppKeys.LAST_SIDE) ?? 'R';
    this.side = savedSide === 'L' ? DockSide.Left : DockSide.Right;
    const savedY: number = AppStorage.get<number>(AppKeys.LAST_Y) ?? 240;
    this.y = this.engine.clampY(savedY);
    this.x = this.engine.restX(this.side);
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
    this.dozeTimer = setTimeout(() => {
      if (this.state !== DockState.Docked) {
        return;
      }
      animateTo({ duration: BubbleMotion.DOZE_DURATION, curve: Curve.EaseOut }, () => {
        this.x = this.engine.dozeX(this.side);
        this.state = DockState.Dozing;
      });
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
    .position({ x: this.x, y: this.y })
    .visibility(this.state === DockState.Hidden ? Visibility.Hidden : Visibility.Visible)
    // 贴边与休眠只是视觉状态，读屏文案恒定
    .accessibilityLevel('yes')
    .accessibilityText(this.accessibilityLabel())
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        PanGesture({ fingers: 1, distance: 3 })
          .onActionStart(() => {
            clearTimeout(this.dozeTimer);
            this.dragOriginX = this.x;
            this.dragOriginY = this.y;
            this.dragging = true;
            this.state = DockState.Free;
            this.panelShown = false;
            this.emitRect();
          })
          .onActionUpdate((e: GestureEvent) => {
            this.x = this.engine.clampDragX(this.dragOriginX + e.offsetX);
            this.y = this.engine.clampDragY(this.dragOriginY + e.offsetY);
            this.dismissVisible = true;
            this.dismissArmed = this.engine.inDismissZone(this.x, this.y);
          })
          .onActionEnd(() => {
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
          .position({ x: this.anchor.x, y: this.anchor.y })
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
      const w: number = Number(newArea.width);
      const h: number = Number(newArea.height);
      if (w <= 0 || h <= 0) {
        return;
      }
      const oldH: number = this.engine.getScreenH();
      this.engine.updateScreen(w, h);
      // 横竖屏切换：按旧比例还原纵向位置，side 保持不变
      this.y = this.engine.remapOnResize(this.y, oldH, h);
      if (this.state !== DockState.Free && this.state !== DockState.Hidden) {
        this.x = this.state === DockState.Dozing
          ? this.engine.dozeX(this.side)
          : this.engine.restX(this.side);
      }
      this.emitRect();
    })
  }
}
```

### `entry/src/main/ets/bubble/BubbleWindowManager.ets`

悬浮窗宿主，负责 resize / move。若项目已有窗口管理代码，见第 5 节的替代方案。

```typescript
/**
 * BubbleWindowManager.ets
 * 悬浮窗宿主。把吸附计算留在 DockEngine，这里只负责搬窗口。
 *
 * 窗口尺寸策略：
 *   收起时窗口只有气泡那么大 → 窗口以外区域完全不拦截下层应用触摸；
 *   拖拽时铺满全屏 → 手指移出小窗不会断触；
 *   展开时扩到气泡 + 面板的并集。
 *
 * 需要在 module.json5 声明：
 *   "requestPermissions": [{ "name": "ohos.permission.SYSTEM_FLOAT_WINDOW" }]
 */

import { common } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { Rect } from './DockEngine';

const TAG: string = 'CopyBubble/Window';
const WINDOW_NAME: string = 'copy_bubble_float';

export class BubbleWindowManager {
  private static instance: BubbleWindowManager | undefined = undefined;
  private win: window.Window | undefined = undefined;
  private ctx: common.UIAbilityContext | undefined = undefined;
  private shown: boolean = false;

  static get(): BubbleWindowManager {
    if (!BubbleWindowManager.instance) {
      BubbleWindowManager.instance = new BubbleWindowManager();
    }
    return BubbleWindowManager.instance;
  }

  /** 屏幕逻辑尺寸，vp */
  screenSizeVp(): Rect {
    const d: display.Display = display.getDefaultDisplaySync();
    return { x: 0, y: 0, w: px2vp(d.width), h: px2vp(d.height) };
  }

  async create(ctx: common.UIAbilityContext): Promise<void> {
    if (this.win) {
      return;
    }
    this.ctx = ctx;
    try {
      const cfg: window.Configuration = {
        name: WINDOW_NAME,
        windowType: window.WindowType.TYPE_FLOAT,
        ctx: ctx
      };
      const w: window.Window = await window.createWindow(cfg);
      this.win = w;
      await w.setUIContent('pages/BubbleWindowPage');
      w.setWindowBackgroundColor('#00000000');
      await w.setWindowLayoutFullScreen(false);
      // 初始铺满，组件挂载后会立刻回调 onWindowRectChange 收缩
      const s: Rect = this.screenSizeVp();
      await this.applyRect(s);
      await w.showWindow();
      this.shown = true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.error(`${TAG} create failed ${err.code} ${err.message}`);
    }
  }

  /** 组件回调过来的目标矩形，单位 vp */
  async applyRect(r: Rect): Promise<void> {
    if (!this.win) {
      return;
    }
    try {
      await this.win.resize(vp2px(r.w), vp2px(r.h));
      await this.win.moveWindowTo(vp2px(r.x), vp2px(r.y));
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.error(`${TAG} applyRect failed ${err.code} ${err.message}`);
    }
  }

  async show(): Promise<void> {
    if (this.win && !this.shown) {
      await this.win.showWindow();
      this.shown = true;
    }
  }

  async hide(): Promise<void> {
    if (this.win && this.shown) {
      await this.win.hide();
      this.shown = false;
    }
  }

  async destroy(): Promise<void> {
    if (!this.win) {
      return;
    }
    try {
      await this.win.destroyWindow();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.error(`${TAG} destroy failed ${err.code} ${err.message}`);
    }
    this.win = undefined;
    this.shown = false;
  }

  isShown(): boolean {
    return this.shown;
  }
}
```

### `entry/src/main/ets/pages/BubbleWindowPage.ets`

悬浮窗 UI 承载页。新增页面，不覆盖任何现有页面。

```typescript
/**
 * BubbleWindowPage.ets
 * 悬浮窗的 UI 内容。这是一个新增页面，不会覆盖你现有的任何页面。
 *
 * 它只依赖 bubble/ 目录，所有业务数据从 BubbleBridge.hooks 取，
 * 不 import 你项目里的任何模块。
 */

import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { FloatBubble } from '../bubble/FloatBubble';
import { BubbleWindowManager } from '../bubble/BubbleWindowManager';
import { BubbleBridge } from '../bubble/BubbleBridge';
import { DockSide, Rect } from '../bubble/DockEngine';
import { ClipItem } from '../bubble/ClipItem';
import { AppKeys } from '../bubble/AppKeys';
import { BubbleSize } from '../bubble/BubbleTokens';

@Entry
@Component
struct BubbleWindowPage {
  @StorageLink(AppKeys.DARK_HOST) darkHost: boolean = false;
  /** 数据变更信号。业务侧调 BubbleBridge.notifyCaptured() 后这里会重新拉取。 */
  @StorageLink(AppKeys.PULSE) @Watch('reload') pulse: number = 0;

  @State private items: ClipItem[] = [];
  @State private hostW: number = 360;
  @State private hostH: number = 780;
  @State private keyboardH: number = 0;

  private mgr: BubbleWindowManager = BubbleWindowManager.get();

  aboutToAppear(): void {
    const s: Rect = this.mgr.screenSizeVp();
    this.hostW = s.w;
    this.hostH = s.h;
    this.reload();
    this.watchKeyboard();
  }

  private reload(): void {
    this.items = BubbleBridge.hooks.getItems();
  }

  /**
   * 输入法弹起时压缩可用高度，气泡会被 clampY 顶到键盘上方。
   * 不做的话，用户在聊天框打字时气泡正好压在候选词条上。
   */
  private watchKeyboard(): void {
    try {
      window.getLastWindow(getContext(this)).then((win: window.Window) => {
        win.on('keyboardHeightChange', (h: number) => {
          this.keyboardH = px2vp(h);
        });
      }).catch((e: BusinessError) => {
        console.error(`CopyBubble keyboard watch failed ${e.code}`);
      });
    } catch (e) {
      console.error('CopyBubble keyboard watch threw');
    }
  }

  private availableH(): number {
    if (this.keyboardH <= 0) {
      return this.hostH;
    }
    return Math.max(this.hostH - this.keyboardH - 16, BubbleSize.BUBBLE * 4);
  }

  build() {
    Stack() {
      FloatBubble({
        hostW: this.hostW,
        hostH: this.availableH(),
        dark: this.darkHost,
        items: this.items,
        onWindowRectChange: (r: Rect) => {
          this.mgr.applyRect(r);
        },
        onPick: (item: ClipItem) => {
          BubbleBridge.hooks.onPick(item);
        },
        onHidden: () => {
          BubbleBridge.hooks.onHidden();
        },
        onDockChange: (side: DockSide, y: number) => {
          BubbleBridge.hooks.onDockChange(side, y);
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}
```

### `entry/src/main/ets/pages/BubblePreviewPage.ets`

免权限调试页。可选，不需要可跳过，但跳过时第 4 节的页面注册也要相应少加一行。

```typescript
/**
 * BubblePreviewPage.ets
 * 应用内预览页。不需要悬浮窗权限就能跑通贴边、休眠、展开、隐藏全流程，
 * 改视觉的时候用它比反复授权快得多。
 */

import { router } from '@kit.ArkUI';
import { FloatBubble } from '../bubble/FloatBubble';
import { DockSide, Rect } from '../bubble/DockEngine';
import { ClipItem, ClipKind, ClipUtil } from '../bubble/ClipItem';
import { AppKeys } from '../bubble/AppKeys';

@Entry
@Component
struct BubblePreviewPage {
  @State private items: ClipItem[] = ClipUtil.mock();
  @State private dark: boolean = false;
  @State private rectLabel: string = '—';
  @State private dockLabel: string = 'R · 240';
  @StorageLink(AppKeys.PULSE) pulse: number = 0;
  @StorageLink(AppKeys.BUBBLE_HIDDEN) hidden: boolean = false;

  private lineWidths: number[] = [88, 100, 62, 88, 100, 62, 88, 100, 62, 88, 100, 62, 88, 100, 62];

  @Builder
  fakeApp() {
    Column({ space: 11 }) {
      Text('某篇正在阅读的长文')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.dark ? '#C4CBE4' : '#2A3050')
        .width('100%')
      ForEach(this.lineWidths, (w: number, i: number) => {
        Row()
          .width(`${w}%`)
          .height(9)
          .borderRadius(5)
          .backgroundColor(this.dark ? '#232842' : '#DCE1EE')
      }, (w: number, i: number) => `line_${i}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20, top: 60 })
  }

  @Builder
  debugBar() {
    Column({ space: 10 }) {
      Row({ space: 14 }) {
        Text(`rect  ${this.rectLabel}`)
          .fontSize(11)
          .fontColor('#8D97BE')
        Text(`dock  ${this.dockLabel}`)
          .fontSize(11)
          .fontColor('#8D97BE')
      }
      .width('100%')

      Row({ space: 8 }) {
        Button('模拟一次复制')
          .fontSize(12)
          .height(32)
          .backgroundColor('#5B6CF6')
          .onClick(() => {
            const text: string = `${Math.floor(Math.random() * 900000 + 100000)}`;
            const fresh: ClipItem =
              new ClipItem(`${Date.now()}`, text, ClipKind.Code, Date.now());
            const next: ClipItem[] = [fresh];
            for (let i = 0; i < this.items.length && i < 5; i++) {
              next.push(this.items[i]);
            }
            this.items = next;
            this.pulse = this.pulse + 1;
          })

        Button(this.dark ? '浅色应用底' : '深色应用底')
          .fontSize(12)
          .height(32)
          .backgroundColor('#2A31A8')
          .onClick(() => {
            this.dark = !this.dark;
          })

        if (this.hidden) {
          Button('召回')
            .fontSize(12)
            .height(32)
            .backgroundColor('#0F8D79')
            .onClick(() => {
              this.hidden = false;
            })
        }
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor(this.dark ? '#CC0A0E20' : '#E6FFFFFF')
    .borderRadius({ topLeft: 18, topRight: 18 })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 模拟下层应用
      Column() {
        this.fakeApp()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.dark ? '#101322' : '#F3F5FA')

      // 返回入口
      Row() {
        Text('返回')
          .fontSize(14)
          .fontColor(this.dark ? '#8D97BE' : '#5F6A94')
          .onClick(() => router.back())
      }
      .width('100%')
      .padding({ left: 20, top: 20 })
      .position({ x: 0, y: 0 })

      // 被测组件
      FloatBubble({
        hostW: 360,
        hostH: 720,
        dark: this.dark,
        items: this.items,
        onWindowRectChange: (r: Rect) => {
          this.rectLabel =
            `${Math.round(r.x)},${Math.round(r.y)} ${Math.round(r.w)}×${Math.round(r.h)}`;
        },
        onPick: (item: ClipItem) => {
          console.info(`preview picked: ${item.content}`);
        },
        onHidden: () => {
          console.info('preview: bubble hidden');
        },
        onDockChange: (side: DockSide, y: number) => {
          this.dockLabel = `${side} · ${Math.round(y)}`;
        }
      })

      this.debugBar()
    }
    .width('100%')
    .height('100%')
  }
}
```

---

## 3. 新增资源文件

这三个文件**可选**。气泡本体的图形由 `BubbleIcon.ets` 用代码绘制，不依赖任何图片资源。仅在需要同步更换应用图标、或需要通知栏召回入口时才拷入。

若拷入 `ic_copybubble_fg.svg` 与 `ic_copybubble_bg.svg`，需同时确认 `entry/src/main/resources/base/media/layered_image.json` 引用了它们：

```json
{
  "layered-image": {
    "background": "$media:ic_copybubble_bg",
    "foreground": "$media:ic_copybubble_fg"
  }
}
```

若该文件已存在且指向其他图标，**询问用户后再决定是否修改**，不要擅自替换应用图标。

### `entry/src/main/resources/base/media/ic_copybubble_fg.svg`

分层图标前景

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="288" height="288" viewBox="0 0 288 288" fill="none">
  <g transform="translate(144,144) scale(3.4) translate(-24,-24)">
    <rect x="13" y="17" width="15" height="17" rx="4.5" stroke="#EEF1FA" stroke-opacity="0.55" stroke-width="2.6"/>
    <rect x="20" y="14" width="15" height="17" rx="4.5" fill="#EEF1FA"/>
  </g>
</svg>
```

### `entry/src/main/resources/base/media/ic_copybubble_bg.svg`

分层图标背景

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="288" height="288" viewBox="0 0 288 288" fill="none">
  <defs>
    <linearGradient id="cbg" x1="36" y1="24" x2="252" y2="264" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#6E7CFF"/>
      <stop offset="0.52" stop-color="#3D45D8"/>
      <stop offset="1" stop-color="#232B92"/>
    </linearGradient>
  </defs>
  <rect width="288" height="288" fill="url(#cbg)"/>
</svg>
```

### `entry/src/main/resources/base/media/ic_bubble_mono.svg`

通知栏单色图标，气泡隐藏后的召回入口用

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 48 48" fill="none">
  <rect x="13" y="17" width="15" height="17" rx="4.5" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="2.6"/>
  <rect x="20" y="14" width="15" height="17" rx="4.5" fill="#FFFFFF"/>
</svg>
```

---

## 4. 需要修改的既有文件（共 3 处，全部为追加）

### 4.1 注册新页面

**文件**：`entry/src/main/resources/base/profile/main_pages.json`

**操作**：在 `src` 数组**末尾追加**两个条目。保留数组中原有的全部页面，不要重排、不要删除。

追加前（示意，你项目里的实际内容可能不同）：

```json
{
  "src": [
    "pages/Index"
  ]
}
```

追加后：

```json
{
  "src": [
    "pages/Index",
    "pages/BubbleWindowPage",
    "pages/BubblePreviewPage"
  ]
}
```

若第 2 节中未创建 `BubblePreviewPage.ets`，则只追加 `"pages/BubbleWindowPage"` 一行。

---

### 4.2 挂接线钩子

**文件**：项目中原本初始化剪贴板逻辑的位置。常见于以下之一，请先搜索确认：

- `entry/src/main/ets/entryability/EntryAbility.ets` 的 `onCreate` 或 `onWindowStageCreate`
- 项目自有的服务类，如 `ClipboardService.ets` / `ClipManager.ets` 的初始化方法

**操作**：在既有初始化代码**之后追加**以下内容，不要删除或改写原有初始化逻辑。

```typescript
import { BubbleBridge, BubbleAdapter } from '../bubble/BubbleBridge';
import { ClipItem } from '../bubble/ClipItem';

// 挂接气泡钩子。以下四个回调需替换为项目实际的方法调用。
BubbleBridge.hooks = {
  // 气泡展开时向业务层要数据。返回空数组会显示空状态。
  getItems: (): ClipItem[] => {
    // TODO: 替换为项目实际的记录仓库
    // 例：return MyClipRepo.get().list().map((r) => BubbleAdapter.of(r.id, r.content, r.time));
    return [];
  },
  // 用户点了面板里某条记录，通常是写回系统剪贴板
  onPick: (item: ClipItem): void => {
    // TODO: 替换为项目实际的剪贴板写回方法
    // 例：MyClipboard.writeBack(item.content);
  },
  // 用户把气泡拖进底部吸入区隐藏了，需提供召回入口（如常驻通知）
  onHidden: (): void => {
    // TODO: 例：MyNotify.showRecall();
  },
  // 停靠位置变化，可用于持久化。不需要则留空实现。
  onDockChange: (side: string, y: number): void => {
  }
};
```

**执行提示**：`getItems` 与 `onPick` 里的 TODO 需要读取项目现有代码后填写。若无法确定对应方法，**保留 TODO 并向用户报告需要补充的两处**，不要臆造方法名。

`BubbleAdapter.of(id, content, time)` 会自动识别内容类型（验证码 / 链接 / 文本）。若项目已有类型字段，改用 `BubbleAdapter.ofKind(id, content, kind, time)`。

---

### 4.3 新记录写入时通知气泡

**文件**：项目中原本往剪贴记录里写入新条目的位置。

**操作**：在写入语句**之后追加一行**。

```typescript
// 原有写入逻辑保持不变，例如：
// this.items.unshift(newItem);
// await this.persist();

BubbleBridge.notifyCaptured();   // 追加此行：触发捕获波纹并唤醒休眠中的气泡
```

这一行会让 `AppStorage` 的 `cb_pulse` 自增，气泡内部通过 `@Watch` 监听。不调用的话，新内容进来时气泡不会有反馈动效，功能其余部分仍正常。

---

## 5. 启动气泡

### 情况 A：项目原本没有悬浮窗代码，或愿意换掉

直接使用新增的 `BubbleWindowManager`：

```typescript
import { BubbleWindowManager } from '../bubble/BubbleWindowManager';

await BubbleWindowManager.get().create(this.context);
```

内部会自动 `setUIContent('pages/BubbleWindowPage')` 并设置透明背景。

### 情况 B：项目已有窗口管理代码，希望保留

保留原有代码，只需满足两个条件：

1. 悬浮窗的 UI 内容指向 `pages/BubbleWindowPage`
2. 把 `FloatBubble` 的 `onWindowRectChange` 回调接到项目自有的 resize / move 实现上

此时可以不拷入 `BubbleWindowManager.ets`，但需要改写 `BubbleWindowPage.ets` 中对 `BubbleWindowManager` 的两处引用（`screenSizeVp()` 与 `applyRect()`）为项目自有实现。

**窗口尺寸策略是本次改动的关键**，逻辑集中在 `DockEngine.windowRect()`，无论用哪种方案都必须遵守：

| 气泡状态 | 窗口大小 | 原因 |
| --- | --- | --- |
| 收起（Docked / Dozing） | 48×48vp | 窗口以外区域完全不拦截下层应用触摸 |
| 拖拽（Free / Snapping） | 铺满全屏 | 手指移出小窗会断触 |
| 展开（Expanded） | 气泡与面板的并集 | 面板要完整显示，又不该全屏拦截 |

---

## 6. 权限

只需要一条。**若 `module.json5` 中已存在则跳过，不要重复添加。**

```json5
{
  "name": "ohos.permission.SYSTEM_FLOAT_WINDOW",
  "reason": "$string:reason_float_window",
  "usedScene": { "abilities": ["EntryAbility"], "when": "always" }
}
```

若添加了 `reason` 引用，需在 `entry/src/main/resources/base/element/string.json` 的 `string` 数组中**追加**（不要覆盖整个文件）：

```json
{ "name": "reason_float_window", "value": "用于在其他应用上方显示剪贴气泡" }
```

---

## 7. 单元测试（可选但建议）

创建 `entry/src/ohosTest/ets/test/DockEngine.test.ets`。若该目录下已有 `List.test.ets`，在其中追加一行 `dockEngineTest();` 调用。

```typescript
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

    it('收起时窗口只有气泡大小', 0, () => {
      const e: DockEngine = new DockEngine(W, H);
      const r: Rect = e.windowRect(DockState.Docked, DockSide.Right, e.restX(DockSide.Right), 300, 3);
      expect(r.w).assertEqual(BubbleSize.BUBBLE);
      expect(r.h).assertEqual(BubbleSize.BUBBLE);
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
```

13 个断言覆盖的是最容易写错的部分：吸附侧判定、中线归属、左侧负坐标、休眠位相对关系、安全区钳制、面板镜像、面板越界、三种窗口尺寸、隐藏吸入区、横竖屏还原。

---

## 8. 验收清单

实施完成后逐项确认：

**编译与静态检查**

- [ ] 工程可正常编译，无 ArkTS 类型报错
- [ ] `bubble/` 目录下除 `BubbleBridge.ets` 外，没有任何文件 import 项目业务模块（可用 grep 验证）
- [ ] 既有文件的改动全部是追加，`git diff` 中没有删除行（`BubbleBridge` 的 TODO 填写除外）

**功能**

- [ ] 气泡拖动后松手，弹簧吸附到最近的左侧或右侧边缘，带轻微过冲
- [ ] 拖到屏幕中线附近松手不出现左右横跳
- [ ] 贴边后气泡变为 D 形：外侧圆角，内侧平直
- [ ] 贴左边时图形向右偏 3vp，贴右边时向左偏 3vp
- [ ] 计数角标在贴右边时位于左上角，贴左边时位于右上角
- [ ] 静置 2.5 秒后气泡外推并变淡，描边层消失
- [ ] 休眠状态下点击气泡只唤醒，不直接展开面板
- [ ] 唤醒后再次点击才展开面板
- [ ] 贴左边时面板向右展开，贴右边时向左展开
- [ ] 气泡在屏幕下缘时，面板向上生长且不越出底部安全区
- [ ] 点击面板外任意位置收起面板
- [ ] 拖到屏幕底部中央出现「松手隐藏气泡」提示，松手后气泡消失
- [ ] 展开面板期间不会自动进入休眠

**边界**

- [ ] 气泡收起时，点击气泡以外的屏幕区域，事件正常传递给下层应用
- [ ] 拖拽过程中手指快速移动到屏幕边缘不断触
- [ ] 横竖屏切换后气泡不飞出屏幕，仍贴在原来那一侧
- [ ] 输入法弹起时气泡不遮挡候选词条
- [ ] 无障碍读屏播报恒为「剪贴板，N 条记录」，不随贴边或休眠状态变化

---

## 9. 已知需要人工确认的两处

以下两处规格中无法给出确定答案，需读取项目现有代码后填写，或向用户询问：

1. **`BubbleBridge.hooks.getItems`** —— 项目现有的剪贴记录仓库类名与列表方法
2. **`BubbleBridge.hooks.onPick`** —— 项目现有的「写回系统剪贴板」方法

若两处均无法确定，保留 TODO 注释并明确报告，不要臆造。此时气泡的视觉与交互全部可用，只是面板内为空状态。
