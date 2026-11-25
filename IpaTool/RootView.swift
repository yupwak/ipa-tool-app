import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct HtmlPayload: Identifiable {
    let id = UUID()
    let name: String
    let data: Data
    let base: URL?
}

struct RootView: View {
    @State private var ipa: LoadedIpa?
    @State private var showImporter = false
    @State private var showFiles = false
    @State private var showAsk = false
    @State private var pickedIcon: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var htmlPreview: HtmlPayload?
    @State private var shareURL: URL?
    @State private var busy = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    if let ipa {
                        loadedCard(ipa)
                    } else {
                        importCard
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }

            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .glassPill()
                        .padding(.bottom, 34)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if showAsk {
                askOverlay
            }
        }
        .animation(.easeOut(duration: 0.25), value: toast)
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: showAsk)
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.item],
                      allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showFiles) {
            if let ipa {
                FileListView(ipa: ipa) { payload in
                    showFiles = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        htmlPreview = payload
                    }
                }
            }
        }
        .sheet(item: $htmlPreview) { payload in
            HtmlViewer(payload: payload)
        }
        .sheet(item: Binding(get: { shareURL.map(ShareFile.init) },
                             set: { if $0 == nil { shareURL = nil } })) { file in
            ShareSheet(items: [file.url])
        }
        .task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            showAsk = true
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run { pickedIcon = img }
                }
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [Glass.accent, Glass.accent2],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text("IPA 图标工坊")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("导入 IPA / ZIP / HTML，换图标，全程本机")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.62))
            }
            Spacer()
        }
    }

    // MARK: - 导入

    private var importCard: some View {
        Button {
            showImporter = true
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(.white.opacity(0.10))
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .frame(width: 78, height: 78)

                Text("导入文件")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text("支持 .ipa、.zip、.html\nIPA 会在本机解析，不上传")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)

                HStack(spacing: 7) {
                    Image(systemName: "folder.fill")
                    Text("从文件中选择")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(height: 40)
                .glassPill()
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .glassCard(30)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 已载入

    private func loadedCard(_ ipa: LoadedIpa) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                iconPreview(ipa)
                VStack(alignment: .leading, spacing: 4) {
                    Text(ipa.info.displayName.isEmpty ? "未知应用" : ipa.info.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(ipa.info.bundleID.isEmpty ? ipa.appRoot : ipa.info.bundleID)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                kv("版本", ipa.info.version.isEmpty ? "—" : ipa.info.version)
                kv("最低系统", ipa.info.minOS.isEmpty ? "—" : "iOS " + ipa.info.minOS)
                kv("文件数", "\(ipa.entries.count) 个")
                kv("体积", ByteCountFormatter.string(fromByteCount: Int64(ipa.totalBytes), countStyle: .file))
            }

            // 新图标
            HStack(spacing: 12) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white.opacity(0.10))
                        if let pickedIcon {
                            Image(uiImage: pickedIcon)
                                .resizable()
                                .scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(width: 84, height: 84)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(.white.opacity(0.20), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pickedIcon == nil ? "选择新图标" : "已选新图标")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(pickedIcon == nil
                         ? "从相册选一张正方形图，会自动生成包里所有尺寸（\(ipa.iconIndexes.count) 个）"
                         : "导出时会按原尺寸重绘，不影响其它文件")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 2)

            VStack(spacing: 9) {
                Button {
                    exportIpa(ipa)
                } label: {
                    HStack(spacing: 8) {
                        if busy { ProgressView().tint(.white) }
                        else { Image(systemName: "arrow.down.circle.fill") }
                        Text(pickedIcon == nil ? "先选新图标" : "导出新 IPA")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Capsule().fill(LinearGradient(colors: [Glass.accent, Glass.accent2],
                                                      startPoint: .leading, endPoint: .trailing))
                    )
                    .opacity(pickedIcon == nil ? 0.45 : 1)
                }
                .buttonStyle(.plain)
                .disabled(pickedIcon == nil || busy)

                HStack(spacing: 9) {
                    Button {
                        showFiles = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                            Text("包内文件")
                        }
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .glassPill()
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation {
                            self.ipa = nil
                            pickedIcon = nil
                            photoItem = nil
                        }
                    } label: {
                        Text("移除")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.42))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .glassPill()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .glassCard(28)
    }

    private func kv(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(key)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
            Text(value)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.07))
        )
    }

    @ViewBuilder
    private func iconPreview(_ ipa: LoadedIpa) -> some View {
        let image: UIImage? = {
            if let pickedIcon { return pickedIcon }
            for i in ipa.iconIndexes {
                if let d = ipa.entries[i].data, let img = UIImage(data: d) { return img }
            }
            return nil
        }()

        ZStack {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(.white.opacity(0.09))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(width: 76, height: 76)
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - 进入弹窗

    private var askOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { closeAsk() }

            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(.white.opacity(0.12))
                    Image(systemName: "questionmark.folder.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(width: 60, height: 60)

                Text("是否关闭这个文件？")
                    .font(.system(size: 17.5, weight: .bold))
                    .foregroundStyle(.white)

                Text(ipa == nil
                     ? "当前没有打开的文件。点「不关闭」或者点空白处，提示会自己收起来。"
                     : "关闭后会回到导入界面，重新导入即可。")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                HStack(spacing: 9) {
                    Button {
                        closeAsk()
                    } label: {
                        Text("不关闭")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .glassPill()
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation {
                            ipa = nil
                            pickedIcon = nil
                            photoItem = nil
                        }
                        closeAsk()
                    } label: {
                        Text("关闭文件")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                Capsule().fill(LinearGradient(colors: [Glass.accent, Glass.accent2],
                                                              startPoint: .leading, endPoint: .trailing))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
            .padding(22)
            .frame(maxWidth: 330)
            .glassCard(30)
            .padding(.horizontal, 26)
        }
        .transition(.opacity)
    }

    private func closeAsk() {
        withAnimation(.easeOut(duration: 0.22)) { showAsk = false }
    }

    // MARK: - 动作

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let ext = url.pathExtension.lowercased()

        if ext == "html" || ext == "htm" {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                flash("HTML 读不出来")
                return
            }
            htmlPreview = HtmlPayload(name: url.lastPathComponent, data: data, base: url.deletingLastPathComponent())
            return
        }

        busy = true
        Task {
            do {
                let loaded = try IpaLoader.load(url: url)
                await MainActor.run {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        self.ipa = loaded
                        self.pickedIcon = nil
                        self.photoItem = nil
                    }
                    busy = false
                    flash("已载入 \(loaded.entries.count) 个文件")
                }
            } catch {
                await MainActor.run {
                    busy = false
                    flash("打不开：\(error.localizedDescription)")
                }
            }
        }
    }

    private func exportIpa(_ ipa: LoadedIpa) {
        guard let icon = pickedIcon else { return }
        busy = true
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> (URL?, Int) in
                let (data, count) = IpaLoader.rebuild(ipa, icon: icon)
                let base = ipa.fileName.replacingOccurrences(of: ".ipa", with: "")
                    .replacingOccurrences(of: ".zip", with: "")
                let name = base + "-newicon.ipa"
                let dir = FileManager.default.temporaryDirectory
                let url = dir.appendingPathComponent(name)
                try? FileManager.default.removeItem(at: url)
                do {
                    try data.write(to: url)
                    return (url, count)
                } catch {
                    return (nil, count)
                }
            }.value

            await MainActor.run {
                busy = false
                if let url = result.0 {
                    shareURL = url
                    flash("换好了 \(result.1) 个图标")
                } else {
                    flash("导出失败，存储空间不够？")
                }
            }
        }
    }

    private func flash(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { if toast == text { toast = nil } }
        }
    }
}

struct ShareFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
