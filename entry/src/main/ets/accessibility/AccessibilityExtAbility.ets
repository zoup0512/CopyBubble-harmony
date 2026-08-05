/**
 * AccessibilityExtAbility.ets
 * 无障碍服务扩展（可行性验证原型）。
 *
 * 用户在系统「设置 → 辅助功能 → 随手贴识屏」里手动开启后，系统拉起本扩展。
 * 验证点全部打 hilog（tag: CopyBubble/A11y）：
 *   1. onConnect 是否触发（服务是否存活、进程是否常驻）
 *   2. onAccessibilityEvent 是否收到事件（windowUpdate / pageContentUpdate / click …）
 *   3. 核心：getWindows / attributeValue 等 API 在 6.1.1(24) 运行时是否仍对三方应用开放
 *
 * 注意：SDK 中这些读取接口全部 @deprecated since 12，且三方应用没有新替代
 * （新接口为系统应用专用）。本文件即实测这条路径是否仍被放行的最小实现，
 * 若调用抛 9300003/9300004，说明该能力已对三方应用关闭，原型即结论。
 */

import { AccessibilityExtensionAbility, AccessibilityEvent } from '@kit.AccessibilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AccessibilityMonitor } from './AccessibilityMonitor';

const TAG: string = 'CopyBubble/A11y';
const DOMAIN: number = 0x1001;

export default class AccessibilityExtAbility extends AccessibilityExtensionAbility {
  onConnect(): void {
    hilog.info(DOMAIN, TAG, 'onConnect 服务已连接');
    AccessibilityMonitor.bind(this);
    // 连上立即抓一次当前页面，第一时间验证读取链路
    AccessibilityMonitor.dumpNow().catch((e: Error) => {
      hilog.error(DOMAIN, TAG, `onConnect dump failed ${JSON.stringify(e)}`);
    });
  }

  onDisconnect(): void {
    hilog.info(DOMAIN, TAG, 'onDisconnect 服务已断开');
    AccessibilityMonitor.unbind();
  }

  onAccessibilityEvent(event: AccessibilityEvent): void {
    AccessibilityMonitor.onEvent(event);
  }
}
