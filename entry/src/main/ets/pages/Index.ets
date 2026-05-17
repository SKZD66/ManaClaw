import { ConnectionPage } from './ConnectionPage';
import { TaskListPage } from './TaskListPage';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      // 将 SSH 配置页面放到首屏
      TabContent() {
        ConnectionPage()
      }
      .tabBar('SSH配置')

      // 将任务流页面放到第二个
      TabContent() {
        TaskListPage()
      }
      .tabBar('任务流')
    }
    .width('100%')
    .height('100%')
    .animationDuration(300)
    .onChange((index: number) => {
      this.currentIndex = index;
    })
  }
}