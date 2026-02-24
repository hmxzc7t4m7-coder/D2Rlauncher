import SwiftUI

struct StatusBannerView: View {
    let isBusy: Bool
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(isError ? Color.red : Color.primary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isError ? Color.red.opacity(0.08) : Color.accentColor.opacity(0.08))
        )
        .padding(.horizontal, 20)
    }
}
