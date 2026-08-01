/**
 * ClipItem.ets
 * 剪贴记录模型。类型识别只做三档：验证码、链接、文本。
 * 分得再细，用户在 226vp 宽的面板里也认不出差别。
 */

import { BubbleColor } from './BubbleTokens';
import { I18n } from '../common/I18n';

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
      return new ClipStyle(BubbleColor.TAG_LINK_BG, BubbleColor.TAG_LINK_FG, I18n.t('tag_link'));
    }
    if (kind === ClipKind.Code) {
      return new ClipStyle(BubbleColor.TAG_CODE_BG, BubbleColor.TAG_CODE_FG, I18n.t('tag_code'));
    }
    return new ClipStyle(BubbleColor.TAG_TEXT_BG, BubbleColor.TAG_TEXT_FG, I18n.t('tag_text'));
  }

  static kindLabel(kind: ClipKind): string {
    if (kind === ClipKind.Link) {
      return I18n.t('type_link');
    }
    if (kind === ClipKind.Code) {
      return I18n.t('type_code');
    }
    return I18n.t('type_text');
  }

  /** 相对时间。超过一天只说「昨天 / N 天前」，不显示具体时刻。 */
  static ago(time: number): string {
    const d: number = Date.now() - time;
    if (d < 60000) {
      return I18n.f('ago_seconds', `${Math.max(Math.floor(d / 1000), 1)}`);
    }
    if (d < 3600000) {
      return I18n.f('minutes_ago', `${Math.floor(d / 60000)}`);
    }
    if (d < 86400000) {
      return I18n.f('ago_hours', `${Math.floor(d / 3600000)}`);
    }
    if (d < 172800000) {
      return I18n.t('ago_yesterday');
    }
    return I18n.f('ago_days', `${Math.floor(d / 86400000)}`);
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
      new ClipItem('3', I18n.t('preview_mock_text'), ClipKind.Text, now - 90000000)
    ];
  }
}
