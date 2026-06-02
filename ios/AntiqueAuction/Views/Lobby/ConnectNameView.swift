import SwiftUI

/// 首屏：输入昵称并连接服务器。昵称存 UserDefaults，下次自动带出。
struct ConnectNameView: View {
    @ObservedObject var client: GameClient

    /// 昵称持久化到 UserDefaults。
    @AppStorage("playerName") private var playerName: String = ""
    @FocusState private var nameFocused: Bool

    private var canConnect: Bool {
        !playerName.trimmingCharacters(in: .whitespaces).isEmpty
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

            Button(action: connect) {
                HStack {
                    if client.connection == .connecting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(client.connection == .connecting ? "连接中…" : "进入大厅")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canConnect ? Color.accentColor : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canConnect || client.connection == .connecting)
            .padding(.horizontal)

            if client.connection == .disconnected {
                Text("将连接到 \(Endpoints.serverURL.absoluteString)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
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
