package ohos_app_cangjie_entry

main(): Int64 {
    let builder = CommandBuilder()

    let taskIdRun = "ccm-qa-000001"
    let taskIdPlan = "ccm-qa-000002"
    let repo = "/root/projects/ccflow-test-repo/"
    let prompt = "请输出当前仓库状态并结束"
    let promptB64 = ShellEscape.base64Encode(prompt)

    let inputRun = TaskCommandInput(taskIdRun, repo, "", "", "", promptB64, RunMode.run)

    let inputPlan = TaskCommandInput(taskIdPlan, repo, "", "", "", promptB64, RunMode.plan)

    println("=== INIT ===")
    println(builder.buildInitCommand())

    println("=== CREATE_RUN ===")
    println(builder.buildCreateTaskCommand(inputRun))

    println("=== START_RUN ===")
    println(builder.buildStartTaskCommand(inputRun))

    println("=== CREATE_PLAN ===")
    println(builder.buildCreateTaskCommand(inputPlan))

    println("=== START_PLAN ===")
    println(builder.buildStartTaskCommand(inputPlan))

    println("=== LIST ===")
    println(builder.buildListTasksCommand())

    println("=== STATUS_RUN ===")
    println(builder.buildTaskStatusCommand(taskIdRun))

    println("=== TAIL_LOG_RUN ===")
    println(builder.buildTailLogCommand(taskIdRun, 200))

    println("=== TAIL_STDERR_RUN ===")
    println(builder.buildTailStderrCommand(taskIdRun))

    println("=== GIT_SUMMARY_RUN ===")
    println(builder.buildGitSummaryCommand(taskIdRun))

    println("=== STOP_RUN ===")
    println(builder.buildStopTaskCommand(taskIdRun))

    println("=== SOFT_DELETE_RUN ===")
    println(builder.buildSoftDeleteCommand(taskIdRun))

    return 0
}
