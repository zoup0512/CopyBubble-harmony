import { window, display } from '@kit.ArkUI';
import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'CopyBubble/Float';
const DOMAIN: number = 0x1001;
const WIN_NAME: string = 'copy_bubble_float';
const PERM_FLOAT: Permissions = 'ohos.permission.SYSTEM_FLOAT_WINDOW';
const MARGIN_VP: number = 8;        // 离屏边的留白
const DEFAULT_TOP_VP: number = 120;  // 默认顶部位置，避开状态栏区域

/**
 * 桌面悬浮气泡。
 * 需要 ohos.permission.SYSTEM_FLOAT_WINDOW（ACL 权限，需申请签名授权）。
 * 未授权时 create 会失败，调用方据此把设置项回滚成关闭状态。
 *
 * 窗口尺寸由页面驱动（收起 64vp、展开 300×400vp），本类负责把窗口
 * 约束在屏幕内：创建时落在右上角默认位置，展开时以气泡右上角为锚
 * 向左下生长并整体收进屏内，避免面板溢出右屏。
 */
export class BubbleWindow {
  private static win: window.Window | null = null;
  private static x: number = 0;  // 窗口左上角 x（px）
  private static y: number = 0;  // 窗口左上角 y（px）
  private static w: number = 0;  // 窗口宽（px）
  private static h: number = 0;  // 窗口高（px）
  private static savedX: number = 0;  // 收起态位置，展开后用于还原
  private static savedY: number = 0;

  static get isShowing(): boolean {
    return BubbleWindow.win !== null;
  }

  /** 窗口左上角 x（px）。拖动计算增量时读这个，避免每帧从 0 起步导致跳屏。 */
  static get posX(): number {
    return BubbleWindow.x;
  }

  /** 窗口左上角 y（px）。 */
  static get posY(): number {
    return BubbleWindow.y;
  }

  /** 窗口宽（px）。拖动增量要按窗口尺寸算，展开/收起态下都正确。 */
  static get width(): number {
    return BubbleWindow.w;
  }

  /** 窗口高（px）。 */
  static get height(): number {
    return BubbleWindow.h;
  }

  /** 悬浮窗权限是否已授予。SYSTEM_FLOAT_WINDOW 是受限的 user_grant 权限。 */
  static hasPermission(): boolean {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const tokenId: number = info.appInfo.accessTokenId;
      return abilityAccessCtrl.createAtManager().checkAccessTokenSync(tokenId, PERM_FLOAT) ===
        abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'check permission failed');
      return false;
    }
  }

  /**
   * 拉起系统授权弹窗请求悬浮窗权限。未授权时 createWindow 会被系统拦下，
   * 表现为开关亮了但气泡不出，所以必须在创建窗口前先拿到权限。
   * 返回是否已授权（用户拒绝则 false）。
   */
  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    if (BubbleWindow.hasPermission()) {
      return true;
    }
    try {
      const res = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, [PERM_FLOAT]);
      const granted: boolean = res.authResults.length > 0 &&
        res.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      hilog.info(DOMAIN, TAG, `request permission granted=${granted}`);
      return granted;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `request permission failed ${err.code} ${err.message}`);
      return false;
    }
  }

  private static screenWidth(): number {
    try {
      return display.getDefaultDisplaySync().width;
    } catch {
      return 0;
    }
  }

  private static screenHeight(): number {
    try {
      return display.getDefaultDisplaySync().height;
    } catch {
      return 0;
    }
  }

  /** 把左上角 x 约束在屏内（窗口宽 w）。屏幕尺寸取不到时原样返回。 */
  private static clampX(x: number, w: number): number {
    const sw: number = BubbleWindow.screenWidth();
    if (sw === 0) {
      return x;
    }
    const m: number = vp2px(MARGIN_VP);
    const maxX: number = Math.max(m, sw - w - m);
    return Math.min(Math.max(x, m), maxX);
  }

  /** 把左上角 y 约束在屏内（窗口高 h）。屏幕尺寸取不到时原样返回。 */
  private static clampY(y: number, h: number): number {
    const sh: number = BubbleWindow.screenHeight();
    if (sh === 0) {
      return y;
    }
    const m: number = vp2px(MARGIN_VP);
    const maxY: number = Math.max(m, sh - h - m);
    return Math.min(Math.max(y, m), maxY);
  }

  static async show(context: common.UIAbilityContext): Promise<boolean> {
    if (BubbleWindow.win !== null) {
      return true;
    }
    // SYSTEM_FLOAT_WINDOW 是受限的 user_grant 权限，未授权时 createWindow/showWindow
    // 不报错却被系统拦下，导致"开关亮了但气泡不出"。先拉起授权弹窗。
    const granted: boolean = await BubbleWindow.requestPermission(context);
    if (!granted) {
      hilog.warn(DOMAIN, TAG, 'float permission denied, abort show');
      return false;
    }
    try {
      const config: window.Configuration = {
        name: WIN_NAME,
        windowType: window.WindowType.TYPE_FLOAT,
        ctx: context
      };
      const win: window.Window = await window.createWindow(config);
      // 默认贴右、略靠上，保证收起态的气泡就在屏内
      const side: number = vp2px(64); // 与 BubbleFloat 的 COLLAPSED 对齐
      const sw: number = BubbleWindow.screenWidth();
      const startX: number = sw > 0 ? sw - side - vp2px(MARGIN_VP) : vp2px(300);
      const startY: number = vp2px(DEFAULT_TOP_VP);
      const px: number = BubbleWindow.clampX(startX, side);
      const py: number = BubbleWindow.clampY(startY, side);
      BubbleWindow.w = side;
      BubbleWindow.h = side;
      BubbleWindow.x = px;
      BubbleWindow.y = py;
      BubbleWindow.savedX = px;
      BubbleWindow.savedY = py;
      await win.resize(side, side);
      await win.moveWindowTo(px, py);
      await win.setUIContent('pages/BubbleFloat');
      await win.setWindowBackgroundColor('#00000000');
      win.setWindowTouchable(true);
      await win.showWindow();
      BubbleWindow.win = win;
      hilog.info(DOMAIN, TAG, 'float bubble shown');
      return true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `create float window failed ${err.code} ${err.message}`);
      BubbleWindow.win = null;
      return false;
    }
  }

  static async hide(): Promise<void> {
    if (BubbleWindow.win === null) {
      return;
    }
    try {
      await BubbleWindow.win.destroyWindow();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `destroy failed ${err.code} ${err.message}`);
    }
    BubbleWindow.win = null;
  }

  /**
   * 展开成面板：记下收起态位置，再以当前气泡的右上角为锚向左下生长，
   * 最后整体收进屏内，避免面板溢出右屏。先移动后缩放，保证生长过程不出屏。
   */
  static async expandTo(w: number, h: number): Promise<void> {
    if (BubbleWindow.win === null) {
      return;
    }
    BubbleWindow.savedX = BubbleWindow.x;
    BubbleWindow.savedY = BubbleWindow.y;
    // 以气泡右上角为锚，面板向左生长；y 沿用气泡顶部
    const anchorX: number = BubbleWindow.x + BubbleWindow.w - w;
    const anchorY: number = BubbleWindow.y;
    const px: number = BubbleWindow.clampX(anchorX, w);
    const py: number = BubbleWindow.clampY(anchorY, h);
    try {
      await BubbleWindow.win.moveWindowTo(px, py);
      await BubbleWindow.win.resize(w, h);
      BubbleWindow.x = px;
      BubbleWindow.y = py;
      BubbleWindow.w = w;
      BubbleWindow.h = h;
    } catch {
      hilog.debug(DOMAIN, TAG, 'expand failed');
    }
  }

  /** 收起回气泡：先回到记下的位置，再缩小尺寸。 */
  static async collapseTo(w: number, h: number): Promise<void> {
    if (BubbleWindow.win === null) {
      return;
    }
    const px: number = BubbleWindow.clampX(BubbleWindow.savedX, w);
    const py: number = BubbleWindow.clampY(BubbleWindow.savedY, h);
    try {
      await BubbleWindow.win.moveWindowTo(px, py);
      await BubbleWindow.win.resize(w, h);
      BubbleWindow.x = px;
      BubbleWindow.y = py;
      BubbleWindow.w = w;
      BubbleWindow.h = h;
    } catch {
      hilog.debug(DOMAIN, TAG, 'collapse failed');
    }
  }

  /** 拖动气泡时调用，自动约束在屏内并同步收起态记忆位置。 */
  static async moveTo(x: number, y: number): Promise<void> {
    if (BubbleWindow.win === null) {
      return;
    }
    const px: number = BubbleWindow.clampX(x, BubbleWindow.w);
    const py: number = BubbleWindow.clampY(y, BubbleWindow.h);
    try {
      await BubbleWindow.win.moveWindowTo(px, py);
      BubbleWindow.x = px;
      BubbleWindow.y = py;
      BubbleWindow.savedX = px;
      BubbleWindow.savedY = py;
    } catch {
      hilog.debug(DOMAIN, TAG, 'move failed');
    }
  }
}
