import UIKit

enum IconMaker {

    /// 读 PNG 的像素宽度
    static func pixelSize(of data: Data?) -> Int? {
        guard let data, let img = UIImage(data: data) else { return nil }
        let scale = img.scale
        return Int(max(img.size.width, img.size.height) * scale)
    }

    /// 按 size 输出正方形 PNG，居中裁切铺满
    static func render(_ source: UIImage, size: Int) -> Data? {
        guard size > 0 else { return nil }
        let side = CGFloat(size)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let out = renderer.image { ctx in
            let s = max(side / source.size.width, side / source.size.height)
            let w = source.size.width * s
            let h = source.size.height * s
            source.draw(in: CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
        }
        return out.pngData()
    }
}
