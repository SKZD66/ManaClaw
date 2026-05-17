package ohos_app_cangjie_entry

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import std.collection.*
import std.convert.*
import encoding.json.*

// ==========================================
// 仅保留用于从仓颉返回给 ArkTS 的 DTO
// ==========================================

@Interop[ArkTS]
public class CjConnectionState {
    public var name: String = ""
    public var host: String = ""
    public var port: String = ""
    public var username: String = ""
    public var password: String = ""
    public var defaultRepoPath: String = ""
    public init() {}
}

@Interop[ArkTS]
public class CjTaskCardState {
    public var title: String = ""
    public var taskId: String = ""
    public var status: String = ""
    public var repo: String = ""
    public var branch: String = ""
    public var live: Bool = false
    public var createdAt: String = ""
    public var updatedAt: String = ""
    public var lastLog: String = ""
    public init() {}
}

@Interop[ArkTS]
public class CjTaskDetailState {
    public var title: String = ""
    public var taskId: String = ""
    public var status: String = ""
    public var repo: String = ""
    public var branch: String = ""
    public var live: Bool = false
    public var createdAt: String = ""
    public var updatedAt: String = ""
    public var lastLog: String = ""
    public var worktree: String = ""
    public var tmuxSession: String = ""
    public var exitCode: String = ""
    public var logs: String = ""
    public var rawLogs: String = ""
    public var stderr: String = ""
    public var gitSummary: String = ""
    public init() {}
}

@Interop[ArkTS]
public class CjLogPanelState {
    public var text: String = ""
    public var raw: String = ""
    public var stderr: String = ""
    public init() {}
}

// ==========================================
// 统一结果包装器
// ==========================================

@Interop[ArkTS]
public class CjResultBool {
    public var ok: Bool = false
    public var msg: String = ""
    public var raw: String = ""
    public var data: Bool = false
    public init() {}
}

@Interop[ArkTS]
public class CjResultString {
    public var ok: Bool = false
    public var msg: String = ""
    public var raw: String = ""
    public var data: String = ""
    public init() {}
}

@Interop[ArkTS]
public class CjResultTaskCard {
    public var ok: Bool = false
    public var msg: String = ""
    public var raw: String = ""
    public var data: Option<CjTaskCardState> = None
    public init() {}
}

@Interop[ArkTS]
public class CjResultTaskDetail {
    public var ok: Bool = false
    public var msg: String = ""
    public var raw: String = ""
    public var data: Option<CjTaskDetailState> = None
    public init() {}
}

@Interop[ArkTS]
public class CjResultLogPanel {
    public var ok: Bool = false
    public var msg: String = ""
    public var raw: String = ""
    public var data: Option<CjLogPanelState> = None
    public init() {}
}

// ==========================================
// 内部纯函数辅助，彻底抛弃全局状态
// ==========================================
private func createServer(host: String, port: String, user: String, pass: String): ServerConfig {
    let portInt = Int64.tryParse(port) ?? 22
    return ServerConfig("default", "default", host, portInt, user, pass, "", 0, 0)
}

private func getGateway(host: String, port: String, user: String, pass: String): RemoteCommandTaskGateway {
    let portInt = Int32(Int64.tryParse(port) ?? 22)
    return RemoteCommandTaskGateway(host, portInt, user, pass)
}

// ==========================================
// 同步操作区（仅限本地 DB）
// ==========================================
@Interop[ArkTS]
public func cjLoadConnection(): CjConnectionState {
    let state = CjConnectionState()
    match (ServerStore().getDefaultServer()) {
        case Some(s) =>
            state.name = s.name
            state.host = s.host
            state.port = s.port.toString()
            state.username = s.username
            state.password = s.passwordRef
            state.defaultRepoPath = s.defaultRepoPath
        case None => ()
    }
    return state
}

@Interop[ArkTS]
public func cjSaveConnection(name: String, host: String, port: String, user: String, pass: String, repo: String): CjResultBool {
    let portInt = Int64.tryParse(port) ?? 22
    let server = ServerConfig("default", name, host, portInt, user, pass, repo, 0, 0)
    ServerStore().upsertServer(server)
    let res = CjResultBool()
    res.ok = true
    res.data = true
    res.msg = "Saved successfully"
    return res
}

// ==========================================
// 异步操作区 (完全无状态化，每次透传鉴权，永不发生线程冲突)
// ==========================================

@Interop[ArkTS, Async]
public func cjTestConnection(host: String, port: String, user: String, pass: String): CjResultBool {
    let res = CjResultBool()
    let portInt = Int32(Int64.tryParse(port) ?? 22)
    let client = SshClient()
    let execRes = client.execEchoOk(host, portInt, user, pass)

    if (execRes.code == 0) {
        res.ok = true
        res.data = true
        res.msg = "Connection OK"
    } else {
        res.ok = false
        res.data = false
        res.msg = "Connection Failed"
        res.raw = execRes.stderr
    }
    return res
}

@Interop[ArkTS, Async]
public func cjInitRemote(host: String, port: String, user: String, pass: String): CjResultBool {
    let res = CjResultBool()
    let srv = createServer(host, port, user, pass)
    let gw = getGateway(host, port, user, pass)
    let initRes = gw.initRemote(srv)
    res.ok = initRes.isOk
    res.data = initRes.isOk
    res.msg = initRes.error ?? "Init Success"
    return res
}

@Interop[ArkTS, Async]
public func cjLoadTasks(host: String, port: String, user: String, pass: String): CjResultString {
    let taskStore = TaskStore()
    let res = CjResultString()
    let srv = createServer(host, port, user, pass)
    let gw = getGateway(host, port, user, pass)
    let svc = TaskService(taskStore, gw)
    let tasksRes = svc.refreshTasks(srv)

    if (tasksRes.isOk) {
        res.ok = true
        match (tasksRes.value) {
            case Some(tasks) => res.data = TaskCoreJson.encodeTasks(tasks)
            case None => res.data = "[]"
        }
    } else {
        res.ok = false
        res.msg = tasksRes.error ?? "Load Tasks Failed"
    }
    return res
}

@Interop[ArkTS, Async]
public func cjSubmitTask(host: String, port: String, user: String, pass: String, repoPath: String, title: String, prompt: String, modeStr: String): CjResultTaskCard {
    let taskStore = TaskStore()
    let res = CjResultTaskCard()
    let srv = createServer(host, port, user, pass)
    let gw = getGateway(host, port, user, pass)
    let svc = TaskService(taskStore, gw)
    let mode = if (modeStr == "plan") { RunMode.plan } else { RunMode.run }

    let taskRes = svc.submitTask(srv, repoPath, title, prompt, mode)
    if (taskRes.isOk) {
        match (taskRes.value) {
            case Some(task) =>
                let card = CjTaskCardState()
                card.taskId = task.id
                card.title = task.title
                card.status = taskStatusToWire(task.status)
                card.repo = task.repoPath
                card.branch = task.branchName
                card.live = true
                card.createdAt = task.createdAt.toString()
                card.updatedAt = task.updatedAt.toString()

                res.ok = true
                res.data = Some(card)
            case None => ()
        }
    } else {
        res.ok = false
        res.msg = taskRes.error ?? "Submit Task Failed"
    }
    return res
}

@Interop[ArkTS, Async]
public func cjOpenTask(taskId: String): CjResultTaskDetail {
    let taskStore = TaskStore()
    let res = CjResultTaskDetail()
    match (taskStore.findTask(taskId)) {
        case Some(task) =>
            let detail = CjTaskDetailState()
            detail.taskId = task.id
            detail.title = task.title
            detail.status = taskStatusToWire(task.status)
            detail.repo = task.repoPath
            detail.branch = task.branchName
            detail.worktree = task.worktreePath
            detail.tmuxSession = task.tmuxSession
            detail.createdAt = task.createdAt.toString()
            detail.updatedAt = task.updatedAt.toString()

            res.ok = true
            res.data = Some(detail)
        case None =>
            res.msg = "Task not found locally"
    }
    return res
}

@Interop[ArkTS, Async]
public func cjRefreshTask(host: String, port: String, user: String, pass: String, taskId: String): CjResultTaskDetail {
    let taskStore = TaskStore()
    let res = CjResultTaskDetail()
    let srv = createServer(host, port, user, pass)
    let gw = getGateway(host, port, user, pass)
    let svc = TaskService(taskStore, gw)
    let detailRes = svc.refreshTask(taskId)

    if (detailRes.isOk) {
        match (detailRes.value) {
            case Some(detailObj) =>
                let detail = CjTaskDetailState()
                detail.taskId = detailObj.task.id
                detail.title = detailObj.task.title
                detail.status = taskStatusToWire(detailObj.task.status)
                detail.repo = detailObj.task.repoPath
                detail.branch = detailObj.task.branchName
                detail.worktree = detailObj.task.worktreePath
                detail.tmuxSession = detailObj.task.tmuxSession
                detail.live = detailObj.live
                detail.createdAt = detailObj.task.createdAt.toString()
                detail.updatedAt = detailObj.task.updatedAt.toString()
                detail.exitCode = match (detailObj.exitCode) { case Some(c) => c.toString() case None => "" }
                detail.rawLogs = detailObj.log
                detail.logs = ClaudeLogFormatter.format(detailObj.log)
                detail.stderr = detailObj.stderr

                res.ok = true
                res.data = Some(detail)
            case None => ()
        }
    } else {
        res.ok = false
        res.msg = detailRes.error ?? "Refresh Failed"
    }
    return res
}

@Interop[ArkTS, Async]
public func cjRefreshLogs(host: String, port: String, user: String, pass: String, taskId: String): CjResultLogPanel {
    let res = CjResultLogPanel()
    let gw = getGateway(host, port, user, pass)
    let logRes = gw.tailLog(taskId, 500)
    let errRes = gw.tailStderr(taskId)

    if (logRes.isOk && errRes.isOk) {
        let logText = logRes.value ?? ""
        let errText = errRes.value ?? ""
        let panel = CjLogPanelState()
        panel.raw = logText
        panel.text = ClaudeLogFormatter.format(logText)
        panel.stderr = errText

        res.ok = true
        res.data = Some(panel)
    } else {
        res.ok = false
        res.msg = "Fetch logs failed"
    }
    return res
}

@Interop[ArkTS, Async]
public func cjStopTask(host: String, port: String, user: String, pass: String, taskId: String): CjResultBool {
    let taskStore = TaskStore()
    let res = CjResultBool()
    let srv = createServer(host, port, user, pass)
    let gw = getGateway(host, port, user, pass)
    let svc = TaskService(taskStore, gw)
    let r = svc.stopTask(taskId)
    res.ok = r.isOk
    res.data = r.isOk
    res.msg = r.error ?? "Task Stopped"
    return res
}

@Interop[ArkTS, Async]
public func cjSoftDeleteTask(host: String, port: String, user: String, pass: String, taskId: String): CjResultBool {
    let taskStore = TaskStore()
    let res = CjResultBool()
    let srv = createServer(host, port, user, pass)
    let gw = getGateway(host, port, user, pass)
    let svc = TaskService(taskStore, gw)
    let r = svc.deleteTask(taskId)
    res.ok = r.isOk
    res.data = r.isOk
    res.msg = r.error ?? "Task Deleted"
    return res
}

@Interop[ArkTS, Async]
public func cjLoadGitSummary(host: String, port: String, user: String, pass: String, taskId: String): CjResultString {
    let taskStore = TaskStore()
    let res = CjResultString()
    let srv = createServer(host, port, user, pass)
    let gw = getGateway(host, port, user, pass)
    let svc = TaskService(taskStore, gw)
    let r = svc.loadGitSummary(taskId)
    res.ok = r.isOk
    res.data = r.value ?? ""
    res.msg = r.error ?? "OK"
    return res
}