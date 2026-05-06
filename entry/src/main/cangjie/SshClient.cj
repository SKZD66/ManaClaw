package ohos_app_cangjie_entry

internal import ohos.base.CStringExtend

foreign func cc_ssh_connect(host: CString, port: Int32, user: CString, password: CString, timeoutMs: Int32): Int32
foreign func cc_ssh_exec(command: CString, timeoutMs: Int32): Int32
foreign func cc_ssh_disconnect(): Int32
foreign func cc_ssh_stdout(): CString
foreign func cc_ssh_stderr(): CString
foreign func cc_ssh_last_error(): CString

class ExecResult {
    let code: Int32
    let stdout: String
    let stderr: String

    public init(code: Int32, stdout: String, stderr: String) {
        this.code = code
        this.stdout = stdout
        this.stderr = stderr
    }
}

class SshClient {
    public func execEchoOk(host: String, port: Int32, user: String, password: String): ExecResult {
        unsafe {
            let cHost = LibC.mallocCString(host)
            let cUser = LibC.mallocCString(user)
            let cPassword = LibC.mallocCString(password)
            let cCommand = LibC.mallocCString("echo ok")

            let connected = cc_ssh_connect(cHost, port, cUser, cPassword, 3000)
            cHost.free()
            cUser.free()
            cPassword.free()

            if (connected != 0) {
                let err = cc_ssh_last_error().toString()
                cc_ssh_disconnect()
                cCommand.free()
                return ExecResult(connected, "", err)
            }

            let code = cc_ssh_exec(cCommand, 3000)
            cCommand.free()
            let out = cc_ssh_stdout().toString()
            let err = cc_ssh_stderr().toString()
            cc_ssh_disconnect()

            if (code < 0 && err.size == 0) {
                return ExecResult(code, out, cc_ssh_last_error().toString())
            }
            return ExecResult(code, out, err)
        }
    }
}
