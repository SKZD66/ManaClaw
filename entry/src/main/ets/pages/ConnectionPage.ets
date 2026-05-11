import { ConnectionState } from '../common/AppModel'

@Component
export struct ConnectionPage {
  @Link conn: ConnectionState
  msg: string = ''
  raw: string = ''
  onSave: () => void = () => {}
  onTest: () => void = () => {}
  onInit: () => void = () => {}
  onEnter: () => void = () => {}

  private canInit(): boolean {
    return this.conn.host.length > 0 &&
      this.conn.port.length > 0 &&
      this.conn.username.length > 0 &&
      this.conn.password.length > 0 &&
      this.conn.defaultRepoPath.length > 0
  }

  @Builder
  private MsgBlock() {
    if (this.msg.length > 0) {
      Text(this.msg).fontSize(13).fontColor(0x1F6FEB).width('100%')
    }
    if (this.raw.length > 0) {
      TextArea({ text: this.raw }).height(110).width('100%')
    }
  }

  build() {
    Scroll() {
      Column({ space: 8 }) {
        Text('ConnectionPage').fontSize(20).fontWeight(FontWeight.Bold)

        TextInput({ text: this.conn.name, placeholder: 'Name' })
          .width('100%')
          .onChange((v: string) => {
            this.conn = {
              name: v,
              host: this.conn.host,
              port: this.conn.port,
              username: this.conn.username,
              password: this.conn.password,
              defaultRepoPath: this.conn.defaultRepoPath
            }
          })

        TextInput({ text: this.conn.host, placeholder: 'Host / IP' })
          .width('100%')
          .onChange((v: string) => {
            this.conn = {
              name: this.conn.name,
              host: v,
              port: this.conn.port,
              username: this.conn.username,
              password: this.conn.password,
              defaultRepoPath: this.conn.defaultRepoPath
            }
          })

        TextInput({ text: this.conn.port, placeholder: 'Port' })
          .width('100%')
          .onChange((v: string) => {
            this.conn = {
              name: this.conn.name,
              host: this.conn.host,
              port: v,
              username: this.conn.username,
              password: this.conn.password,
              defaultRepoPath: this.conn.defaultRepoPath
            }
          })

        TextInput({ text: this.conn.username, placeholder: 'Username' })
          .width('100%')
          .onChange((v: string) => {
            this.conn = {
              name: this.conn.name,
              host: this.conn.host,
              port: this.conn.port,
              username: v,
              password: this.conn.password,
              defaultRepoPath: this.conn.defaultRepoPath
            }
          })

        TextInput({ text: this.conn.password, placeholder: 'Password' })
          .type(InputType.Password)
          .width('100%')
          .onChange((v: string) => {
            this.conn = {
              name: this.conn.name,
              host: this.conn.host,
              port: this.conn.port,
              username: this.conn.username,
              password: v,
              defaultRepoPath: this.conn.defaultRepoPath
            }
          })

        TextInput({ text: this.conn.defaultRepoPath, placeholder: 'Default Repo Path' })
          .width('100%')
          .onChange((v: string) => {
            this.conn = {
              name: this.conn.name,
              host: this.conn.host,
              port: this.conn.port,
              username: this.conn.username,
              password: this.conn.password,
              defaultRepoPath: v
            }
          })

        Row() {
          Button('保存').width('32%').height(36).onClick(() => this.onSave())
          Blank().width('2%')
          Button('测试连接').width('32%').height(36).onClick(() => this.onTest())
          Blank().width('2%')
          Button('进任务页').width('32%').height(36).onClick(() => this.onEnter())
        }.width('100%')

        Button('初始化远端环境')
          .width('100%')
          .height(36)
          .enabled(this.canInit())
          .onClick(() => this.onInit())

        this.MsgBlock()
      }
      .padding(12)
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }
}