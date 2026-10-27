import CoreGraphics
import Foundation

// Giraffy, drawn in code (no images). One drawing for every place he appears: the notch
// (BotEngine), the launch greeting and the file drop. The callers own the animation; this
// file only turns a pose into shapes.
//
// Units: the head is 59 units tall (ossicone knobs excluded), its centre is the origin, y
// points down. Callers translate to the head centre and scale by their unit before drawing.

enum GiraffyEye: Equatable {
    case open, happy, closed, spiral, heart, star
}

enum GiraffyMouth: Equatable {
    case line, smile, frown, flat, chew, wobble, open, oh
}

/// Everything that moves. Angles in radians; ears and ossicones: 0 = rest, + up/out.
struct GiraffyPose {
    var tilt: CGFloat = 0
    /// Head turn, -1 (his right, the viewer's left) … 1.
    var turn: CGFloat = 0
    var earL: CGFloat = 0
    var earR: CGFloat = 0
    var earLen: CGFloat = 1
    var ossL: CGFloat = 0
    var ossR: CGFloat = 0
    var ossLen: CGFloat = 1
    var ossLenL: CGFloat = 1
    var eyeL: GiraffyEye = .open
    var eyeR: GiraffyEye = .open
    /// 0 closed … 1 open (blinks).
    var eyeOpen: CGFloat = 1
    var eyeScale: CGFloat = 1
    /// Flat upper lid, 0 none … 1 shut (sleepy, annoyed).
    var lid: CGFloat = 0
    /// Where the pupils look, -1…1 on each axis.
    var look: CGPoint = .zero
    var mouth: GiraffyMouth = .line
    /// 0…1 for .open and .oh.
    var mouthOpen: CGFloat = 0
    /// -1…1 for .chew.
    var chew: CGFloat = 0
    var blush: CGFloat = 0
    /// Seconds, for the spinning spiral and star eyes.
    var time: CGFloat = 0
}

struct GiraffyColors {
    var body: CGColor
    var bodyDark: CGColor
    var muzzle: CGColor
    var spot: CGColor
    var innerEar: CGColor
    var eyeWhite: CGColor
    var ink: CGColor
    var rim: CGColor

    /// PG purple, from GiraffyTheme.
    static let pg = GiraffyColors.from(hex: GiraffyTheme.pgPurpleHex)

    /// The same giraffe in another body colour (the little ones in the Flow window).
    static func from(hex: String) -> GiraffyColors {
        GiraffyColors(
            body: giraffyCG(hex),
            bodyDark: giraffyCG(GiraffyTheme.mix(hex, towards: 0, amount: 0.35)),
            muzzle: giraffyCG(GiraffyTheme.mix(hex, towards: 1, amount: 0.30)),
            spot: giraffyCG(GiraffyTheme.giraffeSpotHex),
            innerEar: giraffyCG(GiraffyTheme.mix(hex, towards: 1, amount: 0.65)),
            eyeWhite: giraffyCG("#FBF8FF"),
            ink: giraffyCG("#1B1030"),
            rim: giraffyCG(GiraffyTheme.mix(hex, towards: 1, amount: 0.65), alpha: 0.38))
    }

    static func from(cgColor: CGColor) -> GiraffyColors {
        let c = cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components ?? [0.43, 0.25, 0.77, 1]
        let rgb = c.count >= 3 ? Array(c.prefix(3)) : [c[0], c[0], c[0]]
        let hex = "#" + rgb.map { String(format: "%02X", Int((max(0, min(1, $0)) * 255).rounded())) }.joined()
        return from(hex: hex)
    }
}

func giraffyCG(_ hex: String, alpha: CGFloat = 1) -> CGColor {
    let c = GiraffyTheme.components(hex)
    return CGColor(red: CGFloat(c[0]), green: CGFloat(c[1]), blue: CGFloat(c[2]), alpha: alpha)
}

enum Giraffy {
    /// Fixed spot shapes: seeded once, never re-randomised per frame.
    private struct Spot { let x: CGFloat; let y: CGFloat; let r: CGFloat; let rot: CGFloat; let k: [CGFloat] }
    private static let headSpots = [
        Spot(x: -3, y: -21, r: 4.6, rot: 3.2144, k: [0.9838, 1.0197, 1.0115, 1.1314, 0.9875, 0.7768, 0.9840]),
        Spot(x: -16, y: 2, r: 3.8, rot: 3.8185, k: [0.9471, 0.9608, 1.1280, 0.9332, 1.0483, 1.0535, 0.8140]),
        Spot(x: 16.5, y: -21, r: 3.3, rot: 1.1216, k: [0.8670, 0.9221, 0.9134, 1.0080, 0.7986, 1.0147, 1.0052]),
    ]
    /// Neck spots: `y` is the distance below the head centre, `x` the offset from the neck's middle.
    private static let neckSpots = [
        Spot(x: -3, y: 38, r: 4.2, rot: 2.6290, k: [1.1284, 1.1105, 1.0937, 0.8861, 1.0266, 0.8558, 0.7659]),
        Spot(x: 3, y: 58, r: 3.9, rot: 4.6553, k: [1.1897, 0.8765, 0.8074, 1.0820, 0.8997, 0.9946, 1.0053]),
    ]

    /// Draws the neck (from `neckBase`, in head units relative to the head centre, up to the
    /// head; nil for no neck), then the head. The context must already be translated to the
    /// head centre and scaled to head units.
    static func draw(in cg: CGContext, pose p: GiraffyPose, colors c: GiraffyColors, neckBase: CGPoint?) {
        cg.saveGState()
        cg.setLineJoin(.round)
        if let base = neckBase { drawNeck(cg, base: base, colors: c) }

        cg.saveGState()
        cg.rotate(by: p.tilt)
        let tr = max(-1, min(1, p.turn)), fo = tr * 3
        cg.scaleBy(x: 1 - 0.06 * abs(tr), y: 1)

        ossicone(cg, side: -1, angle: p.ossL, len: p.ossLen * p.ossLenL, colors: c)
        ossicone(cg, side: 1, angle: p.ossR, len: p.ossLen, colors: c)
        ear(cg, side: -1, lift: p.earL, len: p.earLen * (1 - 0.3 * max(0, -tr)), colors: c)
        ear(cg, side: 1, lift: p.earR, len: p.earLen * (1 - 0.3 * max(0, tr)), colors: c)

        // Head: purple to dark, spots, lighter muzzle, a thin rim so he reads on a black notch.
        let head = headPath()
        cg.saveGState()
        cg.addPath(head); cg.clip()
        fillVertical(cg, from: c.body, to: c.bodyDark, y0: -29, y1: 30)
        cg.setFillColor(c.spot)
        for s in headSpots { cg.addPath(blob(s, at: CGPoint(x: s.x + fo * 0.6, y: s.y))); cg.fillPath() }
        let muzzle = CGMutablePath()
        muzzle.move(to: CGPoint(x: -24, y: 15))
        muzzle.addQuadCurve(to: CGPoint(x: 24, y: 15), control: CGPoint(x: fo, y: 4))
        muzzle.addLine(to: CGPoint(x: 24, y: 36)); muzzle.addLine(to: CGPoint(x: -24, y: 36)); muzzle.closeSubpath()
        cg.setFillColor(c.muzzle); cg.addPath(muzzle); cg.fillPath()
        if p.blush > 0.01 {
            cg.setFillColor(CGColor(red: 1, green: 0.47, blue: 0.59, alpha: 0.45 * min(1, p.blush)))
            for sd: CGFloat in [-1, 1] {
                cg.fillEllipse(in: CGRect(x: sd * 13 + fo - 4.5, y: 4 - 2.6, width: 9, height: 5.2))
            }
        }
        cg.restoreGState()
        cg.addPath(head); cg.setStrokeColor(c.rim); cg.setLineWidth(1); cg.strokePath()

        eye(cg, side: -1, kind: p.eyeL, pose: p, fo: fo, colors: c)
        eye(cg, side: 1, kind: p.eyeR, pose: p, fo: fo, colors: c)

        cg.setFillColor(c.ink.copy(alpha: 0.55) ?? c.ink)
        for sd: CGFloat in [-1, 1] {
            cg.saveGState()
            cg.translateBy(x: sd * 5 + fo, y: 19); cg.rotate(by: sd * 0.3)
            cg.fillEllipse(in: CGRect(x: -1.7, y: -1.2, width: 3.4, height: 2.4))
            cg.restoreGState()
        }
        mouth(cg, pose: p, fo: fo, colors: c)

        cg.restoreGState()
        cg.restoreGState()
    }

    // MARK: - Parts

    private static func drawNeck(_ cg: CGContext, base: CGPoint, colors c: GiraffyColors) {
        let top = CGPoint(x: 0, y: 16)
        guard base.y > top.y + 4 else { return }
        let ctrl = CGPoint(x: base.x * 0.55, y: (base.y + top.y) / 2)
        let path = CGMutablePath()
        path.move(to: base); path.addQuadCurve(to: top, control: ctrl)
        cg.saveGState()
        cg.addPath(path)
        cg.setLineWidth(17); cg.setLineCap(.round)
        cg.replacePathWithStrokedPath(); cg.clip()
        fillVertical(cg, from: c.body, to: c.bodyDark, y0: top.y, y1: base.y)
        cg.restoreGState()
        // Spots ride the curve (its height is linear in t because the control sits halfway).
        cg.setFillColor(c.spot)
        for s in neckSpots {
            let t = (s.y - base.y) / (top.y - base.y)
            guard t > 0, t < 1 else { continue }
            let x = (1 - t) * (1 - t) * base.x + 2 * (1 - t) * t * ctrl.x + t * t * top.x
            cg.addPath(blob(s, at: CGPoint(x: x + s.x, y: s.y))); cg.fillPath()
        }
    }

    private static func headPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: -29))
        p.addCurve(to: CGPoint(x: 20, y: -12), control1: CGPoint(x: 14, y: -29), control2: CGPoint(x: 20, y: -24))
        p.addCurve(to: CGPoint(x: 15, y: 18), control1: CGPoint(x: 20, y: 2), control2: CGPoint(x: 17, y: 10))
        p.addCurve(to: CGPoint(x: 0, y: 30), control1: CGPoint(x: 13, y: 27), control2: CGPoint(x: 7, y: 30))
        p.addCurve(to: CGPoint(x: -15, y: 18), control1: CGPoint(x: -7, y: 30), control2: CGPoint(x: -13, y: 27))
        p.addCurve(to: CGPoint(x: -20, y: -12), control1: CGPoint(x: -17, y: 10), control2: CGPoint(x: -20, y: 2))
        p.addCurve(to: CGPoint(x: 0, y: -29), control1: CGPoint(x: -20, y: -24), control2: CGPoint(x: -14, y: -29))
        p.closeSubpath()
        return p
    }

    private static func blob(_ s: Spot, at c: CGPoint) -> CGPath {
        let n = s.k.count
        let pts: [CGPoint] = (0..<n).map { i in
            let a = s.rot + CGFloat(i) / CGFloat(n) * 2 * .pi, r = s.r * s.k[i]
            return CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
        }
        let path = CGMutablePath()
        let last = pts[n - 1]
        path.move(to: CGPoint(x: (last.x + pts[0].x) / 2, y: (last.y + pts[0].y) / 2))
        for i in 0..<n {
            let a = pts[i], b = pts[(i + 1) % n]
            path.addQuadCurve(to: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), control: a)
        }
        path.closeSubpath()
        return path
    }

    private static func ossicone(_ cg: CGContext, side: CGFloat, angle: CGFloat, len: CGFloat, colors c: GiraffyColors) {
        cg.saveGState()
        cg.translateBy(x: side * 8.5, y: -25); cg.scaleBy(x: side, y: 1); cg.rotate(by: angle)
        let L = 12 * len
        cg.setStrokeColor(c.body); cg.setLineWidth(5); cg.setLineCap(.round)
        cg.move(to: CGPoint(x: 0, y: 3)); cg.addLine(to: CGPoint(x: 0, y: -L)); cg.strokePath()
        let knob = CGRect(x: -4.2, y: -L - 4.2, width: 8.4, height: 8.4)
        cg.setFillColor(c.bodyDark); cg.fillEllipse(in: knob)
        cg.setStrokeColor(c.rim); cg.setLineWidth(0.9); cg.strokeEllipse(in: knob)
        cg.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
        cg.fillEllipse(in: CGRect(x: -1.3 * side - 1.2, y: -L - 1.3 - 1.2, width: 2.4, height: 2.4))
        cg.restoreGState()
    }

    private static func ear(_ cg: CGContext, side: CGFloat, lift: CGFloat, len: CGFloat, colors c: GiraffyColors) {
        cg.saveGState()
        cg.translateBy(x: side * 17.5, y: -17); cg.scaleBy(x: side, y: 1); cg.rotate(by: -(0.3 + lift))
        let L = 15 * len, w: CGFloat = 6.5
        let outer = CGMutablePath()
        outer.move(to: .zero)
        outer.addQuadCurve(to: CGPoint(x: L, y: 0), control: CGPoint(x: L * 0.5, y: -w))
        outer.addQuadCurve(to: .zero, control: CGPoint(x: L * 0.5, y: w * 0.9))
        cg.setFillColor(c.body); cg.addPath(outer); cg.fillPath()
        cg.setStrokeColor(c.rim); cg.setLineWidth(0.9); cg.addPath(outer); cg.strokePath()
        let inner = CGMutablePath()
        inner.move(to: CGPoint(x: 2.5, y: 0))
        inner.addQuadCurve(to: CGPoint(x: L * 0.8, y: 0), control: CGPoint(x: L * 0.5, y: -w * 0.45))
        inner.addQuadCurve(to: CGPoint(x: 2.5, y: 0), control: CGPoint(x: L * 0.5, y: w * 0.4))
        cg.setFillColor(c.innerEar); cg.addPath(inner); cg.fillPath()
        cg.restoreGState()
    }

    private static func eye(_ cg: CGContext, side: CGFloat, kind: GiraffyEye, pose p: GiraffyPose, fo: CGFloat, colors c: GiraffyColors) {
        cg.saveGState()
        cg.translateBy(x: side * 11 + fo, y: -9); cg.scaleBy(x: side, y: 1); cg.rotate(by: -0.14)
        cg.scaleBy(x: p.eyeScale, y: p.eyeScale)
        cg.setStrokeColor(c.ink); cg.setLineCap(.round); cg.setLineJoin(.round)
        defer { cg.restoreGState() }

        switch kind {
        case .happy:
            cg.setLineWidth(2.2)
            cg.move(to: CGPoint(x: -5.5, y: 2)); cg.addQuadCurve(to: CGPoint(x: 5.5, y: 2), control: CGPoint(x: 0, y: -5.5)); cg.strokePath()
            cg.setLineWidth(1.1)
            cg.move(to: CGPoint(x: 5, y: 0.6)); cg.addLine(to: CGPoint(x: 7.6, y: -1.4)); cg.strokePath()
            return
        case .closed:
            cg.setLineWidth(2)
            cg.move(to: CGPoint(x: -5.5, y: -0.5)); cg.addQuadCurve(to: CGPoint(x: 5.5, y: -0.5), control: CGPoint(x: 0, y: 3.6)); cg.strokePath()
            cg.setLineWidth(1.1)
            for u: CGFloat in [0.55, 0.75, 0.92] {
                let bx = -5.5 + 11 * u, by = -0.5 + 8.2 * u * (1 - u)
                cg.move(to: CGPoint(x: bx, y: by)); cg.addLine(to: CGPoint(x: bx + 1 + u, y: by + 2.4)); cg.strokePath()
            }
            return
        case .spiral:
            cg.setFillColor(c.eyeWhite); cg.fillEllipse(in: CGRect(x: -5.6, y: -5.6, width: 11.2, height: 11.2))
            cg.setLineWidth(1.2)
            let end = 2 * CGFloat.pi * 2.4, spin = p.time * 7
            var a: CGFloat = 0
            while a <= end {
                let r = a / end * 4.8
                let pt = CGPoint(x: cos(a + spin) * r, y: sin(a + spin) * r)
                if a == 0 { cg.move(to: pt) } else { cg.addLine(to: pt) }
                a += 0.25
            }
            cg.strokePath()
            return
        case .heart:
            cg.setFillColor(giraffyCG("#FF4D6D"))
            cg.addPath(heartPath(size: 11)); cg.fillPath()
            return
        case .star:
            cg.rotate(by: p.time * 1.5 * side)
            cg.setFillColor(giraffyCG("#F7B32B"))
            cg.addPath(starPath(outer: 6.2, inner: 2.7)); cg.fillPath()
            return
        case .open:
            break
        }

        let o = max(0.06, min(1.3, p.eyeOpen))
        let almond = CGMutablePath()
        almond.move(to: CGPoint(x: -6.5, y: 0))
        almond.addQuadCurve(to: CGPoint(x: 6.5, y: 0), control: CGPoint(x: 0, y: -8.5 * o))
        almond.addQuadCurve(to: CGPoint(x: -6.5, y: 0), control: CGPoint(x: 0, y: 6.2 * min(1, o)))
        almond.closeSubpath()
        cg.setFillColor(c.eyeWhite); cg.addPath(almond); cg.fillPath()

        cg.saveGState()
        cg.addPath(almond); cg.clip()
        let lx = max(-1, min(1, p.look.x)) * side, ly = max(-1, min(1, p.look.y))
        cg.setFillColor(c.ink)
        cg.fillEllipse(in: CGRect(x: lx * 2.6 - 3.3, y: ly * 2.1 - 0.3 - 3.3, width: 6.6, height: 6.6))
        cg.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        cg.fillEllipse(in: CGRect(x: lx * 2.6 - 1.1 * side - 1.05, y: ly * 2.1 - 1.5 - 1.05, width: 2.1, height: 2.1))
        var lidY: CGFloat? = nil
        if p.lid > 0 {
            let y = -4.25 * o + p.lid * (4.25 * o + 2.5)
            lidY = y
            cg.setFillColor(c.body); cg.fill(CGRect(x: -9, y: -14, width: 18, height: y + 14))
        }
        cg.restoreGState()

        cg.setLineWidth(1.6)
        if let y = lidY {
            let k = y < 0 ? y / (-17 * o) : y / (12.4 * min(1, o))
            let hw = 6.5 * sqrt(max(0, 1 - 4 * min(0.25, k)))
            cg.move(to: CGPoint(x: -hw, y: y)); cg.addLine(to: CGPoint(x: hw, y: y)); cg.strokePath()
            cg.setLineWidth(1)
            cg.move(to: CGPoint(x: hw - 0.4, y: y)); cg.addLine(to: CGPoint(x: hw + 2.2, y: y - 1.6)); cg.strokePath()
        } else {
            cg.move(to: CGPoint(x: -6.5, y: 0)); cg.addQuadCurve(to: CGPoint(x: 6.5, y: 0), control: CGPoint(x: 0, y: -8.5 * o)); cg.strokePath()
            cg.setLineWidth(1)
            for u: CGFloat in [0.58, 0.76, 0.93] {
                let bx = -6.5 + 13 * u, by = -17 * o * u * (1 - u)
                cg.move(to: CGPoint(x: bx, y: by)); cg.addLine(to: CGPoint(x: bx + 1.4 + u * 1.6, y: by - 2.2 - u * 0.8)); cg.strokePath()
            }
        }
    }

    private static func mouth(_ cg: CGContext, pose p: GiraffyPose, fo: CGFloat, colors c: GiraffyColors) {
        cg.saveGState()
        cg.translateBy(x: fo, y: 0)
        cg.setStrokeColor(c.ink.copy(alpha: 0.75) ?? c.ink); cg.setLineCap(.round); cg.setLineWidth(1.3)
        switch p.mouth {
        case .smile:
            cg.move(to: CGPoint(x: -5, y: 23.8)); cg.addQuadCurve(to: CGPoint(x: 5, y: 23.8), control: CGPoint(x: 0, y: 28.6)); cg.strokePath()
        case .frown:
            cg.move(to: CGPoint(x: -4, y: 26.6)); cg.addQuadCurve(to: CGPoint(x: 4, y: 26.6), control: CGPoint(x: 0, y: 23.4)); cg.strokePath()
        case .flat:
            cg.move(to: CGPoint(x: -4, y: 25.4)); cg.addLine(to: CGPoint(x: 4, y: 25.4)); cg.strokePath()
        case .chew:
            let k = p.chew * 1.6
            cg.move(to: CGPoint(x: -3 + k, y: 25.2))
            cg.addQuadCurve(to: CGPoint(x: 3 + k, y: 25.2), control: CGPoint(x: k, y: 26.4 + abs(p.chew) * 0.6)); cg.strokePath()
        case .wobble:
            cg.move(to: CGPoint(x: -4.5, y: 25.5))
            for i in 1...6 { cg.addLine(to: CGPoint(x: -4.5 + CGFloat(i) * 1.5, y: 25.5 + (i % 2 == 1 ? -1.1 : 1.1))) }
            cg.strokePath()
        case .open, .oh:
            let mo = max(0, min(1.2, p.mouthOpen))
            let rx = p.mouth == .oh ? 2 + mo * 2 : 3 + mo * 2, ry = 0.8 + mo * 3.6
            cg.setFillColor(giraffyCG("#2A1440"))
            cg.fillEllipse(in: CGRect(x: -rx, y: 25.3 - ry, width: rx * 2, height: ry * 2))
        case .line:
            cg.move(to: CGPoint(x: -3, y: 25)); cg.addQuadCurve(to: CGPoint(x: 3, y: 25), control: CGPoint(x: 0, y: 26.6)); cg.strokePath()
        }
        cg.restoreGState()
    }

    // MARK: - Helpers

    private static func fillVertical(_ cg: CGContext, from a: CGColor, to b: CGColor, y0: CGFloat, y1: CGFloat) {
        guard let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [a, b] as CFArray, locations: [0, 1]) else { return }
        cg.drawLinearGradient(g, start: CGPoint(x: 0, y: y0), end: CGPoint(x: 0, y: y1),
                              options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private static func heartPath(size s: CGFloat) -> CGPath {
        let r = s / 2, p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: r * 0.9))
        p.addCurve(to: CGPoint(x: 0, y: -r * 0.5), control1: CGPoint(x: -r * 1.6, y: -r * 0.2), control2: CGPoint(x: -r * 0.8, y: -r * 1.4))
        p.addCurve(to: CGPoint(x: 0, y: r * 0.9), control1: CGPoint(x: r * 0.8, y: -r * 1.4), control2: CGPoint(x: r * 1.6, y: -r * 0.2))
        p.closeSubpath()
        return p
    }

    private static func starPath(outer: CGFloat, inner: CGFloat) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<10 {
            let a = CGFloat(i) * .pi / 5 - .pi / 2, r = i % 2 == 0 ? outer : inner
            let pt = CGPoint(x: cos(a) * r, y: sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
