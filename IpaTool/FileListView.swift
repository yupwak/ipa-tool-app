import SwiftUI

struct FileListView: View {
    let ipa: LoadedIpa
    var onOpenHtml: (HtmlPayload) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [ZipEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return ipa.entries }
        return ipa.entries.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { entry in
                    Button {
                        open(entry)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: icon(entry.name))
                                .font(.system(size: 14))
                                .foregroundStyle(ipa.iconIndexes.contains(where: { $0 == indexOf(entry) })
                                                 ? Color.orange : Color.secondary)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                    .font(.system(size: 12.5, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(entry.sizeLabel)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if isHtml(entry.name) {
                                Text("HTML")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.blue.opacity(0.15)))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "搜索文件")
            .navigationTitle("包内文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func isHtml(_ name: String) -> Bool {
        let l = name.lowercased()
        return l.hasSuffix(".html") || l.hasSuffix(".htm")
    }

    private func icon(_ name: String) -> String {
        let l = name.lowercased()
        if l.hasSuffix(".png") || l.hasSuffix(".jpg") || l.hasSuffix(".jpeg") { return "photo" }
        if l.hasSuffix(".plist") { return "list.bullet.rectangle" }
        if l.hasSuffix(".car") { return "square.stack.3d.up" }
        if isHtml(name) { return "safari" }
        if l.hasSuffix(".json") || l.hasSuffix(".txt") { return "doc.text" }
        return "doc"
    }

    private func indexOf(_ entry: ZipEntry) -> Int {
        ipa.entries.firstIndex(where: { $0.id == entry.id }) ?? -1
    }

    private func open(_ entry: ZipEntry) {
        guard isHtml(entry.name) else { return }
        guard let data = entry.data else { return }
        onOpenHtml(HtmlPayload(name: entry.name, data: data, base: nil))
    }
}
