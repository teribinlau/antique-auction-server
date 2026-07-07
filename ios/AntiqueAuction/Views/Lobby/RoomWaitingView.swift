import SwiftUI

/// 等待室：显示玩家名单 + 「开始」按钮（≥2 人可点）+ 离开。
struct RoomWaitingView: View {
    @ObservedObject var client: GameClient

    private var canStart: Bool { client.lobbyPlayers.count >= 2 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        ForEach(Array(client.lobbyPlayers.enumerated()), id: \.offset) { idx, name in
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundStyle(idx == client.myPlayerId ? Color.accentColor : Color.secondary)
                                Text(name)
                                    .font(.body)
                                if idx == client.myPlayerId {
                                    Text("（你）")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("座位 \(idx)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                            .listRowBackground(Color.white.opacity(0.04))
                        }
                        // 补足空位提示（最多 5 人）。min 防越界:人数已满时区间为空。
                        ForEach(min(client.lobbyPlayers.count, 5)..<5, id: \.self) { _ in
                            HStack {
                                Image(systemName: "person.crop.circle.badge.questionmark")
                                    .foregroundStyle(.tertiary)
                                Text("等待加入…")
                                    .font(.body)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text("玩家 \(client.lobbyPlayers.count)/5")
                    } footer: {
                        Text("分享房间码 “\(client.roomCode ?? "")” 邀请好友。至少 2 人即可开始。")
                    }
                }
                .scrollContentBackground(.hidden)   // 透出底层古董背景（iOS 16+）

                VStack(spacing: 12) {
                    Button {
                        client.startGame()
                    } label: {
                        Text(canStart ? "开始游戏" : "至少需要 2 名玩家")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canStart ? Color.accentColor : Color.gray)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canStart)
                }
                .padding()
            }
            .navigationTitle(client.roomName ?? "等待室")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        client.leaveToLobby()
                    } label: {
                        Label("离开", systemImage: "arrow.left")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let code = client.roomCode {
                        Text(code)
                            .font(.headline.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
