# 任务文档 3：AppUI 界面包

## 1. 背景

Milestone 1 已经完成，SSH 测试连接页面已有基础能力。后续需要让用户能够初始化远端环境、创建 Claude Code 任务、查看任务列表、进入详情页看日志、停止任务、查看 Git 摘要。

本任务只负责 UI、交互和展示，不负责真实 SSH、不负责 bash 命令生成、不负责本地任务状态机。

---

## 2. 任务目标

实现第一版 App 的主要页面和交互闭环。

第一版页面尽量压缩成 3 个主页面：

```text
ConnectionPage
TaskListPage
TaskDetailPage
```

新建任务可以作为独立页面，也可以作为 TaskListPage 的弹窗或子页面。

---

## 3. 负责范围

### 3.1 页面

```text
ConnectionPage
TaskListPage
TaskDetailPage
NewTaskView 或 NewTaskPage
```

### 3.2 UI 状态展示

需要展示：

```text
running
completed
failed
stopped
unknown
deleted
```

状态颜色建议：

```text
running: 蓝色
completed: 绿色
failed: 红色
stopped: 灰色
unknown: 黄色
deleted: 灰色
```

### 3.3 交互

必须支持：

1. 测试连接。
2. 初始化远端环境。
3. 新建任务。
4. 查看任务列表。
5. 刷新任务列表。
6. 打开任务详情。
7. 刷新任务状态。
8. 刷新日志。
9. 查看 stderr。
10. 查看 Git 摘要。
11. 停止任务。
12. 软删除任务。
13. Danger Run 风险提示。

---

## 4. 对外依赖接口

AppUI 不直接依赖真实 TaskService。开发阶段使用以下抽象接口：

```text
TaskViewModel
  loadConnection(): ConnectionState
  saveConnection(input): UiResult
  testConnection(input): UiResult
  initRemote(): UiResult

  loadTasks(): UiResult<List<TaskCardState>>
  submitTask(input): UiResult<TaskCardState>
  openTask(taskId): UiResult<TaskDetailState>
  refreshTask(taskId): UiResult<TaskDetailState>
  refreshLogs(taskId): UiResult<LogPanelState>
  stopTask(taskId): UiResult
  softDeleteTask(taskId): UiResult
  loadGitSummary(taskId): UiResult<String>
```

开发阶段必须提供：

```text
FakeTaskViewModel
```

Fake 数据至少包含：

```text
running task
completed task
failed task
stopped task
unknown task
```

---

## 5. 页面详细要求

## 5.1 ConnectionPage

### 字段

```text
Name
Host/IP
Port
Username
Password
Default Repo Path
```

### 按钮

```text
保存
测试连接
初始化远端环境
进入任务列表
```

### 展示

测试连接结果：

```text
连接成功：ok
连接失败：错误摘要
```

初始化远端环境结果：

```text
git: ok / missing
tmux: ok / missing
claude: ok / missing
base64: ok / missing
~/.cc-mobile: created / failed
```

### 要求

1. Password 默认隐藏。
2. 错误信息中不能展示 password。
3. 初始化按钮必须在服务器配置完整后才能点击。
4. 初始化失败时显示可复制的原始 stderr。

---

## 5.2 TaskListPage

### 顶部区域

显示：

```text
当前服务器名称
默认 repo path
运行中任务数量
刷新按钮
新建任务按钮
```

### 任务卡片

每张任务卡片显示：

```text
标题
task_id
状态 badge
repo
branch
live
创建时间
最后更新时间
最后一行日志摘要，可选
```

### 卡片快捷操作

```text
打开详情
停止任务
软删除
```

### 列表行为

1. 支持下拉刷新。
2. 默认不自动刷新。
3. 可以提供“每 10 秒刷新运行中任务”的开关，但第一版不是必须。
4. deleted 任务默认隐藏。
5. failed 任务应该明显标红。

---

## 5.3 NewTaskView / NewTaskPage

### 字段

```text
Repo Path
Task Title
Prompt
Mode: Danger Run / Plan
```

### 默认值

```text
Repo Path = defaultRepoPath
Mode = Danger Run
```

### 按钮

```text
Submit
Submit & Open Logs
Cancel
```

### Danger Run 提示

当 Mode 是 Danger Run 时，必须显示：

```text
危险模式已开启：Claude Code 将使用 --dangerously-skip-permissions 在远端执行任务。请确保使用低权限用户和安全的开发环境。
```

### 表单校验

1. repo path 不能为空。
2. title 不能为空。
3. prompt 不能为空。
4. prompt 太短时给出提示，但不强制禁止。
5. 提交中显示 loading 状态，防止重复提交。

---

## 5.4 TaskDetailPage

### 顶部状态区

显示：

```text
title
task_id
status
live
repo
branch
worktree
tmux session
createdAt
updatedAt
exitCode
```

### 操作按钮

```text
刷新状态
刷新日志
查看 Git 改动
停止任务
软删除
```

可选：

```text
重试任务
复制 task_id
复制 worktree path
```

### 日志区

显示：

```text
events.jsonl 最近 200 行解析后的文本
```

要求：

1. 默认简洁文本视图。
2. 支持展开 raw JSON。
3. 支持复制日志。
4. running 状态下每 3 秒刷新。
5. completed/failed/stopped 后停止自动刷新。
6. App 切后台后停止刷新。
7. App 回前台后刷新一次。

### stderr 区

显示：

```text
stderr.log 最近 100 行
```

要求：

1. stderr 为空时显示“暂无错误输出”。
2. stderr 非空时可以折叠/展开。
3. failed 状态时默认展开。

### Git 摘要区

显示：

```text
--- STATUS ---
git status --short

--- DIFF STAT ---
git diff --stat

--- RECENT COMMITS ---
git log --oneline -5
```

要求：

1. 用户点击“查看 Git 改动”后再加载。
2. 加载中显示 loading。
3. 失败时显示错误和复制按钮。

---

## 6. 错误展示要求

所有错误使用两层展示：

```text
第一行：用户可读错误
展开：原始 stderr / debug 信息
```

示例：

```text
远端缺少 tmux：请在服务器执行 sudo apt install tmux。
```

```text
repo 不是 git 仓库：请检查 repo path。
```

```text
worktree 创建失败：可能分支已存在或 repo 状态异常。
```

---

## 7. 不负责内容

本任务不做：

1. SSH C wrapper。
2. Cangjie FFI。
3. bash 命令模板。
4. shell 转义。
5. task_id 生成细节。
6. 本地 JSON 存储细节。
7. JSONL 日志解析细节。
8. TSV 解析。
9. 自动 merge。
10. 文件浏览器。
11. 终端模拟器。

---

## 8. 交付物

1. `ConnectionPage`。
2. `TaskListPage`。
3. `TaskDetailPage`。
4. `NewTaskView` 或 `NewTaskPage`。
5. `TaskViewModel` 抽象接口。
6. `FakeTaskViewModel`。
7. Mock 数据。
8. 页面状态截图或录屏。
9. 基础 UI 测试。

---

## 9. 独立验收标准

不需要真实 SSH，不需要 TaskCore，即可验收。

### 9.1 ConnectionPage

必须通过：

1. 能输入 host、port、username、password、repo path。
2. password 默认隐藏。
3. 点击测试连接后能显示成功 mock。
4. 点击测试连接后能显示失败 mock。
5. 点击初始化后能显示依赖检查结果。
6. 初始化失败时能显示错误详情。

### 9.2 TaskListPage

必须通过：

1. 能显示 running 任务。
2. 能显示 completed 任务。
3. 能显示 failed 任务。
4. 能显示 stopped 任务。
5. 能显示 unknown 任务。
6. 状态 badge 颜色正确。
7. 点击任务能进入详情页。
8. 点击新建任务能打开表单。
9. 点击停止任务有二次确认。

### 9.3 NewTaskView

必须通过：

1. 默认 Mode 为 Danger Run。
2. Danger Run 提示可见。
3. repo path 为空时无法提交。
4. title 为空时无法提交。
5. prompt 为空时无法提交。
6. Submit 后显示 loading。
7. Submit & Open Logs 后跳转详情页。

### 9.4 TaskDetailPage

必须通过：

1. 能显示状态区。
2. 能显示日志区。
3. 能显示 stderr 区。
4. failed 状态时 stderr 默认展开。
5. 点击查看 Git 改动能展示 mock git summary。
6. running 状态下能模拟自动刷新。
7. completed/failed/stopped 后停止自动刷新。
8. 停止任务有二次确认。
9. 软删除任务有二次确认。

---

## 10. 与其他任务的接口

最终集成关系：

```text
AppUI
  -> TaskService
```

开发阶段：

```text
AppUI
  -> FakeTaskViewModel
```

因此 AppUI 可以完全独立开发，不需要等待 RemoteCommandKit、TaskCore、LogAndQA 完成。
