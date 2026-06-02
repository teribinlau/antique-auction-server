import Foundation

/// 网络端点配置。
///
/// 部署后把 `serverURL` 换成你的 Railway 域名（wss://，真机/模拟器都能直连）。
///
/// 本地调试：改用下面注释里的 `ws://localhost:3000`（server.js 默认监听 3000）。
/// 注意 ws:// 是明文，iOS ATS 默认拦截 —— 需要在 Info.plist 里加
/// `NSAppTransportSecurity > NSAllowsLocalNetworking = YES`（仅放行 localhost / *.local，
/// 不影响 App Store 审核）。详见 ios/README.md。
enum Endpoints {
    /// 生产环境 WebSocket 地址。⚠️ 部署后替换为你的真实域名。
    static let serverURL = URL(string: "wss://YOUR-APP.up.railway.app")!

    // 本地调试时改用这一行（并在 Info.plist 配置 NSAllowsLocalNetworking）：
    // static let serverURL = URL(string: "ws://localhost:3000")!
}
