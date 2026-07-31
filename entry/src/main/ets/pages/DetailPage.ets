import { promptAction } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ClipItem, ClipType } from '../model/ClipItem';
import { ClipStore } from '../manager/ClipStore';
import { ClipboardKit } from '../manager/ClipboardKit';
import { Theme } from '../common/Theme';
import { ActionRowParam } from '../common/UiModels';
import { TimeUtil } from '../utils/TimeUtil';
import { TypeDetector } from '../utils/TypeDetector';

const TAG: string = 'CopyBubble/Detail';
const DOMAIN: number = 0x1001;

@Component
export struct DetailPage {
  @Consume('nav') pathStack: NavPathStack;
  itemId: string = '';

  @State private item: ClipItem | null = null;
  @State private editing: boolean = false;
  @State private draft: string = '';

  private store: ClipStore = ClipStore.getInstance();

  aboutToAppear(): void {
    this.item = this.store.getById(this.itemId);
    if (this.item !== null) {
      this.draft = this.item.content;
    }
  }

  build() {
    NavDestination() {
      Column({ space: 0 }) {
        this.Bar()
        if (this.item === null) {
          Column() {
            Text('这条记录已经不在了')
              .fontSize(14)
              .fontColor(Theme.TEXT_2)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 14 }) {
              this.MetaRow()
              this.ContentBox()
              this.QuickActions()
              this.DangerZone()
            }
            .padding({ left: Theme.PAGE_PAD, right: Theme.PAGE_PAD, bottom: 40 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .align(Alignment.TopStart)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.PAGE_BG)
    }
    .hideTitleBar(true)
    .backgroundColor(Theme.PAGE_BG)
  }

  // ---------- UI 片段 ----------

  @Builder
  Bar() {
    Row({ space: 8 }) {
      Text('‹')
        .fontSize(28)
        .fontColor(Theme.TEXT_1)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => this.pathStack.pop())

      Text('详情')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_1)
        .layoutWeight(1)

      if (this.item !== null) {
        Text(this.editing ? '完成' : '编辑')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.BRAND)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .onClick(() => this.toggleEdit())
      }
    }
    .width('100%')
    .padding({ left: 8, right: 12, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  MetaRow() {
    if (this.item !== null) {
      Row({ space: 8 }) {
        Text(`${Theme.styleOf(this.item.type).glyph} ${Theme.styleOf(this.item.type).label}`)
          .fontSize(12)
          .fontColor(Theme.styleOf(this.item.type).tint)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(Theme.styleOf(this.item.type).wash)
          .borderRadius(Theme.RADIUS_CHIP)

        Text(`${this.item.charCount} 字`)
          .fontSize(12)
          .fontColor(Theme.TEXT_2)

        Blank()

        Text(this.item.pinned ? '★ 已置顶' : '☆ 置顶')
          .fontSize(12)
          .fontColor(this.item.pinned ? Theme.PIN : Theme.TEXT_2)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(Theme.CARD_BG)
          .borderRadius(Theme.RADIUS_CHIP)
          .onClick(() => this.doPin())
      }
      .width('100%')
      .margin({ top: 4 })
    }
  }

  @Builder
  ContentBox() {
    if (this.item !== null) {
      Column({ space: 10 }) {
        if (this.editing) {
          TextArea({ text: this.draft })
            .fontSize(15)
            .lineHeight(24)
            .constraintSize({ minHeight: 160 })
            .backgroundColor('#F5F5FA')
            .borderRadius(12)
            .padding(12)
            .onChange((v: string) => { this.draft = v; })
        } else {
          Text(this.item.content)
            .fontSize(15)
            .lineHeight(24)
            .fontColor(Theme.TEXT_1)
            .width('100%')
            .textAlign(TextAlign.Start)
            .copyOption(CopyOptions.LocalDevice)
        }

        Divider().color(Theme.DIVIDER)

        Row() {
          Text(`收录于 ${TimeUtil.full(this.item.createTime)}`)
            .fontSize(11)
            .fontColor(Theme.TEXT_3)
          Blank()
          Text(this.item.source)
            .fontSize(11)
            .fontColor(Theme.TEXT_3)
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Theme.CARD_BG)
      .borderRadius({ topLeft: 20, topRight: 20, bottomRight: 20, bottomLeft: 6 })
    }
  }

  @Builder
  QuickActions() {
    if (this.item !== null) {
      Column({ space: 8 }) {
        this.ActionRow({
          title: '复制全文',
          sub: '把这条内容写回系统剪贴板',
          color: Theme.BRAND,
          action: () => this.doCopy()
        })

        if (this.item.type === ClipType.LINK) {
          this.ActionRow({
            title: '用浏览器打开',
            sub: TypeDetector.extractUrl(this.item.content),
            color: '#0F9D8F',
            action: () => this.openUri(this.linkTarget())
          })
        }
        if (this.item.type === ClipType.PHONE) {
          this.ActionRow({
            title: '拨号',
            sub: this.item.content,
            color: '#D97706',
            action: () => this.openUri(this.telTarget())
          })
        }
        if (this.item.type === ClipType.EMAIL) {
          this.ActionRow({
            title: '写邮件',
            sub: this.item.content,
            color: '#DB2777',
            action: () => this.openUri(this.mailTarget())
          })
        }
        if (this.item.type === ClipType.CODE) {
          this.ActionRow({
            title: '只复制数字',
            sub: TypeDetector.extractCode(this.item.content),
            color: '#7A5CE8',
            action: () => this.copyCode()
          })
        }

        this.ActionRow({
          title: '分享',
          sub: '发送到其他应用',
          color: Theme.TEXT_2,
          action: () => this.doShare()
        })
      }
      .width('100%')
    }
  }

  @Builder
  ActionRow($$: ActionRowParam) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text($$.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($$.color)
        if ($$.sub.length > 0) {
          Text($$.sub)
            .fontSize(12)
            .fontColor(Theme.TEXT_3)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontSize(18)
        .fontColor(Theme.TEXT_3)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(16)
    .onClick(() => $$.action())
  }

  @Builder
  DangerZone() {
    Text('删除这条记录')
      .fontSize(14)
      .fontColor(Theme.DANGER)
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding({ top: 14, bottom: 14 })
      .backgroundColor('#FDECEC')
      .borderRadius(16)
      .margin({ top: 6 })
      .onClick(() => this.confirmDelete())
  }

  // ---------- 行为 ----------

  private async toggleEdit(): Promise<void> {
    if (this.editing) {
      if (this.item !== null && this.draft.trim().length > 0) {
        await this.store.update(this.item.id, this.draft);
        this.item = this.store.getById(this.itemId);
      }
      this.editing = false;
      promptAction.showToast({ message: '已保存' });
    } else {
      this.editing = true;
    }
  }

  private linkTarget(): string {
    return this.item === null ? '' : TypeDetector.extractUrl(this.item.content);
  }

  private telTarget(): string {
    return this.item === null ? '' : `tel:${this.item.content.replace(/[\s-]/g, '')}`;
  }

  private mailTarget(): string {
    return this.item === null ? '' : `mailto:${this.item.content}`;
  }

  private async copyCode(): Promise<void> {
    if (this.item === null) {
      return;
    }
    await this.copyText(TypeDetector.extractCode(this.item.content));
  }

  private async doPin(): Promise<void> {
    if (this.item === null) {
      return;
    }
    await this.store.togglePin(this.item.id);
    this.item = this.store.getById(this.itemId);
  }

  private async doCopy(): Promise<void> {
    if (this.item === null) {
      return;
    }
    await this.copyText(this.item.content);
    await this.store.markUsed(this.item.id);
  }

  private async copyText(text: string): Promise<void> {
    if (text.length === 0) {
      promptAction.showToast({ message: '没有可复制的内容' });
      return;
    }
    const ok: boolean = await ClipboardKit.write(text);
    promptAction.showToast({ message: ok ? '已复制到剪贴板' : '复制失败，请重试' });
  }

  private openUri(uri: string): void {
    if (uri.length === 0) {
      promptAction.showToast({ message: '没有找到可打开的地址' });
      return;
    }
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const want: Want = { action: 'ohos.want.action.viewData', uri: uri };
    ctx.startAbility(want).catch((e: BusinessError) => {
      hilog.error(DOMAIN, TAG, `startAbility failed ${e.code}`);
      promptAction.showToast({ message: '没有应用可以打开它' });
    });
  }

  private doShare(): void {
    if (this.item === null) {
      return;
    }
    try {
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.PLAIN_TEXT,
        content: this.item.content
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      controller.show(ctx, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, `share failed ${err.code}`);
      promptAction.showToast({ message: '分享面板打不开' });
    }
  }

  private confirmDelete(): void {
    promptAction.showDialog({
      title: '删除这条记录',
      message: '删掉之后没法恢复。',
      buttons: [
        { text: '取消', color: Theme.TEXT_2 },
        { text: '删除', color: Theme.DANGER }
      ]
    }).then(async (res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index === 1 && this.item !== null) {
        await this.store.remove(this.item.id);
        this.pathStack.pop();
      }
    });
  }
}
