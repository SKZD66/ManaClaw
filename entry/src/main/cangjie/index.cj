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
import std.convert.*

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
