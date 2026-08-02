import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { vibrator } from '@kit.SensorServiceKit';
import { StorageManager } from './StorageManager';
import { Const } from '../common/Theme';

const TAG: string = 'CopyBubble/Clipboard';
const DOMAIN: number = 0x1001;
const PERM: Permissions = 'ohos.permission.READ_PASTEBOARD';

export type ClipboardChange = () => void;

/**
 * 系统剪贴板封装。
 *
 * 读取剪贴板需要 ohos.permission.READ_PASTEBOARD（user_grant）。授权后 read()
 * 可在应用前台时直接拿到内容；未授权时由 read() 自身静默兜底，调用方另可走
 * PasteButton 安全控件路径（点击即视为临时授权）。
 */
export class ClipboardKit {
  private static listener: ClipboardChange | null = null;
  private static hooked: boolean = false;

  /** 剪贴板读取权限是否已授予。READ_PASTEBOARD 是 user_grant 权限。 */
  static hasPermission(): boolean {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const tokenId: number = info.appInfo.accessTokenId;
      return abilityAccessCtrl.createAtManager().checkAccessTokenSync(tokenId, PERM) ===
        abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'check clipboard permission failed');
      return false;
    }
  }

  /**
   * 拉起系统授权弹窗请求剪贴板读取权限。已授权直接返回 true。
   * 调用方负责用偏好位控制弹窗频次（避免每次冷启动都打扰用户）。
   * 返回是否已授权（用户拒绝或出错则 false）。
   */
  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    if (ClipboardKit.hasPermission()) {
      return true;
    }
    try {
      const res = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, [PERM]);
      const granted: boolean = res.authResults.length > 0 &&
        res.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      hilog.info(DOMAIN, TAG, `request clipboard permission granted=${granted}`);
      return granted;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `request clipboard permission failed ${err.code} ${err.message}`);
      return false;
    }
  }

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
