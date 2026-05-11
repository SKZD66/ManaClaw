import { TaskCardState, NewTaskInput, statusColor } from '../common/AppModel'

@Component
export struct TaskListPage {
  connName: string = ''
  repoPath: string = ''
  tasks: TaskCardState[] = []
  listMsg: string = ''
  showNew: boolean = false
  creating: boolean = false

  @Link newTask: NewTaskInput

  onRefresh: () => void = () => {}
  onToggleNew: () => void = () => {}
  onOpen: (taskId: string) => void = (_: string) => {}
  onStop: (taskId: string) => void = (_: string) => {}
  onDelete: (taskId: string) => void = (_: string) => {}
  onSubmit: (openLogs: boolean) => void = (_: boolean) => {}

  private runningCount(): number {
    let n = 0
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].status === 'running') {
        n++
      }
    }
    return n
  }

  private canSubmit(): boolean {
    return !this.creating &&
      this.newTask.repoPath.length > 0 &&
      this.newTask.title.length > 0 &&
      this.newTask.prompt.length > 0
  }

  @Builder
  private Badge(status: string) {
    Text(status)
      .fontSize(11)
      .fontColor(0xFFFFFF)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(statusColor(status))
      .borderRadius(10)
  }

  @Builder
  private TaskCard(t: TaskCardState) {
    Column({ space: 6 }) {
      Row() {
        Text(t.title).fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
        this.Badge(t.status)
      }.width('100%')

      Text('task_id: ' + t.taskId).fontSize(12).fontColor(0x4B5563)
      Text('repo: ' + t.repo).fontSize(12).fontColor(0x4B5563)
      Text('branch: ' + t.branch).fontSize(12).fontColor(0x4B5563)
      Text('live: ' + (t.live ? 'true' : 'false')).fontSize(12).fontColor(0x4B5563)
      Text('created: ' + t.createdAt).fontSize(12).fontColor(0x4B5563)
      Text('updated: ' + t.updatedAt).fontSize(12).fontColor(0x4B5563)
      Text('last: ' + t.lastLog).fontSize(12).fontColor(t.status === 'failed' ? 0xD94841 : 0x111827)

      Row() {
        Button('打开详情').height(32).width('32%').onClick(() => this.onOpen(t.taskId))
        Blank().width('2%')
        Button('停止').height(32).width('32%').onClick(() => this.onStop(t.taskId))
        Blank().width('2%')
        Button('删除').height(32).width('32%').onClick(() => this.onDelete(t.taskId))
      }.width('100%')
    }
    .padding(12)
    .borderRadius(12)
    .backgroundColor(0xFFFFFF)
    .border({ width: 1, color: t.status === 'failed' ? 0xF1B5B2 : 0xE5E7EB })
  }

  @Builder
  private NewTaskView() {
    Column({ space: 8 }) {
      Text('NewTaskView').fontSize(16).fontWeight(FontWeight.Medium)

      TextInput({ text: this.newTask.repoPath, placeholder: 'Repo Path' })
        .width('100%')
        .onChange((v: string) => {
          this.newTask = {
            repoPath: v,
            title: this.newTask.title,
            prompt: this.newTask.prompt,
            mode: this.newTask.mode
          }
        })

      TextInput({ text: this.newTask.title, placeholder: 'Task Title' })
        .width('100%')
        .onChange((v: string) => {
          this.newTask = {
            repoPath: this.newTask.repoPath,
            title: v,
            prompt: this.newTask.prompt,
            mode: this.newTask.mode
          }
        })

      TextArea({ text: this.newTask.prompt, placeholder: 'Prompt' })
        .width('100%')
        .height(90)
        .onChange((v: string) => {
          this.newTask = {
            repoPath: this.newTask.repoPath,
            title: this.newTask.title,
            prompt: v,
            mode: this.newTask.mode
          }
        })

      Row() {
        Button(this.newTask.mode === 'run' ? 'Mode: Danger Run' : 'Mode: Plan')
          .width('49%')
          .height(34)
          .backgroundColor(this.newTask.mode === 'run' ? 0xD94841 : 0x2B8A3E)
          .fontColor(0xFFFFFF)
          .onClick(() => {
            this.newTask = {
              repoPath: this.newTask.repoPath,
              title: this.newTask.title,
              prompt: this.newTask.prompt,
              mode: this.newTask.mode === 'run' ? 'plan' : 'run'
            }
          })

        Blank().width('2%')

        Button('取消')
          .width('49%')
          .height(34)
          .onClick(() => this.onToggleNew())
      }.width('100%')

      if (this.newTask.mode === 'run') {
        Text('危险模式已开启：Claude Code 将使用 --dangerously-skip-permissions 在远端执行任务。请确保使用低权限用户和安全的开发环境。')
          .fontSize(12)
          .fontColor(0xD94841)
      }

      if (this.newTask.prompt.length > 0 && this.newTask.prompt.length < 10) {
        Text('提示：prompt 过短，效果可能较差。').fontSize(12).fontColor(0xE0A800)
      }

      Row() {
        Button(this.creating ? '提交中...' : 'Submit')
          .width('32%')
          .height(34)
          .enabled(this.canSubmit())
          .onClick(() => this.onSubmit(false))

        Blank().width('2%')

        Button('Submit&Open')
          .width('32%')
          .height(34)
          .enabled(this.canSubmit())
          .onClick(() => this.onSubmit(true))

        Blank().width('2%')

        Button('收起')
          .width('32%')
          .height(34)
          .onClick(() => this.onToggleNew())
      }.width('100%')
    }
    .padding(12)
    .borderRadius(12)
    .backgroundColor(0xFFFFFF)
  }

  build() {
    Scroll() {
      Column({ space: 8 }) {
        Text('TaskListPage').fontSize(20).fontWeight(FontWeight.Bold)
        Text(this.connName + ' · ' + this.repoPath).fontSize(13).fontColor(0x6B7280)
        Text('运行中任务数量：' + this.runningCount()).fontSize(13).fontColor(0x1F6FEB)

        Row() {
          Button('刷新').width('49%').height(36).onClick(() => this.onRefresh())
          Blank().width('2%')
          Button(this.showNew ? '收起新建' : '新建任务')
            .width('49%')
            .height(36)
            .onClick(() => this.onToggleNew())
        }.width('100%')

        if (this.showNew) {
          this.NewTaskView()
        }

        if (this.listMsg.length > 0) {
          Text(this.listMsg).fontSize(13).fontColor(0x1F6FEB).width('100%')
        }

        if (this.tasks.length === 0) {
          Text('暂无任务').fontSize(14).fontColor(0x6B7280)
        }

        ForEach(this.tasks, (t: TaskCardState) => {
          this.TaskCard(t)
        }, (t: TaskCardState) => t.taskId)
      }
      .padding(12)
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }
}