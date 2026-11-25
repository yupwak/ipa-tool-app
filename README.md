# IPA 工坊

原生 iOS App：导入 IPA / ZIP / HTML，查看包内文件、解析 Info.plist、替换 App 图标并导出新 IPA。全部在本机完成。

- ZIP 读写：自研（zlib raw inflate + store 打包）
- 图标：按包内原尺寸重绘，居中裁切
- HTML：内置 WKWebView 预览，支持预览 zip 里的 html
- UI：iOS 26 液态玻璃，低版本回落材质

构建：GitHub Actions（macos-26 + Xcode 26），产出未签名 IPA。
