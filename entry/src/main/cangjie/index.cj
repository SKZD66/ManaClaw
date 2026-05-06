package ohos_app_cangjie_entry

internal import ohos.base.LengthProp
internal import ohos.component.Column
internal import ohos.component.Row
internal import ohos.component.Button
internal import ohos.component.Text
internal import ohos.component.TextInput
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

@Entry
@Component
class EntryView {
    @State
    var host: String = ""
    @State
    var portText: String = "22"
    @State
    var username: String = ""
    @State
    var password: String = ""
    @State
    var result: String = "输入服务器信息后点击测试连接"

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

    func build() {
        Row {
            Column {
                Text("CC-Flow SSH")
                    .fontSize(28)
                    .height(56)
                TextInput(placeholder: "Host / IP", text: host)
                    .onChange { value => host = value; () }
                    .height(56)
                    .width(100.percent)
                TextInput(placeholder: "Port", text: portText)
                    .onChange { value => portText = value; () }
                    .height(56)
                    .width(100.percent)
                TextInput(placeholder: "Username", text: username)
                    .onChange { value => username = value; () }
                    .height(56)
                    .width(100.percent)
                TextInput(placeholder: "Password", text: password)
                    .onChange { value => password = value; () }
                    .height(56)
                    .width(100.percent)
                Button("测试连接")
                    .onClick { evt => testConnection() }
                    .height(56)
                    .width(100.percent)
                Text(result)
                    .fontSize(16)
                    .width(100.percent)
            }.width(100.percent).height(100.percent)
        }.height(100.percent)
    }
}

public func manualAppEntry(): Bool {
    let view = EntryView(Option<CustomView>.None)
    loadNativeView(view)
    return true
}

let MANUAL_ENTRY_REGISTER_RESULT = CJEntry.getInstance().registerEntry("MainPage", manualAppEntry)
