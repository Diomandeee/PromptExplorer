import ComposableArchitecture
import Foundation
import OpenClawCore


@Reducer
struct PromptExplorerFeature: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        var threads: [HubThread] = []
        var selectedThread: HubThread? = nil
        var messages: [HubMessage] = []
        var isLoading = false
        var error: String? = nil
        var searchQuery: String = ""
        var selectedCategory: String? = nil

        var filteredThreads: [HubThread] {
            var result = threads
            if let cat = selectedCategory {
                result = result.filter { $0.category == cat }
            }
            if !searchQuery.isEmpty {
                let q = searchQuery.lowercased()
                result = result.filter {
                    $0.title.lowercased().contains(q) ||
                    ($0.subtitle?.lowercased().contains(q) ?? false) ||
                    $0.category.lowercased().contains(q)
                }
            }
            return result
        }

        var categories: [String] {
            Array(Set(threads.map(\.category))).sorted()
        }
    }

    enum Action: Sendable, Equatable {
        case onAppear
        case loadThreads
        case threadsLoaded([HubThread])
        case selectThread(HubThread?)
        case loadMessages(UUID)
        case messagesLoaded([HubMessage])
        case loadFailed(String)
        case setSearchQuery(String)
        case filterByCategory(String?)
        case refresh
    }

    @Dependency(\.hubClient) var hubClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.loadThreads)

            case .loadThreads:
                state.isLoading = true
                return .run { send in
                    do {
                        let threads = try await hubClient.fetchThreads(nil, .conversation, 100)
                        await send(.threadsLoaded(threads))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case let .threadsLoaded(threads):
                state.isLoading = false
                state.threads = threads
                return .none

            case let .selectThread(thread):
                state.selectedThread = thread
                if let thread {
                    return .send(.loadMessages(thread.id))
                }
                state.messages = []
                return .none

            case let .loadMessages(threadId):
                return .run { send in
                    do {
                        let messages = try await hubClient.fetchMessages(threadId, 50, nil)
                        await send(.messagesLoaded(messages))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case let .messagesLoaded(messages):
                state.messages = messages
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                state.error = error
                return .none

            case let .setSearchQuery(query):
                state.searchQuery = query
                return .none

            case let .filterByCategory(category):
                state.selectedCategory = category
                return .none

            case .refresh:
                return .send(.loadThreads)
            }
        }
    }
}
