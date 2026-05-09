package ohos_app_cangjie_entry

import encoding.json.*

class ClaudeLogFormatter {
    public static func format(jsonl: String): String {
        var out = ""
        for (line in jsonl.split("\n")) {
            let text = renderLineSafe(line)
            if (text.size > 0) {
                if (out.size > 0) {
                    out += "\n\n"
                }
                out += text
            }
        }
        return if (out.size > 0) { out } else { "<empty>" }
    }

    private static func renderLineSafe(line: String): String {
        if (line.size == 0) {
            return ""
        }
        try {
            return renderObject(JsonValue.fromStr(line).asObject(), line)
        } catch (e: Exception) {
            return clip(line, 1200)
        }
    }

    private static func renderObject(o: JsonObject, raw: String): String {
        let kind = str(o, "type")
        if (kind == "system") {
            return "SYSTEM ${str(o, "subtype")}\n  cwd: ${str(o, "cwd")}\n  model: ${str(o, "model")}\n  session: ${str(o, "session_id")}"
        }
        if (kind == "result") {
            return "RESULT ${str(o, "subtype")}\n  stop: ${str(o, "stop_reason")}\n  cost: ${rawValue(o, "total_cost_usd")}\n  ${indent(clip(str(o, "result"), 1800))}"
        }
        return match (contentObject(o)) {
            case Some(c) => renderContent(c)
            case None => clip(raw, 1200)
        }
    }

    private static func renderContent(c: JsonObject): String {
        let kind = str(c, "type")
        if (kind == "thinking") {
            return "THINK\n  ${indent(clip(str(c, "thinking"), 1200))}"
        }
        if (kind == "tool_use") {
            return renderToolUse(c)
        }
        if (kind == "tool_result") {
            return "TOOL RESULT\n  ${indent(clip(str(c, "content"), 1800))}"
        }
        if (kind == "text") {
            return "ASSISTANT\n  ${indent(clip(str(c, "text"), 1800))}"
        }
        return c.toString()
    }

    private static func renderToolUse(c: JsonObject): String {
        let input = obj(c, "input")
        let command = match (input) { case Some(i) => str(i, "command") case None => "" }
        let desc = match (input) { case Some(i) => str(i, "description") case None => "" }
        let path = match (input) { case Some(i) => str(i, "file_path") case None => "" }
        let pattern = match (input) { case Some(i) => str(i, "pattern") case None => "" }
        let url = match (input) { case Some(i) => str(i, "url") case None => "" }
        let prompt = match (input) { case Some(i) => str(i, "prompt") case None => "" }
        var out = "TOOL ${str(c, "name")}"
        if (desc.size > 0) { out += "\n  ${desc}" }
        if (command.size > 0) { out += "\n  $ ${indent(clip(command, 1200))}" }
        if (path.size > 0) { out += "\n  file: ${path}" }
        if (pattern.size > 0) { out += "\n  pattern: ${pattern}" }
        if (url.size > 0) { out += "\n  url: ${url}" }
        if (prompt.size > 0) { out += "\n  prompt: ${indent(clip(prompt, 1200))}" }
        return out
    }

    private static func contentObject(o: JsonObject): Option<JsonObject> {
        return match (obj(o, "message")) {
            case Some(m) =>
                match (m.get("content")) {
                    case Some(v) =>
                        let a = v.asArray()
                        if (a.size() > 0) { Some(a[0].asObject()) } else { None }
                    case None => None
                }
            case None => None
        }
    }

    private static func str(o: JsonObject, key: String): String {
        return match (o.get(key)) {
            case Some(v) =>
                try {
                    v.asString().getValue()
                } catch (e: Exception) {
                    v.toString()
                }
            case None => ""
        }
    }

    private static func rawValue(o: JsonObject, key: String): String {
        return match (o.get(key)) {
            case Some(v) => v.toString()
            case None => ""
        }
    }

    private static func obj(o: JsonObject, key: String): Option<JsonObject> {
        return match (o.get(key)) {
            case Some(v) => Some(v.asObject())
            case None => None
        }
    }

    private static func indent(s: String): String {
        return s.replace("\n", "\n  ")
    }

    private static func clip(s: String, max: Int64): String {
        return if (s.size > max) { s[0..max] + "\n  ..." } else { s }
    }
}
