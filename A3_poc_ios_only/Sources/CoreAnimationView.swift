import SwiftUI
import UIKit

// ════════════════════════════════════════════════════════════════════════════
// Core Animation Demo
//
// Mirrors the KB examples for "2.2.4.2. How to animate some figure?":
//   • Progress Ring    – CAShapeLayer + explicit CABasicAnimation on `strokeEnd`
//                        (strokeEnd isn't implicitly animatable, so UIView.animate
//                        can't touch it — you must add the animation explicitly).
//   • Spring Transform – UIView.animate with usingSpringWithDamping for a plain view.
// ════════════════════════════════════════════════════════════════════════════

struct CoreAnimationView: View {

    @State private var log: [String] = []
    @State private var ringTrigger = 0
    @State private var springTrigger = 0

    var body: some View {
        VStack(spacing: 0) {
            // ── Button grid ──────────────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    demoButton("Progress Ring", color: .blue) {
                        append("[Progress Ring] button tapped")
                        ringTrigger += 1
                    }
                    demoButton("Spring Transform", color: .purple) {
                        append("[Spring Transform] button tapped")
                        springTrigger += 1
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)

            Divider()

            // ── Canvas: UIKit views hosting the Core Animation demos ──────
            HStack(spacing: 24) {
                ProgressRingRepresentable(trigger: ringTrigger) { append($0) }
                    .frame(width: 140, height: 140)

                SpringTransformRepresentable(trigger: springTrigger) { append($0) }
                    .frame(width: 100, height: 100)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)

            Divider()

            // ── Log output ───────────────────────────────────────────────
            logView
        }
        .navigationTitle("Core Animation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") { log.removeAll() }
            }
        }
    }

    // MARK: - UI helpers

    private func demoButton(_ title: String,
                             color: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color.opacity(0.15))
                .foregroundColor(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(log.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .id(index)
                    }
                }
                .padding()
            }
            .onChange(of: log.count) { _, _ in
                if let last = log.indices.last {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Append helper

    private func append(_ line: String) {
        DispatchQueue.main.async {          // ← safe main-thread UI update
            log.append(line)
        }
    }
}

// MARK: - DEMO 1 — Progress Ring (CAShapeLayer + CABasicAnimation on strokeEnd)

private struct ProgressRingRepresentable: UIViewRepresentable {
    let trigger: Int
    let onLog: (String) -> Void

    func makeUIView(context: Context) -> ProgressRingUIView {
        ProgressRingUIView(onLog: onLog)
    }

    func updateUIView(_ uiView: ProgressRingUIView, context: Context) {
        guard trigger > 0, trigger != context.coordinator.lastTrigger else { return }
        context.coordinator.lastTrigger = trigger
        uiView.animateRing()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastTrigger = 0
    }
}

private final class ProgressRingUIView: UIView {
    private let circleLayer = CAShapeLayer()
    private let onLog: (String) -> Void

    init(onLog: @escaping (String) -> Void) {
        self.onLog = onLog
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 4
        circleLayer.path = UIBezierPath(arcCenter: center, radius: radius,
                                         startAngle: -.pi / 2, endAngle: 1.5 * .pi,
                                         clockwise: true).cgPath
        if circleLayer.superlayer == nil {
            circleLayer.strokeColor = UIColor.systemBlue.cgColor
            circleLayer.fillColor = UIColor.clear.cgColor
            circleLayer.lineWidth = 6
            circleLayer.strokeEnd = 0
            layer.addSublayer(circleLayer)
            onLog("[Progress Ring] CAShapeLayer path set, strokeEnd=0")
        }
    }

    func animateRing() {
        circleLayer.strokeEnd = 0
        circleLayer.removeAnimation(forKey: "strokeEndAnimation")

        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 0.6
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        circleLayer.strokeEnd = 1 // model value, so it doesn't snap back
        circleLayer.add(animation, forKey: "strokeEndAnimation")
        onLog("[Progress Ring] CABasicAnimation(strokeEnd: 0 → 1) added")
    }
}

// MARK: - DEMO 2 — Spring Transform (UIView.animate + usingSpringWithDamping)

private struct SpringTransformRepresentable: UIViewRepresentable {
    let trigger: Int
    let onLog: (String) -> Void

    func makeUIView(context: Context) -> SpringTransformUIView {
        SpringTransformUIView(onLog: onLog)
    }

    func updateUIView(_ uiView: SpringTransformUIView, context: Context) {
        guard trigger > 0, trigger != context.coordinator.lastTrigger else { return }
        context.coordinator.lastTrigger = trigger
        uiView.animateSpring()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastTrigger = 0
    }
}

private final class SpringTransformUIView: UIView {
    private let figureView = UIView()
    private let onLog: (String) -> Void

    init(onLog: @escaping (String) -> Void) {
        self.onLog = onLog
        super.init(frame: .zero)
        figureView.backgroundColor = .systemPurple
        figureView.layer.cornerRadius = 12
        addSubview(figureView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height) * 0.6
        figureView.frame = CGRect(x: (bounds.width - side) / 2,
                                   y: (bounds.height - side) / 2,
                                   width: side, height: side)
    }

    func animateSpring() {
        onLog("[Spring Transform] UIView.animate scale up, damping=0.6")
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.8, options: [], animations: {
            self.figureView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            self.onLog("[Spring Transform] scaling back to identity")
            UIView.animate(withDuration: 0.2) {
                self.figureView.transform = .identity
            } completion: { _ in
                self.onLog("[Spring Transform] animation complete")
            }
        }
    }
}

#Preview {
    NavigationStack {
        CoreAnimationView()
    }
}
