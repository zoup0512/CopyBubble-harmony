/**
 * @Builder 的参数必须整体打包成对象传入，按值传递的基础类型
 * 在 ArkTS 里不会触发 builder 内部的重新渲染。
 */

export class ActionRowParam {
  title: string = '';
  sub: string = '';
  color: string = '#141626';
  action: () => void = () => {};
}

export class KVParam {
  key: string = '';
  value: string = '';
}

/**
 * 各分类的条数。@Observed + 父组件 @State + 子组件 @ObjectLink。
 *
 * 注意：@Observed 只能感知「一级属性的赋值」，无法感知 Map.set() 这类对内部
 * 结构的改动。因此父组件刷新计数时必须整体换一个新实例赋给 @State，
 * 而不能复用旧对象调 set()——否则 CategoryStrip 上的数字会卡住不刷新。
 */
@Observed
export class CategoryCounts {
  private map: Map<string, number> = new Map<string, number>();

  get(key: string): number {
    return this.map.get(key) ?? 0;
  }

  set(key: string, n: number): void {
    this.map.set(key, n);
  }
}
