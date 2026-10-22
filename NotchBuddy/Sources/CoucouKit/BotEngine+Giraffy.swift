import SwiftUI
import QuartzCore

/// The slow parts of Giraffy's pose (ears, ossicones, neck), eased towards each state's
/// target so he never snaps. Quick motions (flicks, wobbles, waves) are added on top.
struct GiraffyRig {
    var earL: CGFloat = 0
    var earR: CGFloat = 0
    var earLen: CGFloat = 1
    var ossL: CGFloat = 0
    var ossR: CGFloat = 0
    var ossLen: CGFloat = 1
    var ossLenL: CGFloat = 1
    /// Neck stretch in head units: + up out of the notch, − down into it.
    var neck: CGFloat = 0

    mutating func ease(to t: GiraffyRig, k: CGFloat) {
        earL += (t.earL - earL) * k; earR += (t.earR - earR) * k; earLen += (t.earLen - earLen) * k
        ossL += (t.ossL - ossL) * k; ossR += (t.ossR - ossR) * k
        ossLen += (t.ossLen - ossLen) * k; ossLenL += (t.ossLenL - ossLenL) * k
        neck += (t.neck - neck) * k
    }
}

extension BotEngine {
    /// Head units per point: the head (59 units) is a little taller than Mochi's body was.
    static func giraffyUnit(R: CGFloat) -> CGFloat { R / 32 }

    /// Draws Giraffy for the engine's current frame: the same box, centre and motion as before
    /// (offsets, squash, tilt, look, blinks, emotes); a squash taller than 1 stretches his neck.
    func drawGiraffy(context: GraphicsContext, size: CGSize) {
        let W = size.width, H = size.height, R = W * 0.3
        let u = Self.giraffyUnit(R: R)
        let now = CACurrentMediaTime()
        let dt = giraffyLastDraw > 0 ? min(0.1, now - giraffyLastDraw) : 0.016
        giraffyLastDraw = now

        giraffyRig.ease(to: giraffyRigTarget(), k: CGFloat(1 - exp(-dt * 9)))
        let pose = giraffyPose(now: now)

        let stretch = max(0, sy - 1) * 24 + giraffyRig.neck
        let hx = W / 2 + ox * R
        let hy = H / 2 + particleOverhang / 2 + oy * R + R * 0.06 - stretch * u
        giraffyHead = CGPoint(x: hx, y: hy)
        let scaleX = u * (1 + (sx - 1) * 0.5)
        let scaleY = u * (1 + (min(sy, 1) - 1) * 0.5)
        let base = CGPoint(x: (W / 2 - hx) / scaleX, y: (H - hy) / scaleY + 30)

        if bodyColor !== giraffyColorsFor {
            giraffyColorsFor = bodyColor
            giraffyColors = bodyColor.map { GiraffyColors.from(cgColor: $0) } ?? .pg
        }
        let colors = giraffyColors
        var ctx = context
        ctx.withCGContext { cg in
            cg.translateBy(x: hx, y: hy)
            cg.scaleBy(x: scaleX, y: scaleY)
            Giraffy.draw(in: cg, pose: pose, colors: colors, neckBase: base)
        }
    }

    /// Where each state wants his ears, ossicones and neck.
    private func giraffyRigTarget() -> GiraffyRig {
        var r = GiraffyRig()
        switch state {
        case .idle, .dizzy:
            break
        case .working:
            r.ossL = -0.22; r.ossR = -0.22; r.ossLen = 0.93; r.earL = 0.12; r.earR = 0.12
        case .thinking:
            r.earR = -0.55; r.earL = 0.15
        case .searching:
            r.earL = 0.25; r.earR = 0.25; r.neck = 4
        case .approval:
            // The key moment: neck up tall, ears straight up.
            r.earL = 1.15; r.earR = 1.15; r.ossL = -0.08; r.ossR = -0.08; r.ossLen = 1.08; r.neck = 8
        case .question:
            r.ossL = 0.8; r.ossLenL = 0.85; r.earL = 0.35; r.earR = -0.1
        case .finished:
            r.earL = 0.4; r.earR = 0.4
        case .error:
            r.earL = -0.95; r.earR = -0.95; r.ossL = 0.7; r.ossR = 0.7; r.ossLen = 0.92; r.neck = -3
        case .ratelimit:
            r.earL = -0.4; r.earR = -0.4; r.neck = -10
        case .sleeping:
            r.earL = -0.55; r.earR = -0.55; r.neck = -14
        }
        if isInListeningMode || voiceSubState == .listening {
            r.earL = 0.45; r.earR = 0.45; r.earLen = 0.75
        }
        if let emote = activeGiraffyEmote {
            switch emote {
            case .surprised: r.earL = 1.25; r.earR = 1.25; r.ossLen = 1.3; r.ossL = -0.1; r.ossR = -0.1
            case .annoyed:   r.earL = -0.25; r.earR = -0.25
            case .happy:     r.earL = 0.4; r.earR = 0.4
            case .proud:     r.earL = 0.2; r.earR = 0.2
            case .love:      r.earL = 0.35; r.earR = 0.35
            case .yawn:      r.earL = -0.3; r.earR = -0.3
            case .wink:      break
            case .listening: r.earL = 0.45; r.earR = 0.45; r.earLen = 0.75
            }
        }
        return r
    }

    private var activeGiraffyEmote: BotEmote? {
        CACurrentMediaTime() < giraffyEmoteUntil ? giraffyEmote : nil
    }

    private func giraffyPose(now: Double) -> GiraffyPose {
        var p = GiraffyPose()
        let t = CGFloat(now - t0)
        let r = giraffyRig
        p.earL = r.earL; p.earR = r.earR; p.earLen = r.earLen
        p.ossL = r.ossL; p.ossR = r.ossR; p.ossLen = r.ossLen; p.ossLenL = r.ossLenL
        p.tilt = tilt
        p.turn = max(-1, min(1, yaw / 0.6)) * 0.5
        p.time = t

        // Quick motions on top of the eased rig.
        switch state {
        case .idle:
            let ph = t.truncatingRemainder(dividingBy: 4.3)
            if ph < 0.4 { p.earR += 0.45 * sin(ph / 0.4 * 2 * .pi) }
        case .thinking:
            p.earR += 0.18 * sin(t * 1.3)
        case .dizzy:
            p.earL += 0.3 * sin(t * 5); p.earR -= 0.3 * sin(t * 5)
        default:
            break
        }
        if activeGiraffyEmote == .happy {
            let w = sin(t * 11); p.earL += 0.35 * w; p.earR -= 0.35 * w
        }
        if waveStart > 0, now >= waveStart, now < waveUntil {
            // A wave is an ear wave: he has no hands.
            let wt = CGFloat(now - waveStart)
            p.earR += 0.6 * sin(13 * wt) * min(1, wt / 0.18)
        }
        if isInListeningMode {
            p.earL += listeningLevel * 0.2; p.earR += listeningLevel * 0.2
        }

        // Eyes: the engine's shape, open amount and size.
        var shape = eyeOverride ?? cfg.eye
        if isDancing && dancingLevel > 0.15 && !isMini && (state == .idle || state == .finished) { shape = .happy }
        if morph > 0.5 {
            if isChewing { shape = .happy }
            else if slotHTarget > 0.05 || slotH > 0.10 { shape = .cup }
        }
        var eye: GiraffyEye = .open
        var scale: CGFloat = 1
        switch shape {
        case .pill: break
        case .wide: scale = 1.22
        case .dot: scale = 0.9
        case .line: p.lid = 0.5
        case .flat: p.lid = 0.55
        case .tired: p.lid = 0.55
        case .happy, .cup: eye = .happy
        case .closed: eye = .closed
        case .spiral: eye = .spiral
        case .heart: eye = .heart
        case .star: eye = .star
        case .wink: break
        }
        p.eyeL = shape == .wink ? .happy : eye
        p.eyeR = eye
        let fear = isMini ? 0 : min(1, moodBusy * 1.3)
        p.eyeScale = scale * es * (isMini ? 1.3 : 1) * (1 - 0.15 * fear)
        p.eyeOpen = open
        p.look = CGPoint(x: max(-1, min(1, yaw / 0.55)) + stressTremble.x * 4,
                         y: max(-1, min(1, -pitch / 0.45)) + stressTremble.y * 4)

        // Mouth.
        if isChewing {
            p.mouth = .chew; p.chew = sin(CGFloat(now) * 14)
        } else if slotH > 0.04 || morph > 0.05 {
            p.mouth = .open; p.mouthOpen = max(slotH / 0.42, morph * 0.8)
        } else if voiceSubState == .speaking {
            p.mouth = .open; p.mouthOpen = 0.25 + 0.45 * abs(sin(CGFloat(now) * 9))
        } else if let emote = activeGiraffyEmote {
            switch emote {
            case .surprised: p.mouth = .oh; p.mouthOpen = 0.4
            case .yawn: p.mouth = .open; p.mouthOpen = 0.9
            case .annoyed: p.mouth = .flat
            default: p.mouth = .smile
            }
        } else {
            switch state {
            case .finished: p.mouth = .smile
            case .error: p.mouth = .frown
            case .dizzy: p.mouth = .wobble
            case .thinking: p.mouth = .chew; p.chew = sin(t * 5)
            default: p.mouth = .line
            }
        }
        p.blush = max(blush, moodHot * 0.85)
        return p
    }
}
