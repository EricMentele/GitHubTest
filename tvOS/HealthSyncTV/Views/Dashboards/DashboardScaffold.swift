import SwiftUI

struct DashboardScaffold<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text(title).font(.system(size: 72, weight: .bold))
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 96)
        .padding(.vertical, 64)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3).foregroundStyle(.secondary)
            Text(value).font(.system(size: 80, weight: .bold))
            if let subtitle { Text(subtitle).font(.callout).foregroundStyle(.secondary) }
        }
        .padding(40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 28))
    }
}

struct EmptyDashboardMessage: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.slash").font(.system(size: 80, weight: .light))
            Text("Waiting for the first sync from your iPhone…").font(.title3).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    var anyView: AnyView { AnyView(self) }
}
