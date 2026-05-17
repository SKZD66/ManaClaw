import dataPreferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

import {
  ConnectionState, TaskCardState, TaskDetailState, LogPanelState,
  NewTaskInput, UiResult, TaskViewModel
} from '../common/AppModel'

import { requireCJLib } from "libark_interop_loader.so"
import { CustomLib, CjTaskDetailState, CjResultTaskDetail } from "libark_interop_api.so"

const cjLib = requireCJLib("libohos_app_cangjie_entry.so") as CustomLib

// 【核心支持】：安全结构体声明
export interface ServerJsonData {
  name: string; host: string; port: string; username: string; password: string; defaultRepoPath: string;
}
export interface TaskJsonData {
  id: string; title: string; status: string; repoPath: string; branchName: string; createdAt: number; updatedAt: number;
}

class ServerJsonDataImpl implements ServerJsonData {
  name: string = ""; host: string = ""; port: string = ""; username: string = ""; password: string = ""; defaultRepoPath: string = "";
}

class ConnectionStateImpl implements ConnectionState {
  name: string = ""; host: string = ""; port: string = ""; username: string = ""; password: string = ""; defaultRepoPath: string = "";
}

class TaskCardStateImpl implements TaskCardState {
  title: string = ""; taskId: string = ""; status: string = ""; repo: string = ""; branch: string = ""; live: boolean = false; createdAt: string = ""; updatedAt: string = ""; lastLog: string = "";
}

class TaskDetailStateImpl implements TaskDetailState {
  title: string = ""; taskId: string = ""; status: string = ""; repo: string = ""; branch: string = ""; live: boolean = false; createdAt: string = ""; updatedAt: string = ""; lastLog: string = ""; worktree: string = ""; tmuxSession: string = ""; exitCode: string = ""; logs: string = ""; rawLogs: string = ""; stderr: string = ""; gitSummary: string = "";
}

class LogPanelStateImpl implements LogPanelState {
  text: string = ""; raw: string = ""; stderr: string = "";
}

export class TaskViewModelImpl implements TaskViewModel {
  private static prefsCache: dataPreferences.Preferences | null = null;

  constructor() {}

  private getPrefs(): dataPreferences.Preferences {
    if (TaskViewModelImpl.prefsCache) { return TaskViewModelImpl.prefsCache; }
    let context = getContext();
    if (!context) throw new Error("Context is currently unavailable");
    TaskViewModelImpl.prefsCache = dataPreferences.getPreferencesSync(context as common.Context, { name: 'SshAgentConfigPreferences' });
    return TaskViewModelImpl.prefsCache;
  }

  loadAllConnections(): ConnectionState[] {
    try {
      let prefs = this.getPrefs();
      let jsonStr = prefs.getSync('serversList', '[]').toString();
      let arr = JSON.parse(jsonStr) as Array<ServerJsonData>;
      return arr.map((item: ServerJsonData) => {
        let s = new ConnectionStateImpl();
        s.name = item.name; s.host = item.host; s.port = item.port;
        s.username = item.username; s.password = item.password; s.defaultRepoPath = item.defaultRepoPath;
        return s;
      });
    } catch (err) { return []; }
  }

  loadConnection(): ConnectionState {
    let all = this.loadAllConnections();
    let prefs = this.getPrefs();
    let activeName = prefs.getSync('activeServerName', '').toString();

    let active = all.find(s => s.name === activeName);
    if (active) return active;
    if (all.length > 0) return all[0];
    return new ConnectionStateImpl();
  }

  saveConnection(input: ConnectionState): UiResult<boolean> {
    try {
      let all = this.loadAllConnections();
      let index = all.findIndex(s => s.name === input.name);
      if (index >= 0) { all[index] = input; } else { all.push(input); }

      let pureArr = all.map((s: ConnectionState) => {
        let obj = new ServerJsonDataImpl();
        obj.name = s.name; obj.host = s.host; obj.port = s.port;
        obj.username = s.username; obj.password = s.password; obj.defaultRepoPath = s.defaultRepoPath;
        return obj;
      });

      let prefs = this.getPrefs();
      prefs.putSync('serversList', JSON.stringify(pureArr));

      let activeName = prefs.getSync('activeServerName', '').toString();
      if (!activeName || (index === -1 && all.length === 1)) {
        prefs.putSync('activeServerName', input.name);
      }
      prefs.flushSync();
      return new UiResult<boolean>(true, "配置已保存至列表", "", true);
    } catch(err) {
      return new UiResult<boolean>(false, "保存失败", String(err), false);
    }
  }

  setActiveConnection(name: string): UiResult<boolean> {
    try {
      let prefs = this.getPrefs();
      prefs.putSync('activeServerName', name);
      prefs.flushSync();
      return new UiResult<boolean>(true, "已切换为当前服务器", "", true);
    } catch(err) {
      return new UiResult<boolean>(false, "切换失败", String(err), false);
    }
  }

  deleteConnection(name: string): UiResult<boolean> {
    try {
      let all = this.loadAllConnections();
      all = all.filter(s => s.name !== name);

      let pureArr = all.map((s: ConnectionState) => {
        let obj = new ServerJsonDataImpl();
        obj.name = s.name; obj.host = s.host; obj.port = s.port;
        obj.username = s.username; obj.password = s.password; obj.defaultRepoPath = s.defaultRepoPath;
        return obj;
      });

      let prefs = this.getPrefs();
      prefs.putSync('serversList', JSON.stringify(pureArr));

      let activeName = prefs.getSync('activeServerName', '').toString();
      if (activeName === name) {
        prefs.putSync('activeServerName', all.length > 0 ? all[0].name : "");
      }
      prefs.flushSync();
      return new UiResult<boolean>(true, "删除成功", "", true);
    } catch(err) {
      return new UiResult<boolean>(false, "删除失败", String(err), false);
    }
  }

  async testConnection(input: ConnectionState): Promise<UiResult<boolean>> {
    const res = await cjLib.cjTestConnection(input.host, input.port, input.username, input.password);
    return new UiResult<boolean>(res.ok, res.msg, res.raw, res.data);
  }

  async initRemote(input: ConnectionState): Promise<UiResult<boolean>> {
    const res = await cjLib.cjInitRemote(input.host, input.port, input.username, input.password);
    return new UiResult<boolean>(res.ok, res.msg, res.raw, res.data);
  }

  async loadTasks(): Promise<UiResult<TaskCardState[]>> {
    const conn = this.loadConnection();
    if (!conn.host) return new UiResult<TaskCardState[]>(false, "未配置服务器", "");
    const res = await cjLib.cjLoadTasks(conn.host, conn.port, conn.username, conn.password);

    if (res.ok) {
      try {
        const tasksJson = JSON.parse(res.data) as Array<TaskJsonData>;
        const taskCards: TaskCardState[] = tasksJson.map((t: TaskJsonData) => {
          let card = new TaskCardStateImpl();
          card.title = t.title; card.taskId = t.id; card.status = t.status;
          card.repo = t.repoPath; card.branch = t.branchName; card.live = t.status === 'running';
          card.createdAt = t.createdAt.toString(); card.updatedAt = t.updatedAt.toString(); card.lastLog = '';
          return card;
        });
        return new UiResult<TaskCardState[]>(true, res.msg, res.raw, taskCards);
      } catch (err) { return new UiResult<TaskCardState[]>(false, "JSON Parsing error", String(err)); }
    }
    return new UiResult<TaskCardState[]>(res.ok, res.msg, res.raw);
  }

  async submitTask(input: NewTaskInput): Promise<UiResult<TaskCardState>> {
    const conn = this.loadConnection();
    if (!conn.host) return new UiResult<TaskCardState>(false, "未配置服务器", "");
    const res = await cjLib.cjSubmitTask(conn.host, conn.port, conn.username, conn.password, input.repoPath, input.title, input.prompt, input.mode);

    let card: TaskCardState | undefined = undefined;
    if (res.ok && res.data !== undefined) {
      card = new TaskCardStateImpl();
      card.title = res.data.title; card.taskId = res.data.taskId; card.status = res.data.status;
      card.repo = res.data.repo; card.branch = res.data.branch; card.live = res.data.live;
      card.createdAt = res.data.createdAt; card.updatedAt = res.data.updatedAt; card.lastLog = res.data.lastLog;
    }
    return new UiResult<TaskCardState>(res.ok, res.msg, res.raw, card);
  }

  async openTask(taskId: string): Promise<UiResult<TaskDetailState>> {
    const res = await cjLib.cjOpenTask(taskId);
    return this.mapDetailResult(res);
  }

  async refreshTask(taskId: string): Promise<UiResult<TaskDetailState>> {
    const conn = this.loadConnection();
    if (!conn.host) return new UiResult<TaskDetailState>(false, "未配置服务器", "");
    const res = await cjLib.cjRefreshTask(conn.host, conn.port, conn.username, conn.password, taskId);
    return this.mapDetailResult(res);
  }

  async refreshLogs(taskId: string): Promise<UiResult<LogPanelState>> {
    const conn = this.loadConnection();
    if (!conn.host) return new UiResult<LogPanelState>(false, "未配置服务器", "");
    const res = await cjLib.cjRefreshLogs(conn.host, conn.port, conn.username, conn.password, taskId);
    let panel: LogPanelState | undefined = undefined;
    if (res.ok && res.data !== undefined) {
      panel = new LogPanelStateImpl();
      panel.text = res.data.text; panel.raw = res.data.raw; panel.stderr = res.data.stderr;
    }
    return new UiResult<LogPanelState>(res.ok, res.msg, res.raw, panel);
  }

  async stopTask(taskId: string): Promise<UiResult<boolean>> {
    const conn = this.loadConnection();
    if (!conn.host) return new UiResult<boolean>(false, "未配置服务器", "");
    const res = await cjLib.cjStopTask(conn.host, conn.port, conn.username, conn.password, taskId);
    return new UiResult<boolean>(res.ok, res.msg, res.raw, res.data);
  }

  async deleteTask(taskId: string): Promise<UiResult<boolean>> {
    const conn = this.loadConnection();
    if (!conn.host) return new UiResult<boolean>(false, "未配置服务器", "");
    const res = await cjLib.cjSoftDeleteTask(conn.host, conn.port, conn.username, conn.password, taskId);
    return new UiResult<boolean>(res.ok, res.msg, res.raw, res.data);
  }

  async loadGitSummary(taskId: string): Promise<UiResult<string>> {
    const conn = this.loadConnection();
    if (!conn.host) return new UiResult<string>(false, "未配置服务器", "");
    const res = await cjLib.cjLoadGitSummary(conn.host, conn.port, conn.username, conn.password, taskId);
    return new UiResult<string>(res.ok, res.msg, res.raw, res.data);
  }

  private mapDetailResult(res: CjResultTaskDetail): UiResult<TaskDetailState> {
    let detail: TaskDetailState = new TaskDetailStateImpl();
    if (res.ok && res.data !== undefined) {
      const cjData: CjTaskDetailState = res.data;
      detail.title = cjData.title; detail.taskId = cjData.taskId; detail.status = cjData.status;
      detail.repo = cjData.repo; detail.branch = cjData.branch; detail.live = cjData.live;
      detail.createdAt = cjData.createdAt; detail.updatedAt = cjData.updatedAt; detail.lastLog = cjData.lastLog;
      detail.worktree = cjData.worktree; detail.tmuxSession = cjData.tmuxSession; detail.exitCode = cjData.exitCode;
      detail.logs = cjData.logs; detail.rawLogs = cjData.rawLogs; detail.stderr = cjData.stderr; detail.gitSummary = cjData.gitSummary;
      return new UiResult<TaskDetailState>(true, res.msg, res.raw, detail);
    }
    return new UiResult<TaskDetailState>(false, res.msg, res.raw, detail);
  }
}