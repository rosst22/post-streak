import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let logButton = UIButton(type: .system)
    private var sharedURL: URL?
    private var platform: Platform = .other

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        Task { await prepareSharedLink() }
    }

    private func configureView() {
        view.backgroundColor = .systemBackground
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.text = "Log shared post"
        detailLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 3
        detailLabel.text = "Reading link…"

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = "Log post"
        buttonConfiguration.baseBackgroundColor = .systemGreen
        logButton.configuration = buttonConfiguration
        logButton.isEnabled = false
        logButton.addTarget(self, action: #selector(logPost), for: .touchUpInside)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel, logButton, cancelButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    @MainActor
    private func prepareSharedLink() async {
        do {
            let url = try await extractURL()
            sharedURL = url
            platform = PlatformDetector.detect(from: url)
            detailLabel.text = "\(platform.label)\n\(url.absoluteString)"
            logButton.isEnabled = true
        } catch {
            detailLabel.text = "No web link was found in the shared item."
        }
    }

    @objc private func logPost() {
        guard let sharedURL else { return }
        logButton.isEnabled = false
        detailLabel.text = "Logging…"

        Task { @MainActor in
            do {
                let configuration = try AppConfiguration.load()
                let client = NetworkClient(configuration: configuration)
                try await client.createPost(platform: platform, url: sharedURL)
                detailLabel.text = "Logged to \(platform.label)"
                try? await Task.sleep(for: .milliseconds(500))
                extensionContext?.completeRequest(returningItems: nil)
            } catch {
                detailLabel.text = error.localizedDescription
                logButton.isEnabled = true
            }
        }
    }

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }

    private func extractURL() async throws -> URL {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = try await loadURL(from: provider) { return url }
        }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let text = try await loadText(from: provider), let url = firstURL(in: text) { return url }
        }
        throw AppError.invalidResponse
    }

    private func loadURL(from provider: NSItemProvider) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                if let error { continuation.resume(throwing: error); return }
                if let url = item as? URL { continuation.resume(returning: url); return }
                if let url = item as? NSURL { continuation.resume(returning: url as URL); return }
                if let string = item as? String { continuation.resume(returning: URL(string: string)); return }
                continuation.resume(returning: nil)
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: item as? String)
            }
        }
    }

    private func firstURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, range: range)?.url
    }
}

