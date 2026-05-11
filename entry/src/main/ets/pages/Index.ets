import {
  ConnectionState, TaskCardState, TaskDetailState, TaskViewModel,
  NewTaskInput, emptyDetail, copyDetail, newTaskDraft
} from '../common/AppModel'
import { FakeTaskViewModel } from '../vm/FakeTaskViewModel'
import { ConnectionPage } from './ConnectionPage'
import { TaskListPage } from './TaskListPage'
import { TaskDetailPage } from './TaskDetailPage'

const APP_VM: TaskViewModel = new FakeTaskViewModel()
const INIT_CONN: ConnectionState = APP_VM.loadConnection()

@Entry
@Component
struct Index {
  private vm: TaskViewModel = APP_VM
  private timer: number = -1

  @State tab: number = 0

  @State conn: ConnectionState = {
    name: INIT_CONN.name,
    host: INIT_CONN.host,
    port: INIT_CONN.port,
    username: INIT_CONN.username,
    password: INIT_CONN.password,
    defaultRepoPath: INIT_CONN.defaultRepoPath
  }

  @State connMsg: string = ''
  @State connRaw: string = ''

  @State tasks: TaskCardState[] = []
  @State listMsg: string = ''

  @State detail: TaskDetailState = emptyDetail()
  @State detailMsg: string = ''
  @State logText: string = ''
  @State logRaw: string = ''
  @State gitText: string = ''
  @State gitLoading: boolean = false
  @State showRaw: boolean = false
  @State showErr: boolean = false

  @State showNew: boolean = false
  @State creating: boolean = false
  @State newTask: NewTaskInput = newTaskDraft(INIT_CONN.defaultRepoPath)

  aboutToAppear(): void {
    this.refreshTasks()
  }

  aboutToDisappear(): void {
    this.stopAuto()
  }

  private stopAuto(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
      this.timer = -1
    }
  }

  private syncAuto(): void {
    this.stopAuto()
    if (this.tab === 2 && this.detail.taskId.length > 0 && this.detail.status === 'running') {
      this.timer = setInterval(() => {
        this.refreshDetail()
        this.refreshLogs()
      }, 3000)
    }
  }

  private saveConn(): void {
    let r = this.vm.saveConnection(this.conn)
    this.connMsg = r.msg
    this.connRaw = r.raw
    this.newTask = {
      repoPath: this.conn.defaultRepoPath,
      title: this.newTask.title,
      prompt: this.newTask.prompt,
      mode: this.newTask.mode
    }
  }

  private testConn(): void {
    let r = this.vm.testConnection(this.conn)
    this.connMsg = r.msg
    this.connRaw = r.raw
  }

  private initRemote(): void {
    this.vm.saveConnection(this.conn)
    let r = this.vm.initRemote()
    this.connMsg = r.msg
    this.connRaw = r.raw
  }

  private enterTaskList(): void {
    this.saveConn()
    this.tab = 1
    this.refreshTasks()
    this.syncAuto()
  }

  private refreshTasks(): void {
    let r = this.vm.loadTasks()
    this.listMsg = r.msg
    if (r.ok && r.data) {
      this.tasks = r.data
    }
  }

  private openDetail(taskId: string): void {
    let r = this.vm.openTask(taskId)
    if (!r.ok || !r.data) {
      this.listMsg = r.msg
      return
    }
    this.detail = r.data
    this.detailMsg = ''
    this.logText = r.data.logs
    this.logRaw = r.data.rawLogs
    this.gitText = ''
    this.showRaw = false
    this.showErr = r.data.status === 'failed'
    this.tab = 2
    this.syncAuto()
  }

  private refreshDetail(): void {
    if (this.detail.taskId.length === 0) {
      return
    }
    let r = this.vm.refreshTask(this.detail.taskId)
    if (!r.ok || !r.data) {
      this.detailMsg = r.msg
      this.stopAuto()
      return
    }
    this.detail = r.data
    this.detailMsg = r.msg
    if (this.detail.status === 'failed') {
      this.showErr = true
    }
    this.refreshTasks()
    this.syncAuto()
  }

  private refreshLogs(): void {
    if (this.detail.taskId.length === 0) {
      return
    }
    let r = this.vm.refreshLogs(this.detail.taskId)
    if (!r.ok || !r.data) {
      this.detailMsg = r.msg
      return
    }
    this.logText = r.data.text
    this.logRaw = r.data.raw
    let d = copyDetail(this.detail)
    d.stderr = r.data.stderr
    this.detail = d
    if (this.detail.status === 'failed') {
      this.showErr = true
    }
  }

  private loadGit(): void {
    if (this.detail.taskId.length === 0) {
      return
    }
    this.gitLoading = true
    let r = this.vm.loadGitSummary(this.detail.taskId)
    this.gitLoading = false
    this.gitText = r.ok && r.data ? r.data : (r.msg + '\n' + r.raw)
  }

  private confirmStop(taskId: string): void {
    AlertDialog.show({
      title: '停止任务',
      message: '确认停止任务 ' + taskId + ' ?',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确定',
        action: () => {
          let r = this.vm.stopTask(taskId)
          this.listMsg = r.msg
          this.refreshTasks()
          if (this.detail.taskId === taskId) {
            this.refreshDetail()
          }
        }
      }
    })
  }

  private confirmDelete(taskId: string): void {
    AlertDialog.show({
      title: '删除任务',
      message: '确认删除任务 ' + taskId + ' ? 将停止任务并删除目录，保留 git branch。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确定',
        action: () => {
          let r = this.vm.deleteTask(taskId)
          this.listMsg = r.msg
          this.refreshTasks()
          if (r.ok && this.detail.taskId === taskId) {
            this.detail = emptyDetail()
            this.logText = ''
            this.logRaw = ''
            this.gitText = ''
            this.tab = 1
            this.syncAuto()
          }
        }
      }
    })
  }

  private toggleNew(): void {
    this.showNew = !this.showNew
    this.newTask = {
      repoPath: this.conn.defaultRepoPath,
      title: this.newTask.title,
      prompt: this.newTask.prompt,
      mode: this.newTask.mode
    }
  }

  private submitNew(openLogs: boolean): void {
    if (this.creating) {
      return
    }
    if (this.newTask.repoPath.length === 0 || this.newTask.title.length === 0 || this.newTask.prompt.length === 0) {
      this.listMsg = 'repo/title/prompt 不能为空'
      return
    }

    this.creating = true
    let r = this.vm.submitTask(this.newTask)
    this.creating = false
    this.listMsg = r.msg
    this.refreshTasks()

    if (r.ok && r.data) {
      this.showNew = false
      let repoPath = this.conn.defaultRepoPath
      this.newTask = newTaskDraft(repoPath)
      if (openLogs) {
        this.openDetail(r.data.taskId)
      }
    }
  }

  @Builder
  private Nav(title: string, i: number) {
    Button(title)
      .width('33.3%')
      .height(52)
      .fontColor(this.tab === i ? 0xFFFFFF : 0x374151)
      .backgroundColor(this.tab === i ? 0x1F6FEB : 0xFFFFFF)
      .onClick(() => {
        this.tab = i
        this.syncAuto()
      })
  }

  build() {
    Column() {
      Column() {
        if (this.tab === 0) {
          ConnectionPage({
            conn: $conn,
            msg: this.connMsg,
            raw: this.connRaw,
            onSave: () => this.saveConn(),
            onTest: () => this.testConn(),
            onInit: () => this.initRemote(),
            onEnter: () => this.enterTaskList()
          })
        } else if (this.tab === 1) {
          TaskListPage({
            connName: this.conn.name,
            repoPath: this.conn.defaultRepoPath,
            tasks: this.tasks,
            listMsg: this.listMsg,
            showNew: this.showNew,
            creating: this.creating,
            newTask: $newTask,
            onRefresh: () => this.refreshTasks(),
            onToggleNew: () => this.toggleNew(),
            onOpen: (taskId: string) => this.openDetail(taskId),
            onStop: (taskId: string) => this.confirmStop(taskId),
            onDelete: (taskId: string) => this.confirmDelete(taskId),
            onSubmit: (openLogs: boolean) => this.submitNew(openLogs)
          })
        } else {
          TaskDetailPage({
            detail: this.detail,
            detailMsg: this.detailMsg,
            logText: this.logText,
            logRaw: this.logRaw,
            gitText: this.gitText,
            gitLoading: this.gitLoading,
            showRaw: $showRaw,
            showErr: $showErr,
            onRefreshDetail: () => this.refreshDetail(),
            onRefreshLogs: () => this.refreshLogs(),
            onLoadGit: () => this.loadGit(),
            onStop: (taskId: string) => this.confirmStop(taskId),
            onDelete: (taskId: string) => this.confirmDelete(taskId)
          })
        }
      }
      .layoutWeight(1)
      .width('100%')

      Row() {
        this.Nav('连接', 0)
        this.Nav('任务', 1)
        this.Nav('详情', 2)
      }
      .width('100%')
      .height(56)
      .backgroundColor(0xFFFFFF)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(0xF6F8FB)
  }
}