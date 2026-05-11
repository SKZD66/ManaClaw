import { TaskDetailState, statusColor, emptyDetail } from '../common/AppModel'

@Component
export struct TaskDetailPage {
  detail: TaskDetailState = emptyDetail()
  detailMsg: string = ''
  logText: string = ''
  logRaw: string = ''
  gitText: string = ''
  gitLoading: boolean = false

  @Link showRaw: boolean
  @Link showErr: boolean

  onRefreshDetail: () => void = () => {}
  onRefreshLogs: () => void = () => {}
  onLoadGit: () => void = () => {}
  onStop: (taskId: string) => void = (_: string) => {}
  onDelete: (taskId: string) => void = (_: string) => {}

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
  private KV(k: string, v: string) {
    Row() {
      Text(k).width('34%').fontSize(13).fontColor(0x6B7280)
      Text(v).width('66%').fontSize(13).fontColor(0x111827)
    }.width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 8 }) {
        Text('TaskDetailPage').fontSize(20).fontWeight(FontWeight.Bold)

        if (this.detail.taskId.length === 0) {
          Text('请先在任务列表中打开一个任务').fontSize(14).fontColor(0x6B7280)
        } else {
          Row() {
            Text(this.detail.title).fontSize(18).fontWeight(FontWeight.Medium).layoutWeight(1)
            this.Badge(this.detail.status)
          }.width('100%')

          this.KV('task_id', this.detail.taskId)
          this.KV('live', this.detail.live ? 'true' : 'false')
          this.KV('repo', this.detail.repo)
          this.KV('branch', this.detail.branch)
          this.KV('worktree', this.detail.worktree)
          this.KV('tmux', this.detail.tmuxSession)
          this.KV('createdAt', this.detail.createdAt)
          this.KV('updatedAt', this.detail.updatedAt)
          this.KV('exitCode', this.detail.exitCode.length > 0 ? this.detail.exitCode : '-')

          Row() {
            Button('刷新状态').width('32%').height(34).onClick(() => this.onRefreshDetail())
            Blank().width('2%')
            Button('刷新日志').width('32%').height(34).onClick(() => this.onRefreshLogs())
            Blank().width('2%')
            Button('Git').width('32%').height(34).onClick(() => this.onLoadGit())
          }.width('100%')

          Row() {
            Button('停止任务').width('49%').height(34).onClick(() => this.onStop(this.detail.taskId))
            Blank().width('2%')
            Button('删除').width('49%').height(34).onClick(() => this.onDelete(this.detail.taskId))
          }.width('100%')

          if (this.detailMsg.length > 0) {
            Text(this.detailMsg).fontSize(13).fontColor(0x1F6FEB).width('100%')
          }

          Row() {
            Text('日志区').fontSize(16).layoutWeight(1)
            Button(this.showRaw ? '简洁视图' : 'Raw JSON')
              .height(30)
              .onClick(() => this.showRaw = !this.showRaw)
          }.width('100%')

          TextArea({ text: this.showRaw ? this.logRaw : this.logText })
            .height(180)
            .width('100%')

          Row() {
            Text('stderr 区').fontSize(16).layoutWeight(1)
            Button(this.showErr ? '折叠' : '展开')
              .height(30)
              .onClick(() => this.showErr = !this.showErr)
          }.width('100%')

          if (this.showErr) {
            TextArea({
              text: this.detail.stderr.length > 0 ? this.detail.stderr : '暂无错误输出'
            }).height(100).width('100%')
          }

          Row() {
            Text('Git 摘要').fontSize(16).layoutWeight(1)
            if (this.gitLoading) {
              Text('loading...').fontSize(12).fontColor(0x6B7280)
            }
          }.width('100%')

          if (this.gitText.length > 0) {
            TextArea({ text: this.gitText }).height(180).width('100%')
          }
        }
      }
      .padding(12)
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }
}