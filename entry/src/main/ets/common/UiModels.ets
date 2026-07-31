/**
 * @Builder 的参数必须整体打包成对象传入，按值传递的基础类型
 * 在 ArkTS 里不会触发 builder 内部的重新渲染。
 */

export class SwitchRowParam {
  title: string = '';
  desc: string = '';
  value: boolean = false;
  onToggle: (v: boolean) => void = () => {};
}

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
