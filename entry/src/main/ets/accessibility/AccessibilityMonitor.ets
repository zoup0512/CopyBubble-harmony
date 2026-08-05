/**
 * AccessibilityMonitor.ets
 * 无障碍服务的同进程单例。UIAbility 与 ExtensionAbility 默认同进程，静态状态可直接共享。
 *
 * - bind/unbind：记录服务就绪状态，写 AppStorage（a11y_ready）供设置页展示
 * - onEvent：事件驱动的被动抓取（防抖 1s + 节流 3s），结果只进 hilog 与 a11y_last，
 *   不写剪贴板不落库——被动验证用，避免污染剪贴板历史
 * - dumpNow：主动抓取（气泡「识屏」按钮触发），由调用方决定是否写剪贴板/落库
 *
 * 读取链路（全部 @deprecated since 12，原型目的即实测其可用性）：
 *   context.getWindows() → 按 bundleName/isVisible 过滤自身窗口
 *   → 递归 attributeValue('children') → 收集 attributeValue('text'/'contents'/'description')
 */

import { AccessibilityExtensionAbility, AccessibilityElement, AccessibilityEvent } from '@kit.AccessibilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG: string = 'CopyBubble/A11y';
const DOMAIN: number = 0x1001;

/** 本应用包名：抓取时跳过自己的悬浮窗/主窗口，只留第三方页面 */
const SELF_BUNDLE: string = 'com.razor.tools.copybubble';

/** 遍历上限，防止极端页面下递归过深/节点爆炸 */
const MAX_DEPTH: number = 20;
const MAX_NODES: number = 500;
/** 文本行数上限，防止整屏内容撑爆剪贴板 */
const MAX_LINES: number = 300;

export interface DumpResult {
  /** 目标窗口所属包名 */
  bundle: string;
  /** 去重后的文本行 */
  texts: string[];
  /** 耗时 ms */
  cost: number;
  /** 失败时的错误码+信息，成功为空串 */
  error: string;
}

/** 遍历节点预算，跨窗口共享一个全局上限 */
class NodeBudget {
  n: number = 0;
}

export class AccessibilityMonitor {
  /** 设置页展示用的 AppStorage key */
  static readonly KEY_READY: string = 'a11y_ready';
  static readonly KEY_LAST: string = 'a11y_last';

  private static ext: AccessibilityExtensionAbility | null = null;
  private static debounceTimer: number = -1;
  private static lastAutoDump: number = 0;
  private static dumping: boolean = false;

  static bind(ext: AccessibilityExtensionAbility): void {
    AccessibilityMonitor.ext = ext;
    AppStorage.setOrCreate(AccessibilityMonitor.KEY_READY, true);
    hilog.info(DOMAIN, TAG, 'monitor bound, service ready');
  }

  static unbind(): void {
    AccessibilityMonitor.ext = null;
    AppStorage.setOrCreate(AccessibilityMonitor.KEY_READY, false);
    hilog.info(DOMAIN, TAG, 'monitor unbound');
  }

  static isReady(): boolean {
    return AccessibilityMonitor.ext !== null;
  }

  /** 无障碍事件回调：记录事件 + 页面变化时被动抓取一次（防抖 1s、节流 3s） */
  static onEvent(event: AccessibilityEvent): void {
    const type: string = `${event.eventType}`;
    hilog.debug(DOMAIN, TAG, `event ${type}`);
    const interesting: boolean =
      type === 'pageContentUpdate' || type === 'pageStateUpdate' || type === 'active';
    if (!interesting) {
      return;
    }
    if (AccessibilityMonitor.debounceTimer !== -1) {
      clearTimeout(AccessibilityMonitor.debounceTimer);
    }
    AccessibilityMonitor.debounceTimer = setTimeout(() => {
      AccessibilityMonitor.debounceTimer = -1;
      const now: number = Date.now();
      if (now - AccessibilityMonitor.lastAutoDump < 3000) {
        return;
      }
      AccessibilityMonitor.lastAutoDump = now;
      AccessibilityMonitor.dumpNow().catch((e: BusinessError) => {
        hilog.error(DOMAIN, TAG, `auto dump failed ${e.code} ${e.message}`);
      });
    }, 1000);
  }

  /** 主动抓取当前前台第三方页面的文本。服务未就绪或抓取中返回 null。 */
  static async dumpNow(): Promise<DumpResult | null> {
    if (AccessibilityMonitor.dumping) {
      hilog.warn(DOMAIN, TAG, 'dumpNow skipped: another dump in progress');
      return null;
    }
    const ext: AccessibilityExtensionAbility | null = AccessibilityMonitor.ext;
    if (!ext) {
      hilog.warn(DOMAIN, TAG, 'dumpNow skipped: service not ready');
      return null;
    }
    AccessibilityMonitor.dumping = true;
    const t0: number = Date.now();
    const result: DumpResult = { bundle: '', texts: [], cost: 0, error: '' };
    try {
      const windows: AccessibilityElement[] = await ext.context.getWindows();
      hilog.info(DOMAIN, TAG, `getWindows ok: ${windows.length} windows`);
      const texts: string[] = [];
      const budget: NodeBudget = new NodeBudget();
      for (const win of windows) {
        let bundle: string = '';
        let visible: boolean = true;
        try {
          bundle = await win.attributeValue('bundleName');
          visible = await win.attributeValue('isVisible');
        } catch (e) {
          const err: BusinessError = e as BusinessError;
          hilog.debug(DOMAIN, TAG, `window attr failed ${err.code}, skip`);
          continue;
        }
        if (bundle === SELF_BUNDLE || !visible) {
          hilog.debug(DOMAIN, TAG, `skip window bundle=${bundle} visible=${visible}`);
          continue;
        }
        if (result.bundle === '') {
          result.bundle = bundle;
        }
        await AccessibilityMonitor.collectText(win, texts, 0, budget);
      }
      result.texts = AccessibilityMonitor.dedupe(texts);
      result.cost = Date.now() - t0;
      const joined: string = result.texts.join('\n');
      hilog.info(DOMAIN, TAG,
        `dump done bundle=${result.bundle} lines=${result.texts.length} chars=${joined.length} cost=${result.cost}ms`);
      AccessibilityMonitor.publish(result);
      return result;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      result.error = `${err.code} ${err.message}`;
      result.cost = Date.now() - t0;
      hilog.error(DOMAIN, TAG, `dump failed ${result.error}`);
      AccessibilityMonitor.publish(result);
      return result;
    } finally {
      AccessibilityMonitor.dumping = false;
    }
  }

  /** 递归收集节点文本。单个节点失败只跳过该节点，不中断整棵遍历。 */
  private static async collectText(el: AccessibilityElement, out: string[],
    depth: number, budget: NodeBudget): Promise<void> {
    if (depth > MAX_DEPTH || budget.n >= MAX_NODES) {
      return;
    }
    budget.n++;
    try {
      const text: string = await el.attributeValue('text');
      if (text !== '' && text.trim().length > 0) {
        out.push(text.trim());
      }
      const contents: Array<string> = await el.attributeValue('contents');
      if (contents) {
        for (const c of contents) {
          if (c.trim().length > 0) {
            out.push(c.trim());
          }
        }
      }
      const children: Array<AccessibilityElement> = await el.attributeValue('children');
      if (children) {
        for (const child of children) {
          await AccessibilityMonitor.collectText(child, out, depth + 1, budget);
        }
      }
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.debug(DOMAIN, TAG, `node visit failed ${err.code} ${err.message}`);
    }
  }

  /** 按出现顺序去重并截断行数 */
  private static dedupe(texts: string[]): string[] {
    const seen: Set<string> = new Set<string>();
    const unique: string[] = [];
    for (const t of texts) {
      if (t.length === 0 || seen.has(t)) {
        continue;
      }
      seen.add(t);
      unique.push(t);
      if (unique.length >= MAX_LINES) {
        break;
      }
    }
    return unique;
  }

  /** 把最近一次结果写到 AppStorage，供设置页展示（调试用） */
  private static publish(result: DumpResult): void {
    const joined: string = result.texts.join('\n');
    let preview: string = joined.length > 120 ? `${joined.substring(0, 120)}…` : joined;
    if (result.error !== '') {
      preview = `错误: ${result.error}`;
    } else if (result.texts.length === 0) {
      preview = '未抓到文本';
    } else {
      preview = `[${result.bundle}] ${result.texts.length} 行 / ${joined.length} 字\n${preview}`;
    }
    AppStorage.setOrCreate(AccessibilityMonitor.KEY_LAST, preview);
  }
}
