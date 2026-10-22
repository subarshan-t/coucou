import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Draws Giraffy in every pose the app uses into an off-screen bitmap: each one must draw
// something and stay inside its frame. With GIRAFFY_RENDER_DIR set, the frames are also
// saved as PNGs (CI uploads them) so the Swift drawing can be reviewed without the app.
@main
enum GiraffyDrawingTests {
    nonisolated(unsafe) static var failures = 0
    static func check(_ name: String, _ ok: Bool) {
        print("\(ok ? "✓" : "✗") \(name)")
        if !ok { failures += 1 }
    }

    static func poses() -> [(String, GiraffyPose)] {
        var out: [(String, GiraffyPose)] = [("idle", GiraffyPose())]
        var p = GiraffyPose(); p.earL = 1.15; p.earR = 1.15; p.ossLen = 1.08; p.eyeScale = 1.22
        out.append(("approval", p))
        p = GiraffyPose(); p.tilt = 0.2; p.ossL = 0.8; p.ossLenL = 0.85; p.earL = 0.35; p.earR = -0.1
        out.append(("question", p))
        p = GiraffyPose(); p.eyeL = .happy; p.eyeR = .happy; p.mouth = .smile; p.earL = 0.4; p.earR = 0.4
        out.append(("finished", p))
        p = GiraffyPose(); p.earL = -0.95; p.earR = -0.95; p.ossL = 0.7; p.ossR = 0.7; p.mouth = .frown; p.eyeOpen = 0.72
        out.append(("error", p))
        p = GiraffyPose(); p.lid = 0.55; p.earL = -0.4; p.earR = -0.4
        out.append(("ratelimit", p))
        p = GiraffyPose(); p.eyeL = .closed; p.eyeR = .closed; p.tilt = 0.13; p.earL = -0.55; p.earR = -0.55
        out.append(("sleeping", p))
        p = GiraffyPose(); p.eyeL = .spiral; p.eyeR = .spiral; p.mouth = .wobble; p.time = 1
        out.append(("dizzy", p))
        p = GiraffyPose(); p.turn = 0.8; p.look = CGPoint(x: 1, y: -0.25); p.earL = 0.25; p.earR = 0.25
        out.append(("searching", p))
        p = GiraffyPose(); p.look = CGPoint(x: 0.75, y: -0.85); p.earR = -0.55; p.mouth = .chew; p.chew = 0.6
        out.append(("thinking", p))
        p = GiraffyPose(); p.mouth = .open; p.mouthOpen = 0.6
        out.append(("speaking", p))
        p = GiraffyPose(); p.eyeL = .heart; p.eyeR = .heart; p.blush = 1; p.mouth = .smile
        out.append(("love", p))
        p = GiraffyPose(); p.eyeL = .star; p.eyeR = .star; p.time = 0.5
        out.append(("star", p))
        p = GiraffyPose(); p.mouth = .oh; p.mouthOpen = 0.4; p.earL = 1.25; p.earR = 1.25; p.ossLen = 1.3
        out.append(("surprised", p))
        p = GiraffyPose(); p.lid = 0.5; p.mouth = .flat; p.look = CGPoint(x: 0.6, y: 0)
        out.append(("annoyed", p))
        p = GiraffyPose(); p.eyeL = .happy; p.mouth = .smile
        out.append(("wink", p))
        return out
    }

    static func render(_ pose: GiraffyPose, colors: GiraffyColors, size: Int, neck: Bool) -> CGImage? {
        guard let cg = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                 space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // y down, like SwiftUI's Canvas.
        cg.translateBy(x: 0, y: CGFloat(size)); cg.scaleBy(x: 1, y: -1)
        cg.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        cg.fill(CGRect(x: 0, y: 0, width: size, height: size))
        let u = CGFloat(size) / 130
        cg.translateBy(x: CGFloat(size) / 2, y: CGFloat(size) * 0.48)
        cg.scaleBy(x: u, y: u)
        Giraffy.draw(in: cg, pose: pose, colors: colors, neckBase: neck ? CGPoint(x: 0, y: 80) : nil)
        return cg.makeImage()
    }

    /// Share of pixels that are not the black background.
    static func coverage(_ image: CGImage) -> Double {
        guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return 0 }
        let n = image.width * image.height, bpr = image.bytesPerRow
        var lit = 0
        for y in 0..<image.height {
            for x in 0..<image.width {
                let i = y * bpr + x * 4
                if Int(bytes[i]) + Int(bytes[i + 1]) + Int(bytes[i + 2]) > 30 { lit += 1 }
            }
        }
        return Double(lit) / Double(n)
    }

    static func save(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    static func main() {
        let dir = ProcessInfo.processInfo.environment["GIRAFFY_RENDER_DIR"].map { URL(fileURLWithPath: $0) }
        if let dir { try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }

        for (name, pose) in poses() {
            guard let image = render(pose, colors: .pg, size: 260, neck: true) else { check("\(name): renders", false); continue }
            let c = coverage(image)
            check("\(name): draws a giraffe (\(Int(c * 100))% of the frame)", c > 0.08 && c < 0.7)
            if let dir { save(image, to: dir.appendingPathComponent("giraffy-\(name).png")) }
        }
        // Notch size: the head alone at 26 pt must still draw.
        if let small = render(GiraffyPose(), colors: .pg, size: 26, neck: false) {
            check("notch size draws", coverage(small) > 0.05)
            if let dir { save(small, to: dir.appendingPathComponent("giraffy-26pt.png")) }
        } else { check("notch size renders", false) }
        // Another body colour (the little ones in the Flow window).
        if let blue = render(GiraffyPose(), colors: .from(hex: "#3E86E0"), size: 120, neck: true) {
            check("tinted giraffe draws", coverage(blue) > 0.08)
            if let dir { save(blue, to: dir.appendingPathComponent("giraffy-tinted.png")) }
        }
        check("PG colours come from the theme", GiraffyColors.pg.body.components == giraffyCG(GiraffyTheme.pgPurpleHex).components)

        if failures > 0 { print("\n\(failures) failure(s)"); exit(1) }
        print("\nAll Giraffy drawing tests passed")
    }
}
