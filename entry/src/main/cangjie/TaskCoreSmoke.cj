/**
 * Created on 2026/5/10
 */
package ohos_app_cangjie_entry
  import std.time.*

  main(): Int64 {
      let now = DateTime.now().toUnixTimeStamp().toSeconds()
      let store = TaskStore("taskcore_test_data")
      let gateway = FakeRemoteTaskGateway()
      let service = TaskService(store, gateway)

      let server = ServerConfig(
          "s1", "dev", "127.0.0.1", 22, "root", "pw-ref", "/repo", now, now
      )

      let r1 = service.submitTask(server, "/repo", "demo-title", "demo-prompt",
  RunMode.run)
      println("submit isOk = ${r1.isOk}")

      if (let Some(task) <- r1.value) {
          println("taskId = ${task.id}")
          println("branch = ${task.branchName}")
          println("tmux = ${task.tmuxSession}")
          println("remoteDir = ${task.remoteTaskDir}")
          println("worktree = ${task.worktreePath}")

          let r2 = service.refreshTask(task.id)
          println("refresh isOk = ${r2.isOk}")

          let r3 = service.stopTask(task.id)
          println("stop isOk = ${r3.isOk}")

          let r4 = service.softDeleteTask(task.id)
          println("delete isOk = ${r4.isOk}")
      }

      return 0
  }