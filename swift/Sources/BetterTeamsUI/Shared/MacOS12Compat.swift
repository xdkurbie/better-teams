// MacOS12Compat.swift — deployment-floor shims.
//
// The package builds with the macOS 26 SDK and runs back to macOS 12.
// APIs introduced later stay on the new OS (the branch inside
// `#available`) and take a plain fallback on Monterey. Perception tracks
// `@Perceptible` models on both sides; this file does not replace that.
import AppKit
import OstMacCore
import SwiftUI

#if canImport(Translation)
import Translation
#endif

// MARK: - Foreground style (macOS 13+)

extension View {
    /// `foregroundStyle` on macOS 13+, `foregroundColor` on macOS 12.
    @ViewBuilder
    func compatForeground<S: ShapeStyle>(_ style: S) -> some View {
        if #available(macOS 13, *) {
            self.foregroundStyle(style)
        } else {
            self.foregroundColor(MontereyInk.color(style))
        }
    }
}

enum MontereyInk {
    /// Best-effort Color for a ShapeStyle the macOS 12 foreground API can draw.
    static func color<S: ShapeStyle>(_ style: S) -> Color {
        if let color = style as? Color { return color }
        let name = (String(describing: type(of: style)) + " " + String(describing: style)).lowercased()
        if name.contains("separator") { return Color(nsColor: .separatorColor) }
        if name.contains("quaternary") || name.contains("tertiary") || name.contains("secondary") {
            return .secondary
        }
        if name.contains("tint") || name.contains("accent") { return .accentColor }
        if name.contains("clear") { return .clear }
        if name.contains("white") { return .white }
        if name.contains("black") { return .black }
        if name.contains("red") { return .red }
        if name.contains("green") { return .green }
        if name.contains("orange") { return .orange }
        if name.contains("blue") { return .blue }
        if name.contains("yellow") { return .yellow }
        return .primary
    }
}

extension Font {
    /// `Font.weight` is macOS 13+. Older systems keep the base font.
    func compatWeight(_ weight: Font.Weight) -> Font {
        if #available(macOS 13, *) { return self.weight(weight) }
        return self
    }
}

extension Text {
    /// `fontWeight` (macOS 13+). Older systems bold only the heavy weights.
    func compatWeight(_ weight: Font.Weight) -> Text {
        if #available(macOS 13, *) { return self.fontWeight(weight) }
        if weight == .bold || weight == .semibold || weight == .heavy || weight == .black {
            return self.bold()
        }
        return self
    }

    func compatItalic() -> Text {
        if #available(macOS 13, *) { return self.italic() }
        return self
    }

    func compatKerning(_ value: CGFloat) -> Text {
        if #available(macOS 13, *) { return self.kerning(value) }
        return self
    }
}

// MARK: - Forms, lists, scroll (macOS 13 / 14)

extension View {
    @ViewBuilder
    func compatFormStyleGrouped() -> some View {
        if #available(macOS 13, *) {
            self.formStyle(.grouped)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatFormStyleColumns() -> some View {
        if #available(macOS 14, *) {
            self.formStyle(.columns)
        } else if #available(macOS 13, *) {
            self.formStyle(.grouped)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatScrollDisabled() -> some View {
        if #available(macOS 13, *) {
            self.scrollDisabled(true)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatScrollBounceBasedOnSize() -> some View {
        if #available(macOS 13, *) {
            self.scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatScrollContentBackgroundHidden() -> some View {
        if #available(macOS 13, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatScrollIndicators(visible: Bool) -> some View {
        if #available(macOS 13, *) {
            self.scrollIndicators(visible ? .automatic : .never)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatListRowSeparatorHidden() -> some View {
        if #available(macOS 13, *) {
            self.listRowSeparator(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatAlternatingRowsDisabled() -> some View {
        if #available(macOS 14, *) {
            self.alternatingRowBackgrounds(.disabled)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatBorderedList(alternates: Bool = true) -> some View {
        if #available(macOS 14, *) {
            self.listStyle(.bordered(alternatesRowBackgrounds: alternates))
        } else {
            self.listStyle(.bordered)
        }
    }

    /// Space bar (Quick Look). `onKeyPress` is macOS 14+; the File menu
    /// equivalent still works on macOS 12.
    @ViewBuilder
    func compatOnSpace(_ action: @escaping () -> Bool) -> some View {
        if #available(macOS 14, *) {
            self.onKeyPress(.space) { action() ? .handled : .ignored }
        } else {
            self
        }
    }

    /// Bottom-of-scroll tracking. `onScrollGeometryChange` is macOS 15+.
    /// Older systems treat the list as pinned to the newest row.
    @ViewBuilder
    func compatTrackScrolledToEnd(
        _ atEnd: Binding<Bool>,
        isAtEnd: @escaping (CGFloat, CGFloat, CGFloat) -> Bool
    ) -> some View {
        if #available(macOS 15, *) {
            self.onScrollGeometryChange(for: Bool.self) { geometry in
                isAtEnd(geometry.contentOffset.y, geometry.containerSize.height, geometry.contentSize.height)
            } action: { _, now in
                atEnd.wrappedValue = now
            }
        } else {
            self.onAppear { atEnd.wrappedValue = true }
        }
    }

    @ViewBuilder
    func compatCapsuleBorder() -> some View {
        if #available(macOS 14, *) {
            self.buttonBorderShape(.capsule)
        } else {
            self
        }
    }

    /// Selection context menus (`contextMenu(forSelectionType:)`, macOS 13+).
    /// On macOS 12 the menu-bar commands still cover the same actions.
    @ViewBuilder
    func compatSelectionMenu<I: Hashable, M: View>(
        forSelectionType itemType: I.Type,
        @ViewBuilder menu: @escaping (Set<I>) -> M,
        primaryAction: ((Set<I>) -> Void)? = nil
    ) -> some View {
        if #available(macOS 13, *) {
            if let primaryAction {
                self.contextMenu(forSelectionType: itemType, menu: menu, primaryAction: primaryAction)
            } else {
                self.contextMenu(forSelectionType: itemType, menu: menu)
            }
        } else {
            self
        }
    }
}

enum CompatInsetEdge {
    case top, bottom
}

extension View {
    /// `safeAreaInset` (macOS 13+). macOS 12 stacks the inset outside the content.
    @ViewBuilder
    func compatSafeAreaInset<V: View>(
        edge: CompatInsetEdge,
        spacing: CGFloat = 0,
        @ViewBuilder content: () -> V
    ) -> some View {
        if #available(macOS 13, *) {
            self.safeAreaInset(edge: edge == .top ? .top : .bottom, spacing: spacing, content: content)
        } else {
            VStack(spacing: spacing) {
                if edge == .top { content() }
                self
                if edge == .bottom { content() }
            }
        }
    }

    /// `dropDestination(for: URL.self)` (macOS 13+). macOS 12 loads file URLs from the pasteboard.
    @ViewBuilder
    func compatDropFiles(_ perform: @escaping ([URL], CGPoint) -> Bool) -> some View {
        if #available(macOS 13, *) {
            self.dropDestination(for: URL.self, action: perform)
        } else {
            self.onDrop(of: [.fileURL], isTargeted: nil) { providers in
                let group = DispatchGroup()
                let box = URLBox()
                for provider in providers {
                    group.enter()
                    _ = provider.loadObject(ofClass: URL.self) { object, _ in
                        if let url = object as? URL {
                            box.append(url)
                        }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    _ = perform(box.urls, .zero)
                }
                return !providers.isEmpty
            }
        }
    }
}

/// Main-thread-only URL accumulator for the macOS 12 drop fallback.
private final class URLBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []
    var urls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ url: URL) {
        lock.lock()
        storage.append(url)
        lock.unlock()
    }
}

// MARK: - Empty states (ContentUnavailableView is macOS 14)

/// Stand-in for `SwiftUI.ContentUnavailableView`. macOS 14+ draws the system
/// view; macOS 12 draws the same title, symbol, description and actions.
struct ContentUnavailableView: View {
    private let label: AnyView
    private let description: AnyView
    private let actions: AnyView

    init(_ title: String, systemImage: String, description: Text = Text("")) {
        label = AnyView(
            Label(title, systemImage: systemImage)
                .font(.title2)
                .multilineTextAlignment(.center)
        )
        self.description = AnyView(description.multilineTextAlignment(.center))
        actions = AnyView(EmptyView())
    }

    init<L: View, D: View, A: View>(
        @ViewBuilder label: () -> L,
        @ViewBuilder description: () -> D = { EmptyView() },
        @ViewBuilder actions: () -> A = { EmptyView() }
    ) {
        self.label = AnyView(label())
        self.description = AnyView(description())
        self.actions = AnyView(actions())
    }

    static func search(text: String) -> ContentUnavailableView {
        ContentUnavailableView(
            label: {
                Label("No Results for “\(text)”", systemImage: "magnifyingglass")
                    .font(.title2)
            },
            description: { Text("Check the spelling or try a new search.") },
            actions: { EmptyView() }
        )
    }

    var body: some View {
        if #available(macOS 14, *) {
            SwiftUI.ContentUnavailableView {
                label
            } description: {
                description
            } actions: {
                actions
            }
        } else {
            VStack(spacing: 8) {
                label
                description
                    .font(.callout)
                    .compatForeground(.secondary)
                actions
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
        }
    }
}

// MARK: - LabeledContent (macOS 13)

/// Stand-in for `SwiftUI.LabeledContent`.
struct LabeledContent: View {
    private let title: String
    private let value: String?
    private let content: AnyView?

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
        content = nil
    }

    init<C: View>(_ title: String, @ViewBuilder content: () -> C) {
        self.title = title
        value = nil
        self.content = AnyView(content())
    }

    var body: some View {
        if #available(macOS 13, *), let value {
            SwiftUI.LabeledContent(title, value: value)
        } else if #available(macOS 13, *), let content {
            SwiftUI.LabeledContent(title) { content }
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer(minLength: 12)
                if let value {
                    Text(value).compatForeground(.secondary)
                }
                if let content { content }
            }
        }
    }
}

// MARK: - On-device translation (macOS 15)

extension View {
    /// Attaches a Translation session on macOS 15+. No-op before that
    /// (Translate stays hidden: `MessageTranslation.isAvailable` is false).
    @ViewBuilder
    func compatTranslationTask(_ store: TranslationStore) -> some View {
        #if canImport(Translation)
        if #available(macOS 15, *) {
            self.modifier(LiveTranslationTask(store: store))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if canImport(Translation)
@available(macOS 15, *)
private struct LiveTranslationTask: ViewModifier {
    let store: TranslationStore

    func body(content: Content) -> some View {
        content.translationTask(
            TranslationSession.Configuration(target: store.sessionTarget)
        ) { session in
            store.attached(session)
        }
    }
}
#endif
