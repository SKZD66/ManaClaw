package ohos_app_cangjie_entry

internal import ohos.base.LengthProp
internal import ohos.component.Column
internal import ohos.component.If
internal import ohos.component.Row
internal import ohos.component.Button
internal import ohos.component.Text
internal import ohos.component.TextInput
internal import ohos.component.TextArea
internal import ohos.component.Scroll
internal import ohos.component.CustomView
internal import ohos.component.CJEntry
internal import ohos.component.loadNativeView
internal import ohos.state_manage.SubscriberManager
internal import ohos.state_manage.ObservedProperty
internal import ohos.state_manage.LocalStorage
import ohos.state_macro_manage.Entry
import ohos.state_macro_manage.Component
import ohos.state_macro_manage.State
import ohos.state_macro_manage.r
import std.collection.*
import std.convert.*
import std.time.*

class CommandCase {
    let name: String
    let command: String

    public init(name: String, command: String) {
        this.name = name
        this.command = command
    }
}

@Entry
@Component
class EntryView {
    @State
    var host: String = "182.92.107.89"
    @State
    var portText: String = "11761"
    @State
    var username: String = "root"
    @State
    var password: String = ""
    @State
    var result: String = "输入服务器信息后点击测试连接"
    @State
    var commandOutput: String = ""
    @State
    var selectedTaskId: String = "ccm-qa-000001"
    @State
    var repoPath: String = "/root/projects/ccflow-test-repo"
    @State
    var prompt: String = "请输出当前仓库状态并结束。"
    @State
    var selectedMode: String = "run"
    @State
    var commandSection: String = "ops"
    @State
    var flowIndex: Int64 = 0
    @State
    var outputOnly: Bool = false

    func testConnection(): Unit {
        if (host.size == 0 || portText.size == 0 || username.size == 0) {
            result = "Host、Port 和 Username 必填"
            return
        }

        let port = match (Int32.tryParse(portText)) {
            case Some(v) => v
            case None =>
                result = "Port 必须是 1-65535 的数字"
                return
        }
        if (port < 1 || port > 65535) {
            result = "Port 必须是 1-65535 的数字"
            return
        }

        result = "正在连接..."
        let ssh = SshClient()
        let execResult = ssh.execEchoOk(host, port, username, password)
        if (execResult.code == 0) {
            result = execResult.stdout
        } else {
            result = "连接失败: ${execResult.stderr}"
        }
    }

    private func parsePortOrZero(): Int32 {
        match (Int32.tryParse(portText)) {
            case Some(v) => v
            case None => 0
        }
    }

    private func checkReadyForCommand(): Bool {
        if (host.size == 0 || username.size == 0 || password.size == 0) {
            commandOutput = "请先填写 Host/Username/Password"
            return false
        }
        let port = parsePortOrZero()
        if (port < 1 || port > 65535) {
            commandOutput = "Port 必须是 1-65535"
            return false
        }
        if (repoPath.size == 0) {
            commandOutput = "Repo Path 不能为空"
            return false
        }
        if (selectedTaskId.size == 0) {
            commandOutput = "Task ID 不能为空"
            return false
        }
        return true
    }

    private func flowSteps(): Array<String> {
        return [
            "CLEAN_TEST_DATA",
            "INIT",
            "CREATE",
            "VERIFY_CREATE",
            "START",
            "VERIFY_START",
            "STATUS",
            "TAIL_LOG",
            "TAIL_STDERR",
            "GIT_SUMMARY",
            "STOP",
            "VERIFY_STOP",
            "SOFT_DELETE",
            "VERIFY_DELETE"
        ]
    }

    private func runFlowNextStep(): Unit {
        let steps = flowSteps()
        if (flowIndex >= steps.size) {
            result = "流程已完成，请点击重置流程后再开始"
            return
        }
        let stepName = steps[flowIndex]
        flowIndex += 1
        result = "流程步骤 ${flowIndex}/${steps.size}: ${stepName}"
        runByName(stepName)
    }

    private func resetFlow(): Unit {
        flowIndex = 0
        result = "流程已重置"
    }

    private func makeInput(): TaskCommandInput {
        let mode = if (selectedMode == "plan") {
            RunMode.plan
        } else {
            RunMode.run
        }
        let promptB64 = ShellEscape.base64Encode(prompt)
        return TaskCommandInput(selectedTaskId, repoPath, "", "", "", promptB64, mode)
    }

    private func buildCases(): Array<CommandCase> {
        let builder = CommandBuilder()
        let input = makeInput()
        let taskIdQ = ShellEscape.shellSingleQuote(selectedTaskId)
        let repoQ = ShellEscape.shellSingleQuote(repoPath)

        let cleanCmd = """
set -e
TASK_ID=${taskIdQ}
REPO=${repoQ}
ROOT="$HOME/.cc-mobile"
tmux has-session -t "cc-$TASK_ID" 2>/dev/null && tmux kill-session -t "cc-$TASK_ID" || true
rm -rf "$ROOT/tasks/$TASK_ID"
rm -rf "$ROOT/worktrees/$TASK_ID"
cd "$REPO"
git worktree prune || true
git branch -D "agent/$TASK_ID" 2>/dev/null || true
echo "clean_done"
"""

        let verifyCreateCmd = """
set -e
TASK_ID=${taskIdQ}
REPO=${repoQ}
TASK_DIR="$HOME/.cc-mobile/tasks/$TASK_ID"
WT_DIR="$HOME/.cc-mobile/worktrees/$TASK_ID"
ERR=0
[ -f "$TASK_DIR/prompt.txt" ] || { echo "missing:prompt.txt"; ERR=1; }
[ -f "$TASK_DIR/meta.env" ] || { echo "missing:meta.env"; ERR=1; }
[ -f "$TASK_DIR/status" ] || { echo "missing:status"; ERR=1; }
[ -d "$WT_DIR" ] || { echo "missing:worktree"; ERR=1; }
cd "$REPO"
BRANCH=$(git branch --list "agent/$TASK_ID")
if [ -z "$BRANCH" ]; then
  echo "missing:branch"
  ERR=1
fi
if [ "$ERR" -eq 0 ]; then
  echo "VERIFY_CREATE:PASS"
else
  echo "VERIFY_CREATE:FAIL"
  exit 1
fi
"""

        let verifyStartCmd = """
set -e
TASK_ID=${taskIdQ}
TASK_DIR="$HOME/.cc-mobile/tasks/$TASK_ID"
ERR=0
STATUS=$(cat "$TASK_DIR/status" 2>/dev/null || echo unknown)
if [ "$STATUS" != "running" ] && [ "$STATUS" != "completed" ] && [ "$STATUS" != "failed" ]; then
  echo "bad_status:$STATUS"
  ERR=1
fi
[ -f "$TASK_DIR/events.jsonl" ] || { echo "missing:events.jsonl"; ERR=1; }
[ -f "$TASK_DIR/stderr.log" ] || { echo "missing:stderr.log"; ERR=1; }
if [ "$STATUS" = "completed" ] || [ "$STATUS" = "failed" ]; then
  [ -f "$TASK_DIR/exit.code" ] || { echo "missing:exit.code"; ERR=1; }
fi
if [ "$ERR" -eq 0 ]; then
  echo "VERIFY_START:PASS"
else
  echo "VERIFY_START:FAIL"
  exit 1
fi
"""

        let verifyStopCmd = """
set -e
TASK_ID=${taskIdQ}
TASK_DIR="$HOME/.cc-mobile/tasks/$TASK_ID"
ERR=0
tmux has-session -t "cc-$TASK_ID" 2>/dev/null && { echo "session_still_alive"; ERR=1; } || true
STATUS=$(cat "$TASK_DIR/status" 2>/dev/null || echo unknown)
if [ "$STATUS" != "stopped" ]; then
  echo "bad_status:$STATUS"
  ERR=1
fi
if [ "$ERR" -eq 0 ]; then
  echo "VERIFY_STOP:PASS"
else
  echo "VERIFY_STOP:FAIL"
  exit 1
fi
"""

        let verifyDeleteCmd = """
set -e
TASK_ID=${taskIdQ}
TASK_DIR="$HOME/.cc-mobile/tasks/$TASK_ID"
WT_DIR="$HOME/.cc-mobile/worktrees/$TASK_ID"
ERR=0
STATUS=$(cat "$TASK_DIR/status" 2>/dev/null || echo unknown)
if [ "$STATUS" != "deleted" ]; then
  echo "bad_status:$STATUS"
  ERR=1
fi
[ -d "$TASK_DIR" ] || { echo "missing:task_dir"; ERR=1; }
[ -d "$WT_DIR" ] || { echo "missing:worktree_dir"; ERR=1; }
if [ "$ERR" -eq 0 ]; then
  echo "VERIFY_DELETE:PASS"
else
  echo "VERIFY_DELETE:FAIL"
  exit 1
fi
"""

        return [
            CommandCase("INIT", builder.buildInitCommand()),
            CommandCase("CREATE", builder.buildCreateTaskCommand(input)),
            CommandCase("START", builder.buildStartTaskCommand(input)),
            CommandCase("LIST", builder.buildListTasksCommand()),
            CommandCase("STATUS", builder.buildTaskStatusCommand(selectedTaskId)),
            CommandCase("TAIL_LOG", builder.buildTailLogCommand(selectedTaskId, 200)),
            CommandCase("TAIL_STDERR", builder.buildTailStderrCommand(selectedTaskId)),
            CommandCase("GIT_SUMMARY", builder.buildGitSummaryCommand(selectedTaskId)),
            CommandCase("STOP", builder.buildStopTaskCommand(selectedTaskId)),
            CommandCase("SOFT_DELETE", builder.buildSoftDeleteCommand(selectedTaskId)),
            CommandCase("CLEAN_TEST_DATA", cleanCmd),
            CommandCase("VERIFY_CREATE", verifyCreateCmd),
            CommandCase("VERIFY_START", verifyStartCmd),
            CommandCase("VERIFY_STOP", verifyStopCmd),
            CommandCase("VERIFY_DELETE", verifyDeleteCmd)
        ]
    }

    private func runRemoteCommand(name: String, command: String): Unit {
        if (!checkReadyForCommand()) {
            return
        }

        commandOutput = "[${name}] 执行中..."
        result = "[${name}] 执行中..."
        let port = parsePortOrZero()
        let ssh = SshClient()
        let res = ssh.execCommand(host, port, username, password, command, 120000)
        let outBody = if (res.stdout.size > 0) {
            res.stdout
        } else {
            "<empty>"
        }
        let displayOut = if (name == "TAIL_LOG") {
            ClaudeLogFormatter.format(outBody)
        } else {
            outBody
        }
        let outTitle = if (name == "TAIL_LOG") {
            "CLAUDE LOG"
        } else {
            "STDOUT"
        }
        let errBody = if (res.stderr.size > 0) {
            res.stderr
        } else {
            "<empty>"
        }
        commandOutput = "[${name}] exit=${res.code}\n\n${outTitle}:\n${displayOut}\n\nSTDERR:\n${errBody}"
        result = "[${name}] exit=${res.code}"
    }

    private func runByName(targetName: String): Unit {
        for (c in buildCases()) {
            if (c.name == targetName) {
                runRemoteCommand(c.name, c.command)
                return
            }
        }
    }

    private func modeName(): String {
        if (selectedMode == "plan") {
            return "PLAN"
        }
        return "RUN"
    }

    private func modeHint(): String {
        if (selectedMode == "plan") {
            return "规划模式，不直接执行危险写操作"
        }
        return "运行模式，会使用 danger run 参数"
    }

    private func toggleMode(): Unit {
        if (selectedMode == "plan") {
            selectedMode = "run"
        } else {
            selectedMode = "plan"
        }
    }

    private func flowProgressText(): String {
        return "流程 ${flowIndex}/${flowSteps().size}"
    }

    private func connectionSummary(): String {
        return "${username}@${host}:${portText}"
    }

    private func runTaskCoreMockSuite(): Unit {
        try {
            runTaskCoreMockSuiteUnsafe()
        } catch (e: Exception) {
            result = "[TASKCORE_MOCK] EXCEPTION"
            commandOutput = "TaskCore Mock 验收发生异常：\n${e.toString()}"
        }
    }

    private func runTaskCoreMockSuiteUnsafe(): Unit {
        result = "[TASKCORE_MOCK] 执行中..."
        commandOutput = "[TASKCORE_MOCK] 执行中..."

        let sb = StringBuilder()
        var allPass = true
        sb.append("TaskCore Mock 验收\n")
        sb.append("说明：本测试只使用 FakeRemoteTaskGateway，不连接服务器，不读取密码。\n\n")

        if (!appendTaskCoreSuccessChecks(sb)) {
            allPass = false
        }
        if (!appendTaskCoreFailureChecks(sb)) {
            allPass = false
        }
        if (!appendTaskCoreRefreshChecks(sb)) {
            allPass = false
        }
        if (!appendTaskCoreStoreChecks(sb)) {
            allPass = false
        }

        sb.append("\n结论：")
        if (allPass) {
            sb.append("TASKCORE_MOCK_ALL_PASS")
            result = "[TASKCORE_MOCK] ALL PASS"
        } else {
            sb.append("TASKCORE_MOCK_HAS_FAIL")
            result = "[TASKCORE_MOCK] HAS FAIL"
        }
        commandOutput = sb.toString()
    }

    private func runTaskCoreRemoteSuite(): Unit {
        try {
            runTaskCoreRemoteSuiteUnsafe()
        } catch (e: Exception) {
            result = "[TASKCORE_REMOTE] EXCEPTION"
            commandOutput = "TaskCore 真实服务器验收发生异常：\n${e.toString()}"
        }
    }

    private func runTaskCoreRemoteSuiteUnsafe(): Unit {
        if (!checkReadyForTaskCoreRemote()) {
            return
        }

        result = "[TASKCORE_REMOTE] 执行中..."
        commandOutput = "[TASKCORE_REMOTE] 执行中..."

        let sb = StringBuilder()
        var allPass = true
        sb.append("TaskCore 真实服务器验收\n")
        sb.append("说明：本测试路径是 index.cj -> TaskService -> RemoteCommandTaskGateway -> CommandBuilder -> SshClient -> 服务器。\n")
        sb.append("注意：会在服务器创建一个真实任务、worktree、tmux session，最后执行 stop 和 soft delete。\n\n")

        let port = parsePortOrZero()
        let server = taskCoreRemoteServer()
        let storeName = "taskcore-remote-${generateTaskId()}"
        let store = TaskStore(storeName)
        let gateway = RemoteCommandTaskGateway(host, port, username, password)
        let service = TaskService(store, gateway)

        let initResult = gateway.initRemote(server)
        allPass = appendTaskCoreCheck(sb, initResult.isOk, "initRemote 返回成功") && allPass
        if (!initResult.isOk) {
            appendTaskCoreError(sb, initResult.error ?? "unknown initRemote error")
            sb.append("\n结论：TASKCORE_REMOTE_HAS_FAIL")
            result = "[TASKCORE_REMOTE] HAS FAIL"
            commandOutput = sb.toString()
            return
        }

        let submit = service.submitTask(server, repoPath, "TaskCore Remote UI", prompt, selectedRunMode())
        allPass = appendTaskCoreCheck(sb, submit.isOk, "submitTask 通过真实 SSH 创建并启动任务") && allPass
        if (!submit.isOk) {
            appendTaskCoreError(sb, submit.error ?? "unknown submitTask error")
            sb.append("\n结论：TASKCORE_REMOTE_HAS_FAIL")
            result = "[TASKCORE_REMOTE] HAS FAIL"
            commandOutput = sb.toString()
            return
        }

        match (submit.value) {
            case Some(task) =>
                selectedTaskId = task.id
                allPass = appendTaskCoreRemoteTaskChecks(sb, service, store, task) && allPass
            case None =>
                allPass = appendTaskCoreCheck(sb, false, "submitTask 返回 Task 内容") && allPass
        }

        sb.append("\n结论：")
        if (allPass) {
            sb.append("TASKCORE_REMOTE_ALL_PASS")
            result = "[TASKCORE_REMOTE] ALL PASS"
        } else {
            sb.append("TASKCORE_REMOTE_HAS_FAIL")
            result = "[TASKCORE_REMOTE] HAS FAIL"
        }
        commandOutput = sb.toString()
    }

    private func appendTaskCoreSuccessChecks(sb: StringBuilder): Bool {
        var allPass = true
        sb.append("一、submit / refresh / stop / delete 成功链路\n")

        let store = TaskStore("taskcore-ui-success-${generateTaskId()}")
        let gateway = FakeRemoteTaskGateway()
        let service = TaskService(store, gateway)
        let server = taskCoreMockServer("srv-taskcore-success")
        let submit = service.submitTask(server, "/repo/demo", "UI TaskCore", "请实现一个按钮", RunMode.run)
        allPass = appendTaskCoreCheck(sb, submit.isOk, "submitTask 返回成功") && allPass

        match (submit.value) {
            case Some(task) =>
                allPass = appendTaskCoreCheck(sb, isValidTaskId(task.id), "task_id 格式合法: ${task.id}") && allPass
                allPass = appendTaskCoreCheck(sb, task.branchName == "agent/${task.id}", "branchName = agent/<task_id>") &&
                    allPass
                allPass = appendTaskCoreCheck(sb, task.tmuxSession == "cc-${task.id}", "tmuxSession = cc-<task_id>") &&
                    allPass
                allPass = appendTaskCoreCheck(
                    sb,
                    task.worktreePath == "$HOME/.cc-mobile/worktrees/${task.id}",
                    "worktreePath 派生正确"
                ) && allPass
                allPass = appendTaskCoreCheck(
                    sb,
                    task.remoteTaskDir == "$HOME/.cc-mobile/tasks/${task.id}",
                    "remoteTaskDir 派生正确"
                ) && allPass
                allPass = appendTaskCoreCheck(sb, taskStatusToWire(task.status) == "running", "成功提交后状态为 running") &&
                    allPass
                allPass = appendTaskCoreCheck(sb, gateway.createCallCount == 1, "调用 createTask 一次") && allPass
                allPass = appendTaskCoreCheck(sb, gateway.startCallCount == 1, "调用 startTask 一次") && allPass

                let wrappedPrompt = gateway.wrappedPrompts.get(task.id) ?? ""
                allPass = appendTaskCoreCheck(sb, wrappedPrompt.contains("你正在一个独立 git worktree 中工作。"), "prompt 已包装") &&
                    allPass
                allPass = appendTaskCoreCheck(sb, wrappedPrompt.contains("完成后创建一个 git commit"), "prompt 包含提交规范") &&
                    allPass

                match (store.findTask(task.id)) {
                    case Some(saved) =>
                        allPass = appendTaskCoreCheck(sb, taskStatusToWire(saved.status) == "running", "TaskStore 保存 running 任务") &&
                            allPass
                    case None =>
                        allPass = appendTaskCoreCheck(sb, false, "TaskStore 保存 running 任务") && allPass
                }

                let detail = service.refreshTask(task.id)
                allPass = appendTaskCoreCheck(sb, detail.isOk, "refreshTask 返回详情") && allPass
                match (detail.value) {
                    case Some(d) =>
                        allPass = appendTaskCoreCheck(sb, taskStatusToWire(d.task.status) == "running", "refreshTask 合并 running 状态") &&
                            allPass
                        allPass = appendTaskCoreCheck(sb, d.live, "refreshTask 返回 live=true") && allPass
                        allPass = appendTaskCoreCheck(sb, d.log.contains("running"), "refreshTask 读取日志") && allPass
                    case None =>
                        allPass = appendTaskCoreCheck(sb, false, "refreshTask 返回详情内容") && allPass
                }

                let gitSummary = service.loadGitSummary(task.id)
                allPass = appendTaskCoreCheck(sb, gitSummary.isOk, "loadGitSummary 成功") && allPass
                allPass = appendTaskCoreCheck(sb, (gitSummary.value ?? "").contains("--- STATUS ---"), "Git 摘要包含 STATUS 区块") &&
                    allPass

                let stopped = service.stopTask(task.id)
                allPass = appendTaskCoreCheck(sb, stopped.isOk, "stopTask 成功") && allPass
                allPass = appendTaskCoreCheck(sb, gateway.stopCallCount == 1, "stopTask 调用 gateway") && allPass
                allPass = appendTaskCoreCheck(sb, taskCoreStoredStatus(store, task.id) == "stopped", "stopTask 后本地状态 stopped") &&
                    allPass

                let deleted = service.softDeleteTask(task.id)
                allPass = appendTaskCoreCheck(sb, deleted.isOk, "softDeleteTask 成功") && allPass
                allPass = appendTaskCoreCheck(sb, gateway.softDeleteCallCount == 1, "softDeleteTask 调用 gateway") && allPass
                allPass = appendTaskCoreCheck(sb, taskCoreStoredStatus(store, task.id) == "deleted", "softDeleteTask 后本地状态 deleted") &&
                    allPass

                let visible = service.refreshTasks(server)
                match (visible.value) {
                    case Some(tasks) =>
                        allPass = appendTaskCoreCheck(sb, tasks.size == 0, "deleted 任务默认不出现在列表") && allPass
                    case None =>
                        allPass = appendTaskCoreCheck(sb, false, "deleted 任务默认不出现在列表") && allPass
                }
            case None =>
                allPass = appendTaskCoreCheck(sb, false, "submitTask 返回 Task 内容") && allPass
        }

        sb.append("\n")
        return allPass
    }

    private func appendTaskCoreFailureChecks(sb: StringBuilder): Bool {
        var allPass = true
        sb.append("二、失败分支与可诊断状态\n")

        let createStore = TaskStore("taskcore-ui-create-fail-${generateTaskId()}")
        let createGateway = FakeRemoteTaskGateway()
        createGateway.failCreate = true
        let createService = TaskService(createStore, createGateway)
        let server = taskCoreMockServer("srv-taskcore-fail")
        let createResult = createService.submitTask(server, "/repo/demo", "Create Fail", "触发创建失败", RunMode.run)
        allPass = appendTaskCoreCheck(sb, !createResult.isOk, "createTask 失败时 submitTask 返回失败") && allPass
        let createTasks = createStore.loadTasks()
        allPass = appendTaskCoreCheck(sb, createTasks.size == 1, "createTask 失败时保留本地任务") && allPass
        if (createTasks.size > 0) {
            allPass = appendTaskCoreCheck(sb, taskStatusToWire(createTasks[0].status) == "local_created", "createTask 失败保留 local_created") &&
                allPass
            allPass = appendTaskCoreCheck(sb, (createTasks[0].lastError ?? "").contains("fake createTask failed"), "createTask 错误写入 lastError") &&
                allPass
        }

        let startStore = TaskStore("taskcore-ui-start-fail-${generateTaskId()}")
        let startGateway = FakeRemoteTaskGateway()
        startGateway.failStart = true
        let startService = TaskService(startStore, startGateway)
        let startResult = startService.submitTask(server, "/repo/demo", "Start Fail", "触发启动失败", RunMode.run)
        allPass = appendTaskCoreCheck(sb, !startResult.isOk, "startTask 失败时 submitTask 返回失败") && allPass
        let startTasks = startStore.loadTasks()
        allPass = appendTaskCoreCheck(sb, startTasks.size == 1, "startTask 失败时保留本地任务") && allPass
        if (startTasks.size > 0) {
            allPass = appendTaskCoreCheck(sb, taskStatusToWire(startTasks[0].status) == "worktree_created", "startTask 失败保留 worktree_created") &&
                allPass
            allPass = appendTaskCoreCheck(sb, (startTasks[0].lastError ?? "").contains("fake startTask failed"), "startTask 错误写入 lastError") &&
                allPass
        }

        sb.append("\n")
        return allPass
    }

    private func appendTaskCoreRefreshChecks(sb: StringBuilder): Bool {
        var allPass = true
        sb.append("三、refreshTasks 状态合并规则\n")

        let store = TaskStore("taskcore-ui-refresh-${generateTaskId()}")
        let gateway = FakeRemoteTaskGateway()
        let service = TaskService(store, gateway)
        let server = taskCoreMockServer("srv-taskcore-refresh")

        store.upsertTask(Task(
            "ccm-local-missing",
            "Local Missing",
            "prompt",
            server.id,
            "/repo/demo",
            "agent/ccm-local-missing",
            "$HOME/.cc-mobile/worktrees/ccm-local-missing",
            "cc-ccm-local-missing",
            "$HOME/.cc-mobile/tasks/ccm-local-missing",
            TaskStatus.running,
            RunMode.run,
            1,
            1,
            0,
            None
        ))

        gateway.setRemoteStatus(RemoteTaskStatus(
            "ccm-remote-completed",
            TaskStatus.unknown,
            false,
            Some(0),
            "/repo/demo",
            "$HOME/.cc-mobile/worktrees/ccm-remote-completed",
            "agent/ccm-remote-completed",
            "cc-ccm-remote-completed"
        ))
        gateway.setRemoteStatus(RemoteTaskStatus(
            "ccm-remote-failed",
            TaskStatus.unknown,
            false,
            Some(2),
            "/repo/demo",
            "$HOME/.cc-mobile/worktrees/ccm-remote-failed",
            "agent/ccm-remote-failed",
            "cc-ccm-remote-failed"
        ))
        gateway.setRemoteStatus(RemoteTaskStatus(
            "ccm-remote-live",
            TaskStatus.worktree_created,
            true,
            None,
            "/repo/demo",
            "$HOME/.cc-mobile/worktrees/ccm-remote-live",
            "agent/ccm-remote-live",
            "cc-ccm-remote-live"
        ))

        let refreshed = service.refreshTasks(server)
        allPass = appendTaskCoreCheck(sb, refreshed.isOk, "refreshTasks 返回成功") && allPass
        allPass = appendTaskCoreCheck(sb, taskCoreStoredStatus(store, "ccm-local-missing") == "unknown", "本地存在但远端不存在 -> unknown") &&
            allPass
        allPass = appendTaskCoreCheck(sb, taskCoreStoredStatus(store, "ccm-remote-completed") == "completed", "exit_code=0 推断 completed") &&
            allPass
        allPass = appendTaskCoreCheck(sb, taskCoreStoredStatus(store, "ccm-remote-failed") == "failed", "exit_code 非 0 推断 failed") &&
            allPass
        allPass = appendTaskCoreCheck(sb, taskCoreStoredStatus(store, "ccm-remote-live") == "running", "live=true 推断 running") &&
            allPass

        sb.append("\n")
        return allPass
    }

    private func appendTaskCoreStoreChecks(sb: StringBuilder): Bool {
        var allPass = true
        sb.append("四、本地 JSON 存储与重启恢复\n")

        let path = "taskcore-ui-store-${generateTaskId()}"
        let taskStore = TaskStore(path)
        let gateway = FakeRemoteTaskGateway()
        let service = TaskService(taskStore, gateway)
        let server = taskCoreMockServer("srv-taskcore-store")
        let submit = service.submitTask(server, "/repo/demo", "Store Recover", "验证重启恢复", RunMode.plan)
        allPass = appendTaskCoreCheck(sb, submit.isOk, "plan 模式任务可提交") && allPass

        match (submit.value) {
            case Some(task) =>
                let reloaded = TaskStore(path)
                match (reloaded.findTask(task.id)) {
                    case Some(saved) =>
                        allPass = appendTaskCoreCheck(sb, saved.id == task.id, "重建 TaskStore 后 id 不丢失") && allPass
                        allPass = appendTaskCoreCheck(sb, saved.serverId == server.id, "重建 TaskStore 后 serverId 不丢失") &&
                            allPass
                        allPass = appendTaskCoreCheck(sb, saved.createdAt == task.createdAt, "重建 TaskStore 后 createdAt 不丢失") &&
                            allPass
                        allPass = appendTaskCoreCheck(sb, saved.updatedAt > 0, "重建 TaskStore 后 updatedAt 有值") && allPass
                        allPass = appendTaskCoreCheck(sb, taskStatusToWire(saved.status) == "running", "重建 TaskStore 后状态不丢失") &&
                            allPass
                    case None =>
                        allPass = appendTaskCoreCheck(sb, false, "重建 TaskStore 后可读回任务") && allPass
                }

                let wrappedPrompt = gateway.wrappedPrompts.get(task.id) ?? ""
                allPass = appendTaskCoreCheck(sb, wrappedPrompt.contains("本次任务只做计划"), "plan 模式 prompt 追加计划说明") &&
                    allPass
            case None =>
                allPass = appendTaskCoreCheck(sb, false, "plan 模式任务返回 Task") && allPass
        }

        let serverStore = ServerStore(path)
        serverStore.upsertServer(server)
        match (ServerStore(path).getDefaultServer()) {
            case Some(savedServer) =>
                allPass = appendTaskCoreCheck(sb, savedServer.id == server.id, "ServerStore 可保存并恢复默认服务器") && allPass
            case None =>
                allPass = appendTaskCoreCheck(sb, false, "ServerStore 可保存并恢复默认服务器") && allPass
        }

        sb.append("\n")
        return allPass
    }

    private func appendTaskCoreCheck(sb: StringBuilder, ok: Bool, label: String): Bool {
        if (ok) {
            sb.append("PASS  ")
        } else {
            sb.append("FAIL  ")
        }
        sb.append(label)
        sb.append("\n")
        return ok
    }

    private func appendTaskCoreRemoteTaskChecks(
        sb: StringBuilder,
        service: TaskService,
        store: TaskStore,
        task: Task
    ): Bool {
        var allPass = true
        sb.append("生成任务：${task.id}\n")
        sb.append("远端目录：${task.remoteTaskDir}\n")
        sb.append("Worktree：${task.worktreePath}\n\n")

        allPass = appendTaskCoreCheck(sb, isValidTaskId(task.id), "TaskCore 生成合法 task_id") && allPass
        allPass = appendTaskCoreCheck(sb, task.branchName == "agent/${task.id}", "branchName 由 TaskCore 派生") && allPass
        allPass = appendTaskCoreCheck(sb, task.tmuxSession == "cc-${task.id}", "tmuxSession 由 TaskCore 派生") &&
            allPass
        allPass = appendTaskCoreCheck(sb, taskStatusToWire(task.status) == "running", "submitTask 后本地状态 running") &&
            allPass
        let storedAfterSubmit = taskCoreStoredStatus(store, task.id)
        allPass = appendTaskCoreCheck(sb, storedAfterSubmit == "running", "TaskStore 已保存 running 任务") &&
            allPass
        if (storedAfterSubmit != "running") {
            sb.append("诊断：TaskStore 当前状态=${storedAfterSubmit}, 任务数量=${store.loadTasks().size}\n")
        }

        let refreshed = service.refreshTask(task.id)
        allPass = appendTaskCoreCheck(sb, refreshed.isOk, "refreshTask 可读取真实远端状态和日志") && allPass
        if (!refreshed.isOk) {
            appendTaskCoreError(sb, refreshed.error ?? "unknown refreshTask error")
        }
        match (refreshed.value) {
            case Some(detail) =>
                let statusText = taskStatusToWire(detail.task.status)
                sb.append("远端状态：${statusText}, live=${detail.live}, exitCode=${detail.exitCode.toString()}\n")
                allPass = appendTaskCoreCheck(
                    sb,
                    statusText == "running" || statusText == "completed" || statusText == "failed",
                    "refreshTask 合并真实远端状态"
                ) && allPass
                allPass = appendTaskCoreCheck(
                    sb,
                    detail.task.repoPath == repoPath,
                    "refreshTask 保留/合并 repoPath"
                ) && allPass
            case None =>
                allPass = appendTaskCoreCheck(sb, false, "refreshTask 返回 TaskDetail 内容") && allPass
        }

        let listed = service.refreshTasks(taskCoreRemoteServer())
        allPass = appendTaskCoreCheck(sb, listed.isOk, "refreshTasks 可拉取真实任务列表") && allPass
        if (listed.isOk) {
            allPass = appendTaskCoreCheck(sb, taskCoreListContains(listed.value.getOrThrow(), task.id), "任务列表包含新建任务") &&
                allPass
        }

        let gitSummary = service.loadGitSummary(task.id)
        allPass = appendTaskCoreCheck(sb, gitSummary.isOk, "loadGitSummary 可通过真实 SSH 执行") && allPass
        if (!gitSummary.isOk) {
            appendTaskCoreError(sb, gitSummary.error ?? "unknown gitSummary error")
        }
        if (gitSummary.isOk) {
            allPass = appendTaskCoreCheck(
                sb,
                (gitSummary.value ?? "").contains("--- STATUS ---"),
                "Git 摘要包含 STATUS 区块"
            ) && allPass
        }

        let stopped = service.stopTask(task.id)
        allPass = appendTaskCoreCheck(sb, stopped.isOk, "stopTask 可停止真实远端任务") && allPass
        if (!stopped.isOk) {
            appendTaskCoreError(sb, stopped.error ?? "unknown stopTask error")
        }
        allPass = appendTaskCoreCheck(sb, taskCoreStoredStatus(store, task.id) == "stopped", "stopTask 后本地状态 stopped") &&
            allPass

        let deleted = service.softDeleteTask(task.id)
        allPass = appendTaskCoreCheck(sb, deleted.isOk, "softDeleteTask 可软删除真实远端任务") && allPass
        if (!deleted.isOk) {
            appendTaskCoreError(sb, deleted.error ?? "unknown softDeleteTask error")
        }
        allPass = appendTaskCoreCheck(sb, taskCoreStoredStatus(store, task.id) == "deleted", "softDeleteTask 后本地状态 deleted") &&
            allPass
        return allPass
    }

    private func appendTaskCoreError(sb: StringBuilder, message: String): Unit {
        sb.append("ERROR:\n")
        sb.append(message)
        sb.append("\n")
    }

    private func selectedRunMode(): RunMode {
        if (selectedMode == "plan") {
            return RunMode.plan
        }
        return RunMode.run
    }

    private func checkReadyForTaskCoreRemote(): Bool {
        if (!checkReadyForCommand()) {
            return false
        }
        if (prompt.trimAscii().size == 0) {
            commandOutput = "Prompt 不能为空"
            return false
        }
        return true
    }

    private func taskCoreRemoteServer(): ServerConfig {
        let now = DateTime.now().toUnixTimeStamp().toSeconds()
        return ServerConfig(
            "remote-${host}-${portText}-${username}",
            "Remote TaskCore",
            host,
            Int64(parsePortOrZero()),
            username,
            "ui-password",
            repoPath,
            now,
            now
        )
    }

    private func taskCoreMockServer(id: String): ServerConfig {
        let now = DateTime.now().toUnixTimeStamp().toSeconds()
        return ServerConfig(id, "TaskCore Mock", "127.0.0.1", 22, "mock", "mock-password-ref", "/repo/demo", now, now)
    }

    private func taskCoreStoredStatus(store: TaskStore, taskId: String): String {
        match (store.findTask(taskId)) {
            case Some(task) => taskStatusToWire(task.status)
            case None => "not_found"
        }
    }

    private func taskCoreListContains(tasks: ArrayList<Task>, taskId: String): Bool {
        for (task in tasks) {
            if (task.id == taskId) {
                return true
            }
        }
        return false
    }

    func build() {
        Row {
            Scroll {
                Column {
                    Text("远程任务控制台").fontSize(22).fontColor(0x151A22).height(34).width(100.percent)
                    Text(connectionSummary()).fontSize(13).fontColor(0x5F6B7A).height(20).width(100.percent)
                    Text(result).fontSize(14).fontColor(0x1F6FEB).height(28).width(100.percent)
                    Text(" ").height(6)
                    Row {
                        Button("下一步 · ${flowProgressText()}")
                            .onClick {evt => runFlowNextStep()}
                            .fontColor(0xFFFFFF)
                            .backgroundColor(0x1F6FEB)
                            .height(38)
                            .width(49.percent)
                        Text(" ").width(2.percent)
                        Button(if (outputOnly) {
                            "返回表单"
                        } else {
                            "输出全屏"
                        })
                            .onClick {
                                evt =>
                                outputOnly = !outputOnly
                                ()
                            }
                            .fontColor(0x151A22)
                            .backgroundColor(0xE8EDF3)
                            .height(38)
                            .width(49.percent)
                    }.width(100.percent)
                    Text(" ").height(4)
                    Row {
                        Button("重置流程")
                            .onClick {
                                evt =>
                                resetFlow()
                                ()
                            }
                            .fontColor(0x151A22)
                            .backgroundColor(0xE8EDF3)
                            .height(34)
                            .width(32.percent)
                        Text(" ").width(2.percent)
                        Button("模式: ${modeName()}")
                            .onClick {
                                evt =>
                                toggleMode()
                                ()
                            }
                            .fontColor(0xFFFFFF)
                            .backgroundColor(0x2B8A3E)
                            .height(34)
                            .width(32.percent)
                        Text(" ").width(2.percent)
                        Button("测试连接")
                            .onClick {evt => testConnection()}
                            .fontColor(0xFFFFFF)
                            .backgroundColor(0x3B5BDB)
                            .height(34)
                            .width(32.percent)
                    }.width(100.percent)
                    Text(modeHint()).fontSize(12).fontColor(0x6B7280).height(22).width(100.percent)
                    Text(" ").height(6)

                    if (outputOnly) {
                        Text("命令输出").fontSize(16).fontColor(0x151A22).height(26).width(100.percent)
                        TextArea(text: commandOutput).fontSize(12).fontColor(0x1F2933).height(560).width(100.percent)
                    } else {
                        Text("连接").fontSize(16).fontColor(0x151A22).height(26).width(100.percent)
                        Row {
                            TextInput(placeholder: "Host / IP", text: host)
                                .onChange {
                                    value =>
                                    host = value
                                    ()
                                }
                                .height(38)
                                .width(66.percent)
                            Text(" ").width(2.percent)
                            TextInput(placeholder: "Port", text: portText)
                                .onChange {
                                    value =>
                                    portText = value
                                    ()
                                }
                                .height(38)
                                .width(32.percent)
                        }.width(100.percent)
                        Text(" ").height(4)
                        Row {
                            TextInput(placeholder: "Username", text: username)
                                .onChange {
                                    value =>
                                    username = value
                                    ()
                                }
                                .height(38)
                                .width(49.percent)
                            Text(" ").width(2.percent)
                            TextInput(placeholder: "Password", text: password)
                                .onChange {
                                    value =>
                                    password = value
                                    ()
                                }
                                .height(38)
                                .width(49.percent)
                        }.width(100.percent)
                        Text(" ").height(8)

                        Text("任务").fontSize(16).fontColor(0x151A22).height(26).width(100.percent)
                        TextInput(placeholder: "Repo Path", text: repoPath)
                            .onChange {
                                value =>
                                repoPath = value
                                ()
                            }
                            .height(38)
                            .width(100.percent)
                        Text(" ").height(4)
                        Row {
                            TextInput(placeholder: "Task ID", text: selectedTaskId)
                                .onChange {
                                    value =>
                                    selectedTaskId = value
                                    ()
                                }
                                .height(38)
                                .width(66.percent)
                            Text(" ").width(2.percent)
                            Button("切换 ${modeName()}")
                                .onClick {
                                    evt =>
                                    toggleMode()
                                    ()
                                }
                                .fontColor(0xFFFFFF)
                                .backgroundColor(0x2B8A3E)
                                .height(38)
                                .width(32.percent)
                        }.width(100.percent)
                        Text(" ").height(4)
                        TextArea(text: prompt).onChange {
                            value =>
                            prompt = value
                            ()
                        }.height(76).width(100.percent)

                        Text(" ").height(8)
                        Text("快捷操作").fontSize(16).fontColor(0x151A22).height(26).width(100.percent)
                        Row {
                            Button("INIT")
                                .onClick {evt => runByName("INIT")}
                                .fontColor(0xFFFFFF)
                                .backgroundColor(0x1F6FEB)
                                .height(34)
                                .width(32.percent)
                            Text(" ").width(2.percent)
                            Button("CREATE")
                                .onClick {evt => runByName("CREATE")}
                                .fontColor(0xFFFFFF)
                                .backgroundColor(0x1F6FEB)
                                .height(34)
                                .width(32.percent)
                            Text(" ").width(2.percent)
                            Button("START")
                                .onClick {evt => runByName("START")}
                                .fontColor(0xFFFFFF)
                                .backgroundColor(0x1F6FEB)
                                .height(34)
                                .width(32.percent)
                        }.width(100.percent)
                        Text(" ").height(4)
                        Row {
                            Button("STATUS").onClick {evt => runByName("STATUS")}.height(34).width(32.percent)
                            Text(" ").width(2.percent)
                            Button("LIST").onClick {evt => runByName("LIST")}.height(34).width(32.percent)
                            Text(" ").width(2.percent)
                            Button("GIT").onClick {evt => runByName("GIT_SUMMARY")}.height(34).width(32.percent)
                        }.width(100.percent)

                        Text(" ").height(8)
                        Row {
                            Button(if (commandSection == "ops") {
                                "常用命令"
                            } else {
                                "切到常用"
                            }).onClick {
                                evt => commandSection = "ops"
                            }.height(34).width(49.percent)
                            Text(" ").width(2.percent)
                            Button(if (commandSection == "verify") {
                                "验证命令"
                            } else {
                                "切到验证"
                            }).onClick {
                                evt => commandSection = "verify"
                            }.height(34).width(49.percent)
                        }.width(100.percent)
                        Text(" ").height(4)

                        if (commandSection == "ops") {
                            Row {
                                Button("TAIL_LOG").onClick {evt => runByName("TAIL_LOG")}.height(32).width(49.percent)
                                Text(" ").width(2.percent)
                                Button("TAIL_ERR")
                                    .onClick {evt => runByName("TAIL_STDERR")}
                                    .height(32)
                                    .width(49.percent)
                            }.width(100.percent)
                            Text(" ").height(4)
                            Row {
                                Button("STOP").onClick {evt => runByName("STOP")}.height(32).width(49.percent)
                                Text(" ").width(2.percent)
                                Button("SOFT_DELETE")
                                    .onClick {evt => runByName("SOFT_DELETE")}
                                    .height(32)
                                    .width(49.percent)
                            }.width(100.percent)
                            Text(" ").height(4)
                            Button("CLEAN_TEST_DATA")
                                .onClick {evt => runByName("CLEAN_TEST_DATA")}
                                .height(32)
                                .width(100.percent)
                        } else {
                            Row {
                                Button("VERIFY_CREATE")
                                    .onClick {evt => runByName("VERIFY_CREATE")}
                                    .height(32)
                                    .width(49.percent)
                                Text(" ").width(2.percent)
                                Button("VERIFY_START")
                                    .onClick {evt => runByName("VERIFY_START")}
                                    .height(32)
                                    .width(49.percent)
                            }.width(100.percent)
                            Text(" ").height(4)
                            Row {
                                Button("VERIFY_STOP")
                                    .onClick {evt => runByName("VERIFY_STOP")}
                                    .height(32)
                                    .width(49.percent)
                                Text(" ").width(2.percent)
                                Button("VERIFY_DELETE")
                                    .onClick {evt => runByName("VERIFY_DELETE")}
                                    .height(32)
                                    .width(49.percent)
                            }.width(100.percent)
                        }

                        Text(" ").height(8)
                        Text("TaskCore 测试").fontSize(16).fontColor(0x151A22).height(26).width(100.percent)
                        Button("运行 TaskCore Mock 验收")
                            .onClick {
                                evt =>
                                runTaskCoreMockSuite()
                                ()
                            }
                            .fontColor(0xFFFFFF)
                            .backgroundColor(0x6F42C1)
                            .height(36)
                            .width(100.percent)
                        Text(" ").height(4)
                        Button("运行 TaskCore 真实服务器验收")
                            .onClick {
                                evt =>
                                runTaskCoreRemoteSuite()
                                ()
                            }
                            .fontColor(0xFFFFFF)
                            .backgroundColor(0xC2410C)
                            .height(36)
                            .width(100.percent)
                        Text(" ").height(8)
                        Text("命令输出").fontSize(16).fontColor(0x151A22).height(26).width(100.percent)
                        TextArea(text: commandOutput).fontSize(12).fontColor(0x1F2933).height(190).width(100.percent)
                    }
                }.width(100.percent)
            }.width(100.percent).height(100.percent).backgroundColor(0xF6F8FB)
        }.height(100.percent)
    }
}

public func manualAppEntry(): Bool {
    let view = EntryView(Option<CustomView>.None)
    loadNativeView(view)
    return true
}

let MANUAL_ENTRY_REGISTER_RESULT = CJEntry.getInstance().registerEntry("MainPage", manualAppEntry)
