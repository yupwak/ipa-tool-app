import Foundation
import UIKit

struct IpaInfo {
    var displayName: String = ""
    var bundleID: String = ""
    var version: String = ""
    var minOS: String = ""
    var executable: String = ""
}

struct LoadedIpa {
    var fileName: String
    var entries: [ZipEntry]
    var appRoot: String          // 例如 "Payload/XiaoqiRes.app/"
    var rootIconPrefix: String   // 图标判断用的 app 根前缀
    var info: IpaInfo
    var iconIndexes: [Int]

    var totalBytes: Int {
        entries.reduce(0) { $0 + ($1.data?.count ?? $1.uncompressedSize) }
    }
}

enum IpaLoader {

    static func load(url: URL) throws -> LoadedIpa {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let raw = try Data(contentsOf: url)
        return try load(data: raw, fileName: url.lastPathComponent)
    }

    static func load(data raw: Data, fileName: String) throws -> LoadedIpa {
        var entries = try ZipArchive.read(raw)

        // 找出 app 根目录
        var appRoot = ""
        for e in entries {
            let n = e.name
            if let r = n.range(of: #"^(Payload/)?[^/]+\.app/"#, options: .regularExpression) {
                appRoot = String(n[r])
                break
            }
        }
        guard !appRoot.isEmpty else { throw ZipError.damaged("包里找不到 .app 目录") }

        // 只解出需要的：Info.plist + 图标 + 其它按需
        let plistPath = appRoot + "Info.plist"
        var info = IpaInfo()
        if let idx = entries.firstIndex(where: { $0.name == plistPath }) {
            entries[idx].data = try ZipArchive.extract(entries[idx], from: raw)
            if let d = entries[idx].data,
               let obj = try? PropertyListSerialization.propertyList(from: d, options: [], format: nil),
               let dict = obj as? [String: Any] {
                info.displayName = (dict["CFBundleDisplayName"] as? String)
                    ?? (dict["CFBundleName"] as? String) ?? ""
                info.bundleID = (dict["CFBundleIdentifier"] as? String) ?? ""
                info.version = (dict["CFBundleShortVersionString"] as? String) ?? ""
                info.minOS = (dict["MinimumOSVersion"] as? String) ?? ""
                info.executable = (dict["CFBundleExecutable"] as? String) ?? ""
            }
        }

        // 图标
        var iconIdx: [Int] = []
        for (i, e) in entries.enumerated() {
            let n = e.name
            let base = (n as NSString).lastPathComponent
            if n.hasPrefix(appRoot) {
                if n.hasSuffix(".png") {
                    let rel = String(n.dropFirst(appRoot.count))
                    let isRootIcon = !rel.contains("/")
                        && (base == "icon.png" || base == "icon@2x.png" || base == "icon@3x.png")
                    if base.hasPrefix("AppIcon") || isRootIcon {
                        iconIdx.append(i)
                    }
                }
            } else if base.hasPrefix("iTunesArtwork") {
                iconIdx.append(i)
            }
        }

        // 解出图标数据
        for i in iconIdx where entries[i].data == nil {
            entries[i].data = try? ZipArchive.extract(entries[i], from: raw)
        }

        return LoadedIpa(fileName: fileName, entries: entries, appRoot: appRoot,
                         rootIconPrefix: appRoot, info: info, iconIndexes: iconIdx)
    }

    /// 替换全部图标并用新数据重建 IPA
    static func rebuild(_ ipa: LoadedIpa, icon: UIImage) -> (Data, Int) {
        var entries = ipa.entries
        var count = 0
        for i in ipa.iconIndexes {
            let e = entries[i]
            let size = IconMaker.pixelSize(of: e.data) ?? 180
            guard let png = IconMaker.render(icon, size: size) else { continue }
            entries[i].data = png
            entries[i].methodFix()
            count += 1
        }
        return (ZipArchive.write(entries), count)
    }
}

private extension ZipEntry {
    mutating func methodFix() {
        // 写入时统一按 store 处理，这里不需要额外动作
    }
}
