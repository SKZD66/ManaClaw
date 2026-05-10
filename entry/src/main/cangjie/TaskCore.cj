package ohos_app_cangjie_entry

import std.collection.*
import std.convert.*
import std.fs.*
import std.random.*
import std.time.*

public enum TaskStatus {
    | LocalCreated
    | RemoteCreated
    | WorktreeCreated
    | Running
    | Completed
    | Failed
    | Stopped
    | Unknown
    | Deleted
}

public class Result<T> {
    public let isOk: Bool
    public let value: ?T
    public let error: ?String

    public init(isOk: Bool, value: ?T, error: ?String) {
        this.isOk = isOk
        this.value = value
        this.error = error
    }
}

public func ok<T>(value: T): Result<T> {
    return Result<T>(true, Some(value), None)
}

public func fail<T>(error: String): Result<T> {
    return Result<T>(false, None, Some(error))
}

public class Task {
    public var id: String
    public var title: String
    public var prompt: String
    public var serverId: String
    public var repoPath: String
    public var branchName: String
    public var worktreePath: String
    public var tmuxSession: String
    public var remoteTaskDir: String
    public var status: TaskStatus
    public var mode: RunMode
    public var createdAt: Int64
    public var updatedAt: Int64
    public var lastLogOffset: Int64
    public var lastError: ?String

    public init(
        id: String,
        title: String,
        prompt: String,
        serverId: String,
        repoPath: String,
        branchName: String,
        worktreePath: String,
        tmuxSession: String,
        remoteTaskDir: String,
        status: TaskStatus,
        mode: RunMode,
        createdAt: Int64,
        updatedAt: Int64,
        lastLogOffset: Int64,
        lastError: ?String
    ) {
        this.id = id
        this.title = title
        this.prompt = prompt
        this.serverId = serverId
        this.repoPath = repoPath
        this.branchName = branchName
        this.worktreePath = worktreePath
        this.tmuxSession = tmuxSession
        this.remoteTaskDir = remoteTaskDir
        this.status = status
        this.mode = mode
        this.createdAt = createdAt
        this.updatedAt = updatedAt
        this.lastLogOffset = lastLogOffset
        this.lastError = lastError
    }
}

public class ServerConfig {
    public var id: String
    public var name: String
    public var host: String
    public var port: Int64
    public var username: String
    public var passwordRef: String
    public var defaultRepoPath: String
    public var createdAt: Int64
    public var updatedAt: Int64

    public init(
        id: String,
        name: String,
        host: String,
        port: Int64,
        username: String,
        passwordRef: String,
        defaultRepoPath: String,
        createdAt: Int64,
        updatedAt: Int64
    ) {
        this.id = id
        this.name = name
        this.host = host
        this.port = port
        this.username = username
        this.passwordRef = passwordRef
        this.defaultRepoPath = defaultRepoPath
        this.createdAt = createdAt
        this.updatedAt = updatedAt
    }
}

public class InitResult {
    public let message: String

    public init(message: String) {
        this.message = message
    }
}

public class RemoteTaskRow {
    public let taskId: String
    public let status: TaskStatus
    public let live: Bool
    public let exitCode: ?Int64
    public let repo: String
    public let branch: String
    public let worktree: String

    public init(
        taskId: String,
        status: TaskStatus,
        live: Bool,
        exitCode: ?Int64,
        repo: String,
        branch: String,
        worktree: String
    ) {
        this.taskId = taskId
        this.status = status
        this.live = live
        this.exitCode = exitCode
        this.repo = repo
        this.branch = branch
        this.worktree = worktree
    }
}

public class RemoteTaskStatus {
    public let taskId: String
    public let status: TaskStatus
    public let live: Bool
    public let exitCode: ?Int64
    public let repo: String
    public let worktree: String
    public let branch: String
    public let tmux: String

    public init(
        taskId: String,
        status: TaskStatus,
        live: Bool,
        exitCode: ?Int64,
        repo: String,
        worktree: String,
        branch: String,
        tmux: String
    ) {
        this.taskId = taskId
        this.status = status
        this.live = live
        this.exitCode = exitCode
        this.repo = repo
        this.worktree = worktree
        this.branch = branch
        this.tmux = tmux
    }
}

public class TaskDetail {
    public let task: Task
    public let log: String
    public let stderr: String
    public let live: Bool
    public let exitCode: ?Int64

    public init(task: Task, log: String, stderr: String, live: Bool, exitCode: ?Int64) {
        this.task = task
        this.log = log
        this.stderr = stderr
        this.live = live
        this.exitCode = exitCode
    }
}

public interface RemoteTaskGateway {
    func initRemote(server: ServerConfig): Result<InitResult>
    func createTask(task: Task, wrappedPrompt: String): Result<Unit>
    func startTask(task: Task): Result<Unit>
    func listTasks(server: ServerConfig): Result<ArrayList<RemoteTaskRow>>
    func getTaskStatus(taskId: String): Result<RemoteTaskStatus>
    func tailLog(taskId: String, lines: Int64): Result<String>
    func tailStderr(taskId: String): Result<String>
    func stopTask(taskId: String): Result<Unit>
    func softDeleteTask(taskId: String): Result<Unit>
    func gitSummary(taskId: String): Result<String>
}

public class TaskStore {
    private let storageDir: Path
    private let tasksFile: Path

    public init() {
        let base = Path(".cc-mobile-local")
        storageDir = base
        tasksFile = base.join("tasks.json")
        ensureDir(storageDir)
    }

    public init(storageDir: String) {
        let base = Path(storageDir)
        this.storageDir = base
        tasksFile = base.join("tasks.json")
        ensureDir(base)
    }

//    public func loadTasks(): ArrayList<Task> {
//        if (!File.exists(tasksFile)) {
//            return ArrayList<Task>()
//        }
//        let text = String.fromUtf8(File.readFrom(tasksFile))
//        return TaskJson.decodeTasks(text)
//    }
    public func loadTasks(): ArrayList<Task> {
    try {
        let text = String.fromUtf8(File.readFrom(tasksFile))
        return TaskJson.decodeTasks(text)
    } catch (e: FSException) {
        return ArrayList<Task>()
    }
}

    public func saveTasks(tasks: ArrayList<Task>): Unit {
        ensureDir(storageDir)
        File.writeTo(tasksFile, TaskJson.encodeTasks(tasks).toArray())
    }

    public func upsertTask(task: Task): Unit {
        let tasks = loadTasks()
        var updated = false
        for (i in 0..tasks.size) {
            if (tasks[i].id == task.id) {
                tasks[i] = task
                updated = true
                break
            }
        }
        if (!updated) {
            tasks.append(task)
        }
        saveTasks(tasks)
    }

    public func findTask(taskId: String): ?Task {
        for (task in loadTasks()) {
            if (task.id == taskId) {
                return Some(task)
            }
        }
        return None
    }

    public func markDeleted(taskId: String): Unit {
        if (let Some(task) <- findTask(taskId)) {
            task.status = TaskStatus.Deleted
            task.updatedAt = nowSeconds()
            upsertTask(task)
        }
    }
}

public class ServerStore {
    private let storageDir: Path
    private let serversFile: Path

    public init() {
        let base = Path(".cc-mobile-local")
        storageDir = base
        serversFile = base.join("servers.json")
        ensureDir(storageDir)
    }

    public init(storageDir: String) {
        let base = Path(storageDir)
        this.storageDir = base
        serversFile = base.join("servers.json")
        ensureDir(base)
    }

//    public func loadServers(): ArrayList<ServerConfig> {
//        if (!File.exists(serversFile)) {
//            return ArrayList<ServerConfig>()
//        }
//        let text = String.fromUtf8(File.readFrom(serversFile))
//        return TaskJson.decodeServers(text)
//    }
    public func loadServers(): ArrayList<ServerConfig> {
    try {
        let text = String.fromUtf8(File.readFrom(serversFile))
        return TaskJson.decodeServers(text)
    } catch (e: FSException) {
        return ArrayList<ServerConfig>()
    }
}

    public func saveServers(servers: ArrayList<ServerConfig>): Unit {
        ensureDir(storageDir)
        File.writeTo(serversFile, TaskJson.encodeServers(servers).toArray())
    }

    public func getDefaultServer(): ?ServerConfig {
        let servers = loadServers()
        if (servers.size == 0) {
            return None
        }
        return Some(servers[0])
    }

    public func upsertServer(server: ServerConfig): Unit {
        let servers = loadServers()
        var updated = false
        for (i in 0..servers.size) {
            if (servers[i].id == server.id) {
                servers[i] = server
                updated = true
                break
            }
        }
        if (!updated) {
            servers.append(server)
        }
        saveServers(servers)
    }
}

public class TaskService {
    private let taskStore: TaskStore
    private let gateway: RemoteTaskGateway

    public init(taskStore: TaskStore, gateway: RemoteTaskGateway) {
        this.taskStore = taskStore
        this.gateway = gateway
    }

    public func submitTask(
        server: ServerConfig,
        repoPath: String,
        title: String,
        prompt: String,
        mode: RunMode
    ): Result<Task> {
        let validationError = validateSubmit(repoPath, title, prompt)
        if (validationError.size > 0) {
            return fail<Task>(validationError)
        }

        let now = nowSeconds()
        let taskId = generateTaskId()
        let task = Task(
            taskId,
            title.trimAscii(),
            prompt,
            server.id,
            repoPath.trimAscii(),
            deriveBranchName(taskId),
            deriveWorktreePath(taskId),
            deriveTmuxSession(taskId),
            deriveRemoteTaskDir(taskId),
            TaskStatus.LocalCreated,
            mode,
            now,
            now,
            0,
            None
        )
        taskStore.upsertTask(task)

        let wrappedPrompt = wrapPrompt(prompt, mode)
        let created = gateway.createTask(task, wrappedPrompt)
        if (!created.isOk) {
            task.lastError = resultError(created)
            task.updatedAt = nowSeconds()
            taskStore.upsertTask(task)
            return fail<Task>(resultErrorText(created))
        }

        task.status = TaskStatus.WorktreeCreated
        task.updatedAt = nowSeconds()
        taskStore.upsertTask(task)

        let started = gateway.startTask(task)
        if (!started.isOk) {
            task.lastError = resultError(started)
            task.updatedAt = nowSeconds()
            taskStore.upsertTask(task)
            return fail<Task>(resultErrorText(started))
        }

        task.status = TaskStatus.Running
        task.updatedAt = nowSeconds()
        taskStore.upsertTask(task)
        return ok<Task>(task)
    }

    public func submitTask(server: ServerConfig, repoPath: String, title: String, prompt: String): Result<Task> {
        return submitTask(server, repoPath, title, prompt, RunMode.run)
    }

    public func refreshTasks(server: ServerConfig): Result<ArrayList<Task>> {
        let remoteResult = gateway.listTasks(server)
        if (!remoteResult.isOk) {
            return fail<ArrayList<Task>>(resultErrorText(remoteResult))
        }

        let tasks = taskStore.loadTasks()
        let remoteRows = remoteResult.value.getOrThrow()
        let seen = HashMap<String, Bool>()
        for (row in remoteRows) {
            seen[row.taskId] = true
            if (let Some(local) <- findIn(tasks, row.taskId)) {
                if (isDeleted(local.status)) {
                    continue
                }
                local.status = inferStatus(row.status, row.exitCode)
                local.repoPath = row.repo
                local.branchName = row.branch
                local.worktreePath = row.worktree
                local.updatedAt = nowSeconds()
            } else {
                let now = nowSeconds()
                tasks.append(Task(
                    row.taskId,
                    row.taskId,
                    "",
                    server.id,
                    row.repo,
                    row.branch,
                    row.worktree,
                    deriveTmuxSession(row.taskId),
                    deriveRemoteTaskDir(row.taskId),
                    inferStatus(row.status, row.exitCode),
                    RunMode.run,
                    now,
                    now,
                    0,
                    None
                ))
            }
        }

        for (task in tasks) {
            if (task.serverId == server.id && !seen.contains(task.id) && !isDeleted(task.status)) {
                task.status = TaskStatus.Unknown
                task.updatedAt = nowSeconds()
            }
        }

        taskStore.saveTasks(tasks)
        return ok<ArrayList<Task>>(visibleTasksForServer(tasks, server.id))
    }

    public func refreshTask(taskId: String): Result<TaskDetail> {
        let local = taskStore.findTask(taskId)
        if (let None <- local) {
            return fail<TaskDetail>("Task not found: ${taskId}")
        }

        let task = local.getOrThrow()
        let statusResult = gateway.getTaskStatus(taskId)
        if (!statusResult.isOk) {
            task.lastError = resultError(statusResult)
            task.updatedAt = nowSeconds()
            taskStore.upsertTask(task)
            return fail<TaskDetail>(resultErrorText(statusResult))
        }

        let remote = statusResult.value.getOrThrow()
        task.status = inferStatus(remote.status, remote.exitCode)
        task.repoPath = remote.repo
        task.worktreePath = remote.worktree
        task.branchName = remote.branch
        task.tmuxSession = remote.tmux
        task.updatedAt = nowSeconds()
        taskStore.upsertTask(task)

        let log = gateway.tailLog(taskId, 200)
        let stderr = gateway.tailStderr(taskId)
        return ok<TaskDetail>(TaskDetail(
            task,
            resultValueOr(log, ""),
            resultValueOr(stderr, ""),
            remote.live,
            remote.exitCode
        ))
    }

    public func stopTask(taskId: String): Result<Unit> {
        let stopped = gateway.stopTask(taskId)
        if (!stopped.isOk) {
            return fail<Unit>(resultErrorText(stopped))
        }
        if (let Some(task) <- taskStore.findTask(taskId)) {
            task.status = TaskStatus.Stopped
            task.updatedAt = nowSeconds()
            taskStore.upsertTask(task)
        }
        return ok<Unit>(())
    }

    public func softDeleteTask(taskId: String): Result<Unit> {
        let deleted = gateway.softDeleteTask(taskId)
        if (!deleted.isOk) {
            return fail<Unit>(resultErrorText(deleted))
        }
        taskStore.markDeleted(taskId)
        return ok<Unit>(())
    }

    public func loadGitSummary(taskId: String): Result<String> {
        return gateway.gitSummary(taskId)
    }
}

public class FakeRemoteTaskGateway <: RemoteTaskGateway {
    public var failCreate: Bool = false
    public var failStart: Bool = false
    public let createdPrompts: HashMap<String, String> = HashMap<String, String>()
    private let rows: HashMap<String, RemoteTaskStatus> = HashMap<String, RemoteTaskStatus>()

    public init() {}

    public func initRemote(server: ServerConfig): Result<InitResult> {
        let _ = server
        return ok<InitResult>(InitResult("ok"))
    }

    public func createTask(task: Task, wrappedPrompt: String): Result<Unit> {
        if (failCreate) {
            return fail<Unit>("fake createTask failed")
        }
        createdPrompts[task.id] = wrappedPrompt
        rows[task.id] = RemoteTaskStatus(
            task.id,
            TaskStatus.WorktreeCreated,
            false,
            None,
            task.repoPath,
            task.worktreePath,
            task.branchName,
            task.tmuxSession
        )
        return ok<Unit>(())
    }

    public func startTask(task: Task): Result<Unit> {
        if (failStart) {
            return fail<Unit>("fake startTask failed")
        }
        rows[task.id] = RemoteTaskStatus(
            task.id,
            TaskStatus.Running,
            true,
            None,
            task.repoPath,
            task.worktreePath,
            task.branchName,
            task.tmuxSession
        )
        return ok<Unit>(())
    }

    public func listTasks(server: ServerConfig): Result<ArrayList<RemoteTaskRow>> {
        let _ = server
        let list = ArrayList<RemoteTaskRow>()
        for ((_, status) in rows) {
            list.append(RemoteTaskRow(
                status.taskId,
                status.status,
                status.live,
                status.exitCode,
                status.repo,
                status.branch,
                status.worktree
            ))
        }
        return ok<ArrayList<RemoteTaskRow>>(list)
    }

    public func getTaskStatus(taskId: String): Result<RemoteTaskStatus> {
        if (let Some(status) <- rows.get(taskId)) {
            return ok<RemoteTaskStatus>(status)
        }
        return fail<RemoteTaskStatus>("fake task not found: ${taskId}")
    }

    public func tailLog(taskId: String, lines: Int64): Result<String> {
        let _ = lines
        return ok<String>("fake log for ${taskId}")
    }

    public func tailStderr(taskId: String): Result<String> {
        let _ = taskId
        return ok<String>("")
    }

    public func stopTask(taskId: String): Result<Unit> {
        if (let Some(status) <- rows.get(taskId)) {
            rows[taskId] = RemoteTaskStatus(
                status.taskId,
                TaskStatus.Stopped,
                false,
                status.exitCode,
                status.repo,
                status.worktree,
                status.branch,
                status.tmux
            )
        }
        return ok<Unit>(())
    }

    public func softDeleteTask(taskId: String): Result<Unit> {
        if (let Some(status) <- rows.get(taskId)) {
            rows[taskId] = RemoteTaskStatus(
                status.taskId,
                TaskStatus.Deleted,
                false,
                status.exitCode,
                status.repo,
                status.worktree,
                status.branch,
                status.tmux
            )
        }
        return ok<Unit>(())
    }

    public func gitSummary(taskId: String): Result<String> {
        let _ = taskId
        return ok<String>("--- STATUS ---\n M fake.cj\n\n--- DIFF STAT ---\nfake.cj | 1 +\n\n--- RECENT COMMITS ---\nabc123 fake")
    }

    public func setRemoteStatus(status: RemoteTaskStatus): Unit {
        rows[status.taskId] = status
    }
}

public func wrapPrompt(prompt: String, mode: RunMode): String {
    var sb = StringBuilder()
    sb.append("你正在一个独立 git worktree 中工作。\n\n")
    sb.append("任务：\n")
    sb.append(prompt)
    sb.append("\n\n要求：\n")
    sb.append("1. 先快速理解项目结构。\n")
    sb.append("2. 尽量小步修改。\n")
    sb.append("3. 修改后运行相关测试或构建命令。\n")
    sb.append("4. 如果测试失败，继续修复。\n")
    sb.append("5. 重要决策写入 PROGRESS.md。\n")
    sb.append("6. 完成后创建一个 git commit，commit message 要清晰。\n")
    sb.append("7. 不要修改与任务无关的文件。\n")
    sb.append("8. 完成后退出。\n")
    if (isPlan(mode)) {
        sb.append("\n本次任务只做计划，不直接修改代码。请输出实施步骤、风险点、建议拆分方式。\n")
    }
    return sb.toString()
}

public func generateTaskId(): String {
    let timestamp = formatTaskTimestamp(DateTime.now())
    let random = leftPad(Random().nextInt64(1000000).toString(), 6, "0")
    return "ccm-${timestamp}-${random}"
}

public func deriveBranchName(taskId: String): String {
    return "agent/${taskId}"
}

public func deriveTmuxSession(taskId: String): String {
    return "cc-${taskId}"
}

public func deriveRemoteTaskDir(taskId: String): String {
    return "$HOME/.cc-mobile/tasks/${taskId}"
}

public func deriveWorktreePath(taskId: String): String {
    return "$HOME/.cc-mobile/worktrees/${taskId}"
}

public func isValidTaskId(taskId: String): Bool {
    if (taskId.size == 0) {
        return false
    }
    for (r in taskId.runes()) {
        if (!((r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z') || (r >= r'0' && r <= r'9') || r == r'_' || r == r'-')) {
            return false
        }
    }
    return true
}

private func validateSubmit(repoPath: String, title: String, prompt: String): String {
    if (repoPath.trimAscii().size == 0) {
        return "repoPath cannot be empty"
    }
    if (title.trimAscii().size == 0) {
        return "title cannot be empty"
    }
    if (prompt.trimAscii().size == 0) {
        return "prompt cannot be empty"
    }
    return ""
}

private func nowSeconds(): Int64 {
    return DateTime.now().toUnixTimeStamp().toSeconds()
}

//private func ensureDir(path: Path): Unit {
//    if (!File.exists(path)) {
//        Directory.create(path, recursive: true)
//    }
//}

private func ensureDir(path: Path): Unit {
    try {
        Directory.create(path, recursive: true)
    } catch (e: FSException) {
        // 目录已存在则忽略
    }
}

private func leftPad(value: String, width: Int64, pad: String): String {
    var out = value
    while (out.size < width) {
        out = pad + out
    }
    return out
}

private func isPlan(mode: RunMode): Bool {
    match (mode) {
        case RunMode.plan => true
        case RunMode.run => false
    }
}

private func isDeleted(status: TaskStatus): Bool {
    match (status) {
        case TaskStatus.Deleted => true
        case _ => false
    }
}

private func inferStatus(status: TaskStatus, exitCode: ?Int64): TaskStatus {
    match (status) {
        case TaskStatus.Unknown =>
            match (exitCode) {
                case Some(code) => if (code == 0) { TaskStatus.Completed } else { TaskStatus.Failed }
                case None => TaskStatus.Unknown
            }
        case _ => status
    }
}

private func findIn(tasks: ArrayList<Task>, taskId: String): ?Task {
    for (task in tasks) {
        if (task.id == taskId) {
            return Some(task)
        }
    }
    return None
}

private func visibleTasksForServer(tasks: ArrayList<Task>, serverId: String): ArrayList<Task> {
    let visible = ArrayList<Task>()
    for (task in tasks) {
        if (task.serverId == serverId && !isDeleted(task.status)) {
            visible.append(task)
        }
    }
    return visible
}

private func resultError<T>(result: Result<T>): ?String {
    return result.error
}

private func resultErrorText<T>(result: Result<T>): String {
    match (result.error) {
        case Some(e) => e
        case None => "unknown error"
    }
}

private func resultValueOr(result: Result<String>, fallback: String): String {
    match (result.value) {
        case Some(v) => v
        case None => fallback
    }
}

private func taskStatusToString(status: TaskStatus): String {
    match (status) {
        case TaskStatus.LocalCreated => "local_created"
        case TaskStatus.RemoteCreated => "remote_created"
        case TaskStatus.WorktreeCreated => "worktree_created"
        case TaskStatus.Running => "running"
        case TaskStatus.Completed => "completed"
        case TaskStatus.Failed => "failed"
        case TaskStatus.Stopped => "stopped"
        case TaskStatus.Unknown => "unknown"
        case TaskStatus.Deleted => "deleted"
    }
}

private func taskStatusFromString(value: String): TaskStatus {
    match (value) {
        case "local_created" => TaskStatus.LocalCreated
        case "remote_created" => TaskStatus.RemoteCreated
        case "worktree_created" => TaskStatus.WorktreeCreated
        case "running" => TaskStatus.Running
        case "completed" => TaskStatus.Completed
        case "failed" => TaskStatus.Failed
        case "stopped" => TaskStatus.Stopped
        case "deleted" => TaskStatus.Deleted
        case _ => TaskStatus.Unknown
    }
}

private func runModeToString(mode: RunMode): String {
    match (mode) {
        case RunMode.plan => "plan"
        case RunMode.run => "run"
    }
}

private func runModeFromString(value: String): RunMode {
    match (value) {
        case "plan" => RunMode.plan
        case _ => RunMode.run
    }
}

private func formatTaskTimestamp(value: DateTime): String {
    return "${leftPad(value.year.toString(), 4, "0")}${monthToDigits(value.month)}${leftPad(value.dayOfMonth.toString(), 2, "0")}-${leftPad(value.hour.toString(), 2, "0")}${leftPad(value.minute.toString(), 2, "0")}${leftPad(value.second.toString(), 2, "0")}"
}

private func monthToDigits(value: Month): String {
    match (value) {
        case January => "01"
        case February => "02"
        case March => "03"
        case April => "04"
        case May => "05"
        case June => "06"
        case July => "07"
        case August => "08"
        case September => "09"
        case October => "10"
        case November => "11"
        case December => "12"
    }
}

private class TaskJson {
    public static func encodeTasks(tasks: ArrayList<Task>): String {
        let sb = StringBuilder()
        sb.append("[\n")
        for (i in 0..tasks.size) {
            let task = tasks[i]
            sb.append("  {")
            appendField(sb, "id", task.id, false)
            appendField(sb, "title", task.title, true)
            appendField(sb, "prompt", task.prompt, true)
            appendField(sb, "serverId", task.serverId, true)
            appendField(sb, "repoPath", task.repoPath, true)
            appendField(sb, "branchName", task.branchName, true)
            appendField(sb, "worktreePath", task.worktreePath, true)
            appendField(sb, "tmuxSession", task.tmuxSession, true)
            appendField(sb, "remoteTaskDir", task.remoteTaskDir, true)
            appendField(sb, "status", taskStatusToString(task.status), true)
            appendField(sb, "mode", runModeToString(task.mode), true)
            appendNumberField(sb, "createdAt", task.createdAt, true)
            appendNumberField(sb, "updatedAt", task.updatedAt, true)
            appendNumberField(sb, "lastLogOffset", task.lastLogOffset, true)
            appendNullableField(sb, "lastError", task.lastError, true)
            sb.append("}")
            if (i < tasks.size - 1) {
                sb.append(",")
            }
            sb.append("\n")
        }
        sb.append("]\n")
        return sb.toString()
    }

    public static func decodeTasks(text: String): ArrayList<Task> {
        let tasks = ArrayList<Task>()
        for (obj in splitObjects(text)) {
            let now = nowSeconds()
            let task = Task(
                jsonString(obj, "id", ""),
                jsonString(obj, "title", ""),
                jsonString(obj, "prompt", ""),
                jsonString(obj, "serverId", ""),
                jsonString(obj, "repoPath", ""),
                jsonString(obj, "branchName", ""),
                jsonString(obj, "worktreePath", ""),
                jsonString(obj, "tmuxSession", ""),
                jsonString(obj, "remoteTaskDir", ""),
                taskStatusFromString(jsonString(obj, "status", "unknown")),
                runModeFromString(jsonString(obj, "mode", "run")),
                jsonInt(obj, "createdAt", now),
                jsonInt(obj, "updatedAt", now),
                jsonInt(obj, "lastLogOffset", 0),
                jsonNullableString(obj, "lastError")
            )
            if (task.id.size > 0) {
                tasks.append(task)
            }
        }
        return tasks
    }

    public static func encodeServers(servers: ArrayList<ServerConfig>): String {
        let sb = StringBuilder()
        sb.append("[\n")
        for (i in 0..servers.size) {
            let server = servers[i]
            sb.append("  {")
            appendField(sb, "id", server.id, false)
            appendField(sb, "name", server.name, true)
            appendField(sb, "host", server.host, true)
            appendNumberField(sb, "port", server.port, true)
            appendField(sb, "username", server.username, true)
            appendField(sb, "passwordRef", server.passwordRef, true)
            appendField(sb, "defaultRepoPath", server.defaultRepoPath, true)
            appendNumberField(sb, "createdAt", server.createdAt, true)
            appendNumberField(sb, "updatedAt", server.updatedAt, true)
            sb.append("}")
            if (i < servers.size - 1) {
                sb.append(",")
            }
            sb.append("\n")
        }
        sb.append("]\n")
        return sb.toString()
    }

    public static func decodeServers(text: String): ArrayList<ServerConfig> {
        let servers = ArrayList<ServerConfig>()
        for (obj in splitObjects(text)) {
            let now = nowSeconds()
            let server = ServerConfig(
                jsonString(obj, "id", ""),
                jsonString(obj, "name", ""),
                jsonString(obj, "host", ""),
                jsonInt(obj, "port", 22),
                jsonString(obj, "username", ""),
                jsonString(obj, "passwordRef", ""),
                jsonString(obj, "defaultRepoPath", ""),
                jsonInt(obj, "createdAt", now),
                jsonInt(obj, "updatedAt", now)
            )
            if (server.id.size > 0) {
                servers.append(server)
            }
        }
        return servers
    }
}

private func appendField(sb: StringBuilder, key: String, value: String, comma: Bool): Unit {
    if (comma) {
        sb.append(",")
    }
    sb.append("\"")
    sb.append(key)
    sb.append("\":\"")
    sb.append(jsonEscape(value))
    sb.append("\"")
}

private func appendNullableField(sb: StringBuilder, key: String, value: ?String, comma: Bool): Unit {
    if (comma) {
        sb.append(",")
    }
    sb.append("\"")
    sb.append(key)
    sb.append("\":")
    match (value) {
        case Some(v) =>
            sb.append("\"")
            sb.append(jsonEscape(v))
            sb.append("\"")
        case None => sb.append("null")
    }
}

private func appendNumberField(sb: StringBuilder, key: String, value: Int64, comma: Bool): Unit {
    if (comma) {
        sb.append(",")
    }
    sb.append("\"")
    sb.append(key)
    sb.append("\":")
    sb.append(value)
}

private func jsonEscape(value: String): String {
    var out = value.replace("\\", "\\\\")
    out = out.replace("\"", "\\\"")
    out = out.replace("\n", "\\n")
    out = out.replace("\r", "\\r")
    out = out.replace("\t", "\\t")
    return out
}

private func jsonUnescape(value: String): String {
    var sb = StringBuilder()
    var escaping = false
    for (r in value.runes()) {
        if (escaping) {
            match (r) {
                case r'n' => sb.append("\n")
                case r'r' => sb.append("\r")
                case r't' => sb.append("\t")
                case r'"' => sb.append("\"")
                case r'\\' => sb.append("\\")
                case _ => sb.append(r)
            }
            escaping = false
        } else if (r == r'\\') {
            escaping = true
        } else {
            sb.append(r)
        }
    }
    return sb.toString()
}

private func splitObjects(text: String): ArrayList<String> {
    let objects = ArrayList<String>()
    var depth = 0
    var inString = false
    var escaping = false
    var sb = StringBuilder()
    for (r in text.runes()) {
        if (depth > 0) {
            sb.append(r)
        }
        if (inString) {
            if (escaping) {
                escaping = false
            } else if (r == r'\\') {
                escaping = true
            } else if (r == r'"') {
                inString = false
            }
        } else {
            if (r == r'"') {
                inString = true
            } else if (r == r'{') {
                depth += 1
            } else if (r == r'}') {
                depth -= 1
                if (depth == 0) {
                    objects.append(sb.toString())
                    sb = StringBuilder()
                }
            }
        }
    }
    return objects
}

private func jsonString(obj: String, key: String, fallback: String): String {
    match (readJsonString(obj, key)) {
        case Some(v) => v
        case None => fallback
    }
}

private func jsonNullableString(obj: String, key: String): ?String {
    return readJsonString(obj, key)
}

private func jsonInt(obj: String, key: String, fallback: Int64): Int64 {
    let marker = "\"${key}\":"
    if (let Some(start) <- obj.indexOf(marker)) {
        let raw = readRawToken(obj, start + marker.size)
        match (Int64.tryParse(raw.trimAscii())) {
            case Some(v) => return v
            case None => return fallback
        }
    }
    return fallback
}

private func readJsonString(obj: String, key: String): ?String {
    let marker = "\"${key}\":"
    if (let Some(start) <- obj.indexOf(marker)) {
        let runes = obj.toRuneArray()
        var i = byteIndexToRuneIndex(obj, start + marker.size)
        while (i < runes.size && (runes[i] == r' ' || runes[i] == r'\n' || runes[i] == r'\r' || runes[i] == r'\t')) {
            i += 1
        }
        if (i >= runes.size || runes[i] != r'"') {
            return None
        }
        i += 1
        let sb = StringBuilder()
        var escaping = false
        while (i < runes.size) {
            let r = runes[i]
            if (escaping) {
                sb.append(r'\\')
                sb.append(r)
                escaping = false
            } else if (r == r'\\') {
                escaping = true
            } else if (r == r'"') {
                return Some(jsonUnescape(sb.toString()))
            } else {
                sb.append(r)
            }
            i += 1
        }
    }
    return None
}

private func readRawToken(obj: String, byteStart: Int64): String {
    let runes = obj.toRuneArray()
    var i = byteIndexToRuneIndex(obj, byteStart)
    let sb = StringBuilder()
    while (i < runes.size) {
        let r = runes[i]
        if (r == r',' || r == r'}' || r == r'\n' || r == r'\r') {
            break
        }
        sb.append(r)
        i += 1
    }
    return sb.toString()
}

private func byteIndexToRuneIndex(value: String, byteIndex: Int64): Int64 {
    var bytes = 0
    var idx = 0
    for (r in value.runes()) {
        if (bytes >= byteIndex) {
            return idx
        }
        bytes += String([r]).size
        idx += 1
    }
    return idx
}
