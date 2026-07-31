import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { vibrator } from '@kit.SensorServiceKit';
import { StorageManager } from './StorageManager';
import { Const } from '../common/Theme';

const TAG: string = 'CopyBubble/Clipboard';
const DOMAIN: number = 0x1001;

export type ClipboardChange = () => void;

/**
 * 系统剪贴板封装。
 *
 * 说明：HarmonyOS NEXT 对静默读取剪贴板有管控，读取动作需要由用户操作触发
 * （推荐使用 PasteButton 安全控件）。这里的 read() 只在应用处于前台、
 * 且用户已开启“自动收录”时调用，失败会被安静地忽略。
 */
export class ClipboardKit {
  private static listener: ClipboardChange | null = null;
  private static hooked: boolean = false;

  /** 写入剪贴板 */
  static async write(text: string): Promise<boolean> {
    try {
      const data: pasteboard.PasteData =
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
      ClipboardKit.tick();
      return true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `write failed ${err.code} ${err.message}`);
      return false;
    }
  }

  /** 读取剪贴板纯文本，无内容或被系统拒绝时返回空串 */
  static async read(): Promise<string> {
    try {
      const board: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      const has: boolean = await board.hasData();
      if (!has) {
        return '';
      }
      const data: pasteboard.PasteData = await board.getData();
      const text: string = data.getPrimaryText();
      return text !== undefined && text !== null ? text : '';
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.warn(DOMAIN, TAG, `read blocked or empty ${err.code}`);
      return '';
    }
  }

  /** 订阅剪贴板变化（仅前台有效） */
  static observe(fn: ClipboardChange): void {
    ClipboardKit.listener = fn;
    if (ClipboardKit.hooked) {
      return;
    }
    try {
      pasteboard.getSystemPasteboard().on('update', () => {
        if (ClipboardKit.listener !== null) {
          ClipboardKit.listener();
        }
      });
      ClipboardKit.hooked = true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `observe failed ${err.code} ${err.message}`);
    }
  }

  static unobserve(): void {
    if (!ClipboardKit.hooked) {
      return;
    }
    try {
      pasteboard.getSystemPasteboard().off('update');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'unobserve failed');
    }
    ClipboardKit.hooked = false;
    ClipboardKit.listener = null;
  }

  /** 复制成功的轻震动反馈 */
  private static tick(): void {
    const on: boolean = StorageManager.getInstance().getBool(Const.KEY_HAPTIC, true);
    if (!on) {
      return;
    }
    try {
      vibrator.startVibration(
        { type: 'preset', effectId: 'haptic.clock.timer', count: 1 },
        { usage: 'touch' }
      ).catch(() => {
        hilog.debug(DOMAIN, TAG, 'vibrate rejected');
      });
    } catch (e) {
      hilog.debug(DOMAIN, TAG, 'vibrate unavailable');
    }
  }
}
