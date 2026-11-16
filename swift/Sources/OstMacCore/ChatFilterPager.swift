// ChatFilterPager.swift — bounded paging behind a chat list filter.
//
// A filter narrows the rows already loaded, at once. When few rows
// match and Teams has older chats, this fetches a few more pages to
// look for matches — never the whole history (each older page costs
// seconds live: one member lookup per untitled 1:1 chat). It always
// reaches `.finished`: after `maxPages` pages, on enough matches, on a
// failed or superseded page, at the end of the list, or when `timeout`
// runs out on `clock` even if a page never returns.
import Foundation

@MainActor
public final class ChatFilterPager: ObservableObject {
    public enum Phase: Equatable, Sendable {
        /// No filter search (the full list, or not started).
        case idle
        /// Fetching older pages for more matches (inline indicator).
        case searching
        /// Terminal: the search stopped (see the type comment).
        case finished
    }

    @Published public private(set) var phase: Phase = .idle
    /// Older pages this pager fetched since the last `start` (tests,
    /// diagnostics).
    public private(set) var pagesFetched = 0

    public let maxPages: Int
    /// Seconds before an in-flight search is finished even if a page never returns.
    public let timeout: TimeInterval
    /// Matches that fill the pane; the search stops once reached.
    public let target: Int
    /// Test seam. Nil sleeps with `Task.sleep` (wall clock).
    private let sleeper: (@Sendable (TimeInterval) async -> Void)?
    private var run = 0

    public init(maxPages: Int = 2, timeout: TimeInterval = 10, target: Int = 20,
                sleeper: (@Sendable (TimeInterval) async -> Void)? = nil) {
        self.maxPages = maxPages
        self.timeout = timeout
        self.target = target
        self.sleeper = sleeper
    }

    /// Start a bounded search for more rows matching the filter.
    /// `matches` counts the matching rows in the list right now.
    public func start(_ list: ChatListViewModel, matches: @escaping @MainActor () -> Int) {
        run += 1
        let current = run
        pagesFetched = 0
        guard list.hasMore, matches() < target, maxPages > 0 else {
            phase = .finished
            return
        }
        phase = .searching
        let sleeper = sleeper
        let timeout = timeout
        Task { [weak self] in
            if let sleeper {
                await sleeper(timeout)
            } else {
                try? await BTSleep.seconds(timeout)
            }
            self?.finish(current)
        }
        Task { [weak self] in
            while let self, self.run == current, self.phase == .searching,
                  self.pagesFetched < self.maxPages, list.hasMore, matches() < self.target
            {
                let before = list.loadedPages
                await list.loadMore()
                // Failed, superseded (reload/account switch), or another
                // fetch already in flight: stop rather than spin.
                guard list.loadedPages > before, self.run == current else { break }
                self.pagesFetched += 1
            }
            self?.finish(current)
        }
    }

    /// Back to idle (the filter was cleared or changed); a page still in
    /// flight lands in the list but no longer drives this pager.
    public func cancel() {
        run += 1
        pagesFetched = 0
        phase = .idle
    }

    private func finish(_ which: Int) {
        guard which == run, phase == .searching else { return }
        phase = .finished
    }
}
