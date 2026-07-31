/**
 * Copy Bubble - 数据模型
 * bundleName: com.razor.tools.copybubble
 */

/** 剪贴内容类型 */
export enum ClipType {
  TEXT = 'text',
  LINK = 'link',
  PHONE = 'phone',
  EMAIL = 'email',
  CODE = 'code',
  NUMBER = 'number',
  ADDRESS = 'address'
}

/** 持久化用的纯数据结构（可被 JSON 直接序列化） */
export interface ClipItemRaw {
  id: string;
  content: string;
  type: string;
  createTime: number;
  updateTime: number;
  pinned: boolean;
  useCount: number;
  source: string;
}

/** 列表项模型，@Observed 以支持卡片内属性变更驱动刷新 */
@Observed
export class ClipItem {
  id: string = '';
  content: string = '';
  type: ClipType = ClipType.TEXT;
  createTime: number = 0;
  updateTime: number = 0;
  pinned: boolean = false;
  useCount: number = 0;
  source: string = '';

  constructor(content: string, type: ClipType, source: string) {
    const now: number = Date.now();
    this.id = `${now}_${Math.floor(Math.random() * 100000)}`;
    this.content = content;
    this.type = type;
    this.createTime = now;
    this.updateTime = now;
    this.source = source;
  }

  /** 单行预览：折叠换行与连续空白 */
  get preview(): string {
    return this.content.replace(/\s+/g, ' ').trim();
  }

  get charCount(): number {
    return this.content.length;
  }

  toRaw(): ClipItemRaw {
    const raw: ClipItemRaw = {
      id: this.id,
      content: this.content,
      type: this.type as string,
      createTime: this.createTime,
      updateTime: this.updateTime,
      pinned: this.pinned,
      useCount: this.useCount,
      source: this.source
    };
    return raw;
  }

  static fromRaw(raw: ClipItemRaw): ClipItem {
    const item: ClipItem = new ClipItem(raw.content, raw.type as ClipType, raw.source);
    item.id = raw.id;
    item.createTime = raw.createTime;
    item.updateTime = raw.updateTime;
    item.pinned = raw.pinned;
    item.useCount = raw.useCount;
    return item;
  }
}

/** 分类筛选项 */
export class Category {
  key: string = 'all';
  label: string = '全部';

  constructor(key: string, label: string) {
    this.key = key;
    this.label = label;
  }
}

export const CATEGORIES: Category[] = [
  new Category('all', '全部'),
  new Category('pinned', '置顶'),
  new Category(ClipType.LINK as string, '链接'),
  new Category(ClipType.CODE as string, '验证码'),
  new Category(ClipType.PHONE as string, '电话'),
  new Category(ClipType.EMAIL as string, '邮箱'),
  new Category(ClipType.TEXT as string, '文本')
];

/** 路由参数：ArkTS 的 navDestination 只接受 object，不能直接塞字符串 */
export class NavParam {
  id: string = '';

  constructor(id: string) {
    this.id = id;
  }
}
