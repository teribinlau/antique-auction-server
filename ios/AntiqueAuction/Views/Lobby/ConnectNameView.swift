import SwiftUI

/// 首屏：输入昵称并连接服务器。昵称存 UserDefaults，下次自动带出。
struct ConnectNameView: View {
    @ObservedObject var client: GameClient

    /// 昵称持久化到 UserDefaults。
    @AppStorage("playerName") private var playerName: String = ""
    /// 服务器地址持久化到 UserDefaults（与 `Endpoints.serverURL` 共用同一个键）。
    /// 换主机 / 换服务名直接在这里改，不必动代码重新编译。
    @AppStorage(Endpoints.storageKey) private var serverURLString: String = Endpoints.defaultURLString
    @FocusState private var nameFocused: Bool

    private var canConnect: Bool {
        !playerName.trimmingCharacters(in: .whitespaces).isEmpty
            && Endpoints.normalized(serverURLString) != nil
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                Text("古董拍卖")
                    .font(.largeTitle.weight(.bold))
                Text("一场关于眼力、诈唬与运气的较量")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("你的昵称")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("输入昵称", text: $playerName)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .submitLabel(.go)
                    .onSubmit(connect)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("服务器地址")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("wss://你的应用.onrender.com", text: $serverURLString)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit(connect)
                Text("可直接粘贴 Render 的 https 地址，会自动转成 wss")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Button(action: connect) {
                HStack {
                    if client.connection == .connecting {
                        ProgressView()
                            .tint(.black)
                    }
                    Text(client.connection == .connecting ? "连接中…" : "进入大厅")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canConnect ? Color.accentColor : Color.gray)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canConnect || client.connection == .connecting)
            .padding(.horizontal)

            if client.connection == .disconnected {
                if let url = Endpoints.normalized(serverURLString) {
                    Text("将连接到 \(url.absoluteString)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("请输入有效的服务器地址")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                }
            }

            Spacer()

            // 音效 / 触感 / 减弱动画开关（小设置入口）。
            VStack(spacing: 6) {
                FeedbackToggleButtons(showMotion: true)
                Text("音效 · 触感 · 动画")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            Spacer()
        }
        .onAppear {
            if playerName.isEmpty { nameFocused = true }
        }
    }

    private func connect() {
        let trimmed = playerName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        client.setPlayerName(trimmed)
        client.connect()
    }
}
