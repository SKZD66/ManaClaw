# 任务文档 2：TaskCore 任务核心包

## 1. 背景

Milestone 1 已经完成，SSH exec 能力已经可用。后续 App 需要管理远端 Claude Code 任务，包括创建任务、本地保存任务、刷新任务状态、停止任务、查看日志和 Git 摘要。

本任务负责业务核心，不负责 UI、不负责 bash 命令细节。

---

## 2. 任务目标

实现一个独立的 `TaskCore`，负责：

1. 任务模型。
2. 本地状态机。
3. 本地 JSON 存储。
4. prompt 包装。
5. task_id 生成。
6. 任务提交流程。
7. 任务刷新流程。
8. 停止、软删除、Git 摘要等业务动作。

开发阶段必须能使用 `FakeRemoteTaskGateway` 独立跑通，不等待 RemoteCommandKit 和 AppUI。

---

## 3. 负责范围

### 3.1 必须实现的数据模型

```text
Task
  id: String
  title: String
  prompt: String
  serverId: String
  repoPath: String
  branchName: String
  worktreePath: String
  tmuxSession: String
  remoteTaskDir: String
  status: TaskStatus
  mode: RunMode
  createdAt: Int64
  updatedAt: Int64
  lastLogOffset: Int64
  lastError: String?
```

```text
TaskStatus
  local_created
  remote_created
  worktree_created
  running
  completed
  failed
  stopped
  unknown
  deleted
```

```text
RunMode
  plan
  run
```

```text
ServerConfig
  id: String
  name: String
  host: String
  port: Int
  username: String
  passwordRef: String
  defaultRepoPath: String
  createdAt: Int64
  updatedAt: Int64
```

### 3.2 必须实现的存储模块

```text
TaskStore
  loadTasks(): List<Task>
  saveTasks(tasks: List<Task>): Unit
  upsertTask(task: Task): Unit
  findTask(taskId: String): Task?
  markDeleted(taskId: String): Unit
```

```text
ServerStore
  loadServers(): List<ServerConfig>
  saveServers(servers: List<ServerConfig>): Unit
  getDefaultServer(): ServerConfig?
  upsertServer(server: ServerConfig): Unit
```

第一版可以用 JSON 文件或系统偏好存储，不要求重型数据库。

### 3.3 必须实现的服务模块

```text
TaskService
  submitTask(server, repoPath, title, prompt, mode): Result<Task>
  refreshTasks(server): Result<List<Task>>
  refreshTask(taskId): Result<TaskDetail>
  stopTask(taskId): Result<Unit>
  softDeleteTask(taskId): Result<Unit>
  loadGitSummary(taskId): Result<String>
```

---

## 4. 对外依赖接口

TaskCore 不直接依赖真实 SSH，也不直接依赖 CommandBuilder。

它只依赖抽象接口：

```text
RemoteTaskGateway
  initRemote(server): Result<InitResult>
  createTask(task, wrappedPrompt): Result<Unit>
  startTask(task): Result<Unit>
  listTasks(server): Result<List<RemoteTaskRow>>
  getTaskStatus(taskId): Result<RemoteTaskStatus>
  tailLog(taskId, lines): Result<String>
  tailStderr(taskId): Result<String>
  stopTask(taskId): Result<Unit>
  softDeleteTask(taskId): Result<Unit>
  gitSummary(taskId): Result<String>
```

开发阶段必须提供：

```text
FakeRemoteTaskGateway
```

用于单元测试和 UI mock。

---

## 5. task_id 规则

TaskCore 负责生成 task id。

格式：

```text
ccm-YYYYMMDD-HHMMSS-<6位随机数>
```

示例：

```text
ccm-20260506-143522-482913
```

只允许：

```text
a-z A-Z 0-9 _ -
```

派生字段规则：

```text
branchName = "agent/" + taskId
tmuxSession = "cc-" + taskId
remoteTaskDir = "$HOME/.cc-mobile/tasks/" + taskId
worktreePath = "$HOME/.cc-mobile/worktrees/" + taskId
```

---

## 6. Prompt 包装要求

用户原始 prompt 不应该原样传给 Claude Code。TaskCore 需要包装成统一任务规范：

```text
你正在一个独立 git worktree 中工作。

任务：
<用户输入>

要求：
1. 先快速理解项目结构。
2. 尽量小步修改。
3. 修改后运行相关测试或构建命令。
4. 如果测试失败，继续修复。
5. 重要决策写入 PROGRESS.md。
6. 完成后创建一个 git commit，commit message 要清晰。
7. 不要修改与任务无关的文件。
8. 完成后退出。
```

如果用户选择 `plan` 模式，可以追加（可以先不支持plan模式）：

```text
本次任务只做计划，不直接修改代码。请输出实施步骤、风险点、建议拆分方式。
```

---

## 7. 核心流程

### 7.1 submitTask

```text
submitTask(server, repoPath, title, prompt, mode):
  1. 校验 repoPath/title/prompt。
  2. 生成 taskId。
  3. 派生 branchName/worktreePath/tmuxSession/remoteTaskDir。
  4. 创建本地 Task，状态为 local_created。
  5. 保存本地 Task。
  6. 包装 prompt。
  7. 调用 RemoteTaskGateway.createTask(task, wrappedPrompt)。
  8. 将状态更新为 worktree_created。
  9. 调用 RemoteTaskGateway.startTask(task)。
  10. 将状态更新为 running。
  11. 保存本地 Task。
  12. 返回 Task。
```

如果 create 阶段失败，状态保持可诊断，不要丢失本地 Task。

如果 start 阶段失败，记录 `lastError`。

### 7.2 refreshTasks

```text
refreshTasks(server):
  1. 调用 RemoteTaskGateway.listTasks(server)。
  2. 解析远端任务行。
  3. 和本地 tasks.json 合并。
  4. 远端状态优先于本地旧状态。
  5. 保存合并结果。
  6. 返回当前服务器下任务列表。
```

### 7.3 refreshTask

```text
refreshTask(taskId):
  1. 从本地读取 Task。
  2. 调用 RemoteTaskGateway.getTaskStatus(taskId)。
  3. 更新本地 Task 状态。
  4. 调用 tailLog(taskId, 200)。
  5. 调用 tailStderr(taskId)。
  6. 返回 TaskDetail。
```

### 7.4 stopTask

```text
stopTask(taskId):
  1. 调用 RemoteTaskGateway.stopTask(taskId)。
  2. 本地 Task 状态更新为 stopped。
  3. 保存 Task。
```

### 7.5 softDeleteTask

```text
softDeleteTask(taskId):
  1. 调用 RemoteTaskGateway.softDeleteTask(taskId)。
  2. 本地 Task 状态更新为 deleted。
  3. 保存 Task。
```

### 7.6 loadGitSummary

```text
loadGitSummary(taskId):
  1. 调用 RemoteTaskGateway.gitSummary(taskId)。
  2. 返回原始文本。
```

---

## 8. 状态合并规则

刷新任务时，状态优先级：

1. 远端能明确返回状态时，以远端为准。
2. 远端找不到任务，但本地存在，则标记为 `unknown`，不要直接删除。
3. 本地是 `deleted` 时，默认不在普通列表展示。
4. tmux live 为 true 时，即使 status 文件不是 running，也可以展示 live 标记。
5. exit_code 为 0 且 status 为空时，可推断为 `completed`。
6. exit_code 非 0 且 status 为空时，可推断为 `failed`。

---

## 9. 不负责内容

本任务不做：

1. bash 命令模板。
2. shell 转义。
3. 真实 SSH 底层实现。
4. UI 页面。
5. UI 自动刷新计时器。
6. 日志 JSONL 深度解析。
7. Git diff 高亮。
8. 自动 merge。
9. 文件浏览器。
10. 终端模拟器。

---

## 10. 交付物

1. `Task`、`TaskStatus`、`RunMode`、`ServerConfig` 模型。
2. `TaskStore`。
3. `ServerStore`。
4. `TaskService`。
5. `RemoteTaskGateway` 抽象接口。
6. `FakeRemoteTaskGateway`。
7. 单元测试。
8. 本地 JSON 文件样例：
   - `servers.json`
   - `tasks.json`

---

## 11. 独立验收标准

不需要真实 SSH，不需要 UI，即可验收。

### 11.1 submitTask 测试

必须通过：

1. submitTask 后生成合法 task id。
2. submitTask 后本地保存 Task。
3. branchName 正确等于 `agent/<task_id>`。
4. tmuxSession 正确等于 `cc-<task_id>`。
5. mode 默认是 `run`。
6. prompt 被正确包装。
7. createTask 失败时，本地保留任务并记录错误。
8. startTask 失败时，本地保留任务并记录错误。
9. 成功后状态变为 `running`。

### 11.2 refreshTasks 测试

必须通过：

1. 能合并远端 running 任务。
2. 能合并远端 completed 任务。
3. 能合并远端 failed 任务。
4. 本地存在但远端不存在时，状态变 unknown。
5. deleted 任务默认不出现在普通列表。
6. 刷新后写回 tasks.json。

### 11.3 stop / delete 测试

必须通过：

1. stopTask 调用 gateway。
2. stopTask 后本地状态变 stopped。
3. softDeleteTask 调用 gateway。
4. softDeleteTask 后本地状态变 deleted。

### 11.4 重启恢复测试

必须通过：

1. App 重启后能从 tasks.json 读回任务。
2. 任务 createdAt/updatedAt 不丢失。
3. lastError 不丢失。
4. serverId 不丢失。

---

## 12. 与其他任务的接口

最终集成关系：

```text
AppUI
  -> TaskService
    -> RemoteTaskGateway
      -> RemoteCommandKit
      -> SshClient.exec()
```

TaskCore 开发阶段只依赖 `FakeRemoteTaskGateway`，不需要等待 RemoteCommandKit 或 AppUI。
