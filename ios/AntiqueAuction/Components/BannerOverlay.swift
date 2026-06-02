import SwiftUI

/// 顶部横幅：展示 error / payment_failed 曝光 / silver_bonus 等提示。
/// 由 `GameClient.banner`（可选字符串）驱动；点击或自动延时后消除。
struct BannerOverlay: View {
    @ObservedObject var client: GameClient

    var body: some View {
        VStack {
            if let banner = client.banner {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .foregroundStyle(.white)
                    Text(banner)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button {
                        client.clearBanner()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor)
                        .shadow(radius: 6, y: 3)
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    // 自动 4 秒后消除（用户也可手动叉掉）。
                    let snapshot = banner
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        if client.banner == snapshot {
                            client.clearBanner()
                        }
                    }
                }
                Spacer()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: client.banner)
        .allowsHitTesting(client.banner != nil)
    }
}
