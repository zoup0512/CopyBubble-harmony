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

/** 每种类型的样式条目：i18n key + glyph + 深浅两套 tint/wash */
class StyleEntry {
  key: string = '';
  glyph: string = '';
  tint: string = '';
  wash: string = '';
  tintDark: string = '';
  washDark: string = '';

  constructor(key: string, glyph: string, tint: string, wash: string, tintDark: string, washDark: string) {
    this.key = key;
    this.glyph = glyph;
    this.tint = tint;
    this.wash = wash;
    this.tintDark = tintDark;
    this.washDark = washDark;
  }
}

/** 深浅色各自的完整色板 */
class Palette {
  pageBg: string = '';
  cardBg: string = '';
  text1: string = '';
  text2: string = '';
  text3: string = '';
  divider: string = '';
  danger: string = '';
  pin: string = '';
  brand: string = '';
  brandSoft: string = '';
  inputBg: string = '';
  cancelBg: string = '';
  chipUnselBg: string = '';
  chipAccentBg: string = '';
  pinChipBg: string = '';
  dangerChipBg: string = '';

  constructor(pageBg: string, cardBg: string, text1: string, text2: string, text3: string,
    divider: string, danger: string, pin: string, brand: string, brandSoft: string,
    inputBg: string, cancelBg: string, chipUnselBg: string, chipAccentBg: string, pinChipBg: string,
    dangerChipBg: string) {
    this.pageBg = pageBg;
    this.cardBg = cardBg;
    this.text1 = text1;
    this.text2 = text2;
    this.text3 = text3;
    this.divider = divider;
    this.danger = danger;
    this.pin = pin;
    this.brand = brand;
    this.brandSoft = brandSoft;
    this.inputBg = inputBg;
    this.cancelBg = cancelBg;
    this.chipUnselBg = chipUnselBg;
    this.chipAccentBg = chipAccentBg;
    this.pinChipBg = pinChipBg;
    this.dangerChipBg = dangerChipBg;
  }
}

/** 浅色色板（原硬编码值） */
const LIGHT: Palette = new Palette(
  '#F3F4FB', '#FFFFFF', '#141626', '#6B6F85', '#9EA2B8',
  '#E6E7F0', '#E5484D', '#F5A524', '#4C5BD4', '#7A5CE8',
  '#F5F5FA', '#F0F0F6', '#F2F2F8', '#ECEEFF', '#FDF3E0',
  '#FDECEC'
);

/** 深色色板：深蓝底、提亮主色与文字，保证对比度达标 */
const DARK: Palette = new Palette(
  '#0E0F17', '#1B1D2A', '#E9EBF7', '#A3A8C2', '#6E738F',
  '#2B2E40', '#FF6B70', '#FFB84D', '#6E7CFF', '#8F7AFF',
  '#262840', '#2B2D3F', '#262840', '#2B3055', '#3A2F1E',
  '#3A2226'
);

/**
 * 调色板：以靛蓝为主色，七种内容类型各有独立色相，
 * 让气泡列表在滚动时靠颜色就能区分内容种类。
 * 所有颜色均为 getter，读取时按 AppStorage['darkMode'] 取深浅色板——
 * 组件只需声明 @StorageProp(Theme.KEY_DARK_MODE) 即可在系统深浅色切换时自动重绘。
 */
export class Theme {
  static readonly KEY_DARK_MODE: string = 'darkMode';

  static isDark(): boolean {
    return AppStorage.get<boolean>(Theme.KEY_DARK_MODE) ?? false;
  }

  private static p(): Palette {
    return Theme.isDark() ? DARK : LIGHT;
  }

  static get BRAND(): string {
    return Theme.p().brand;
  }
  static get BRAND_SOFT(): string {
    return Theme.p().brandSoft;
  }
  static get PAGE_BG(): string {
    return Theme.p().pageBg;
  }
  static get CARD_BG(): string {
    return Theme.p().cardBg;
  }
  static get TEXT_1(): string {
    return Theme.p().text1;
  }
  static get TEXT_2(): string {
    return Theme.p().text2;
  }
  static get TEXT_3(): string {
    return Theme.p().text3;
  }
  static get DIVIDER(): string {
    return Theme.p().divider;
  }
  static get DANGER(): string {
    return Theme.p().danger;
  }
  static get PIN(): string {
    return Theme.p().pin;
  }
  /** 输入框底色（编辑框、取消/置顶按钮等浅灰块） */
  static get INPUT_BG(): string {
    return Theme.p().inputBg;
  }
  /** 取消按钮底色 */
  static get CANCEL_BG(): string {
    return Theme.p().cancelBg;
  }
  /** 容量选项等未选中色块底色 */
  static get CHIP_UNSEL_BG(): string {
    return Theme.p().chipUnselBg;
  }
  /** 「复制」按钮等强调色块底色 */
  static get CHIP_ACCENT_BG(): string {
    return Theme.p().chipAccentBg;
  }
  /** 「已置顶」标签色块底色 */
  static get PIN_CHIP_BG(): string {
    return Theme.p().pinChipBg;
  }
  /** 危险操作色块底色（删除按钮等） */
  static get DANGER_CHIP_BG(): string {
    return Theme.p().dangerChipBg;
  }

  static readonly RADIUS_CARD: number = 20;
  static readonly RADIUS_CHIP: number = 999;
  static readonly GAP: number = 12;
  static readonly PAGE_PAD: number = 16;

  private static readonly STYLES: Map<string, StyleEntry> = new Map<string, StyleEntry>([
    [ClipType.TEXT as string, new StyleEntry('type_text', '✎', '#4C5BD4', '#ECEEFF', '#7B87F5', '#242E5A')],
    [ClipType.LINK as string, new StyleEntry('type_link', '⛓', '#0F9D8F', '#E3F6F3', '#2FD3C2', '#173B38')],
    [ClipType.PHONE as string, new StyleEntry('type_phone', '☎', '#D97706', '#FDF0DC', '#FFA94D', '#3A2F1E')],
    [ClipType.EMAIL as string, new StyleEntry('type_email', '✉', '#DB2777', '#FCE7F2', '#FF7AB0', '#3A2130')],
    [ClipType.CODE as string, new StyleEntry('type_code', '＃', '#7A5CE8', '#F0EBFF', '#9B8CFF', '#2C2444')],
    [ClipType.NUMBER as string, new StyleEntry('type_number', '№', '#2563EB', '#E4EDFE', '#6CA0FF', '#1C2C4E')],
    [ClipType.ADDRESS as string, new StyleEntry('type_address', '⌖', '#059669', '#E2F5EE', '#2FD08C', '#18372C')]
  ]);

  static styleOf(type: ClipType): TypeStyle {
    const e: StyleEntry | undefined = Theme.STYLES.get(type as string);
    if (e === undefined) {
      const tint: string = Theme.isDark() ? '#7B87F5' : Theme.BRAND;
      const wash: string = Theme.isDark() ? '#242E5A' : '#ECEEFF';
      return new TypeStyle(I18n.t('type_text'), '✎', tint, wash);
    }
    const dark: boolean = Theme.isDark();
    return new TypeStyle(I18n.t(e.key), e.glyph,
      dark ? e.tintDark : e.tint, dark ? e.washDark : e.wash);
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
  static readonly KEY_HELP_SEEDED: string = 'help_seeded';

  static readonly DEFAULT_MAX: number = 100;
  static readonly MAX_UNLIMITED: number = 0;
  static readonly MAX_OPTIONS: number[] = [10, 50, 100, Const.MAX_UNLIMITED];
  static readonly PREVIEW_LIMIT: number = 240;
}
