/**
 * I18n.ets
 * 全局多语言支持。启动时检测系统语言，渲染时用 t()/f() 取对应文案。
 * 中英文双表，找不到 key 时原样返回 key（兼容旧数据里直接存的中文 source）。
 */
import { i18n } from '@kit.LocalizationKit';

export type Locale = 'zh' | 'en';

export class I18n {
  private static locale: Locale = 'en';

  private static readonly ZH: Map<string, string> = new Map<string, string>([
    // ---------- 通用按钮 ----------
    ['btn_cancel', '取消'],
    ['btn_save', '保存'],
    ['btn_delete', '删除'],
    ['btn_clear', '清空'],
    ['btn_done', '完成'],
    ['btn_edit', '编辑'],

    // ---------- 首页 ----------
    ['app_title', '随手贴'],
    ['app_name', '随手贴'],
    ['stats_summary', '共 {0} 条 · 今天新增 {1} · 置顶 {2}'],
    ['empty_no_match_title', '没有匹配的内容'],
    ['empty_no_match_hint', '换个关键词试试，或者清空搜索框'],
    ['empty_quiet_title', '剪贴板还很安静'],
    ['empty_quiet_hint', '点下面的「粘贴」把当前剪贴板存进来，也可以手动新建一条'],
    ['list_end', '到底了 · {0} 条'],
    ['search_placeholder', '搜索剪贴内容'],
    ['compose_title', '新建一条'],
    ['compose_placeholder', '粘贴或输入要保存的内容'],

    // ---------- 首页 Toast ----------
    ['toast_captured_1', '已收录 1 条'],
    ['toast_copied', '已复制到剪贴板'],
    ['toast_copy_failed', '复制失败，请重试'],
    ['toast_pinned', '已置顶'],
    ['toast_unpinned', '已取消置顶'],
    ['toast_clipboard_empty', '剪贴板是空的'],
    ['toast_captured', '已收录'],
    ['toast_already_exists', '这条已经在列表里了'],
    ['toast_saved', '已保存'],
    ['toast_deleted', '已删除'],
    ['toast_paste_failed', '没能读取剪贴板'],
    ['toast_copied_short', '已复制'],

    // ---------- 来源 ----------
    ['source_clipboard', '剪贴板'],
    ['source_paste', '粘贴按钮'],
    ['source_manual', '手动输入'],
    ['source_help', '内置'],
    ['source_screen', '屏幕抓取'],

    // ---------- 识屏（无障碍原型） ----------
    ['panel_capture', '识屏'],
    ['toast_capture_ok', '已抓取 {0} 页面的文字'],
    ['toast_capture_empty', '没有抓到文字'],
    ['toast_capture_failed', '抓取失败：{0}'],
    ['toast_capture_nosvc', '请先在系统设置「辅助功能」里开启随手贴识屏'],
    ['section_a11y', '识屏原型（验证用）'],
    ['a11y_status_title', '服务状态'],
    ['a11y_status_on', '已开启'],
    ['a11y_status_off', '未开启'],
    ['a11y_howto', '开启：系统设置 → 辅助功能 → 随手贴识屏。开启后打开任意应用，点悬浮球里的「识屏」抓取页面文字。'],

    // ---------- 卡片 ----------
    ['pinned_tag', '置顶'],
    ['pin_action', '置顶'],
    ['unpin_action', '取消置顶'],
    ['copy_action', '复制'],
    ['char_count', '{0} 字'],
    ['used_count', '· 用过 {0} 次'],

    // ---------- 空状态默认 ----------
    ['empty_default_title', '还没有记录'],
    ['empty_default_hint', '复制点什么，然后回到这里'],

    // ---------- 设置页 ----------
    ['settings_title', '设置'],
    ['section_capture', '收录'],
    ['section_bubble', '气泡'],
    ['section_capacity', '容量'],
    ['section_data', '数据'],
    ['section_about', '关于'],
    ['dedupe_title', '跳过重复内容'],
    ['dedupe_desc', '相同文本只保留一条，时间刷新到最新。'],
    ['float_bubble_title', '桌面悬浮气泡'],
    ['float_bubble_desc', '在其他应用之上显示一枚可拖动的气泡，随手取用最近几条。需要悬浮窗权限。'],
    ['haptic_title', '复制震动反馈'],
    ['haptic_desc', '复制成功时给一次轻震动。'],
    ['max_records_title', '保留条数上限'],
    ['max_records_desc', '超出后从最旧的非置顶记录开始清理，置顶内容永远保留。'],
    ['unlimited', '无上限'],
    ['clear_unpinned', '清空非置顶记录'],
    ['clear_all', '清空全部记录'],
    ['about_app', '应用'],
    ['about_storage', '数据存放'],
    ['about_storage_value', '仅在本机，不联网上传'],
    ['float_permission_denied', '打不开悬浮窗，需要先授予悬浮窗权限'],
    ['clear_all_msg', '包括置顶在内的所有内容都会消失，无法恢复。'],
    ['clear_unpinned_msg', '置顶的内容会留下，其余全部删除。'],
    ['toast_cleared', '已清空'],
    ['toast_deleted_n', '已删除 {0} 条'],

    // ---------- 详情页 ----------
    ['detail_title', '详情'],
    ['detail_gone', '这条记录已经不在了'],
    ['pinned_badge', '★ 已置顶'],
    ['pin_badge', '☆ 置顶'],
    ['collected_at', '收录于 {0}'],
    ['action_copy_all', '复制全文'],
    ['action_copy_all_sub', '把这条内容写回系统剪贴板'],
    ['action_open_browser', '用浏览器打开'],
    ['action_dial', '拨号'],
    ['action_email', '写邮件'],
    ['action_copy_code', '只复制数字'],
    ['action_share', '分享'],
    ['action_share_sub', '发送到其他应用'],
    ['delete_record', '删除这条记录'],
    ['toast_no_copy_content', '没有可复制的内容'],
    ['toast_no_uri', '没有找到可打开的地址'],
    ['toast_no_app_open', '没有应用可以打开它'],
    ['toast_share_failed', '分享面板打不开'],
    ['delete_confirm_msg', '删掉之后没法恢复。'],

    // ---------- 内容类型 ----------
    ['type_text', '文本'],
    ['type_link', '链接'],
    ['type_phone', '电话'],
    ['type_email', '邮箱'],
    ['type_code', '验证码'],
    ['type_number', '数字'],
    ['type_address', '地址'],

    // ---------- 分类 ----------
    ['cat_all', '全部'],
    ['cat_pinned', '置顶'],

    // ---------- 相对时间（主列表） ----------
    ['just_now', '刚刚'],
    ['minutes_ago', '{0} 分钟前'],
    ['today_time', '今天 {0}'],
    ['yesterday_time', '昨天 {0}'],

    // ---------- 相对时间（气泡面板） ----------
    ['ago_seconds', '{0} 秒前'],
    ['ago_hours', '{0} 小时前'],
    ['ago_yesterday', '昨天'],
    ['ago_days', '{0} 天前'],

    // ---------- 气泡面板 ----------
    ['panel_empty_title', '还没有复制过东西'],
    ['panel_empty_hint', '复制任意文本，它会出现在这里'],
    ['panel_header', '剪贴板'],
    ['panel_close_bubble', '关闭悬浮气泡'],
    ['tag_link', '链'],
    ['tag_code', '码'],
    ['tag_text', '文'],

    // ---------- 评分反馈弹窗 ----------
    ['dialog_feedback_title', '体验反馈'],
    ['dialog_feedback_message', '感谢你的支持，如果用着还不错，不妨去应用市场给个好评鼓励一下'],
    ['dialog_feedback_later', '以后再说'],
    ['dialog_feedback_rate', '去评价'],

    // ---------- 内置使用说明 ----------
    ['help_guide', `随手贴 · 使用说明

1. 复制任意文本，回到这里会自动收录
2. 点击卡片即可复制回剪贴板
3. 长按可置顶常用内容，置顶内容不会被清空
4. 顶部可按类型筛选（链接 / 验证码 / 电话 / 邮箱 / 文本）
5. 在「设置」开启桌面悬浮气泡，可在其他应用上方随手取用最近几条
6. 所有数据仅保存在本机，不会上传`]
  ]);

  private static readonly EN: Map<string, string> = new Map<string, string>([
    // ---------- Common buttons ----------
    ['btn_cancel', 'Cancel'],
    ['btn_save', 'Save'],
    ['btn_delete', 'Delete'],
    ['btn_clear', 'Clear'],
    ['btn_done', 'Done'],
    ['btn_edit', 'Edit'],

    // ---------- Home ----------
    ['app_title', 'Copy Bubble'],
    ['app_name', 'Copy Bubble'],
    ['stats_summary', '{0} total · {1} today · {2} pinned'],
    ['empty_no_match_title', 'No matches'],
    ['empty_no_match_hint', 'Try another keyword or clear the search box'],
    ['empty_quiet_title', 'Nothing here yet'],
    ['empty_quiet_hint', 'Tap Paste below to save the current clipboard, or create one manually'],
    ['list_end', 'End · {0} items'],
    ['search_placeholder', 'Search clips'],
    ['compose_title', 'New clip'],
    ['compose_placeholder', 'Paste or type something to save'],

    // ---------- Home toasts ----------
    ['toast_captured_1', 'Captured 1 item'],
    ['toast_copied', 'Copied to clipboard'],
    ['toast_copy_failed', 'Copy failed, please retry'],
    ['toast_pinned', 'Pinned'],
    ['toast_unpinned', 'Unpinned'],
    ['toast_clipboard_empty', 'Clipboard is empty'],
    ['toast_captured', 'Captured'],
    ['toast_already_exists', 'Already in the list'],
    ['toast_saved', 'Saved'],
    ['toast_deleted', 'Deleted'],
    ['toast_paste_failed', "Couldn't read the clipboard"],
    ['toast_copied_short', 'Copied'],

    // ---------- Sources ----------
    ['source_clipboard', 'Clipboard'],
    ['source_paste', 'Paste button'],
    ['source_manual', 'Manual input'],
    ['source_help', 'Built-in'],
    ['source_screen', 'Screen capture'],

    // ---------- Screen capture (accessibility prototype) ----------
    ['panel_capture', 'Capture'],
    ['toast_capture_ok', 'Captured text from {0}'],
    ['toast_capture_empty', 'No text found'],
    ['toast_capture_failed', 'Capture failed: {0}'],
    ['toast_capture_nosvc', 'Enable "Copy Bubble Capture" in Settings > Accessibility first'],
    ['section_a11y', 'Capture Prototype (testing)'],
    ['a11y_status_title', 'Service status'],
    ['a11y_status_on', 'Enabled'],
    ['a11y_status_off', 'Disabled'],
    ['a11y_howto', 'To enable: Settings > Accessibility > Copy Bubble Capture. Then open any app and tap Capture in the bubble panel.'],

    // ---------- Card ----------
    ['pinned_tag', 'Pinned'],
    ['pin_action', 'Pin'],
    ['unpin_action', 'Unpin'],
    ['copy_action', 'Copy'],
    ['char_count', '{0} chars'],
    ['used_count', '· Used {0} times'],

    // ---------- Empty state defaults ----------
    ['empty_default_title', 'No records yet'],
    ['empty_default_hint', 'Copy something, then come back here'],

    // ---------- Settings ----------
    ['settings_title', 'Settings'],
    ['section_capture', 'Capture'],
    ['section_bubble', 'Bubble'],
    ['section_capacity', 'Capacity'],
    ['section_data', 'Data'],
    ['section_about', 'About'],
    ['dedupe_title', 'Skip duplicates'],
    ['dedupe_desc', 'Keep only one copy of identical text and refresh its time to the latest.'],
    ['float_bubble_title', 'Floating bubble'],
    ['float_bubble_desc', 'Show a draggable bubble over other apps for quick access to recent clips. Requires floating window permission.'],
    ['haptic_title', 'Haptic feedback'],
    ['haptic_desc', 'A light vibration when copying succeeds.'],
    ['max_records_title', 'Max records'],
    ['max_records_desc', 'When exceeded, the oldest non-pinned records are removed first. Pinned records are always kept.'],
    ['unlimited', 'Unlimited'],
    ['clear_unpinned', 'Clear non-pinned'],
    ['clear_all', 'Clear all'],
    ['about_app', 'App'],
    ['about_storage', 'Storage'],
    ['about_storage_value', 'On-device only, never uploaded'],
    ['float_permission_denied', "Can't open the floating window. Please grant the floating window permission first."],
    ['clear_all_msg', 'All records including pinned ones will be deleted. This cannot be undone.'],
    ['clear_unpinned_msg', 'Pinned records will be kept; all others will be deleted.'],
    ['toast_cleared', 'Cleared'],
    ['toast_deleted_n', 'Deleted {0} records'],

    // ---------- Detail ----------
    ['detail_title', 'Details'],
    ['detail_gone', 'This record is gone'],
    ['pinned_badge', '★ Pinned'],
    ['pin_badge', '☆ Pin'],
    ['collected_at', 'Saved {0}'],
    ['action_copy_all', 'Copy all'],
    ['action_copy_all_sub', 'Write this content back to the system clipboard'],
    ['action_open_browser', 'Open in browser'],
    ['action_dial', 'Dial'],
    ['action_email', 'Write email'],
    ['action_copy_code', 'Copy numbers only'],
    ['action_share', 'Share'],
    ['action_share_sub', 'Send to other apps'],
    ['delete_record', 'Delete this record'],
    ['toast_no_copy_content', 'Nothing to copy'],
    ['toast_no_uri', 'No openable address found'],
    ['toast_no_app_open', 'No app can open it'],
    ['toast_share_failed', "Can't open the share panel"],
    ['delete_confirm_msg', "This can't be undone."],

    // ---------- Content types ----------
    ['type_text', 'Text'],
    ['type_link', 'Link'],
    ['type_phone', 'Phone'],
    ['type_email', 'Email'],
    ['type_code', 'Code'],
    ['type_number', 'Number'],
    ['type_address', 'Address'],

    // ---------- Categories ----------
    ['cat_all', 'All'],
    ['cat_pinned', 'Pinned'],

    // ---------- Relative time (main list) ----------
    ['just_now', 'Just now'],
    ['minutes_ago', '{0} min ago'],
    ['today_time', 'Today {0}'],
    ['yesterday_time', 'Yesterday {0}'],

    // ---------- Relative time (bubble panel) ----------
    ['ago_seconds', '{0}s ago'],
    ['ago_hours', '{0}h ago'],
    ['ago_yesterday', 'Yesterday'],
    ['ago_days', '{0}d ago'],

    // ---------- Bubble panel ----------
    ['panel_empty_title', 'Nothing copied yet'],
    ['panel_empty_hint', 'Copy any text and it will show up here'],
    ['panel_header', 'Clipboard'],
    ['panel_close_bubble', 'Close floating bubble'],
    ['tag_link', 'L'],
    ['tag_code', '#'],
    ['tag_text', 'T'],

    // ---------- Feedback / rating dialog ----------
    ['dialog_feedback_title', 'Enjoying Copy Bubble?'],
    ['dialog_feedback_message', 'Thanks for your support! If you like the app, please consider leaving us a rating in the AppGallery.'],
    ['dialog_feedback_later', 'Later'],
    ['dialog_feedback_rate', 'Rate Now'],

    // ---------- Built-in usage guide ----------
    ['help_guide', `Copy Bubble · Quick Guide

1. Copy any text and return here — it's captured automatically
2. Tap a card to copy it back to the clipboard
3. Long-press to pin favorites; pinned items are never cleared
4. Filter by type at the top (Link / Code / Phone / Email / Text)
5. Enable the floating bubble in Settings to access recent clips over any app
6. All data stays on this device — nothing is uploaded`]
  ]);

  /** 启动时调一次，按系统语言选定文案表 */
  static init(): void {
    try {
      const lang: string = i18n.System.getSystemLanguage();
      I18n.locale = lang.toLowerCase().startsWith('zh') ? 'zh' : 'en';
    } catch (e) {
      I18n.locale = 'en';
    }
  }

  static setLocale(locale: Locale): void {
    I18n.locale = locale;
  }

  static getLocale(): Locale {
    return I18n.locale;
  }

  static isZh(): boolean {
    return I18n.locale === 'zh';
  }

  /** 取字符串，找不到 key 时原样返回（兼容旧数据里存的中文 source） */
  static t(key: string): string {
    const table: Map<string, string> = I18n.locale === 'zh' ? I18n.ZH : I18n.EN;
    const v: string | undefined = table.get(key);
    return v !== undefined ? v : key;
  }

  /** 取带占位符的字符串，{0} {1} … 依次替换为 args */
  static f(key: string, ...args: string[]): string {
    let s: string = I18n.t(key);
    for (let i = 0; i < args.length; i++) {
      s = s.replace(`{${i}}`, args[i]);
    }
    return s;
  }
}
