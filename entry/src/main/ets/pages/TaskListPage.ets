import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { TaskCardState, NewTaskInput, UiResult, TaskViewModel, statusColor } from '../common/AppModel';
import { TaskViewModelImpl } from '../vm/TaskService';

class NewTaskInputImpl implements NewTaskInput {
  repoPath: string = "";
  title: string = "";
  prompt: string = "";
  mode: string = "run";
}

class TaskDetailParams {
  taskId: string = "";
}

@CustomDialog
struct CreateTaskDialog {
  controller?: CustomDialogController;
  @Link title: string;
  @Link repo: string;
  @Link prompt: string;
  @Link mode: string;
  onSubmit: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text('新建 Agent 任务').fontSize(20).fontWeight(FontWeight.Bold).alignSelf(ItemAlign.Start)
      TextInput({ text: this.title, placeholder: '任务简短标题' }).onChange(v => this.title = v)
      TextInput({ text: this.repo, placeholder: '远端源码仓库绝对路径' }).onChange(v => this.repo = v)
      TextArea({ text: this.prompt, placeholder: '请输入具体下发给 Claude 的工程指令...' })
        .height(100).onChange(v => this.prompt = v)

      Row({ space: 20 }) {
        Row() { Radio({ value: 'run', group: 'modeGroup' }).checked(this.mode === 'run').onChange(c => { if(c) this.mode = 'run'; }); Text('运行模式').fontSize(14) }
        Row() { Radio({ value: 'plan', group: 'modeGroup' }).checked(this.mode === 'plan').onChange(c => { if(c) this.mode = 'plan'; }); Text('规划模式').fontSize(14) }
      }.width('100%')

      Row({ space: 12 }) {
        Button('取消').layoutWeight(1).backgroundColor('#F3F4F6').fontColor('#374151').onClick(() => this.controller?.close())
        Button('提交运行').layoutWeight(1).backgroundColor('#1F6FEB').onClick(() => { this.onSubmit(); })
      }.width('100%').margin({ top: 8 })
    }
    .padding(24).backgroundColor(Color.White).borderRadius(16)
  }
}

@Component
export struct TaskListPage {
  private vm: TaskViewModel = new TaskViewModelImpl();
  @State taskList: TaskCardState[] = [];
  @State isRefreshing: boolean = false;

  private isAlive: boolean = false;

  @State newTaskTitle: string = "";
  @State newTaskRepo: string = "";
  @State newTaskPrompt: string = "";
  @State newTaskMode: string = "run";

  dialogController: CustomDialogController = new CustomDialogController({
    builder: CreateTaskDialog({
      title: $newTaskTitle,
      repo: $newTaskRepo,
      prompt: $newTaskPrompt,
      mode: $newTaskMode,
      onSubmit: () => { this.submitNewTask(); }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true
  });

  aboutToAppear() {
    this.isAlive = true;
    setTimeout(() => {
      if (this.isAlive) {
        this.loadTasks(true);
      }
    }, 300);
  }

  aboutToDisappear() {
    this.isAlive = false;
  }

  async loadTasks(isAutoInit: boolean = false) {
    if (isAutoInit) {
      let conn = this.vm.loadConnection();
      if (!conn.host || conn.host.trim().length === 0) return;
    } else {
      this.isRefreshing = true;
    }

    let res: UiResult<TaskCardState[]> = await this.vm.loadTasks();
    if (!this.isAlive) return;

    this.isRefreshing = false;

    if (res.ok && res.data !== undefined) {
      this.taskList = res.data;
    } else {
      if (!isAutoInit) {
        promptAction.showToast({ message: res.msg });
      }
    }
  }

  async submitNewTask() {
    if (this.newTaskRepo.length === 0 || this.newTaskPrompt.length === 0) {
      promptAction.showToast({ message: '路径和提示词不能为空' });
      return;
    }
    let draft = new NewTaskInputImpl();
    draft.repoPath = this.newTaskRepo;
    draft.title = this.newTaskTitle;
    draft.prompt = this.newTaskPrompt;
    draft.mode = this.newTaskMode;

    let res = await this.vm.submitTask(draft);
    if (!this.isAlive) return;

    if (res.ok) {
      this.dialogController.close();
      this.loadTasks(false);
    }
    promptAction.showToast({ message: res.msg });
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Row() {
          Text('Claude Agent 任务流')
            .fontSize(22).fontWeight(FontWeight.Bold)
        }
        .width('100%').padding({ left: 24, top: 24, bottom: 12 })
        .backgroundColor('#F9FAFB')

        Refresh({ refreshing: $$this.isRefreshing }) {
          if (this.taskList.length === 0) {
            Column() {
              Text('暂无任务，下拉刷新或点击右下角添加')
                .fontSize(14).fontColor(0x9CA3AF)
            }
            .justifyContent(FlexAlign.Center).width('100%').height('100%')
          } else {
            List({ space: 16 }) {
              ForEach(this.taskList, (item: TaskCardState, index: number) => {
                ListItem() {
                  Row() {
                    Column() {
                      Text(item.title.length > 0 ? item.title : "未命名任务")
                        .fontSize(16).fontWeight(FontWeight.Medium).margin({ bottom: 4 })
                      Text(`ID: ${item.taskId}`).fontSize(12).fontColor(0x9CA3AF)
                      Text(`分支: ${item.branch}`).fontSize(12).fontColor(0x6B7280).margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Start).layoutWeight(1)

                    Text(item.status)
                      .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Color.White)
                      .backgroundColor(statusColor(item.status))
                      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                      .borderRadius(12)
                  }
                  .width('100%').padding(20)
                  .backgroundColor(Color.White).borderRadius(16)
                  .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.04)', offsetY: 4 })
                  .onClick(() => {
                    let p = new TaskDetailParams();
                    p.taskId = item.taskId;
                    router.pushUrl({
                      url: 'pages/TaskDetailPage',
                      params: p
                    }).catch((err: Error) => {
                      promptAction.showToast({ message: "页面跳转失败，请检查路由注册: " + err.message });
                    });
                  })
                }
              }, (item: TaskCardState, index: number) => item.taskId + '_' + index)
            }
            .width('100%').height('100%').padding({ left: 20, right: 20, top: 8, bottom: 80 })
          }
        }
        .onRefreshing(() => {
          this.loadTasks(false);
        })
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%').height('100%').backgroundColor('#F9FAFB')

      Button('+')
        .type(ButtonType.Circle)
        .width(60).height(60)
        .fontSize(32).fontWeight(FontWeight.Normal).fontColor(Color.White)
        .backgroundColor('#1F6FEB')
        .margin(24)
        .shadow({ radius: 16, color: 'rgba(31, 111, 235, 0.4)', offsetY: 6 })
        .onClick(() => {
          let conn = this.vm.loadConnection();
          this.newTaskRepo = conn.defaultRepoPath;
          this.newTaskTitle = "";
          this.newTaskPrompt = "";
          this.newTaskMode = "run";
          this.dialogController.open();
        })
    }
    .width('100%').height('100%')
  }
}