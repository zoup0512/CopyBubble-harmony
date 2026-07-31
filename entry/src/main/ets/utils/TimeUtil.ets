/** 相对时间显示 */
export class TimeUtil {
  private static pad(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }

  static relative(ts: number): string {
    const now: number = Date.now();
    const diff: number = now - ts;
    if (diff < 60000) {
      return '刚刚';
    }
    if (diff < 3600000) {
      return `${Math.floor(diff / 60000)} 分钟前`;
    }
    const d: Date = new Date(ts);
    const today: Date = new Date(now);
    const sameDay: boolean = d.getFullYear() === today.getFullYear()
      && d.getMonth() === today.getMonth()
      && d.getDate() === today.getDate();
    if (sameDay) {
      return `今天 ${TimeUtil.pad(d.getHours())}:${TimeUtil.pad(d.getMinutes())}`;
    }
    const yesterday: Date = new Date(now - 86400000);
    const isYesterday: boolean = d.getFullYear() === yesterday.getFullYear()
      && d.getMonth() === yesterday.getMonth()
      && d.getDate() === yesterday.getDate();
    if (isYesterday) {
      return `昨天 ${TimeUtil.pad(d.getHours())}:${TimeUtil.pad(d.getMinutes())}`;
    }
    return `${TimeUtil.pad(d.getMonth() + 1)}-${TimeUtil.pad(d.getDate())} ${TimeUtil.pad(d.getHours())}:${TimeUtil.pad(d.getMinutes())}`;
  }

  static full(ts: number): string {
    const d: Date = new Date(ts);
    return `${d.getFullYear()}-${TimeUtil.pad(d.getMonth() + 1)}-${TimeUtil.pad(d.getDate())} `
      + `${TimeUtil.pad(d.getHours())}:${TimeUtil.pad(d.getMinutes())}:${TimeUtil.pad(d.getSeconds())}`;
  }
}
