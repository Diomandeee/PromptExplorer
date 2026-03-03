import ComposableArchitecture
import Foundation
import OpenClawCore
import OpenClawSupabase

// MARK: - HubClient TCA Dependency

/// A TCA dependency that provides Supabase-backed access to hub threads and messages.
struct HubClient: Sendable {
    /// Fetch threads, optionally filtering by category and type, with a limit.
    var fetchThreads: @Sendable (_ category: String?, _ type: ThreadType, _ limit: Int) async throws -> [HubThread]

    /// Fetch messages for a given thread, with a limit and optional cursor (before message ID).
    var fetchMessages: @Sendable (_ threadId: UUID, _ limit: Int, _ before: UUID?) async throws -> [HubMessage]
}

// MARK: - Live Implementation

extension HubClient {
    static let live = HubClient(
        fetchThreads: { category, type, limit in
            // Build filter query first, then apply transforms (order/limit) last
            var query = SupabaseManager.shared.client
                .from("hub_threads")
                .select()
                .eq("type", value: type.rawValue)

            if let category {
                query = query.eq("category", value: category)
            }

            let threads: [HubThread] = try await query
                .order("last_message_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return threads
        },
        fetchMessages: { threadId, limit, before in
            // Build filter query first, then apply transforms last
            var query = SupabaseManager.shared.client
                .from("hub_messages")
                .select()
                .eq("thread_id", value: threadId.uuidString)

            if let before {
                query = query.lt("id", value: before.uuidString)
            }

            let messages: [HubMessage] = try await query
                .order("created_at", ascending: true)
                .limit(limit)
                .execute()
                .value
            return messages
        }
    )
}

// MARK: - TCA DependencyKey

extension HubClient: DependencyKey {
    static let liveValue = HubClient.live

    static let testValue = HubClient(
        fetchThreads: { _, _, _ in [] },
        fetchMessages: { _, _, _ in [] }
    )
}

extension DependencyValues {
    var hubClient: HubClient {
        get { self[HubClient.self] }
        set { self[HubClient.self] = newValue }
    }
}
