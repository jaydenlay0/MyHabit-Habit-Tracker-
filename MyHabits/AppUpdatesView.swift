import SwiftUI

private struct OpenAppUpdatesKey: EnvironmentKey {
    static let defaultValue: (CGRect) -> Void = { _ in }
}
extension EnvironmentValues {
    var openAppUpdates: (CGRect) -> Void {
        get { self[OpenAppUpdatesKey.self] }
        set { self[OpenAppUpdatesKey.self] = newValue }
    }
}

private struct UpdateEntry: Decodable, Identifiable {
    let id: String
    let title: String
}

struct AppUpdatesView: View {
    let close: () -> Void
    private let entries: [UpdateEntry] = {
        guard let url = Bundle.main.url(forResource: "UpdateHistory", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([UpdateEntry].self, from: data) else { return [] }
        return entries
    }()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image("BrandMark").resizable().scaledToFit()
                            .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MyHabits").font(.title2.bold())
                            Text("Small promises. Shared support.").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                        }
                    }.padding(.vertical, 8)
                }.appSectionStyle()
                Section("The people behind MyHabits") {
                    LabeledContent("Created by", value: "Jayden Lay")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Supporters").font(.headline)
                        Text(verbatim: "Teresa C ❤️")
                            .font(.subheadline)
                        Text("Thank you for supporting MyHabits 💙")
                            .font(.caption).foregroundStyle(AppTheme.secondaryText)
                    }.padding(.vertical, 4)
                }.appSectionStyle()
                Section {
                    ForEach(entries) { entry in
                        Text(entry.title).font(.subheadline).padding(.vertical, 5)
                    }
                } header: {
                    Text("Update history")
                } footer: {
                    Text("Newest updates appear first.")
                }.appSectionStyle()
            }
            .appScreenStyle()
            .navigationTitle("What’s New & Supporters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: close) } }
        }
    }
}

private struct BrandLightning: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [CGPoint(x: 0.67, y: 0.04), CGPoint(x: 0.15, y: 0.53), CGPoint(x: 0.45, y: 0.53), CGPoint(x: 0.31, y: 0.96), CGPoint(x: 0.85, y: 0.43), CGPoint(x: 0.54, y: 0.43)]
        var path = Path()
        for (index, point) in points.enumerated() {
            let point = CGPoint(x: point.x * rect.width, y: point.y * rect.height)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

struct AppUpdatesReveal: View {
    let origin: CGRect
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1
    @State private var greenVisible = false
    @State private var pageVisible = false
    private let green = Color(habitHex: "63D6A3")

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppUpdatesView(close: close)
                    .opacity(pageVisible ? 1 : 0)
                    .accessibilityHidden(!pageVisible)
                if !pageVisible {
                    Color.clear.contentShape(Rectangle())
                    green.opacity(greenVisible ? 1 : 0)
                    BrandLightning().fill(green)
                        .frame(width: 56, height: 56)
                        .scaleEffect(scale)
                        .position(x: origin.midX - geometry.frame(in: .global).minX,
                                  y: origin.midY - geometry.frame(in: .global).minY)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .task {
            if reduceMotion { pageVisible = true; return }
            withAnimation(.easeIn(duration: 0.6)) { scale = 140 }
            do { try await Task.sleep(for: .milliseconds(560)) } catch { return }
            greenVisible = true
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            withAnimation(.easeOut(duration: 0.25)) { pageVisible = true }
        }
    }
}
