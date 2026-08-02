import { ClipType } from '../model/ClipItem';
import { I18n } from './I18n';

/** 每种内容类型的视觉标识 */
export class TypeStyle {
  label: string = '';
  glyph: string = '';
  tint: string = '';
  wash: string = '';

  constructor(label: string, glyph: string, tint: string, wash: string) {
    this.label = label;
    this.glyph = glyph;
    this.tint = tint;
    this.wash = wash;
  }
}

/** 每种类型的样式条目：i18n key + glyph + tint + wash */
class StyleEntry {
  key: string = '';
  glyph: string = '';
  tint: string = '';
  wash: string = '';

  constructor(key: string, glyph: string, tint: string, wash: string) {
    this.key = key;
    this.glyph = glyph;
    this.tint = tint;
    this.wash = wash;
  }
}

/**
 * 调色板：以靛蓝为主色，七种内容类型各有独立色相，
 * 让气泡列表在滚动时靠颜色就能区分内容种类。
 */
export class Theme {
  static readonly BRAND: string = '#4C5BD4';
  static readonly BRAND_SOFT: string = '#7A5CE8';
  static readonly PAGE_BG: string = '#F3F4FB';
  static readonly CARD_BG: string = '#FFFFFF';
  static readonly TEXT_1: string = '#141626';
  static readonly TEXT_2: string = '#6B6F85';
  static readonly TEXT_3: string = '#9EA2B8';
  static readonly DIVIDER: string = '#E6E7F0';
  static readonly DANGER: string = '#E5484D';
  static readonly PIN: string = '#F5A524';

  static readonly RADIUS_CARD: number = 20;
  static readonly RADIUS_CHIP: number = 999;
  static readonly GAP: number = 12;
  static readonly PAGE_PAD: number = 16;

  private static readonly STYLES: Map<string, StyleEntry> = new Map<string, StyleEntry>([
    [ClipType.TEXT as string, new StyleEntry('type_text', '✎', '#4C5BD4', '#ECEEFF')],
    [ClipType.LINK as string, new StyleEntry('type_link', '⛓', '#0F9D8F', '#E3F6F3')],
    [ClipType.PHONE as string, new StyleEntry('type_phone', '☎', '#D97706', '#FDF0DC')],
    [ClipType.EMAIL as string, new StyleEntry('type_email', '✉', '#DB2777', '#FCE7F2')],
    [ClipType.CODE as string, new StyleEntry('type_code', '＃', '#7A5CE8', '#F0EBFF')],
    [ClipType.NUMBER as string, new StyleEntry('type_number', '№', '#2563EB', '#E4EDFE')],
    [ClipType.ADDRESS as string, new StyleEntry('type_address', '⌖', '#059669', '#E2F5EE')]
  ]);

  static styleOf(type: ClipType): TypeStyle {
    const e: StyleEntry | undefined = Theme.STYLES.get(type as string);
    if (e === undefined) {
      return new TypeStyle(I18n.t('type_text'), '✎', Theme.BRAND, '#ECEEFF');
    }
    return new TypeStyle(I18n.t(e.key), e.glyph, e.tint, e.wash);
  }
}

/** 存储键与容量上限 */
export class Const {
  static readonly PREF_NAME: string = 'copy_bubble_store';
  static readonly KEY_ITEMS: string = 'clip_items';
  static readonly KEY_AUTO_CAPTURE: string = 'auto_capture';
  static readonly KEY_CLIP_PERM_PROMPTED: string = 'clip_perm_prompted';
  static readonly KEY_FLOAT_BUBBLE: string = 'float_bubble';
  static readonly KEY_DEDUPE: string = 'dedupe';
  static readonly KEY_MAX: string = 'max_records';
  static readonly KEY_HAPTIC: string = 'haptic';
  static readonly KEY_FEEDBACK_DONE: string = 'feedback_done';
  static readonly KEY_FEEDBACK_LAUNCH_COUNT: string = 'feedback_launch_count';
  static readonly FEEDBACK_LAUNCH_THRESHOLD: number = 3;

  static readonly DEFAULT_MAX: number = 100;
  static readonly MAX_UNLIMITED: number = 0;
  static readonly MAX_OPTIONS: number[] = [10, 50, 100, Const.MAX_UNLIMITED];
  static readonly PREVIEW_LIMIT: number = 240;
}
