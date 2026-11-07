import SwiftUI
import UIKit

private let box = CGSize(width: 120, height: 150)

private func shape(_ d: String) -> SVGPath {
    SVGPath(d: d, viewBox: box)
}

private func keyframes(_ t: Double, _ stops: [(Double, Double)]) -> Double {
    guard let first = stops.first else { return 0 }
    if t <= first.0 { return first.1 }
    for i in 1..<stops.count {
        let a = stops[i - 1], b = stops[i]
        if t <= b.0 {
            let u = (t - a.0) / max(0.0001, b.0 - a.0)
            let e = u * u * (3 - 2 * u)
            return a.1 + (b.1 - a.1) * e
        }
    }
    return stops.last!.1
}

private func wave(_ time: Double, _ period: Double, _ offset: Double = 0) -> Double {
    0.5 - 0.5 * cos((time + offset) / period * 2 * .pi)
}

struct MascotFigure: View {
    var width: CGFloat
    var time: Double
    var flying: Bool
    var hop: Double?

    var body: some View {
        let s = width / box.width
        let stroke = StrokeStyle(lineWidth: 3 * s, lineCap: .round, lineJoin: .round)
        let floatY = -5 * wave(time, 2.8)
        let floatR = -1.2 + 2.4 * wave(time, 2.8)
        let waveT = time.truncatingRemainder(dividingBy: 5.2) / 5.2
        let armR = flying ? -30 + 26 * sin(time * 22) : keyframes(waveT, [(0, 0), (0.58, 0), (0.64, -24), (0.70, 14), (0.76, -24), (0.82, 14), (0.90, 0), (1, 0)])
        let armL = flying ? 75 + 18 * sin(time * 22 + 1.4) : -6 * wave(time, 2.8)
        let blinkT = time.truncatingRemainder(dividingBy: 4.6) / 4.6
        let blink = flying ? 1 : keyframes(blinkT, [(0, 1), (0.9, 1), (0.93, 0.08), (0.96, 1), (1, 1)])
        let lookT = time.truncatingRemainder(dividingBy: 6.4) / 6.4
        let lookX = flying ? 0 : keyframes(lookT, [(0, 0), (0.3, 0), (0.4, -2), (0.6, -2), (0.7, 2), (0.85, 2), (1, 0)])
        let lookY = flying ? -1.5 : keyframes(lookT, [(0, 0), (0.3, 0), (0.4, 1), (0.6, 1), (0.7, -1), (0.85, -1), (1, 0)])
        let stepL = flying ? 0 : -2.5 * wave(time, 1.4)
        let stepR = flying ? 0 : -2.5 * wave(time, 1.4, -0.7)
        let smileT = time.truncatingRemainder(dividingBy: 5.2) / 5.2
        let smileX = keyframes(smileT, [(0, 1), (0.58, 1), (0.66, 1.18), (0.84, 1.18), (1, 1)])
        let smileY = keyframes(smileT, [(0, 1), (0.58, 1), (0.66, 1.25), (0.84, 1.25), (1, 1)])

        let h = hop ?? 1
        let hopY = keyframes(h, [(0, 0), (0.22, 2), (0.52, -26), (0.78, 0), (1, 0)])
        let hopSX = keyframes(h, [(0, 1), (0.22, 1.1), (0.52, 0.94), (0.78, 1.07), (1, 1)])
        let hopSY = keyframes(h, [(0, 1), (0.22, 0.88), (0.52, 1.1), (0.78, 0.93), (1, 1)])

        let bottom = UnitPoint(x: 0.53, y: 136 / box.height)

        return ZStack {
            shape("M46 78H80M46 88H70").stroke(Palette.paperLine, style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
                .zIndex(1)
            Group {
                shape("M34 10H92V104L84 97 76 104 68 97 60 104 52 97 44 104 36 97 34 104Z").fill(Color.white)
                shape("M34 10H92V104L84 97 76 104 68 97 60 104 52 97 44 104 36 97 34 104Z").stroke(Palette.ink, style: stroke)
            }
            .zIndex(0)
            shape("M48 106V128M76 106V128").stroke(Palette.ink, style: stroke)
            shoe("M40 134Q40 126 52 128 56 134 56 136H40Z", stroke: stroke)
                .offset(y: stepL * s)
            shoe("M72 136Q72 128 84 128 88 134 88 136H72Z", stroke: stroke)
                .offset(y: stepR * s)
            shape("M34 54Q22 60 20 74").stroke(Palette.ink, style: stroke)
                .rotationEffect(.degrees(armL), anchor: UnitPoint(x: 34 / box.width, y: 54 / box.height))
            shape("M92 54Q104 46 108 34").stroke(Palette.ink, style: stroke)
                .rotationEffect(.degrees(armR), anchor: UnitPoint(x: 92 / box.width, y: 54 / box.height))
                .zIndex(2)
            ZStack {
                eye(52, s: s)
                eye(76, s: s)
                pupil(55 + lookX, 40 + lookY, s: s)
                pupil(79 + lookX, 40 + lookY, s: s)
            }
            .scaleEffect(x: 1, y: blink, anchor: UnitPoint(x: 64 / box.width, y: 38 / box.height))
            .zIndex(3)
            Group {
                if flying {
                    Ellipse()
                        .fill(Palette.ink)
                        .frame(width: 11 * s, height: 13 * s)
                        .position(x: 64 * s, y: 61 * s)
                } else {
                    shape("M54 58Q64 68 74 58").stroke(Palette.ink, style: stroke)
                        .scaleEffect(x: smileX, y: smileY, anchor: UnitPoint(x: 64 / box.width, y: 61 / box.height))
                }
            }
            .zIndex(3)
            dot(42, 56, r: 4, s: s).zIndex(3)
            dot(86, 56, r: 4, s: s).zIndex(3)
        }
        .frame(width: width, height: width * box.height / box.width)
        .scaleEffect(x: hopSX, y: hopSY, anchor: bottom)
        .offset(y: hopY * s)
        .rotationEffect(.degrees(flying ? 0 : floatR), anchor: bottom)
        .offset(y: flying ? 0 : floatY * s)
    }

    private func shoe(_ d: String, stroke: StrokeStyle) -> some View {
        ZStack {
            shape(d).fill(Palette.shoe)
            shape(d).stroke(Palette.ink, style: stroke)
        }
    }

    private func eye(_ cx: CGFloat, s: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Palette.ink, lineWidth: 2.4 * s))
            .frame(width: 20 * s, height: 20 * s)
            .position(x: cx * s, y: 38 * s)
    }

    private func pupil(_ cx: CGFloat, _ cy: CGFloat, s: CGFloat) -> some View {
        Circle()
            .fill(Palette.ink)
            .frame(width: (flying ? 9 : 8) * s, height: (flying ? 9 : 8) * s)
            .position(x: cx * s, y: cy * s)
    }

    private func dot(_ cx: CGFloat, _ cy: CGFloat, r: CGFloat, s: CGFloat) -> some View {
        Circle()
            .fill(Palette.salmon)
            .frame(width: 2 * r * s, height: 2 * r * s)
            .position(x: cx * s, y: cy * s)
    }
}

private final class LinkProxy: NSObject {
    let tick: (CADisplayLink) -> Void

    init(_ tick: @escaping (CADisplayLink) -> Void) {
        self.tick = tick
    }

    @objc func step(_ link: CADisplayLink) {
        tick(link)
    }
}

@MainActor
@Observable
final class MascotPhysics {
    var position: CGPoint = .zero
    var velocity: CGVector = .zero
    var angle: Double = 0
    var spin: Double = 0
    var squash: CGFloat = 0
    var squashSpeed: CGFloat = 0
    var squashOnX = true
    var free = false
    var dragging = false
    var bounds: CGRect = .zero
    var home: CGRect = .zero
    var hopStart: Date?
    var size = CGSize(width: 84, height: 105)

    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var proxy: LinkProxy?
    @ObservationIgnored private var last: CFTimeInterval = 0
    @ObservationIgnored private var grab: CGVector = .zero
    @ObservationIgnored private var lastHaptic: CFTimeInterval = 0
    @ObservationIgnored private let haptic = UIImpactFeedbackGenerator(style: .rigid)

    var center: CGPoint {
        free ? position : CGPoint(x: home.midX, y: home.midY)
    }

    var flying: Bool {
        free && !dragging && hypot(velocity.dx, velocity.dy) > 260
    }

    func hop() {
        hopStart = Date()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    func dragChanged(location: CGPoint, start: CGPoint, velocity v: CGSize) {
        if !dragging {
            dragging = true
            if !free {
                position = CGPoint(x: home.midX, y: home.midY)
                free = true
            }
            grab = CGVector(dx: position.x - start.x, dy: position.y - start.y)
            haptic.prepare()
        }
        position = CGPoint(x: location.x + grab.dx, y: location.y + grab.dy)
        velocity = .zero
        let target = max(-28, min(28, Double(v.width) * 0.012))
        angle += (target - angle) * 0.35
        clamp()
    }

    func dragEnded(velocity v: CGSize) {
        dragging = false
        var vx = v.width, vy = v.height
        let speed = hypot(vx, vy)
        let maxSpeed: CGFloat = 4200
        if speed > maxSpeed {
            vx *= maxSpeed / speed
            vy *= maxSpeed / speed
        }
        velocity = CGVector(dx: vx, dy: vy)
        spin = Double(vx) * 0.12
        start()
    }

    func returnHome() {
        withAnimation(.springSoft) {
            free = false
            velocity = .zero
            spin = 0
            angle = 0
        }
        stop()
    }

    private func clamp() {
        let hw = size.width * 0.42, hh = size.height * 0.45
        position.x = min(max(position.x, bounds.minX + hw), bounds.maxX - hw)
        position.y = min(max(position.y, bounds.minY + hh), bounds.maxY - hh)
    }

    private func start() {
        guard link == nil else { return }
        let p = LinkProxy { [weak self] l in
            MainActor.assumeIsolated { self?.step(l) }
        }
        let l = CADisplayLink(target: p, selector: #selector(LinkProxy.step(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        proxy = p
        link = l
        last = CACurrentMediaTime()
    }

    func stop() {
        link?.invalidate()
        link = nil
        proxy = nil
    }

    private func step(_ l: CADisplayLink) {
        let now = l.timestamp
        let dt = min(1.0 / 30, max(1.0 / 240, now - last))
        last = now
        if dragging { return }

        let friction = pow(0.42, dt)
        velocity.dx *= friction
        velocity.dy *= friction
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt

        let hw = size.width * 0.42, hh = size.height * 0.45
        let restitution: CGFloat = 0.8
        var impact: CGFloat = 0
        if position.x < bounds.minX + hw, velocity.dx < 0 {
            position.x = bounds.minX + hw
            impact = abs(velocity.dx)
            velocity.dx = -velocity.dx * restitution
            spin -= Double(velocity.dy) * 0.18
            kick(impact, onX: true)
        } else if position.x > bounds.maxX - hw, velocity.dx > 0 {
            position.x = bounds.maxX - hw
            impact = abs(velocity.dx)
            velocity.dx = -velocity.dx * restitution
            spin += Double(velocity.dy) * 0.18
            kick(impact, onX: true)
        }
        if position.y < bounds.minY + hh, velocity.dy < 0 {
            position.y = bounds.minY + hh
            impact = abs(velocity.dy)
            velocity.dy = -velocity.dy * restitution
            spin += Double(velocity.dx) * 0.18
            kick(impact, onX: false)
        } else if position.y > bounds.maxY - hh, velocity.dy > 0 {
            position.y = bounds.maxY - hh
            impact = abs(velocity.dy)
            velocity.dy = -velocity.dy * restitution
            spin -= Double(velocity.dx) * 0.18
            kick(impact, onX: false)
        }

        spin *= pow(0.25, dt)
        angle += spin * dt
        angle = angle.truncatingRemainder(dividingBy: 360)
        if angle > 180 { angle -= 360 }
        if angle < -180 { angle += 360 }
        if abs(spin) < 90 {
            angle += (0 - angle) * min(1, dt * 4)
        }

        let accel = -700 * squash - 16 * squashSpeed
        squashSpeed += accel * CGFloat(dt)
        squash += squashSpeed * CGFloat(dt)

        let speed = hypot(velocity.dx, velocity.dy)
        if speed < 6, abs(spin) < 4, abs(angle) < 0.4, abs(squash) < 0.002, abs(squashSpeed) < 0.02 {
            velocity = .zero
            spin = 0
            angle = 0
            squash = 0
            squashSpeed = 0
            stop()
        }
    }

    private func kick(_ impact: CGFloat, onX: Bool) {
        guard impact > 60 else { return }
        squashOnX = onX
        squash = min(0.32, impact / 4500)
        squashSpeed = 0
        let now = CACurrentMediaTime()
        if now - lastHaptic > 0.05 {
            haptic.impactOccurred(intensity: min(1, max(0.25, impact / 2600)))
            lastHaptic = now
        }
    }
}

struct MascotLayer: View {
    var physics: MascotPhysics
    var space: String

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let hop = physics.hopStart.map { min(1, ctx.date.timeIntervalSince($0) / 0.64) }
            let sx = physics.squashOnX ? 1 - physics.squash : 1 + physics.squash * 0.6
            let sy = physics.squashOnX ? 1 + physics.squash * 0.6 : 1 - physics.squash
            MascotFigure(width: physics.size.width, time: t, flying: physics.flying, hop: hop == 1 ? nil : hop)
                .scaleEffect(x: sx, y: sy)
                .rotationEffect(.degrees((physics.free ? 0 : 5) + physics.angle))
                .frame(width: physics.size.width, height: physics.size.height)
                .contentShape(Rectangle())
                .position(physics.center)
                .opacity(physics.home == .zero && !physics.free ? 0 : 1)
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .named(space))
                        .onChanged { g in
                            physics.dragChanged(location: g.location, start: g.startLocation, velocity: g.velocity)
                        }
                        .onEnded { g in
                            physics.dragEnded(velocity: g.velocity)
                        }
                )
                .onTapGesture(count: 2) { physics.returnHome() }
                .onTapGesture { physics.hop() }
        }
        .accessibilityLabel("Bon-Männchen, zum Werfen ziehen")
    }
}
