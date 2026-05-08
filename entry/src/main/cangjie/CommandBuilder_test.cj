package ohos_app_cangjie_entry

/**
 * 任务 01 的命令生成器测试。
 *
 * 设计原则：
 * - 这里只做“字符串层”与“命令内容层”测试，不依赖真实 SSH 环境。
 * - 真实服务器执行测试由集成测试阶段补充。
 */
@Test
class CommandBuilderTests {
    let builder = CommandBuilder()

    /**
     * 构造一份默认输入，便于各测试按需复用。
     */
    private func sampleInput(mode: RunMode): TaskCommandInput {
        let prompt = "请修复登录模块，并补充测试。\n注意处理单引号 ' 与双引号 \"。"
        let promptB64 = ShellEscape.base64Encode(prompt)
        return TaskCommandInput(
            taskId: "ccm_20260509_000001",
            repoPath: "/home/ubuntu/projects/my-app",
            worktreePath: "/tmp/ignored-by-builder",
            branchName: "unsafe-branch-from-user",
            tmuxSession: "unsafe-tmux-from-user",
            promptBase64: promptB64,
            mode: mode
        )
    }

    /**
     * 验证 shell 单引号转义逻辑。
     */
    @TestCase
    func shellSingleQuote_escape_single_quote() {
        let got = ShellEscape.shellSingleQuote("a'b")
        @Expect(got, "'a'\\''b'")
    }

    /**
     * 验证 taskId 安全校验：合法值通过，非法值拒绝。
     */
    @TestCase
    func taskIdSafe_allow_and_reject() {
        @Expect(ShellEscape.taskIdSafe("Abc_123-XYZ"))
        @Expect(!ShellEscape.taskIdSafe("bad/id"))
        @Expect(!ShellEscape.taskIdSafe("bad id"))
        @Expect(!ShellEscape.taskIdSafe(""))
    }

    /**
     * 验证远端路径基础校验。
     */
    @TestCase
    func remotePathSafe_allow_and_reject() {
        @Expect(ShellEscape.remotePathSafe("/home/ubuntu/repo"))
        @Expect(!ShellEscape.remotePathSafe(""))
        @Expect(!ShellEscape.remotePathSafe("relative/path"))
        @Expect(!ShellEscape.remotePathSafe("/home/ubuntu/../repo"))
        @Expect(!ShellEscape.remotePathSafe("/tmp/a;rm -rf /"))
    }

    /**
     * 初始化命令必须包含依赖检查并输出 ok。
     */
    @TestCase
    func buildInitCommand_contains_required_checks() {
        let cmd = builder.buildInitCommand()
        @Expect(cmd.contains("command -v git"))
        @Expect(cmd.contains("command -v tmux"))
        @Expect(cmd.contains("command -v claude"))
        @Expect(cmd.contains("command -v base64"))
        @Expect(cmd.contains("command -v bash"))
        @Expect(cmd.contains("printf \"ok"))
    }

    /**
     * 创建任务命令应写 prompt、meta、status，并创建 git worktree。
     */
    @TestCase
    func buildCreateTaskCommand_contains_core_steps() {
        let cmd = builder.buildCreateTaskCommand(sampleInput(RunMode.run))
        @Expect(cmd.contains("prompt.txt"))
        @Expect(cmd.contains("meta.env"))
        @Expect(cmd.contains("remote_created"))
        @Expect(cmd.contains("worktree_created"))
        @Expect(cmd.contains("git worktree add -b"))

        // 必须由 taskId 派生，不能信任用户传入的 branch / tmux。
        @Expect(cmd.contains("agent/ccm_20260509_000001"))
        @Expect(cmd.contains("cc-ccm_20260509_000001"))
        @Expect(!cmd.contains("unsafe-branch-from-user"))
        @Expect(!cmd.contains("unsafe-tmux-from-user"))
    }

    /**
     * run 模式启动命令必须带 danger run 参数。
     */
    @TestCase
    func buildStartTaskCommand_run_mode_flags() {
        let cmd = builder.buildStartTaskCommand(sampleInput(mode: RunMode.run))
        @Expect(cmd.contains("tmux new-session -d"))
        @Expect(cmd.contains("--dangerously-skip-permissions"))
        @Expect(cmd.contains("--output-format stream-json"))
        @Expect(cmd.contains("--verbose"))
        @Expect(cmd.contains("events.jsonl"))
        @Expect(cmd.contains("stderr.log"))
        @Expect(cmd.contains("exit.code"))
        @Expect(cmd.contains("completed"))
        @Expect(cmd.contains("failed"))
    }

    /**
     * plan 模式启动命令必须带 permission-mode plan 参数。
     */
    @TestCase
    func buildStartTaskCommand_plan_mode_flags() {
        let cmd = builder.buildStartTaskCommand(sampleInput(mode: RunMode.plan))
        @Expect(cmd.contains("--permission-mode plan"))
        @Expect(!cmd.contains("--dangerously-skip-permissions"))
    }

    /**
     * 列表命令必须输出 tab 分隔格式。
     */
    @TestCase
    func buildListTasksCommand_contains_tsv_printf() {
        let cmd = builder.buildListTasksCommand()
        @Expect(cmd.contains("%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s"))
        @Expect(cmd.contains("task_id=$(basename"))
    }

    /**
     * 停止命令必须 kill tmux 并写 stopped。
     */
    @TestCase
    func buildStopTaskCommand_contains_kill_and_status() {
        let cmd = builder.buildStopTaskCommand("ccm_20260509_000001")
        @Expect(cmd.contains("tmux kill-session -t"))
        @Expect(cmd.contains("echo stopped >"))
        @Expect(cmd.contains("echo stopped"))
    }

    /**
     * 软删除命令必须仅写 deleted，不做 rm。
     */
    @TestCase
    func buildSoftDeleteCommand_only_mark_deleted() {
        let cmd = builder.buildSoftDeleteCommand("ccm_20260509_000001")
        @Expect(cmd.contains("echo deleted >"))
        @Expect(!cmd.contains("rm -rf"))
        @Expect(!cmd.contains("git worktree remove"))
    }

    /**
     * 非法 taskId 必须被拒绝。
     */
    @TestCase
    func invalid_task_id_should_be_rejected() {
        let cmd = builder.buildTaskStatusCommand("bad/id")
        @Expect(cmd.contains("invalid task_id"))
        @Expect(cmd.contains("exit 2"))
    }

    /**
     * 空 repoPath / 危险 repoPath 必须被拒绝。
     */
    @TestCase
    func invalid_repo_path_should_be_rejected() {
        let emptyRepoInput = TaskCommandInput(
            taskId: "ccm_20260509_000002",
            repoPath: "",
            worktreePath: "",
            branchName: "",
            tmuxSession: "",
            promptBase64: ShellEscape.base64Encode("hello"),
            mode: RunMode.run
        )
        let dangerRepoInput = TaskCommandInput(
            taskId: "ccm_20260509_000003",
            repoPath: "/tmp/repo;rm -rf /",
            worktreePath: "",
            branchName: "",
            tmuxSession: "",
            promptBase64: ShellEscape.base64Encode("hello"),
            mode: RunMode.run
        )

        let cmd1 = builder.buildCreateTaskCommand(emptyRepoInput)
        let cmd2 = builder.buildCreateTaskCommand(dangerRepoInput)

        @Expect(cmd1.contains("invalid repo_path"))
        @Expect(cmd2.contains("invalid repo_path"))
        @Expect(cmd1.contains("exit 2"))
        @Expect(cmd2.contains("exit 2"))
    }
}
