import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Const } from '../common/Theme';

const TAG: string = 'CopyBubble/Storage';
const DOMAIN: number = 0x1001;

/** preferences 薄封装：全应用只保留一个实例 */
export class StorageManager {
  private static instance: StorageManager | null = null;
  private store: preferences.Preferences | null = null;
  private ready: boolean = false;

  static getInstance(): StorageManager {
    if (StorageManager.instance === null) {
      StorageManager.instance = new StorageManager();
    }
    return StorageManager.instance;
  }

  async init(context: common.Context): Promise<void> {
    if (this.ready) {
      return;
    }
    try {
      const options: preferences.Options = { name: Const.PREF_NAME };
      this.store = await preferences.getPreferences(context, options);
      this.ready = true;
      hilog.info(DOMAIN, TAG, 'preferences ready');
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `init failed ${err.code} ${err.message}`);
    }
  }

  get isReady(): boolean {
    return this.ready && this.store !== null;
  }

  getString(key: string, def: string): string {
    if (this.store === null) {
      return def;
    }
    return this.store.getSync(key, def) as string;
  }

  getBool(key: string, def: boolean): boolean {
    if (this.store === null) {
      return def;
    }
    return this.store.getSync(key, def) as boolean;
  }

  getNumber(key: string, def: number): number {
    if (this.store === null) {
      return def;
    }
    return this.store.getSync(key, def) as number;
  }

  async put(key: string, value: string | boolean | number): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      await this.store.put(key, value);
      await this.store.flush();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `put ${key} failed ${err.code} ${err.message}`);
    }
  }

  async clearAll(): Promise<void> {
    if (this.store === null) {
      return;
    }
    await this.store.clear();
    await this.store.flush();
  }
}
