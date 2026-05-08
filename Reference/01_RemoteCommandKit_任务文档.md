# 任务文档 1：RemoteCommandKit 远端命令包

## 1. 背景

Milestone 1 已经完成，App 已经能够通过 SSH 执行远端命令，例如 `echo ok`。本任务从 Milestone 2 开始，负责把后续所有远端操作封装成稳定、可测试、可复用的 bash 命令生成器。

本任务负责“生成命令字符串”，需要调用相关的接口编写测试来进行进行真实 SSH 执行的测试、不负责 UI、不负责本地任务状态管理。

---

## 2. 任务目标

实现一个独立的远端命令生成模块 `RemoteCommandKit`，为后续远端初始化、任务创建、Claude Code 启动、日志读取、任务停止、Git 摘要等能力提供命令模板。

最终交付后，其他模块只需要调用 `CommandBuilder`，不应该自己拼接 shell 命令。

---

## 3. 负责范围

### 3.1 必须实现的类或模块

```text
CommandBuilder
RemoteScripts
ShellEscape
```

可以根据项目代码结构合并成一个文件，但对外应保持清晰接口。

### 3.2 必须实现的方法

```text
CommandBuilder
  buildInitCommand(): String
  buildCreateTaskCommand(input: TaskCommandInput): String
  buildStartTaskCommand(input: TaskCommandInput): String
  buildListTasksCommand(): String
  buildTaskStatusCommand(taskId: String): String
  buildTailLogCommand(taskId: String, lines: Int): String
  buildTailStderrCommand(taskId: String): String
  buildGitSummaryCommand(taskId: String): String
  buildStopTaskCommand(taskId: String): String
  buildSoftDeleteCommand(taskId: String): String
```

### 3.3 必须实现的工具函数

```text
shellSingleQuote(s: String): String
base64Encode(s: String): String
taskIdSafe(s: String): Bool
remotePathSafe(s: String): Bool
```

---

## 4. 对外输入结构

本任务定义或引用以下输入结构：

```text
TaskCommandInput
  taskId: String
  repoPath: String
  worktreePath: String
  branchName: String
  tmuxSession: String
  promptBase64: String
  mode: RunMode
```

```text
RunMode
  plan
  run
```

`run` 是默认模式，对应 Claude Code 的 danger run。
`plan`模式可暂不支持

---

## 5. 远端目录约定

所有命令都基于固定目录：

```text
~/.cc-mobile/
  config/
  tasks/
    <task_id>/
      meta.env
      prompt.txt
      events.jsonl
      stdout.log
      stderr.log
      exit.code
      status
  worktrees/
    <task_id>/
  tmp/
```

---

## 6. 命令实现要求

### 6.1 初始化命令

`buildInitCommand()` 需要生成命令完成以下动作：

1. 创建远端目录：
   - `~/.cc-mobile/config`
   - `~/.cc-mobile/tasks`
   - `~/.cc-mobile/worktrees`
   - `~/.cc-mobile/tmp`
2. 检查远端依赖：
   - `git`
   - `tmux`
   - `claude`
   - `base64`
   - `bash`
3. 成功时输出 `ok`。
4. 任一依赖缺失时返回非 0 exit code，并在 stderr 中体现错误。

### 6.2 创建任务命令

`buildCreateTaskCommand(input)` 需要完成：

1. 创建 `~/.cc-mobile/tasks/<task_id>`。
2. 将 `promptBase64` 解码写入 `prompt.txt`。
3. 写入 `meta.env`。
4. 写入 `remote_created` 状态。
5. 在 repo 下创建 git worktree：
   - worktree path：`~/.cc-mobile/worktrees/<task_id>`
   - branch：`agent/<task_id>`
6. 写入 `worktree_created` 状态。
7. 成功时输出 task id。

### 6.3 启动任务命令

`buildStartTaskCommand(input)` 建议使用“传输脚本后执行”的方式，而不是复杂嵌套引号。

命令需要完成：

1. 从 `meta.env` 读取任务信息。
2. 检查 tmux session 是否已经存在。
3. 如果已经存在，输出 `already_running` 并退出 0。
4. 创建 `runner.sh`。
5. 通过 tmux detached session 启动 Claude Code。
6. status 写入：
   - 启动后：`running`
   - 退出码为 0：`completed`
   - 退出码非 0：`failed`
7. 退出码写入 `exit.code`。
8. Claude stream-json 输出追加到 `events.jsonl`。
9. stderr 追加到 `stderr.log`。

Danger Run 模式必须包含：

```bash
--dangerously-skip-permissions
--output-format stream-json
--verbose
```

Plan 模式必须包含：

```bash
--permission-mode plan
--output-format stream-json
--verbose
```

### 6.4 查询任务列表命令

`buildListTasksCommand()` 输出 TSV，每行格式：

```text
task_id    status    live    exit_code    repo    branch    worktree
```

字段之间使用 tab 分隔。

### 6.5 查询单任务状态命令

`buildTaskStatusCommand(taskId)` 输出 key-value 格式：

```text
task_id=<task_id>
status=<status>
live=<true|false>
exit_code=<exit_code>
repo=<repo>
worktree=<worktree>
branch=<branch>
tmux=<tmux>
```

### 6.6 日志命令

`buildTailLogCommand(taskId, lines)` 默认读取 `events.jsonl` 最近 N 行。

`buildTailStderrCommand(taskId)` 默认读取 `stderr.log` 最近 100 行。

### 6.7 Git 摘要命令

`buildGitSummaryCommand(taskId)` 需要输出：

```text
--- STATUS ---
git status --short

--- DIFF STAT ---
git diff --stat

--- RECENT COMMITS ---
git log --oneline -5
```

### 6.8 停止任务命令

`buildStopTaskCommand(taskId)` 需要：

1. 如果 tmux session 存在，则 kill session。
2. 写入 `stopped` 到 status。
3. 输出 `stopped`。

### 6.9 软删除命令

`buildSoftDeleteCommand(taskId)` 只写入：

```text
deleted
```

到 status 文件。

第一版不做硬删除。

---

## 7. 安全与转义要求

1. 所有用户输入必须经过校验或转义。
2. prompt 不允许直接拼进 shell 字符串，必须通过 base64 传输。
3. task id 必须只允许：
   - `a-z`
   - `A-Z`
   - `0-9`
   - `_`
   - `-`
4. repo path 必须做基础校验。
5. 不允许把 password 拼入任何命令。
6. 不允许在命令中输出 password。
7. 不允许使用用户输入直接作为 branch name 或 tmux session name。
8. branch name 应由 task id 派生：`agent/<task_id>`。
9. tmux session 应由 task id 派生：`cc-<task_id>`。

---

## 8. 不负责内容

本任务不做：

1. UI 页面。
2. 本地 JSON 存储。
3. Task 状态机。
4. 日志 JSON 解析。
5. 错误弹窗。
6. 自动刷新。
7. 自动 merge。
8.  硬删除 worktree。

---

## 9. 交付物

1. `CommandBuilder` 实现。
2. `RemoteScripts` 或等价脚本模板。
3. `ShellEscape` 工具函数。
4. 单元测试，要连接实际的服务器然后运行相关的命令来测试保证命令能安全稳定的运行。
5. 一份命令样例输出文档，至少覆盖：
   - init
   - create task
   - start task
   - list tasks
   - tail log
   - stop task
   - git summary

---

## 10.0 独立验收标准

需要真实服务器的运行测试。

### 10.1 字符串测试

必须通过：

1. prompt 包含中文，生成命令不损坏。
2. prompt 包含英文双引号，生成命令不损坏。
3. prompt 包含英文单引号，生成命令不损坏。
4. prompt 包含多行文本，生成命令不损坏。
5. prompt 包含 shell 特殊字符，生成命令不损坏。
6. 非法 task id 被拒绝。
7. 空 repo path 被拒绝。
8. 明显危险 repo path 被拒绝。

### 10.2 命令内容测试

必须确认：

1. init command 包含 `git/tmux/claude/base64/bash` 检查。
2. create task command 会写 `prompt.txt`。
3. create task command 会写 `meta.env`。
4. create task command 会创建 git worktree。
5. start task command 包含 `tmux new-session -d`。
6. run mode 包含 `--dangerously-skip-permissions`。
7. plan mode 包含 `--permission-mode plan`。
8. start task command 会写 `events.jsonl`、`stderr.log`、`exit.code`、`status`。
9. stop command 会 kill tmux session 并写 `stopped`。
10. soft delete command 只写 `deleted`，不删除文件。

---

## 11. 与其他任务的接口

本任务最终由 TaskCore 调用：

```text
TaskService
  -> RemoteTaskGateway
    -> CommandBuilder
      -> SshClient.exec()
```

开发阶段不需要等待 TaskCore 完成。可以自己构造 `TaskCommandInput` 做测试。
