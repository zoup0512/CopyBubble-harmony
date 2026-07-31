import { ClipType } from '../model/ClipItem';

/**
 * 内容类型识别：按“越具体越优先”的顺序匹配，
 * 只有全部落空才归到纯文本。
 */
export class TypeDetector {
  private static readonly RE_URL: RegExp = /^(https?:\/\/|www\.)\S+$/i;
  private static readonly RE_URL_IN: RegExp = /(https?:\/\/\S{4,})/i;
  private static readonly RE_EMAIL: RegExp = /^[\w.+-]+@[\w-]+(\.[\w-]+)+$/;
  private static readonly RE_PHONE_CN: RegExp = /^(\+?86)?1[3-9]\d{9}$/;
  private static readonly RE_PHONE_INTL: RegExp = /^\+?\d[\d\s-]{6,18}\d$/;
  private static readonly RE_CODE_CTX: RegExp = /(验证码|校验码|动态码|安全码|verification\s*code|otp)/i;
  private static readonly RE_CODE_PURE: RegExp = /^\d{4,8}$/;
  private static readonly RE_NUMBER: RegExp = /^[\d\s-]{9,32}$/;
  private static readonly RE_ADDRESS: RegExp = /(省|市|区|县|街道|路|号楼|小区|大厦|栋|单元|室)/;

  static detect(input: string): ClipType {
    const text: string = input.trim();
    if (text.length === 0) {
      return ClipType.TEXT;
    }
    if (TypeDetector.RE_URL.test(text)) {
      return ClipType.LINK;
    }
    if (TypeDetector.RE_EMAIL.test(text)) {
      return ClipType.EMAIL;
    }
    if (TypeDetector.RE_PHONE_CN.test(text.replace(/[\s-]/g, ''))) {
      return ClipType.PHONE;
    }
    if (TypeDetector.RE_CODE_PURE.test(text)) {
      return ClipType.CODE;
    }
    if (text.length <= 120 && TypeDetector.RE_CODE_CTX.test(text) && /\d{4,8}/.test(text)) {
      return ClipType.CODE;
    }
    if (text.length <= 200 && TypeDetector.RE_URL_IN.test(text)) {
      return ClipType.LINK;
    }
    if (TypeDetector.RE_PHONE_INTL.test(text)) {
      return ClipType.PHONE;
    }
    if (TypeDetector.RE_NUMBER.test(text)) {
      return ClipType.NUMBER;
    }
    if (text.length <= 80 && TypeDetector.RE_ADDRESS.test(text)) {
      return ClipType.ADDRESS;
    }
    return ClipType.TEXT;
  }

  /** 从任意文本里抽出第一个可直接跳转的链接 */
  static extractUrl(text: string): string {
    const m: RegExpMatchArray | null = text.match(TypeDetector.RE_URL_IN);
    if (m !== null && m.length > 1) {
      return m[1];
    }
    if (/^www\./i.test(text.trim())) {
      return `https://${text.trim()}`;
    }
    return '';
  }

  /** 从验证码短信里抽出那串数字 */
  static extractCode(text: string): string {
    const m: RegExpMatchArray | null = text.match(/\d{4,8}/);
    return m !== null ? m[0] : '';
  }
}
