import Foundation

struct ZipEntry: Identifiable {
    let id = UUID()
    let name: String
    let method: UInt16
    let compressedSize: Int
    let uncompressedSize: Int
    let localHeaderOffset: Int
    var data: Data?

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(data?.count ?? uncompressedSize), countStyle: .file)
    }
}

enum ZipError: LocalizedError {
    case notZip
    case damaged(String)

    var errorDescription: String? {
        switch self {
        case .notZip: return "这不是有效的 ZIP / IPA 文件"
        case .damaged(let s): return "包结构损坏：\(s)"
        }
    }
}

enum ZipArchive {

    // MARK: - 读

    static func read(_ data: Data) throws -> [ZipEntry] {
        let bytes = [UInt8](data)
        guard bytes.count > 22 else { throw ZipError.notZip }

        // 找 EOCD
        var eocd = -1
        let minPos = max(0, bytes.count - 65558)
        var i = bytes.count - 22
        while i >= minPos {
            if u32(bytes, i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw ZipError.notZip }

        let count = Int(u16(bytes, eocd + 10))
        let cdOffset = Int(u32(bytes, eocd + 16))
        guard cdOffset < bytes.count else { throw ZipError.damaged("中央目录越界") }

        var entries: [ZipEntry] = []
        var p = cdOffset
        for _ in 0..<count {
            guard p + 46 <= bytes.count, u32(bytes, p) == 0x02014b50 else { break }
            let method = u16(bytes, p + 10)
            let csize = Int(u32(bytes, p + 20))
            let usize = Int(u32(bytes, p + 24))
            let nlen = Int(u16(bytes, p + 28))
            let elen = Int(u16(bytes, p + 30))
            let clen = Int(u16(bytes, p + 32))
            let lho = Int(u32(bytes, p + 42))
            guard p + 46 + nlen <= bytes.count else { break }
            let name = String(decoding: bytes[(p + 46)..<(p + 46 + nlen)], as: UTF8.self)
            entries.append(ZipEntry(name: name, method: method, compressedSize: csize,
                                    uncompressedSize: usize, localHeaderOffset: lho, data: nil))
            p += 46 + nlen + elen + clen
        }
        return entries
    }

    /// 解出某个条目的内容
    static func extract(_ entry: ZipEntry, from data: Data) throws -> Data {
        let bytes = [UInt8](data)
        let lho = entry.localHeaderOffset
        guard lho + 30 <= bytes.count, u32(bytes, lho) == 0x04034b50 else {
            throw ZipError.damaged("本地头无效：\(entry.name)")
        }
        let nlen = Int(u16(bytes, lho + 26))
        let elen = Int(u16(bytes, lho + 28))
        let start = lho + 30 + nlen + elen
        let end = start + entry.compressedSize
        guard start >= 0, end <= bytes.count else { throw ZipError.damaged("数据越界：\(entry.name)") }
        let raw = data.subdata(in: start..<end)

        switch entry.method {
        case 0:
            return raw
        case 8:
            return try inflateRaw(raw, expected: entry.uncompressedSize)
        default:
            throw ZipError.damaged("不支持的压缩方式 \(entry.method)：\(entry.name)")
        }
    }

    static func inflateRaw(_ input: Data, expected: Int) throws -> Data {
        var stream = z_stream()
        var status = inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { throw ZipError.damaged("解压初始化失败") }
        defer { inflateEnd(&stream) }

        var out = Data(count: max(expected, 1024))
        let cap = out.count
        var produced = 0

        let ok: Bool = input.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Bool in
            guard let srcBase = src.bindMemory(to: Bytef.self).baseAddress else { return false }
            stream.next_in = UnsafeMutablePointer(mutating: srcBase)
            stream.avail_in = uInt(input.count)
            return out.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Bool in
                guard let dstBase = dst.bindMemory(to: Bytef.self).baseAddress else { return false }
                stream.next_out = dstBase
                stream.avail_out = uInt(cap)
                status = inflate(&stream, Z_FINISH)
                produced = cap - Int(stream.avail_out)
                return status == Z_STREAM_END
            }
        }
        guard ok else { throw ZipError.damaged("解压失败") }
        return out.prefix(produced)
    }

    // MARK: - 写（store 方式，无损）

    static func write(_ entries: [ZipEntry]) -> Data {
        var out = Data()
        var central = Data()
        var offset = 0

        for e in entries {
            let nameBytes = Array(e.name.utf8)
            let payload = e.data ?? Data()
            let crc = crc32(payload)
            let size = UInt32(payload.count)

            var lh = Data()
            lh.append(u32le(0x04034b50))
            lh.append(u16le(20))
            lh.append(u16le(0x0800))
            lh.append(u16le(0))
            lh.append(u16le(0))
            lh.append(u16le(0))
            lh.append(u32le(crc))
            lh.append(u32le(size))
            lh.append(u32le(size))
            lh.append(u16le(UInt16(nameBytes.count)))
            lh.append(u16le(0))
            lh.append(contentsOf: nameBytes)

            out.append(lh)
            out.append(payload)

            var ch = Data()
            ch.append(u32le(0x02014b50))
            ch.append(u16le(20))
            ch.append(u16le(20))
            ch.append(u16le(0x0800))
            ch.append(u16le(0))
            ch.append(u16le(0))
            ch.append(u16le(0))
            ch.append(u32le(crc))
            ch.append(u32le(size))
            ch.append(u32le(size))
            ch.append(u16le(UInt16(nameBytes.count)))
            ch.append(u16le(0))
            ch.append(u16le(0))
            ch.append(u16le(0))
            ch.append(u16le(0))
            ch.append(u32le(0))
            ch.append(u32le(UInt32(offset)))
            ch.append(contentsOf: nameBytes)
            central.append(ch)

            offset += lh.count + payload.count
        }

        let cdOffset = UInt32(offset)
        out.append(central)

        var eocd = Data()
        eocd.append(u32le(0x06054b50))
        eocd.append(u16le(0))
        eocd.append(u16le(0))
        eocd.append(u16le(UInt16(entries.count)))
        eocd.append(u16le(UInt16(entries.count)))
        eocd.append(u32le(UInt32(central.count)))
        eocd.append(u32le(cdOffset))
        eocd.append(u16le(0))
        out.append(eocd)
        return out
    }

    // MARK: - 小工具

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            for i in 0..<raw.count {
                crc ^= UInt32(base[i])
                for _ in 0..<8 {
                    crc = (crc & 1) != 0 ? (0xEDB88320 ^ (crc >> 1)) : (crc >> 1)
                }
            }
        }
        return crc ^ 0xFFFFFFFF
    }

    static func u16(_ b: [UInt8], _ o: Int) -> UInt16 {
        guard o + 1 < b.count else { return 0 }
        return UInt16(b[o]) | (UInt16(b[o + 1]) << 8)
    }
    static func u32(_ b: [UInt8], _ o: Int) -> UInt32 {
        guard o + 3 < b.count else { return 0 }
        return UInt32(b[o]) | (UInt32(b[o + 1]) << 8) | (UInt32(b[o + 2]) << 16) | (UInt32(b[o + 3]) << 24)
    }
    static func u16le(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
    static func u32le(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
}
