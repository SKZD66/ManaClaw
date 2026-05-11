export interface ConnectionState {
  name: string
  host: string
  port: string
  username: string
  password: string
  defaultRepoPath: string
}

export interface TaskCardState {
  title: string
  taskId: string
  status: string
  repo: string
  branch: string
  live: boolean
  createdAt: string
  updatedAt: string
  lastLog: string
}

export interface TaskDetailState extends TaskCardState {
  worktree: string
  tmuxSession: string
  exitCode: string
  logs: string
  rawLogs: string
  stderr: string
  gitSummary: string
}

export interface LogPanelState {
  text: string
  raw: string
  stderr: string
}

export interface NewTaskInput {
  repoPath: string
  title: string
  prompt: string
  mode: string
}

export class UiResult<T> {
  ok: boolean
  msg: string
  raw: string
  data?: T

  constructor(ok: boolean, msg: string, raw: string = '', data?: T) {
    this.ok = ok
    this.msg = msg
    this.raw = raw
    this.data = data
  }
}

export interface TaskViewModel {
  loadConnection(): ConnectionState
  saveConnection(input: ConnectionState): UiResult<boolean>
  testConnection(input: ConnectionState): UiResult<boolean>
  initRemote(): UiResult<boolean>

  loadTasks(): UiResult<TaskCardState[]>
  submitTask(input: NewTaskInput): UiResult<TaskCardState>
  openTask(taskId: string): UiResult<TaskDetailState>
  refreshTask(taskId: string): UiResult<TaskDetailState>
  refreshLogs(taskId: string): UiResult<LogPanelState>
  stopTask(taskId: string): UiResult<boolean>
  softDeleteTask(taskId: string): UiResult<boolean>
  loadGitSummary(taskId: string): UiResult<string>
}

export function statusColor(status: string): number {
  if (status === 'running') return 0x1F6FEB
  if (status === 'completed') return 0x2B8A3E
  if (status === 'failed') return 0xD94841
  if (status === 'unknown') return 0xE0A800
  return 0x6B7280
}

export function emptyDetail(): TaskDetailState {
  return {
    title: '',
    taskId: '',
    status: 'unknown',
    repo: '',
    branch: '',
    live: false,
    createdAt: '',
    updatedAt: '',
    lastLog: '',
    worktree: '',
    tmuxSession: '',
    exitCode: '',
    logs: '',
    rawLogs: '',
    stderr: '',
    gitSummary: ''
  }
}

export function copyDetail(d: TaskDetailState): TaskDetailState {
  return {
    title: d.title,
    taskId: d.taskId,
    status: d.status,
    repo: d.repo,
    branch: d.branch,
    live: d.live,
    createdAt: d.createdAt,
    updatedAt: d.updatedAt,
    lastLog: d.lastLog,
    worktree: d.worktree,
    tmuxSession: d.tmuxSession,
    exitCode: d.exitCode,
    logs: d.logs,
    rawLogs: d.rawLogs,
    stderr: d.stderr,
    gitSummary: d.gitSummary
  }
}

export function newTaskDraft(repoPath: string): NewTaskInput {
  return {
    repoPath: repoPath,
    title: '',
    prompt: '',
    mode: 'run'
  }
}