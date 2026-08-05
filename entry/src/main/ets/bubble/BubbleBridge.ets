/**
 * BubbleBridge.ets
 * 气泡与你现有业务代码之间的唯一接触面。
 *
 * 气泡本体（bubble/ 目录下其余文件）不 import 你的任何模块，
 * 所有数据进出都走这里的四个钩子。你在自己原来的初始化位置
 * 挂上这些钩子即可，不需要改动气泡内部一行代码。
 *
 * 挂载示例（放在你原来创建悬浮窗的地方）：
 *
 *   import { BubbleBridge } from '../bubble/BubbleBridge';
 *   import { BubbleAdapter } from '../bubble/BubbleBridge';
 *
 *   BubbleBridge.hooks = {
 *     getItems: () => MyClipRepo.get().list().map(BubbleAdapter.from),
 *     onPick: (item) => MyClipRepo.get().copyToPasteboard(item.content),
 *     onHidden: () => MyNotify.showRecall(),
 *     onDockChange: (side, y) => MySettings.saveDock(side, y)
 *   };
 *
 *   // 用户在面板里拨开关彻底关闭了悬浮球：通常持久化关闭状态。
 *   // 窗口销毁由宿主页执行，本钩子只负责业务副作用（如落库）。
 *   BubbleBridge.hooks.onClose = () => MySettings.setFloatBubble(false);
 */

import { AppKeys } from './AppKeys';
import { ClipItem, ClipKind, ClipUtil } from './ClipItem';
import { DockSide } from './DockEngine';

export interface BubbleHooks {
  /** 气泡展开时向你要数据。返回空数组会显示空状态。 */
  getItems: () => ClipItem[];
  /** 用户点了面板里某条记录。通常是写回系统剪贴板。 */
  onPick: (item: ClipItem) => void;
  /** 用户把气泡拖进底部吸入区隐藏了。你需要提供一个召回入口。 */
  onHidden: () => void;
  /** 用户在面板里拨开关彻底关闭了悬浮球。通常持久化关闭状态。 */
  onClose: () => void;
  /** 用户在面板里点了「识屏」：抓取当前页面文本（无障碍服务，原型功能）。 */
  onCapture: () => void;
  /** 气泡停靠位置变了，可用于持久化。 */
  onDockChange: (side: DockSide, y: number) => void;
}

class DefaultHooks implements BubbleHooks {
  getItems(): ClipItem[] {
    return [];
  }

  onPick(item: ClipItem): void {
    console.info(`CopyBubble picked: ${item.content}`);
  }

  onHidden(): void {
    console.info('CopyBubble hidden');
  }

  onClose(): void {
    console.info('CopyBubble closed');
  }

  onCapture(): void {
    console.info('CopyBubble capture requested');
  }

  onDockChange(side: DockSide, y: number): void {
    console.info(`CopyBubble docked ${side} at ${y}`);
  }
}

export class BubbleBridge {
  static hooks: BubbleHooks = new DefaultHooks();

  /**
   * 通知气泡有新内容进来，触发捕获波纹与唤醒。
   * 在你原来写入剪贴记录的地方调一次即可。
   */
  static notifyCaptured(): void {
    const cur: number = AppStorage.get<number>(AppKeys.PULSE) ?? 0;
    AppStorage.setOrCreate(AppKeys.PULSE, cur + 1);
  }

  /** 从你的通知栏或应用内入口召回被隐藏的气泡 */
  static recall(): void {
    AppStorage.setOrCreate(AppKeys.BUBBLE_HIDDEN, false);
  }

  /** 下层应用是深色时传 true，只影响展开面板的配色 */
  static setDarkHost(dark: boolean): void {
    AppStorage.setOrCreate(AppKeys.DARK_HOST, dark);
  }
}

/**
 * 把你自己的记录模型转成气泡认识的 ClipItem。
 * 如果你原来的模型字段名不同，改这里就够了。
 */
export class BubbleAdapter {
  /** 从最少的字段构造，类型自动识别 */
  static of(id: string, content: string, time: number): ClipItem {
    return new ClipItem(id, content, ClipUtil.detect(content), time);
  }

  /** 显式指定类型 */
  static ofKind(id: string, content: string, kind: ClipKind, time: number): ClipItem {
    return new ClipItem(id, content, kind, time);
  }
}
