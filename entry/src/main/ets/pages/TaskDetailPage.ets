import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard'; // 引入系统剪贴板支持
import { TaskDetailState, UiResult, TaskViewModel, statusColor } from '../common/AppModel';
import { TaskViewModelImpl } from '../vm/TaskService';

class TaskDetailStatePageImpl implements TaskDetailState {
  title: string = "";
  taskId: string = "";
  status: string = "unknown";
  repo: string = "";
  branch: string = "";
  live: boolean = false;
  createdAt: string = "";
  updatedAt: string = "";
  lastLog: string = "";
  worktree: string = "";
  tmuxSession: string = "";
  exitCode: string = "";
  logs: string = "";
  rawLogs: string = "";
  stderr: string = "";
  gitSummary: string = ""; // 这个字段仍然保留，可用于缓存成功状态
}

@Entry
@Component
struct TaskDetailPage {
  private vm: TaskViewModel = new TaskViewModelImpl();
  @State taskId: string = "";
  @State detail: TaskDetailState = new TaskDetailStatePageImpl();
  @State isOperating: boolean = false;

  // 【核心修复】：Git 摘要专属按需加载状态
  @State isGitLoading: boolean = false;
  @State isGitLoaded: boolean = false;
  @State gitLoadError: string = "";

  aboutToAppear() {
    let paramsObj: Object | undefined = router.getParams();
    if (paramsObj !== undefined && paramsObj !== null) {
      let params = paramsObj as Record<string, Object>;
      if (params['taskId'] !== undefined && params['taskId'] !== null) {
        this.taskId = params['taskId'].toString();
        this.doRefresh();
      } else {
        promptAction.showToast({ message: "错误：解析路由参数未找到 taskId" });
      }
    } else {
      promptAction.showToast({ message: "错误：详情页未接收到任何路由参数" });
    }
  }

  async doRefresh() {
    this.isOperating = true;
    // 不再自动拉取 Git 摘要
    let res: UiResult<TaskDetailState> = await this.vm.refreshTask(this.taskId);

    if (res.ok && res.data !== undefined) {
      this.detail = res.data;
    } else {
      promptAction.showToast({ message: res.msg });
    }
    this.isOperating = false;
  }

  // 【核心修复】：单独且带异常捕获的 Git 加载函数
  async fetchGitSummary() {
    this.isGitLoading = true;
    this.gitLoadError = ""; // 清除旧错误
    let gitRes = await this.vm.loadGitSummary(this.taskId);
    this.isGitLoading = false;
    this.isGitLoaded = true;

    if (gitRes.ok && gitRes.data !== undefined) {
      this.detail.gitSummary = gitRes.data;
    } else {
      // 提取详细报错
      this.gitLoadError = gitRes.raw && gitRes.raw.length > 0 ? gitRes.raw : gitRes.msg;
    }
  }

  // 复制文字到剪贴板
  copyToClipboard(text: string) {
    let pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    let systemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setData(pasteData).then(() => {
      promptAction.showToast({ message: '报错日志已复制' });
    });
  }

  build() {
    Column() {
      // 头部导航
      Row() {
        Image($r('sys.media.ohos_ic_compnent_titlebar_back'))
          .width(24).height(24).fillColor('#111827')
          .onClick(() => { router.back(); })
        Text(this.detail.title.length > 0 ? this.detail.title : "任务控制台")
          .fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1).margin({ left: 16 })

        Button() {
          if (this.isOperating) {
            LoadingProgress().width(18).height(18).color('#1F6FEB')
          } else {
            Text('刷新').fontSize(14).fontColor('#1F6FEB')
          }
        }
        .backgroundColor(Color.Transparent).enabled(!this.isOperating)
        .onClick(() => { this.doRefresh(); })
      }
      .width('100%').padding(16).backgroundColor(Color.White)

      // 元信息面板
      Column({ space: 8 }) {
        Row() {
          Text(`ID: ${this.detail.taskId}`).fontSize(13).fontColor(0x4B5563)
          Text(this.detail.status)
            .fontSize(12).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .backgroundColor(statusColor(this.detail.status))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 }).borderRadius(6)
        }.width('100%').justifyContent(FlexAlign.SpaceBetween)

        Text(`仓库: ${this.detail.repo}`).fontSize(12).fontColor(0x6B7280).alignSelf(ItemAlign.Start)
        Text(`会话: ${this.detail.tmuxSession} (${this.detail.live ? '🔴 在线' : '⚪️ 离线'})`).fontSize(12).fontColor(0x6B7280).alignSelf(ItemAlign.Start)

        if (this.detail.exitCode.length > 0) {
          Text(`远端退出码: ${this.detail.exitCode}`).fontSize(12).fontWeight(FontWeight.Bold).fontColor(0xD94841).alignSelf(ItemAlign.Start)
        }
      }
      .padding(16).backgroundColor('#F9FAFB')
      .border({ width: { bottom: 1 }, color: '#E5E7EB' })

      // 滑动终端区域
      Tabs({ barPosition: BarPosition.Start }) {
        TabContent() {
          Scroll() {
            Text(this.detail.logs.length > 0 ? this.detail.logs : "Listening to remote streams...")
              .fontSize(13).fontFamily('monospace').fontColor('#D4D4D4')
              .textAlign(TextAlign.Start).width('100%').copyOption(CopyOptions.LocalDevice)
          }.padding(16).align(Alignment.TopStart).backgroundColor('#1E1E1E')
        }.tabBar('分析日志')

        TabContent() {
          Scroll() {
            Text(this.detail.rawLogs.length > 0 ? this.detail.rawLogs : "No raw events.")
              .fontSize(12).fontFamily('monospace').fontColor('#858585')
              .textAlign(TextAlign.Start).width('100%').copyOption(CopyOptions.LocalDevice)
          }.padding(16).align(Alignment.TopStart).backgroundColor('#1E1E1E')
        }.tabBar('原始流')

        TabContent() {
          Scroll() {
            Text(this.detail.stderr.length > 0 ? this.detail.stderr : "No standard errors.")
              .fontSize(13).fontFamily('monospace').fontColor('#F48771')
              .textAlign(TextAlign.Start).width('100%').copyOption(CopyOptions.LocalDevice)
          }.padding(16).align(Alignment.TopStart).backgroundColor('#1E1E1E')
        }.tabBar('标准错误')

        // 【核心修复】：Git Summary 按需触发面板
        TabContent() {
          Column() {
            if (!this.isGitLoaded && !this.isGitLoading && this.gitLoadError.length === 0) {
              // 状态 1：初始状态，显示触发按钮
              Button('查看 Git 变更摘要')
                .width(200).height(44).backgroundColor('#1F6FEB')
                .onClick(() => { this.fetchGitSummary(); })
            } else if (this.isGitLoading) {
              // 状态 2：加载中 Loading
              LoadingProgress().width(36).height(36).color('#1F6FEB')
              Text('正在拉取远端 Git 信息...').fontSize(13).fontColor('#858585').margin({ top: 12 })
            } else if (this.gitLoadError.length > 0) {
              // 状态 3：加载失败，带复制能力的错误面板
              Column({ space: 12 }) {
                Text('⚠️ Git 摘要加载失败').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#F48771')
                Scroll() {
                  Text(this.gitLoadError)
                    .fontSize(12).fontFamily('monospace').fontColor('#D4D4D4')
                    .textAlign(TextAlign.Start).width('100%').copyOption(CopyOptions.LocalDevice)
                }
                .width('100%').height(160).backgroundColor('#111827').padding(12).borderRadius(8)

                Row({ space: 16 }) {
                  Button('复制报错').fontSize(12).backgroundColor('#374151').height(32)
                    .onClick(() => { this.copyToClipboard(this.gitLoadError); })
                  Button('重试').fontSize(12).backgroundColor('#1F6FEB').height(32)
                    .onClick(() => { this.fetchGitSummary(); })
                }
              }.width('85%')
            } else {
              // 状态 4：加载成功，滚动展示 Diff
              Scroll() {
                Text(this.detail.gitSummary.length > 0 ? this.detail.gitSummary : "Working tree is clean.")
                  .fontSize(13).fontFamily('monospace').fontColor('#4AF626')
                  .textAlign(TextAlign.Start).width('100%').copyOption(CopyOptions.LocalDevice)
              }.padding(16).align(Alignment.TopStart).backgroundColor('#1E1E1E')
            }
          }
          .width('100%').height('100%')
          .backgroundColor('#1E1E1E').justifyContent(FlexAlign.Center)
        }.tabBar('Git Summary')
      }
      .layoutWeight(1)
      .width('100%')
      .barMode(BarMode.Scrollable)

      // 危险操作指令区
      Row({ space: 16 }) {
        Button('终止 Agent')
          .layoutWeight(1).backgroundColor(0xD94841).enabled(this.detail.live)
          .onClick(async () => {
            let r = await this.vm.stopTask(this.taskId);
            promptAction.showToast({ message: r.msg });
            this.doRefresh();
          })

        Button('清理销毁')
          .layoutWeight(1).backgroundColor(0x6B7280)
          .onClick(async () => {
            let r = await this.vm.deleteTask(this.taskId);
            promptAction.showToast({ message: r.msg });
            if (r.ok) {
              router.back();
            }
          })
      }
      .padding({ left: 16, right: 16, top: 12, bottom: 24 })
      .width('100%')
      .backgroundColor(Color.White)
      .border({ width: { top: 1 }, color: '#E5E7EB' })
    }
    .width('100%')
    .height('100%')
  }
}