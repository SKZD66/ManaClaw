import promptAction from '@ohos.promptAction';
import { ConnectionState, UiResult, TaskViewModel } from '../common/AppModel';
import { TaskViewModelImpl } from '../vm/TaskService';

class ConnectionStateImpl implements ConnectionState {
  name: string = ""; host: string = ""; port: string = "22"; username: string = ""; password: string = ""; defaultRepoPath: string = "";
}

@CustomDialog
struct ErrorDetailDialog {
  controller?: CustomDialogController;
  @Link title: string;
  @Link message: string;
  @Link raw: string;
  @State isExpanded: boolean = false;

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor(0xD94841).alignSelf(ItemAlign.Start)

      // 第一层：用户可读错误
      Text(this.message)
        .fontSize(15).fontColor(0x374151).alignSelf(ItemAlign.Start).lineHeight(22)

      // 展开/折叠 触发器
      Row() {
        Text(this.isExpanded ? '收起调试信息 (stderr) ▲' : '展开调试信息 (stderr) ▼')
          .fontSize(13).fontColor('#1F6FEB').fontWeight(FontWeight.Medium)
      }
      .width('100%').padding({ top: 8, bottom: 8 })
      .onClick(() => {
        animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
          this.isExpanded = !this.isExpanded;
        });
      })

      // 第二层：原始 stderr 调试信息
      if (this.isExpanded) {
        Scroll() {
          Text(this.raw)
            .fontSize(13).fontFamily('monospace').fontColor(0x4B5563)
            .textAlign(TextAlign.Start).width('100%')
            .copyOption(CopyOptions.LocalDevice)
        }
        .height(160).width('100%').align(Alignment.TopStart)
        .backgroundColor(0xF3F4F6).padding(12).borderRadius(8)
      }

      Button('关闭')
        .width('100%').height(40).backgroundColor(0xE5E7EB).fontColor(0x374151).margin({ top: 8 })
        .onClick(() => { this.controller?.close(); })
    }
    .width('85%').padding(24).backgroundColor(Color.White).borderRadius(16)
    .shadow({ radius: 24, color: 'rgba(0,0,0,0.1)', offsetY: 8 })
  }
}

@CustomDialog
struct ConnectionDialog {
  controller?: CustomDialogController;
  @Link cName: string; @Link cHost: string; @Link cPort: string;
  @Link cUser: string; @Link cPass: string; @Link cRepo: string;
  @Prop isEditMode: boolean = false;

  onSave: () => void = () => {};
  onTest: () => Promise<void> = async () => {};
  onInit: () => Promise<void> = async () => {};

  @State isTesting: boolean = false;
  @State isInitializing: boolean = false;

  isConfigComplete(): boolean {
    return this.cName.trim().length > 0 && this.cHost.trim().length > 0 &&
      this.cPort.trim().length > 0 && this.cUser.trim().length > 0 &&
      this.cPass.length > 0 ;
  }

  @Builder
  renderInputItem(label: string, placeholder: string, value: string, onChange: (val: string) => void, isPassword: boolean = false, disabled: boolean = false) {
    Column() {
      Text(label).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#4B5563').margin({ bottom: 6 }).alignSelf(ItemAlign.Start)
      TextInput({ text: value, placeholder: placeholder })
        .type(isPassword ? InputType.Password : InputType.Normal).enabled(!disabled).onChange(onChange)
        .width('100%').height(40).backgroundColor('#F3F4F6').borderRadius(8)
    }.width('100%')
  }

  build() {
    Column({space: 16}) {
      Text(this.isEditMode ? '编辑 SSH 配置' : '添加新服务器').fontSize(20).fontWeight(FontWeight.Bold).alignSelf(ItemAlign.Start)

      Scroll() {
        Column({ space: 14 }) {
          this.renderInputItem('配置名称 (唯一标识)', '例如: 编译机1号', this.cName, (v) => this.cName = v, false, this.isEditMode)

          Row({ space: 12 }) {
            Column() { this.renderInputItem('主机地址 (Host)', '192.168.x.x', this.cHost, (v) => this.cHost = v) }.layoutWeight(7)
            Column() { this.renderInputItem('端口', '22', this.cPort, (v) => this.cPort = v) }.layoutWeight(3)
          }.width('100%')

          Row({ space: 12 }) {
            Column() { this.renderInputItem('用户名', 'root', this.cUser, (v) => this.cUser = v) }.layoutWeight(1)
            Column() { this.renderInputItem('密码', '请输入密码', this.cPass, (v) => this.cPass = v, true) }.layoutWeight(1)
          }.width('100%')

          this.renderInputItem('默认源码路径', '例如: /home/ubuntu/repo', this.cRepo, (v) => this.cRepo = v)
        }
      }
      .constraintSize({ maxHeight: 360 })
      .scrollBar(BarState.Auto)

      Column({space: 10}) {
        Button() {
          Row({ space: 8 }) {
            if (this.isTesting) { LoadingProgress().width(18).height(18).color(Color.White) }
            Text(this.isTesting ? '正在测试...' : '测试连接').fontColor(Color.White).fontSize(14)
          }
        }.width('100%').height(40).enabled(!this.isTesting).backgroundColor('#6B7280')
        .onClick(async () => {
          this.isTesting = true; await this.onTest(); this.isTesting = false;
        })

        Button() {
          Row({ space: 8 }) {
            if (this.isInitializing) { LoadingProgress().width(18).height(18).color(Color.White) }
            Text(this.isInitializing ? '正在初始化...' : '初始化远端环境').fontColor(Color.White).fontSize(14)
          }
        }.width('100%').height(40).enabled(!this.isInitializing && this.isConfigComplete()).backgroundColor('#2B8A3E')
        .onClick(async () => {
          this.isInitializing = true; await this.onInit(); this.isInitializing = false;
        })

        Row({space: 12}) {
          Button('取消').layoutWeight(1).height(40).backgroundColor('#E5E7EB').fontColor('#374151').onClick(() => this.controller?.close())
          Button('保存配置').layoutWeight(1).height(40).backgroundColor('#1F6FEB').enabled(this.isConfigComplete()).onClick(() => this.onSave())
        }.width('100%').margin({top: 4})
      }
    }
    .padding(24).backgroundColor(Color.White).borderRadius(16)
  }
}

@Component
export struct ConnectionPage {
  private vm: TaskViewModel = new TaskViewModelImpl();

  @State servers: ConnectionState[] = [];
  @State activeName: string = "";

  @State dName: string = ""; @State dHost: string = ""; @State dPort: string = "22";
  @State dUser: string = ""; @State dPass: string = ""; @State dRepo: string = "";
  @State isEditMode: boolean = false;

  @State errTitle: string = "";
  @State errMsg: string = "";
  @State errRaw: string = "";

  errorDialogController: CustomDialogController = new CustomDialogController({
    builder: ErrorDetailDialog({
      title: $errTitle,
      message: $errMsg,
      raw: $errRaw
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  // 表单 DialogController
  dialogController: CustomDialogController = new CustomDialogController({
    builder: ConnectionDialog({
      cName: $dName, cHost: $dHost, cPort: $dPort, cUser: $dUser, cPass: $dPass, cRepo: $dRepo, isEditMode: this.isEditMode,
      onSave: () => {
        let s = new ConnectionStateImpl();
        s.name = this.dName; s.host = this.dHost; s.port = this.dPort;
        s.username = this.dUser; s.password = this.dPass; s.defaultRepoPath = this.dRepo;
        let res = this.vm.saveConnection(s);
        promptAction.showToast({ message: res.msg });
        this.refreshList();
        this.dialogController.close();
      },
      onTest: async () => {
        let s = new ConnectionStateImpl();
        s.name = this.dName; s.host = this.dHost; s.port = this.dPort;
        s.username = this.dUser; s.password = this.dPass; s.defaultRepoPath = this.dRepo;
        let res = await this.vm.testConnection(s);
        if (res.ok) {
          promptAction.showToast({ message: res.msg });
        } else {
          this.errTitle = "连接失败";
          this.errMsg = res.msg;
          let rawErr = (res.raw && res.raw.length > 0) ? res.raw : "无详细 stderr";
          this.errRaw = this.sanitizeError(rawErr, s.password);
          this.errorDialogController.open();
        }
      },
      onInit: async () => {
        let s = new ConnectionStateImpl();
        s.name = this.dName; s.host = this.dHost; s.port = this.dPort;
        s.username = this.dUser; s.password = this.dPass; s.defaultRepoPath = this.dRepo;
        let res = await this.vm.initRemote(s);
        if (res.ok) {
          promptAction.showToast({ message: res.msg });
        } else {
          this.errTitle = "初始化失败";
          this.errMsg = res.msg;
          let rawErr = (res.raw && res.raw.length > 0) ? res.raw : "无详细 stderr";
          this.errRaw = this.sanitizeError(rawErr, s.password);
          this.errorDialogController.open();
        }
      }
    }),
    alignment: DialogAlignment.Center, autoCancel: false, customStyle: true
  });

  aboutToAppear() {
    this.refreshList();
  }

  refreshList() {
    this.servers = this.vm.loadAllConnections();
    this.activeName = this.vm.loadConnection().name;
  }

  sanitizeError(rawError: string, pass: string): string {
    if (!rawError || rawError.length === 0) return "未知错误";
    if (!pass || pass.length === 0) return rawError;
    return rawError.split(pass).join('********');
  }

  openDialog(conn?: ConnectionState) {
    if (conn) {
      this.isEditMode = true; this.dName = conn.name; this.dHost = conn.host;
      this.dPort = conn.port; this.dUser = conn.username; this.dPass = conn.password; this.dRepo = conn.defaultRepoPath;
    } else {
      this.isEditMode = false; this.dName = ""; this.dHost = ""; this.dPort = "22";
      this.dUser = "root"; this.dPass = ""; this.dRepo = "";
    }
    this.dialogController.open();
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Text('SSH 服务器管理')
          .fontSize(22).fontWeight(FontWeight.Bold).alignSelf(ItemAlign.Start)
          .padding({ left: 24, top: 24, bottom: 16 })

        if (this.servers.length === 0) {
          Column() {
            Text('暂无配置，请点击右下角添加服务器').fontSize(14).fontColor('#9CA3AF')
          }.justifyContent(FlexAlign.Center).layoutWeight(1).width('100%')
        } else {
          List({ space: 16 }) {
            ForEach(this.servers, (item: ConnectionState, index: number) => {
              ListItem() {
                Row() {
                  Column({ space: 6 }) {
                    Row({ space: 8 }) {
                      Text(item.name).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#111827')
                      if (item.name === this.activeName) {
                        Text('当前激活')
                          .fontSize(10).fontColor('#1F6FEB').backgroundColor('#EFF6FF')
                          .padding({left:6, right:6, top:2, bottom:2}).borderRadius(4)
                      }
                    }.alignItems(VerticalAlign.Center)
                    Text(`${item.username}@${item.host}:${item.port}`).fontSize(13).fontColor('#6B7280')
                  }
                  .alignItems(HorizontalAlign.Start).layoutWeight(1)

                  Row({ space: 12 }) {
                    Button('编辑').fontSize(14).height(32).backgroundColor(Color.Transparent).fontColor('#1F6FEB')
                      .onClick(() => { this.openDialog(item); })
                    Button('删除').fontSize(14).height(32).backgroundColor(Color.Transparent).fontColor('#D94841')
                      .onClick(() => {
                        let r = this.vm.deleteConnection(item.name);
                        promptAction.showToast({message: r.msg});
                        this.refreshList();
                      })
                  }
                }
                .width('100%').padding(20).backgroundColor(Color.White).borderRadius(16)
                .shadow({ radius: 12, color: 'rgba(0,0,0,0.04)', offsetY: 4 })
                .onClick(() => {
                  if (item.name !== this.activeName) {
                    let r = this.vm.setActiveConnection(item.name);
                    promptAction.showToast({message: r.msg});
                    this.refreshList();
                  }
                })
              }
            }, (item: ConnectionState, i: number) => item.name + i)
          }
          .width('100%').layoutWeight(1).padding({ left: 20, right: 20, bottom: 80 })
        }
      }
      .width('100%').height('100%').backgroundColor('#F9FAFB')

      Button('+')
        .type(ButtonType.Circle).width(60).height(60)
        .fontSize(32).fontWeight(FontWeight.Normal).fontColor(Color.White)
        .backgroundColor('#1F6FEB').margin(24)
        .shadow({ radius: 16, color: 'rgba(31, 111, 235, 0.4)', offsetY: 6 })
        .onClick(() => { this.openDialog(); })
    }.width('100%').height('100%')
  }
}