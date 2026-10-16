import SwiftUI
import UIKit

// MARK: - UIKit Split View Example
// UISplitViewController (iOS 14+ column API) with a list (primary) and a detail (secondary).
// iPad / wide screens: both columns side by side. iPhone / compact width: the columns collapse
// into one navigation stack. The app is portrait-only, so on iPhone you always see the collapsed form.

struct SplitViewControllerRepresentable: UIViewControllerRepresentable {
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> ItemsSplitViewController {
        ItemsSplitViewController(onClose: onClose)
    }

    func updateUIViewController(_ uiViewController: ItemsSplitViewController, context: Context) {}
}

struct SplitViewExampleScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SplitViewControllerRepresentable(onClose: { dismiss() })
            .toolbar(.hidden, for: .navigationBar)
            .ignoresSafeArea()
    }
}

// MARK: - Model

struct SplitItem {
    let id: Int
    let title: String
    let details: String
}

// MARK: - Split view controller
// Owns the columns, wires list to detail, and is its own delegate (so no lifetime issue with the weak delegate).

final class ItemsSplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    private let detailNav = UINavigationController(rootViewController: SplitDetailViewController(item: nil))

    init(onClose: @escaping () -> Void) {
        super.init(style: .doubleColumn)

        let list = SplitListViewController()
        list.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close",
            primaryAction: UIAction { _ in onClose() }
        )
        list.onSelect = { [weak self] item in self?.showDetail(for: item) }

        setViewController(UINavigationController(rootViewController: list), for: .primary)
        setViewController(detailNav, for: .secondary)
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // Replace the detail content and let the controller decide: update on iPad, push on iPhone.
    private func showDetail(for item: SplitItem) {
        detailNav.setViewControllers([SplitDetailViewController(item: item)], animated: false)
        show(.secondary)
    }

    // Compact width: start on the list instead of the empty placeholder detail.
    func splitViewController(
        _ svc: UISplitViewController,
        topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column
    ) -> UISplitViewController.Column {
        .primary
    }
}

// MARK: - Primary column: list

final class SplitListViewController: UITableViewController {
    var onSelect: ((SplitItem) -> Void)?

    private let items = (1...20).map {
        SplitItem(id: $0, title: "Item \($0)", details: "Details for item \($0).")
    }

    init() {
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Items"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableView.refreshControl
        items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = items[indexPath.row].title
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelect?(items[indexPath.row])
    }
}

// MARK: - Secondary column: detail

final class SplitDetailViewController: UIViewController {
    private let item: SplitItem?

    init(item: SplitItem?) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = item?.title ?? "Detail"

        let label = UILabel()
        label.text = item?.details ?? "Select an item"
        label.textColor = item == nil ? .secondaryLabel : .label
        label.font = .preferredFont(forTextStyle: .title2)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }
}
