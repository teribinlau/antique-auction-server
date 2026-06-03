import SwiftUI

/// 大厅：房间列表（下拉刷新）+ 建房 + 输码加入。
struct LobbyView: View {
    @ObservedObject var client: GameClient

    @State private var showCreateSheet = false
    @State private var showJoinSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if client.rooms.isEmpty {
                        ContentUnavailableCompat(
                            title: "暂无房间",
                            systemImage: "tray",
                            description: "下拉刷新，或创建一个新房间"
                        )
                    } else {
                        ForEach(client.rooms) { room in
                            Button {
                                joinExisting(room)
                            } label: {
                                roomRow(room)
                            }
                            .buttonStyle(.plain)
                            // 行底用半透明材质，透出古董背景又保持可读卡片感。
                            .listRowBackground(roomRowBackground)
                        }
                    }
                } header: {
                    Text("可加入的房间")
                }
            }
            .scrollContentBackground(.hidden)   // 透出底层古董背景（iOS 16+）
            .refreshable {
                client.listRooms()
                // 给服务端一点回包时间（下拉刷新动画体验）。
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            .navigationTitle("大厅")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // 音效 / 触感小设置入口。
                    FeedbackToggleButtons()
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        client.listRooms()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Label("创建房间", systemImage: "plus.circle")
                        }
                        Button {
                            showJoinSheet = true
                        } label: {
                            Label("输入房间码加入", systemImage: "number")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("创建房间", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button {
                        showJoinSheet = true
                    } label: {
                        Label("输码加入", systemImage: "number")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
        }
        .onAppear { client.listRooms() }
        .sheet(isPresented: $showCreateSheet) {
            CreateRoomSheet(client: client)
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinRoomSheet(client: client)
        }
    }

    /// 房间行底色（半透明材质 + 细描边的卡片感）。
    private var roomRowBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private func roomRow(_ room: RoomSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(room.roomName)
                        .font(.headline)
                    if room.hasPassword {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("房间码 \(room.roomCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(room.playerCount)/4")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(room.playerCount >= 4 ? .red : .secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func joinExisting(_ room: RoomSummary) {
        if room.hasPassword {
            // 有密码：转到输码弹窗（预填房间码）。
            showJoinSheet = true
        } else {
            client.joinRoom(roomCode: room.roomCode)
        }
    }
}

/// 创建房间弹窗。
private struct CreateRoomSheet: View {
    @ObservedObject var client: GameClient
    @Environment(\.dismiss) private var dismiss

    @State private var roomName: String = ""
    @State private var password: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("房间名（可选）") {
                    TextField("如：周末古玩局", text: $roomName)
                }
                Section("密码（可选）") {
                    SecureField("留空表示公开房间", text: $password)
                }
            }
            .navigationTitle("创建房间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        let name = roomName.trimmingCharacters(in: .whitespaces)
                        client.createRoom(
                            roomName: name.isEmpty ? nil : name,
                            password: password.isEmpty ? nil : password
                        )
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// 输入房间码加入弹窗。
private struct JoinRoomSheet: View {
    @ObservedObject var client: GameClient
    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var password: String = ""

    private var canJoin: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("房间码") {
                    TextField("4 位房间码", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Section("密码（如有）") {
                    SecureField("公开房间留空", text: $password)
                }
            }
            .navigationTitle("加入房间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入") {
                        let c = code.trimmingCharacters(in: .whitespaces).uppercased()
                        client.joinRoom(
                            roomCode: c,
                            password: password.isEmpty ? nil : password
                        )
                        dismiss()
                    }
                    .disabled(!canJoin)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// iOS 16 兼容的「空状态」占位（ContentUnavailableView 是 iOS 17+）。
struct ContentUnavailableCompat: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
