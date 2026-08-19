import UIKit
import SwiftUI

// MARK: - SwiftUI Bridge
// Wraps ProfileViewController in a UINavigationController so its navigationItem works.

struct ProfileViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        print("[Bridge] makeUIViewController — creating UINavigationController + ProfileViewController")
        return UINavigationController(rootViewController: ProfileViewController())
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        print("[Bridge] updateUIViewController called")
    }
}

// MARK: - ProfileViewController

final class ProfileViewController: UIViewController, UIViewControllerTransitioningDelegate {
    private let animator = FadeAnimator(isPresenting: true)

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[ProfileVC] viewDidLoad")
        view.backgroundColor = .systemBackground
        title = "Profile"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Details",
            style: .plain,
            target: self,
            action: #selector(showDetails)
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("[ProfileVC] viewDidAppear — animated=\(animated)")
    }

    @objc private func showDetails() {
        print("[ProfileVC] showDetails tapped — building DetailsViewController")
        let details = UINavigationController(rootViewController: DetailsViewController())
        details.modalPresentationStyle = .custom
        details.transitioningDelegate = self
        print("[ProfileVC] presenting details — modalPresentationStyle=.custom, transitioningDelegate=self")
        present(details, animated: true) {
            print("[ProfileVC] present completion block fired")
        }
    }

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        print("[ProfileVC] animationController(forPresented:) called → returning FadeAnimator(isPresenting: true)")
        return animator
    }

    func animationController(forDismissed dismissed: UIViewController)
        -> UIViewControllerAnimatedTransitioning? {
        print("[ProfileVC] animationController(forDismissed:) called → returning FadeAnimator(isPresenting: false)")
        return FadeAnimator(isPresenting: false)
    }
}

// MARK: - DetailsViewController

final class DetailsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        print("[DetailsVC] viewDidLoad")
        view.backgroundColor = .systemBlue
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(close)
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("[DetailsVC] viewDidAppear — animated=\(animated)")
    }

    @objc private func close() {
        print("[DetailsVC] close tapped — dismissing")
        dismiss(animated: true) {
            print("[DetailsVC] dismiss completion block fired")
        }
    }
}

// MARK: - FadeAnimator

final class FadeAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let isPresenting: Bool

    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
        print("[FadeAnimator] init(isPresenting: \(isPresenting))")
    }

    func transitionDuration(using context: UIViewControllerContextTransitioning?) -> TimeInterval {
        let duration = 0.25
        print("[FadeAnimator] transitionDuration called → \(duration)s (isPresenting=\(isPresenting))")
        return duration
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        print("[FadeAnimator] animateTransition START — isPresenting=\(isPresenting)")

        // With modalPresentationStyle = .custom the presenting view is NOT placed into the
        // transition container, so context.view(forKey: .from) is nil during presentation
        // and context.view(forKey: .to) is nil during dismissal. Guard per phase separately.
        let container = context.containerView
        print("[FadeAnimator] containerView frame=\(container.frame)")

        if isPresenting {
            guard let toView = context.view(forKey: .to) else {
                print("[FadeAnimator] ❌ toView is nil during presentation — completing with false")
                context.completeTransition(false)
                return
            }
            print("[FadeAnimator] toView frame=\(toView.frame)")

            toView.alpha = 0
            toView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            container.addSubview(toView)
            print("[FadeAnimator] presenting — set toView alpha=0, scale=0.96, added to container")

            UIView.animate(withDuration: transitionDuration(using: context)) {
                toView.alpha = 1
                toView.transform = .identity
                print("[FadeAnimator] animation block — toView → alpha=1, transform=identity")
            } completion: { finished in
                let cancelled = context.transitionWasCancelled
                print("[FadeAnimator] animateTransition COMPLETE — finished=\(finished), cancelled=\(cancelled)")
                context.completeTransition(!cancelled)
            }
        } else {
            guard let fromView = context.view(forKey: .from) else {
                print("[FadeAnimator] ❌ fromView is nil during dismissal — completing with false")
                context.completeTransition(false)
                return
            }
            print("[FadeAnimator] fromView frame=\(fromView.frame)")
            print("[FadeAnimator] dismissing — animating fromView out")

            UIView.animate(withDuration: transitionDuration(using: context)) {
                fromView.alpha = 0
                fromView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
                print("[FadeAnimator] animation block — fromView → alpha=0, scale=0.96")
            } completion: { finished in
                let cancelled = context.transitionWasCancelled
                print("[FadeAnimator] animateTransition COMPLETE — finished=\(finished), cancelled=\(cancelled)")
                context.completeTransition(!cancelled)
            }
        }
    }
}
