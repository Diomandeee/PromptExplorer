import SwiftUI
import ComposableArchitecture
import OpenClawCore

struct PromptExplorerView: View {
    @Bindable var store: StoreOf<PromptExplorerFeature>

    var body: some View {
        NavigationSplitView {
            ThreadListView(store: store)
        } detail: {
            if let thread = store.selectedThread {
                ThreadDetailView(
                    thread: thread,
                    messages: store.messages
                )
            } else {
                ContentUnavailableView(
                    "Select a Thread",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Choose a conversation thread to explore prompts and responses.")
                )
            }
        }
        .task { store.send(.onAppear) }
    }
}

// MARK: - Thread List

struct ThreadListView: View {
    @Bindable var store: StoreOf<PromptExplorerFeature>

    var body: some View {
        List {
            // Category filter section
            if !store.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(
                            label: "All",
                            isActive: store.selectedCategory == nil,
                            color: .indigo
                        ) {
                            store.send(.filterByCategory(nil))
                        }
                        ForEach(store.categories, id: \.self) { cat in
                            CategoryChip(
                                label: cat,
                                isActive: store.selectedCategory == cat,
                                color: categoryColor(cat)
                            ) {
                                store.send(.filterByCategory(cat))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Thread list
            ForEach(store.filteredThreads) { thread in
                Button {
                    store.send(.selectThread(thread))
                } label: {
                    ThreadRow(
                        thread: thread,
                        isSelected: store.selectedThread?.id == thread.id
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Prompt Explorer")
        .searchable(text: Binding(
            get: { store.searchQuery },
            set: { store.send(.setSearchQuery($0)) }
        ), prompt: "Search threads...")
        .refreshable { store.send(.refresh) }
        .overlay {
            if store.isLoading && store.threads.isEmpty {
                ProgressView("Loading threads...")
            }
        }
    }

    private func categoryColor(_ category: String) -> Color {
        guard let tc = ThreadCategory(rawValue: category) else { return .gray }
        switch tc {
        case .agent: return .indigo
        case .compCore: return .blue
        case .pulseControl: return .purple
        case .research: return .green
        case .dispatch: return .orange
        default: return .teal
        }
    }
}

// MARK: - Thread Row

struct ThreadRow: View {
    let thread: HubThread
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: ThreadCategory(rawValue: thread.category)?.icon ?? "bubble.left")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text(thread.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Spacer()

                Text("\(thread.messageCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            HStack {
                Text(thread.category)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())

                if let subtitle = thread.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                if let lastMsg = thread.lastMessageAt {
                    Text(lastMsg, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Thread Detail

struct ThreadDetailView: View {
    let thread: HubThread
    let messages: [HubMessage]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Thread header
                VStack(alignment: .leading, spacing: 8) {
                    Text(thread.title)
                        .font(.title2.bold())

                    HStack {
                        Label(thread.category, systemImage: ThreadCategory(rawValue: thread.category)?.icon ?? "bubble.left")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(messages.count) messages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Messages
                ForEach(messages) { message in
                    MessageBubble(message: message)
                }
            }
            .padding()
        }
        .navigationTitle(thread.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: HubMessage

    private var isUser: Bool {
        message.senderType == .human
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !isUser {
                        Image(systemName: senderIcon)
                            .font(.system(size: 10))
                            .foregroundStyle(senderColor)
                    }
                    Text(message.senderLabel ?? message.senderType.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(senderColor)

                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(message.content)
                    .font(.subheadline)
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(isUser ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !isUser { Spacer(minLength: 40) }
        }
    }

    private var senderIcon: String {
        switch message.senderType {
        case .agent: return "cpu"
        case .system: return "gearshape"
        case .flow: return "arrow.triangle.branch"
        case .pulse: return "waveform.path.ecg"
        case .dispatch: return "paperplane.fill"
        case .human: return "person.fill"
        }
    }

    private var senderColor: Color {
        switch message.senderType {
        case .human: return .blue
        case .agent: return .indigo
        case .system: return .gray
        case .flow: return .green
        case .pulse: return .purple
        case .dispatch: return .orange
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let label: String
    let isActive: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isActive ? color.opacity(0.2) : Color.clear)
                .foregroundStyle(isActive ? color : .secondary)
                .overlay {
                    Capsule()
                        .strokeBorder(isActive ? color.opacity(0.4) : Color.secondary.opacity(0.2), lineWidth: 1)
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
