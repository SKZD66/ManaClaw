import {
  ConnectionState, TaskCardState, TaskDetailState, LogPanelState,
  NewTaskInput, UiResult, TaskViewModel, copyDetail
} from '../common/AppModel'

export class FakeTaskViewModel implements TaskViewModel {
  private conn: ConnectionState = {
    name: '开发机',
    host: '182.92.107.89',
    port: '22',
    username: 'root',
    password: '',
    defaultRepoPath: '/root/projects/ccflow-test-repo'
  }

  private tasks: TaskDetailState[] = []

  constructor() {
    this.tasks.push(this.mk('cc-001', '运行中任务样例', 'running'))
    this.tasks.push(this.mk('cc-002', '已完成任务样例', 'completed'))
    this.tasks.push(this.mk('cc-003', '失败任务样例', 'failed'))
    this.tasks.push(this.mk('cc-004', '已停止任务样例', 'stopped'))
    this.tasks.push(this.mk('cc-005', '未知状态任务样例', 'unknown'))
  }

  private now(): string {
    return new Date().toLocaleString()
  }

  private mk(id: string, title: string, status: string): TaskDetailState {
    let live = status === 'running'
    let stderr = status === 'failed' ? 'mock stderr: permission denied\nmock stderr: exit 1' : ''
    let exitCode = status === 'completed' ? '0' : (status === 'failed' ? '1' : '')
    let logs = '[' + this.now() + '] task created\n[' + this.now() + '] status=' + status
    let raw = '{"ts":"' + this.now() + '","event":"created"}\n{"ts":"' + this.now() + '","status":"' + status + '"}'
    return {
      title: title,
      taskId: id,
      status: status,
      repo: this.conn.defaultRepoPath,
      branch: 'agent/' + id,
      live: live,
      createdAt: this.now(),
      updatedAt: this.now(),
      lastLog: 'status=' + status,
      worktree: '/tmp/worktrees/' + id,
      tmuxSession: 'cc-' + id,
      exitCode: exitCode,
      logs: logs,
      rawLogs: raw,
      stderr: stderr,
      gitSummary: ''
    }
  }

  private idx(taskId: string): number {
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].taskId === taskId) {
        return i
      }
    }
    return -1
  }

  private card(t: TaskDetailState): TaskCardState {
    return {
      title: t.title,
      taskId: t.taskId,
      status: t.status,
      repo: t.repo,
      branch: t.branch,
      live: t.live,
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
      lastLog: t.lastLog
    }
  }

  private beat(t: TaskDetailState): void {
    if (t.status !== 'running') {
      return
    }
    let line = '[' + this.now() + '] running heartbeat'
    t.logs = t.logs + '\n' + line
    t.rawLogs = t.rawLogs + '\n{"ts":"' + this.now() + '","event":"heartbeat"}'
    t.lastLog = line
    t.updatedAt = this.now()
    if (t.logs.split('\n').length > 8) {
      t.status = 'completed'
      t.live = false
      t.exitCode = '0'
      t.lastLog = 'task completed'
      t.logs = t.logs + '\n[' + this.now() + '] completed'
    }
  }

  loadConnection(): ConnectionState {
    return {
      name: this.conn.name,
      host: this.conn.host,
      port: this.conn.port,
      username: this.conn.username,
      password: this.conn.password,
      defaultRepoPath: this.conn.defaultRepoPath
    }
  }

  saveConnection(input: ConnectionState): UiResult<boolean> {
    this.conn = {
      name: input.name,
      host: input.host,
      port: input.port,
      username: input.username,
      password: input.password,
      defaultRepoPath: input.defaultRepoPath
    }
    return new UiResult<boolean>(true, '保存成功', '', true)
  }

  testConnection(input: ConnectionState): UiResult<boolean> {
    if (input.host.length === 0 || input.port.length === 0 || input.username.length === 0) {
      return new UiResult<boolean>(false, '连接失败：配置不完整', 'host/port/username 不能为空')
    }
    if (input.host.indexOf('fail') >= 0 || input.host.indexOf('bad') >= 0) {
      return new UiResult<boolean>(false, '连接失败：mock 网络错误', 'ssh: connect to host failed')
    }
    return new UiResult<boolean>(true, '连接成功：ok', '', true)
  }

  initRemote(): UiResult<boolean> {
    if (this.conn.host.length === 0 || this.conn.username.length === 0 || this.conn.password.length === 0) {
      return new UiResult<boolean>(false, '初始化失败：服务器配置不完整', 'password/host/username 缺失')
    }
    if (this.conn.host.indexOf('missing') >= 0) {
      return new UiResult<boolean>(
        false,
        '远端缺少 tmux：请在服务器执行 sudo apt install tmux。',
        'git: ok\ntmux: missing\nclaude: ok\nbase64: ok\n~/.cc-mobile: failed'
      )
    }
    return new UiResult<boolean>(
      true,
      '初始化完成',
      'git: ok\ntmux: ok\nclaude: ok\nbase64: ok\n~/.cc-mobile: created',
      true
    )
  }

  loadTasks(): UiResult<TaskCardState[]> {
    let arr: TaskCardState[] = []
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].status !== 'deleted') {
        arr.push(this.card(this.tasks[i]))
      }
    }
    return new UiResult<TaskCardState[]>(true, '', '', arr)
  }

  submitTask(input: NewTaskInput): UiResult<TaskCardState> {
    let id = 'cc-' + new Date().getTime()
    let t = this.mk(id, input.title, 'running')
    t.repo = input.repoPath
    t.branch = 'agent/' + id
    t.lastLog = input.mode === 'run' ? 'danger run enabled' : 'plan mode'
    t.logs = t.logs + '\n[' + this.now() + '] ' + t.lastLog + '\n[' + this.now() + '] prompt=' + input.prompt
    this.tasks.unshift(t)
    return new UiResult<TaskCardState>(true, '提交成功', '', this.card(t))
  }

  openTask(taskId: string): UiResult<TaskDetailState> {
    let i = this.idx(taskId)
    if (i < 0) {
      return new UiResult<TaskDetailState>(false, '打开失败：任务不存在', 'task not found')
    }
    return new UiResult<TaskDetailState>(true, '', '', copyDetail(this.tasks[i]))
  }

  refreshTask(taskId: string): UiResult<TaskDetailState> {
    let i = this.idx(taskId)
    if (i < 0) {
      return new UiResult<TaskDetailState>(false, '刷新失败：任务不存在', 'task not found')
    }
    this.beat(this.tasks[i])
    return new UiResult<TaskDetailState>(true, '状态已刷新', '', copyDetail(this.tasks[i]))
  }

  refreshLogs(taskId: string): UiResult<LogPanelState> {
    let i = this.idx(taskId)
    if (i < 0) {
      return new UiResult<LogPanelState>(false, '日志刷新失败：任务不存在', 'task not found')
    }
    this.beat(this.tasks[i])
    return new UiResult<LogPanelState>(true, '', '', {
      text: this.tasks[i].logs,
      raw: this.tasks[i].rawLogs,
      stderr: this.tasks[i].stderr
    })
  }

  stopTask(taskId: string): UiResult<boolean> {
    let i = this.idx(taskId)
    if (i < 0) {
      return new UiResult<boolean>(false, '停止失败：任务不存在', 'task not found')
    }
    this.tasks[i].status = 'stopped'
    this.tasks[i].live = false
    this.tasks[i].updatedAt = this.now()
    this.tasks[i].lastLog = 'task stopped'
    this.tasks[i].logs = this.tasks[i].logs + '\n[' + this.now() + '] stopped'
    return new UiResult<boolean>(true, '任务已停止', '', true)
  }

  deleteTask(taskId: string): UiResult<boolean> {
    let i = this.idx(taskId)
    if (i < 0) {
      return new UiResult<boolean>(false, '删除失败：任务不存在', 'task not found')
    }
    this.tasks.splice(i, 1)
    return new UiResult<boolean>(true, '任务已删除', '', true)
  }

  loadGitSummary(taskId: string): UiResult<string> {
    let i = this.idx(taskId)
    if (i < 0) {
      return new UiResult<string>(false, 'Git 摘要加载失败：任务不存在', 'task not found')
    }
    return new UiResult<string>(
      true,
      '',
      '',
      '--- STATUS ---\nM src/main.ts\n?? notes.md\n\n--- DIFF STAT ---\n src/main.ts | 12 +++++++++---\n notes.md    |  3 +++\n 2 files changed, 12 insertions(+), 3 deletions(-)\n\n--- RECENT COMMITS ---\nabc1234 fix: refine task page\ndef5678 feat: add fake vm\n9876aaa chore: update docs\n1234bbb test: ui smoke\n8888ccc init'
    )
  }
}