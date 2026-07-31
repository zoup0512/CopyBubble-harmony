import { ClipType } from '../model/ClipItem';

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

  private static readonly STYLES: Map<string, TypeStyle> = new Map<string, TypeStyle>([
    [ClipType.TEXT as string, new TypeStyle('文本', '✎', '#4C5BD4', '#ECEEFF')],
    [ClipType.LINK as string, new TypeStyle('链接', '⛓', '#0F9D8F', '#E3F6F3')],
    [ClipType.PHONE as string, new TypeStyle('电话', '☎', '#D97706', '#FDF0DC')],
    [ClipType.EMAIL as string, new TypeStyle('邮箱', '✉', '#DB2777', '#FCE7F2')],
    [ClipType.CODE as string, new TypeStyle('验证码', '＃', '#7A5CE8', '#F0EBFF')],
    [ClipType.NUMBER as string, new TypeStyle('数字', '№', '#2563EB', '#E4EDFE')],
    [ClipType.ADDRESS as string, new TypeStyle('地址', '⌖', '#059669', '#E2F5EE')]
  ]);

  static styleOf(type: ClipType): TypeStyle {
    const s: TypeStyle | undefined = Theme.STYLES.get(type as string);
    return s !== undefined ? s : new TypeStyle('文本', '✎', Theme.BRAND, '#ECEEFF');
  }
}

/** 存储键与容量上限 */
export class Const {
  static readonly PREF_NAME: string = 'copy_bubble_store';
  static readonly KEY_ITEMS: string = 'clip_items';
  static readonly KEY_AUTO_CAPTURE: string = 'auto_capture';
  static readonly KEY_FLOAT_BUBBLE: string = 'float_bubble';
  static readonly KEY_DEDUPE: string = 'dedupe';
  static readonly KEY_MAX: string = 'max_records';
  static readonly KEY_HAPTIC: string = 'haptic';

  static readonly DEFAULT_MAX: number = 200;
  static readonly MAX_OPTIONS: number[] = [50, 100, 200, 500];
  static readonly PREVIEW_LIMIT: number = 240;
}
