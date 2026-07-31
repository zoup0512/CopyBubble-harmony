import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { StorageManager } from '../manager/StorageManager';
import { ClipStore } from '../manager/ClipStore';
import { BubbleWindow } from '../manager/BubbleWindow';
import { Const } from '../common/Theme';

const TAG: string = 'CopyBubble/Ability';
const DOMAIN: number = 0x1001;

export default class EntryAbility extends UIAbility {
  private tick: number = 0;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onCreate');
    AppStorage.setOrCreate('foregroundTick', 0);
    AppStorage.setOrCreate('topInset', 0);
    AppStorage.setOrCreate('bottomInset', 0);
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    // 先把本地存储准备好，再渲染首页，避免首帧读到空列表
    try {
      await StorageManager.getInstance().init(this.context);
      await ClipStore.getInstance().load();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `bootstrap failed ${err.code} ${err.message}`);
    }

    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, `loadContent failed ${JSON.stringify(err)}`);
        return;
      }
      this.applyImmersive(windowStage);
    });
  }

  /** 沉浸式布局：把状态栏/导航栏高度交给页面自己留白 */
  private applyImmersive(windowStage: window.WindowStage): void {
    try {
      const win: window.Window = windowStage.getMainWindowSync();
      win.setWindowLayoutFullScreen(true).catch((e: BusinessError) => {
        hilog.warn(DOMAIN, TAG, `fullscreen failed ${e.code}`);
      });
      const top: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const bottom: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate('topInset', px2vp(top.topRect.height));
      AppStorage.setOrCreate('bottomInset', px2vp(bottom.bottomRect.height));
      win.setWindowSystemBarProperties({
        statusBarContentColor: '#141626',
        navigationBarContentColor: '#141626'
      }).catch((e: BusinessError) => {
        hilog.warn(DOMAIN, TAG, `system bar failed ${e.code}`);
      });
      win.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate('topInset', px2vp(data.area.topRect.height));
        } else if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          AppStorage.setOrCreate('bottomInset', px2vp(data.area.bottomRect.height));
        }
      });
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.warn(DOMAIN, TAG, `immersive setup skipped ${err.code}`);
    }
  }

  onForeground(): void {
    // 通知页面尝试一次剪贴板收录
    this.tick += 1;
    AppStorage.setOrCreate('foregroundTick', this.tick);
  }

  onBackground(): void {
    hilog.debug(DOMAIN, TAG, 'onBackground');
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy');
  }

  onDestroy(): void {
    const on: boolean = StorageManager.getInstance().getBool(Const.KEY_FLOAT_BUBBLE, false);
    if (on) {
      BubbleWindow.hide();
    }
  }
}
