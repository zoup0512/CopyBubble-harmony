import { hilog } from '@kit.PerformanceAnalysisKit';
import { ClipItem, ClipItemRaw, ClipType } from '../model/ClipItem';
import { TypeDetector } from '../utils/TypeDetector';
import { StorageManager } from './StorageManager';
import { Const } from '../common/Theme';
import { BubbleBridge } from '../bubble/BubbleBridge';

const TAG: string = 'CopyBubble/Store';
const DOMAIN: number = 0x1001;

export type StoreListener = () => void;

/** 统计信息 */
export class StoreStats {
  total: number = 0;
  pinned: number = 0;
  today: number = 0;
}

/**
 * 单一数据源。所有页面从这里读，写入后通过监听回调触发刷新。
 */
export class ClipStore {
  private static instance: ClipStore | null = null;
  private items: ClipItem[] = [];
  private listeners: StoreListener[] = [];
  private loaded: boolean = false;

  static getInstance(): ClipStore {
    if (ClipStore.instance === null) {
      ClipStore.instance = new ClipStore();
    }
    return ClipStore.instance;
  }

  // ---------- 订阅 ----------

  subscribe(fn: StoreListener): void {
    this.listeners.push(fn);
  }

  unsubscribe(fn: StoreListener): void {
    const idx: number = this.listeners.indexOf(fn);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  private emit(): void {
    this.listeners.forEach((fn: StoreListener) => fn());
  }

  // ---------- 读写 ----------

  async load(): Promise<void> {
    if (this.loaded) {
      return;
    }
    const sm: StorageManager = StorageManager.getInstance();
    const json: string = sm.getString(Const.KEY_ITEMS, '[]');
    try {
      const raws: ClipItemRaw[] = JSON.parse(json) as ClipItemRaw[];
      this.items = raws.map((r: ClipItemRaw) => ClipItem.fromRaw(r));
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'parse history failed, starting empty');
      this.items = [];
    }
    this.loaded = true;
    this.sort();
    this.emit();
  }

  private async persist(): Promise<void> {
    const raws: ClipItemRaw[] = this.items.map((i: ClipItem) => i.toRaw());
    await StorageManager.getInstance().put(Const.KEY_ITEMS, JSON.stringify(raws));
  }

  private sort(): void {
    this.items.sort((a: ClipItem, b: ClipItem): number => {
      if (a.pinned !== b.pinned) {
        return a.pinned ? -1 : 1;
      }
      return b.updateTime - a.updateTime;
    });
  }

  // ---------- 业务 ----------

  /**
   * 收录一条内容。
   * @returns 真正新增返回 ClipItem，重复或空内容返回 null
   */
  async add(content: string, source: string): Promise<ClipItem | null> {
    const text: string = content;
    if (text.trim().length === 0) {
      return null;
    }

    const dedupe: boolean = StorageManager.getInstance().getBool(Const.KEY_DEDUPE, true);
    if (dedupe) {
      const existing: ClipItem | undefined = this.items.find((i: ClipItem) => i.content === text);
      if (existing !== undefined) {
        existing.updateTime = Date.now();
        this.sort();
        await this.persist();
        this.emit();
        return null;
      }
    }

    const type: ClipType = TypeDetector.detect(text);
    const item: ClipItem = new ClipItem(text, type, source);
    this.items.unshift(item);
    this.trim();
    this.sort();
    await this.persist();
    this.emit();
    // 真正新增时通知气泡：触发捕获波纹并唤醒休眠中的气泡
    BubbleBridge.notifyCaptured();
    return item;
  }

  /** 超出上限时，从未置顶的旧记录里裁掉；MAX_UNLIMITED 表示无上限 */
  private trim(): void {
    const max: number = StorageManager.getInstance().getNumber(Const.KEY_MAX, Const.DEFAULT_MAX);
    if (max === Const.MAX_UNLIMITED || this.items.length <= max) {
      return;
    }
    const pinned: ClipItem[] = this.items.filter((i: ClipItem) => i.pinned);
    const rest: ClipItem[] = this.items.filter((i: ClipItem) => !i.pinned);
    rest.sort((a: ClipItem, b: ClipItem): number => b.updateTime - a.updateTime);
    const keep: number = Math.max(0, max - pinned.length);
    this.items = pinned.concat(rest.slice(0, keep));
  }

  async update(id: string, content: string): Promise<void> {
    const item: ClipItem | undefined = this.items.find((i: ClipItem) => i.id === id);
    if (item === undefined) {
      return;
    }
    item.content = content;
    item.type = TypeDetector.detect(content);
    item.updateTime = Date.now();
    this.sort();
    await this.persist();
    this.emit();
  }

  async togglePin(id: string): Promise<boolean> {
    const item: ClipItem | undefined = this.items.find((i: ClipItem) => i.id === id);
    if (item === undefined) {
      return false;
    }
    item.pinned = !item.pinned;
    this.sort();
    await this.persist();
    this.emit();
    return item.pinned;
  }

  async markUsed(id: string): Promise<void> {
    const item: ClipItem | undefined = this.items.find((i: ClipItem) => i.id === id);
    if (item === undefined) {
      return;
    }
    item.useCount += 1;
    await this.persist();
  }

  async remove(id: string): Promise<void> {
    this.items = this.items.filter((i: ClipItem) => i.id !== id);
    await this.persist();
    this.emit();
  }

  /** 清空未置顶记录，置顶内容保留 */
  async clearUnpinned(): Promise<number> {
    const before: number = this.items.length;
    this.items = this.items.filter((i: ClipItem) => i.pinned);
    await this.persist();
    this.emit();
    return before - this.items.length;
  }

  async clearAll(): Promise<void> {
    this.items = [];
    await this.persist();
    this.emit();
  }

  // ---------- 查询 ----------

  getById(id: string): ClipItem | null {
    const item: ClipItem | undefined = this.items.find((i: ClipItem) => i.id === id);
    return item !== undefined ? item : null;
  }

  query(category: string, keyword: string): ClipItem[] {
    const kw: string = keyword.trim().toLowerCase();
    return this.items.filter((i: ClipItem) => {
      let hitCat: boolean = true;
      if (category === 'pinned') {
        hitCat = i.pinned;
      } else if (category !== 'all') {
        hitCat = (i.type as string) === category;
      }
      const hitKw: boolean = kw.length === 0 || i.content.toLowerCase().includes(kw);
      return hitCat && hitKw;
    });
  }

  /** 气泡悬浮窗只需要最近几条 */
  recent(limit: number): ClipItem[] {
    return this.items.slice(0, limit);
  }

  countOf(category: string): number {
    return this.query(category, '').length;
  }

  stats(): StoreStats {
    const s: StoreStats = new StoreStats();
    s.total = this.items.length;
    s.pinned = this.items.filter((i: ClipItem) => i.pinned).length;
    const dayStart: number = new Date(new Date().toDateString()).getTime();
    s.today = this.items.filter((i: ClipItem) => i.createTime >= dayStart).length;
    return s;
  }
}
