import TimelogCore
import SwiftData
import SwiftUI

struct HistoryView: View {
    var embedded: Bool = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<TimeEntry> { $0.deletedAt == nil }, sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]

    @State private var selectedDate = Date()
    @State private var entryToEdit: TimeEntry?

    private var entries: [TimeEntry] {
        allEntries.filter { $0.userId == settings.userId && Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var totalMinutes: Int {
        entries.reduce(0) { $0 + $1.durationMinutes }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker("Date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(totalMinutes.formattedDuration)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        Image(systemName: "calendar")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.secondary.opacity(0.45))
                    }
                }
                .padding()
                .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
                .padding()

                if entries.isEmpty {
                    ContentUnavailableView(
                        "No entries",
                        systemImage: "calendar",
                        description: Text("Pick another day to review logged time.")
                    )
                } else {
                    List {
                        ForEach(entries) { entry in
                            HistoryEntryRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture { entryToEdit = entry }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        entry.deletedAt = .now
                                        try? context.save()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .sheet(item: $entryToEdit) { QuickLogSheet(entry: $0) }
        }
    }
}

private struct HistoryEntryRow: View {
    let entry: TimeEntry

    var body: some View {
        HStack(spacing: 12) {
            if let color = entry.client?.color {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 4, height: 38)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.client?.name ?? "No client")
                    .font(.subheadline.weight(.semibold))
                if let project = entry.project {
                    HStack(spacing: 4) {
                        Text(project.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let label = entry.label {
                            Text(label)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.durationMinutes.formattedDuration)
                    .font(.subheadline.monospacedDigit())
                Text(entry.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
