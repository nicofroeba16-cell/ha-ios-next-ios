import SwiftUI

struct OwnerTicketInboxView: View {
    let model: AdminControlModel

    var body: some View {
        List {
            if model.supportTickets.isEmpty {
                ContentUnavailableView(
                    "Keine Tickets",
                    systemImage: "ticket",
                    description: Text("Neue Anfragen anderer Benutzer erscheinen hier persistent.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(model.supportTickets) { ticket in
                    NavigationLink {
                        OwnerTicketConversationView(model: model, ticketID: ticket.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(ticket.requesterUserID)
                                    .font(.headline)
                                Spacer()
                                Text(statusTitle(ticket.status))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(statusColor(ticket.status))
                            }
                            Text(ticket.lastMessage ?? "Ticket ohne Nachricht")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text(ticket.updatedAt)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Owner-Tickets")
        .refreshable { await model.refresh() }
    }

    private func statusTitle(_ status: String) -> String {
        switch status {
        case "open": "Neu"
        case "in_progress": "In Arbeit"
        case "resolved": "Erledigt"
        default: status
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "resolved": .green
        case "in_progress": .orange
        default: .blue
        }
    }
}

private struct OwnerTicketConversationView: View {
    let model: AdminControlModel
    let ticketID: String
    @State private var draft = ""
    @State private var isSending = false

    private var ticket: SupportTicket? {
        model.ticketDetails[ticketID]
            ?? model.supportTickets.first(where: { $0.id == ticketID })
    }

    var body: some View {
        VStack(spacing: 0) {
            conversation
            composer
        }
        .background(IOSNextBackground())
        .navigationTitle(ticket?.requesterUserID ?? "Ticket")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Status", systemImage: "checklist") {
                    Button("Neu") { Task { await model.setTicketStatus(ticketID, status: "open") } }
                    Button("In Arbeit") { Task { await model.setTicketStatus(ticketID, status: "in_progress") } }
                    Button("Erledigt") { Task { await model.setTicketStatus(ticketID, status: "resolved") } }
                }
            }
        }
        .task { await model.loadTicket(ticketID) }
        .refreshable { await model.loadTicket(ticketID) }
    }

    @ViewBuilder
    private var conversation: some View {
        if let messages = ticket?.messages {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            ticketBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: messages.count) { _, _ in
                    guard let id = messages.last?.id else { return }
                    withAnimation(.smooth) { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        } else {
            ProgressView("Ticket wird geladen …")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func ticketBubble(_ message: SupportTicketMessage) -> some View {
        HStack {
            if message.authorRole == .owner { Spacer(minLength: 44) }
            VStack(alignment: .leading, spacing: 5) {
                Text(message.authorRole == .owner ? "Du" : message.authorUserID)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(message.body)
                    .textSelection(.enabled)
                Text(message.createdAt)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                message.authorRole == .owner
                    ? Color.accentColor.opacity(0.18)
                    : Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            if message.authorRole == .member { Spacer(minLength: 44) }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Antwort", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            Button {
                Task {
                    isSending = true
                    let sent = await model.replyToTicket(ticketID, message: draft)
                    if sent { draft = "" }
                    isSending = false
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.body.bold())
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .disabled(
                isSending
                    || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || draft.count > 4000
            )
            .accessibilityLabel("Ticket-Antwort senden")
        }
        .padding(10)
        .background(.bar)
    }
}
