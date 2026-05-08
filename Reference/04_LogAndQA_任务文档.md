# 任务文档 4：LogAndQA 日志解析与验收包

## 1. 背景

后续 Milestone 5 和 Milestone 6 需要 App 能展示 Claude Code stream-json 日志、任务状态、stderr、Git 摘要，并能在各种异常场景下给出清晰错误。

本任务负责日志解析、远端输出解析、错误分类、测试 fixtures 和验收用例。

本任务不负责 UI、不负责真实 SSH、不负责命令生成、不负责本地任务状态机。

---

## 2. 任务目标

实现一个独立的 `LogAndQA` 包，为其他模块提供：

1. Claude Code JSONL 日志解析。
2. raw text fallback。
3. task list TSV 解析。
4. 单任务 status key-value 解析。
5. stderr 到用户可读错误的映射。
6. 测试 fixtures。
7. Milestone 2–6 的验收 checklist。

---

## 3. 负责范围

### 3.1 日志模型

```text
LogEvent
  raw: String
  type: String?
  timestamp: Int64?
  text: String?
  level: String?
```

### 3.2 日志解析器

```text
LogParser
  parseJsonl(text: String): List<LogEvent>
  parseLine(line: String): LogEvent
  extractReadableText(json): String
```

### 3.3 任务列表解析器

```text
TaskListParser
  parseListTasksTsv(stdout: String): List<RemoteTaskRow>
```

TSV 每行格式：

```text
task_id    status    live    exit_code    repo    branch    worktree
```

### 3.4 单任务状态解析器

```text
TaskStatusParser
  parseStatusOutput(stdout: String): RemoteTaskStatus
```

输入格式：

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

### 3.5 错误分类器

```text
ErrorClassifier
  classify(stderr: String, exitCode: Int): AppError
  toUserMessage(error: AppError): String
```

---

## 4. 错误类型

必须支持：

```text
AppError
  SshConnectFailed
  SshAuthFailed
  SshExecFailed
  RemoteCommandFailed
  MissingDependency
  RepoInvalid
  WorktreeCreateFailed
  TmuxStartFailed
  LogReadFailed
  ParseFailed
  Unknown
```

建议用户可读文案：

```text
SSH 登录失败：请检查 IP、端口、用户名和密码。
远端缺少 tmux：请在服务器执行 sudo apt install tmux。
远端缺少 Claude Code：请先安装并登录 claude。
repo 不是 git 仓库：请检查 repo path。
worktree 创建失败：可能分支已存在或 repo 状态异常。
tmux 启动失败：请查看 stderr。
日志读取失败：请稍后重试或检查任务目录是否存在。
```

---

## 5. JSONL 解析策略

Claude Code 使用：

```text
--output-format stream-json --verbose
```

输出 JSONL。第一版不需要完整理解所有事件类型，只需要做到：

1. 每行尝试 JSON parse。
2. 如果能解析，提取可读文本。
3. 如果不能解析，按 raw text 显示。
4. 不因为某一行解析失败导致整个日志失败。
5. 保留 raw 字段，方便 UI 展开原始 JSON。

### 5.1 文本提取优先级

按以下字段尝试：

```text
message
content
text
delta
summary
```

如果字段是数组，尝试提取数组内的 text。

如果无法提取，返回 compact JSON。

### 5.2 level 推断

如果 JSON 中有：

```text
level
severity
type
```

可用于推断 LogEvent.level。

如果 raw 文本中包含：

```text
error
failed
exception
```

可以标记为 error。

---

## 6. TSV 解析策略

`parseListTasksTsv` 要求：

1. 空 stdout 返回空列表。
2. 空行跳过。
3. 字段不足时标记该行为 parse error，但不要影响其他行。
4. live 字段解析为 Bool。
5. exit_code 为空时保存为空。
6. status 不认识时保存为 unknown。
7. repo、branch、worktree 原样保留。

---

## 7. Status 输出解析策略

`parseStatusOutput` 要求：

1. 支持 key-value 每行一个字段。
2. 顺序不固定。
3. 缺失字段时使用默认值。
4. status 不认识时为 unknown。
5. live 缺失时为 false。
6. exit_code 为空时为 null。
7. repo/worktree/branch/tmux 原样保留。

---

## 8. 测试 Fixtures

需要创建以下 fixtures：

```text
fixtures/
  events.normal.jsonl
  events.raw-mixed.jsonl
  events.invalid-lines.jsonl
  events.chinese.jsonl
  events.error.jsonl

  list-tasks.empty.tsv
  list-tasks.normal.tsv
  list-tasks.malformed.tsv

  status.running.txt
  status.completed.txt
  status.failed.txt
  status.unknown.txt
  status.malformed.txt

  stderr.missing-tmux.log
  stderr.missing-claude.log
  stderr.repo-invalid.log
  stderr.worktree-failed.log
  stderr.tmux-failed.log

  git-summary.clean.txt
  git-summary.changed.txt
  git-summary.with-commits.txt
```

---

## 9. 验收测试范围

D 负责维护一份完整验收 checklist，覆盖 Milestone 2–6。

### 9.1 Milestone 2：远端环境初始化

验收项：

```text
1. App 显示 git 可用。
2. App 显示 tmux 可用。
3. App 显示 claude 可用。
4. App 显示 base64 可用。
5. 远端存在 ~/.cc-mobile/tasks。
6. 远端存在 ~/.cc-mobile/worktrees。
7. 缺少依赖时能显示明确错误。
```

### 9.2 Milestone 3：创建 worktree

验收项：

```text
1. 远端出现 ~/.cc-mobile/tasks/<task_id>。
2. 远端出现 ~/.cc-mobile/tasks/<task_id>/prompt.txt。
3. 远端出现 ~/.cc-mobile/tasks/<task_id>/meta.env。
4. 远端出现 ~/.cc-mobile/worktrees/<task_id>。
5. git branch 出现 agent/<task_id>。
6. status 文件最终为 worktree_created。
7. repo path 不存在时能提示错误。
8. repo 不是 git 仓库时能提示错误。
```

### 9.3 Milestone 4：tmux 启动 Claude Code

验收项：

```text
1. tmux ls 能看到 cc-<task_id>。
2. events.jsonl 持续增长。
3. stderr.log 能被读取。
4. App 断开后任务继续运行。
5. Claude 退出码写入 exit.code。
6. exit code 为 0 时 status 为 completed。
7. exit code 非 0 时 status 为 failed。
8. Danger Run 包含 --dangerously-skip-permissions。
9. Plan Mode 包含 --permission-mode plan。
```

### 9.4 Milestone 5：任务列表和日志

验收项：

```text
1. App 显示 running。
2. App 显示 completed。
3. App 显示 failed。
4. App 显示 stopped。
5. App 显示 unknown。
6. 进入详情页能看到 Claude Code 日志。
7. 非 JSON 日志行不会导致崩溃。
8. 日志支持复制。
9. stderr 支持展开。
10. running 任务详情页支持自动刷新。
```

### 9.5 Milestone 6：停止和 Git 摘要

验收项：

```text
1. 点击停止后 tmux session 消失。
2. status 文件变 stopped。
3. App 显示 stopped。
4. App 能显示 git status --short。
5. App 能显示 git diff --stat。
6. App 能显示 git log --oneline -5。
7. 停止任务需要二次确认。
8. 软删除后普通列表默认不显示该任务。
```

---

## 10. 边界测试

必须覆盖：

```text
1. prompt 包含中文。
2. prompt 包含英文引号。
3. prompt 包含单引号。
4. prompt 包含换行。
5. prompt 包含 shell 特殊字符。
6. repo path 不存在。
7. repo 不是 git 仓库。
8. branch 已存在。
9. tmux 不存在。
10. claude 不存在。
11. events.jsonl 不存在。
12. stderr.log 不存在。
13. status 文件不存在。
14. exit.code 不存在。
15. 同时启动 2 个任务。
16. 同时启动 5 个任务。
17. 日志不串。
18. tmux session 不重名。
```

---

## 11. 不负责内容

本任务不做：

1. UI 页面。
2. SSH 连接。
3. C wrapper。
4. Cangjie FFI。
5. bash 命令生成。
6. 本地 TaskStore。
7. TaskService。
8. 自动 merge。
9. 文件浏览器。
10. 终端模拟器。

---

## 12. 交付物

1. `LogParser`。
2. `TaskListParser`。
3. `TaskStatusParser`。
4. `ErrorClassifier`。
5. `AppError`。
6. `fixtures/` 测试数据。
7. 单元测试。
8. Milestone 2–6 验收 checklist。
9. 一份常见错误到用户提示文案的映射表。

---

## 13. 独立验收标准

不需要真实 SSH，不需要 UI，即可验收。

### 13.1 LogParser

必须通过：

1. 正常 JSONL 可解析。
2. 混合 raw text 和 JSON 的日志可解析。
3. 非法 JSON 行不会导致崩溃。
4. 中文日志可正常显示。
5. error 日志能标记为 error。
6. raw 字段完整保留。
7. text 字段能提取可读文本。

### 13.2 TaskListParser

必须通过：

1. 空 TSV 返回空列表。
2. 正常 TSV 返回任务列表。
3. malformed 行不会影响其他行。
4. live 字段能解析为 true/false。
5. status 字段能解析为 TaskStatus。
6. 未知 status 变 unknown。

### 13.3 TaskStatusParser

必须通过：

1. running status 可解析。
2. completed status 可解析。
3. failed status 可解析。
4. 缺失字段使用默认值。
5. 顺序变化不影响解析。
6. malformed 行不会导致崩溃。

### 13.4 ErrorClassifier

必须通过：

1. 缺少 tmux 能识别为 MissingDependency。
2. 缺少 claude 能识别为 MissingDependency。
3. repo invalid 能识别为 RepoInvalid。
4. worktree failed 能识别为 WorktreeCreateFailed。
5. tmux failed 能识别为 TmuxStartFailed。
6. 未知错误能映射到 Unknown。
7. 用户提示中不包含 password。

---

## 14. 与其他任务的接口

最终集成关系：

```text
TaskCore
  -> LogParser
  -> TaskListParser
  -> TaskStatusParser
  -> ErrorClassifier

AppUI
  -> 展示 LogEvent
  -> 展示用户可读错误
```

开发阶段 LogAndQA 完全独立，只依赖 fixtures 和单元测试。
