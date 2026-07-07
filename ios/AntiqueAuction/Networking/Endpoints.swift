import Foundation

/// 网络端点配置。
///
/// 服务器地址可在 **App 连接页直接填写**（持久化到 UserDefaults，键 `storageKey`）——
/// 换主机 / 换服务名都不必改代码重新编译。`serverURL` 在每次连接时实时读取该值。
///
/// 填写很宽松：可直接粘贴 Render / Railway 给的 `https://…` 网址，会自动转成 `wss://`；
/// 不写协议则默认补 `wss://`。本地明文调试填 `ws://localhost:3000`
/// （`ws://` 仍需在 Info.plist 配 `NSAllowsLocalNetworking`，详见 ios/README.md）。
enum Endpoints {
    /// UserDefaults 键；连接页的 `@AppStorage` 与下面的 `serverURL` 共用它。
    static let storageKey = "serverURLString"

    /// 未填写时的默认服务器（已指向线上 Render 部署；换服务器在连接页改即可）。
    static let defaultURLString = "wss://antique-auction-server.onrender.com"

    /// 生产环境 WebSocket 地址：实时读取用户在 App 里填写的值，规范化后返回。
    static var serverURL: URL {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? defaultURLString
        return normalized(raw) ?? normalized(defaultURLString) ?? URL(string: defaultURLString)!
    }

    /// 把用户输入规范成可用的 WebSocket URL：
    /// 去首尾空白；`https://`→`wss://`、`http://`→`ws://`；已是 `ws/wss` 原样保留；
    /// 不带协议则补 `wss://`。空串或无法解析时返回 `nil`。
    static func normalized(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let lower = s.lowercased()
        if lower.hasPrefix("https://") {
            s = "wss://" + s.dropFirst("https://".count)
        } else if lower.hasPrefix("http://") {
            s = "ws://" + s.dropFirst("http://".count)
        } else if !(lower.hasPrefix("wss://") || lower.hasPrefix("ws://")) {
            s = "wss://" + s
        }
        return URL(string: s)
    }
}
