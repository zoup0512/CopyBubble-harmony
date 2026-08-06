import { Theme } from '../common/Theme';
import { NavParam } from '../model/ClipItem';
import { HomeView } from './HomeView';
import { DetailPage } from './DetailPage';
import { SettingsPage } from './SettingsPage';

@Entry
@Component
struct Index {
  @Provide('nav') pathStack: NavPathStack = new NavPathStack();
  // 系统深浅色切换时重绘（Theme 色板按此取色）
  @StorageProp(Theme.KEY_DARK_MODE) darkMode: boolean = false;

  @Builder
  PageMap(name: string, param: object) {
    if (name === 'detail') {
      DetailPage({ itemId: (param as NavParam).id })
    } else if (name === 'settings') {
      SettingsPage()
    }
  }

  build() {
    Navigation(this.pathStack) {
      HomeView()
    }
    .navDestination(this.PageMap)
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .backgroundColor(Theme.PAGE_BG)
    .width('100%')
    .height('100%')
  }
}
