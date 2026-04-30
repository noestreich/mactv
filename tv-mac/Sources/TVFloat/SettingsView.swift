import SwiftUI

struct SettingsView: View {

    @ObservedObject var store: ChannelStore
    var onSave: () -> Void

    @State private var selection: UUID?

    private var selIdx: Int? {
        selection.flatMap { id in store.channels.firstIndex { $0.id == id } }
    }

    var body: some View {
        HSplitView {
            channelList
            detailPane
        }
        .frame(minWidth: 640, minHeight: 440)
    }

    // MARK: - Linke Spalte: Senderliste

    private var channelList: some View {
        VStack(spacing: 0) {
            List(store.channels, selection: $selection) { ch in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        if ch.useZDFApi {
                            Image(systemName: "network")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Text(ch.name).font(.body)
                    }
                    Text(ch.url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .tag(ch.id)
                .padding(.vertical, 2)
            }

            Divider()

            HStack(spacing: 4) {
                Button { addChannel()    } label: { Image(systemName: "plus")         }
                    .help("Sender hinzufügen")
                Button { removeChannel() } label: { Image(systemName: "minus")        }
                    .disabled(selection == nil)
                    .help("Sender entfernen")
                Spacer()
                Button { moveUp()        } label: { Image(systemName: "chevron.up")   }
                    .disabled(selIdx == nil || selIdx == 0)
                    .help("Nach oben")
                Button { moveDown()      } label: { Image(systemName: "chevron.down") }
                    .disabled(selIdx == nil || selIdx == store.channels.count - 1)
                    .help("Nach unten")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 210, idealWidth: 230)
    }

    // MARK: - Rechte Spalte: Bearbeiten + Shortcuts

    private var detailPane: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Bearbeitungsbereich
            Group {
                if let idx = selIdx {
                    editFields(idx: idx)
                } else {
                    Text("Sender in der Liste auswählen,\num ihn zu bearbeiten.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minHeight: 130)
            .padding()

            Divider()

            // Tastaturkürzel
            shortcutsSection
                .padding()

            Spacer(minLength: 0)
            Divider()

            // Buttons
            HStack {
                Button("Auf Standard zurücksetzen") {
                    store.reset()
                    selection = nil
                }
                .foregroundColor(.red)
                Spacer()
                Button("Abbrechen") { NSApp.keyWindow?.close() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Speichern") {
                    store.save()
                    onSave()
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 340)
    }

    @ViewBuilder
    private func editFields(idx: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sender bearbeiten").font(.headline)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Name").gridColumnAlignment(.trailing)
                    TextField("Sendername", text: binding(idx, \.name))
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Stream-URL").gridColumnAlignment(.trailing)
                    TextField("https://…", text: binding(idx, \.url))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
                GridRow {
                    Text("").gridColumnAlignment(.trailing)
                    Toggle("ZDF API verwenden (dynamische Stream-URL)", isOn: binding(idx, \.useZDFApi))
                        .help("Aktivieren wenn der Stream über die ZDF-API abgefragt werden muss statt direkt über die URL.")
                }
            }
        }
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tastaturkurzbefehle").font(.headline)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 6) {
                shortcutRow("↑  /  →",  "Nächster Sender")
                shortcutRow("↓  /  ←",  "Vorheriger Sender")
                shortcutRow("1 – 9",     "Sender 1–9 direkt anwählen")
                shortcutRow("0",         "Sender 10")
                shortcutRow("M",         "Ton ein / aus")
                shortcutRow("U",         "Untertitel ein / aus")
                shortcutRow("F",         "Vollbild ein / aus")
            }
        }
    }

    private func shortcutRow(_ key: String, _ desc: String) -> some View {
        GridRow {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(5)
                .gridColumnAlignment(.trailing)
            Text(desc).foregroundColor(.secondary)
        }
    }

    // MARK: - Hilfsmethoden

    private func binding<T>(_ idx: Int, _ kp: WritableKeyPath<Channel, T>) -> Binding<T> {
        Binding(
            get: { store.channels[idx][keyPath: kp] },
            set: { store.channels[idx][keyPath: kp] = $0 }
        )
    }

    private func addChannel() {
        let ch = Channel(name: "Neuer Sender", url: "https://")
        store.channels.append(ch)
        selection = ch.id
    }

    private func removeChannel() {
        guard let idx = selIdx else { return }
        store.channels.remove(at: idx)
        selection = store.channels.isEmpty ? nil
                  : store.channels[max(0, idx - 1)].id
    }

    private func moveUp() {
        guard let idx = selIdx, idx > 0 else { return }
        store.channels.swapAt(idx, idx - 1)
    }

    private func moveDown() {
        guard let idx = selIdx, idx < store.channels.count - 1 else { return }
        store.channels.swapAt(idx, idx + 1)
    }
}
