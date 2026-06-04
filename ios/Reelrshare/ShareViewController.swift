//
//  ShareViewController.swift
//  Reelrshare
//
//  Created by Anne-Gaêlle DAVAL on 28/05/2026.
//

import UIKit
import UniformTypeIdentifiers
import AudioToolbox

class ShareViewController: UIViewController {
    private let silentShareInboxKey = "ReelrSilentInboxUrls"
    private let inboxPlopSound: SystemSoundID = 1104
    private var didComplete = false
    private var feedbackWrapper: UIView?
    private var feedbackCard: UIVisualEffectView?
    private var feedbackIcon: UIImageView?
    private var feedbackTitle: UILabel?
    private var feedbackSubtitle: UILabel?

    private var appGroupId: String {
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String)
            ?? "group.com.reelr.app.shared"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        showLoadingFeedback()
        handleSharedURL()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // La fenêtre système qui héberge l'extension a un fond blanc par défaut.
        // On remonte toute la hiérarchie pour la rendre transparente.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var current: UIView? = self.view
            while let parent = current?.superview {
                parent.backgroundColor = .clear
                parent.isOpaque = false
                current = parent
            }
            self.view.window?.backgroundColor = .clear
            self.view.window?.isOpaque = false
        }
    }

    private func mainAppBundle() -> Bundle? {
        // Dans une share extension, le .appex est dans PlugIns/ à l'intérieur du .app principal.
        let url = Bundle.main.bundleURL
            .deletingLastPathComponent()   // PlugIns/
            .deletingLastPathComponent()   // Runner.app/
        return Bundle(url: url)
    }

    private func loadAppIconImage() -> UIImage? {
        // Essai dans le bundle de l'extension d'abord, puis dans le bundle de l'app principale.
        for bundle in [Bundle.main, mainAppBundle()].compactMap({ $0 }) {
            guard
                let icons = bundle.infoDictionary?["CFBundleIcons"] as? [String: Any],
                let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
                let files = primary["CFBundleIconFiles"] as? [String],
                let iconName = files.last,
                let image = UIImage(named: iconName, in: bundle, with: nil)
            else { continue }
            return image
        }
        return nil
    }

    private func showLoadingFeedback() {
        let wrapper = buildFeedbackCardIfNeeded()
        if let appIcon = loadAppIconImage() {
            feedbackIcon?.image = appIcon
            feedbackIcon?.tintColor = nil
            feedbackIcon?.alpha = 0.86
        } else {
            feedbackIcon?.image = UIImage(systemName: "bookmark.fill")
            feedbackIcon?.tintColor = UIColor.white.withAlphaComponent(0.88)
            feedbackIcon?.alpha = 1
        }
        feedbackTitle?.text = "Ajout en cours…"
        feedbackSubtitle?.text = "Capture silencieuse"

        wrapper.transform = CGAffineTransform(translationX: 0, y: 8).scaledBy(x: 0.98, y: 0.98)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut], animations: {
            self.feedbackCard?.alpha = 1
            wrapper.transform = .identity
        })
    }

    @discardableResult
    private func buildFeedbackCardIfNeeded() -> UIView {
        if let wrapper = feedbackWrapper {
            return wrapper
        }

        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        card.alpha = 0
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 20
        card.layer.masksToBounds = true
        card.contentView.layoutMargins = UIEdgeInsets(top: 13, left: 14, bottom: 13, right: 14)
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor

        let shadowWrapper = UIView()
        shadowWrapper.translatesAutoresizingMaskIntoConstraints = false
        shadowWrapper.layer.shadowColor = UIColor.black.cgColor
        shadowWrapper.layer.shadowOpacity = 0.28
        shadowWrapper.layer.shadowRadius = 18
        shadowWrapper.layer.shadowOffset = CGSize(width: 0, height: 8)

        let iconBg = UIView()
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        iconBg.layer.cornerRadius = 15

        let appIconImage = loadAppIconImage()
        let icon = UIImageView(image: appIconImage ?? UIImage(systemName: "bookmark.fill"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = appIconImage == nil ? UIColor.white.withAlphaComponent(0.88) : nil
        icon.alpha = 0.86
        icon.contentMode = .scaleAspectFit
        icon.clipsToBounds = true
        icon.layer.cornerRadius = 8

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Ajout en cours..."
        title.textColor = .white
        title.font = UIFont.systemFont(ofSize: 16, weight: .semibold)

        let subtitle = UILabel()
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.text = "Capture silencieuse"
        subtitle.textColor = UIColor.white.withAlphaComponent(0.82)
        subtitle.font = UIFont.systemFont(ofSize: 12, weight: .regular)

        let labels = UIStackView(arrangedSubviews: [title, subtitle])
        labels.translatesAutoresizingMaskIntoConstraints = false
        labels.axis = .vertical
        labels.spacing = 2

        card.contentView.addSubview(iconBg)
        iconBg.addSubview(icon)
        card.contentView.addSubview(labels)
        shadowWrapper.addSubview(card)
        view.addSubview(shadowWrapper)

        NSLayoutConstraint.activate([
            shadowWrapper.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shadowWrapper.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 180),

            card.topAnchor.constraint(equalTo: shadowWrapper.topAnchor),
            card.bottomAnchor.constraint(equalTo: shadowWrapper.bottomAnchor),
            card.leadingAnchor.constraint(equalTo: shadowWrapper.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: shadowWrapper.trailingAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 304),

            iconBg.leadingAnchor.constraint(equalTo: card.contentView.layoutMarginsGuide.leadingAnchor),
            iconBg.centerYAnchor.constraint(equalTo: card.contentView.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 30),
            iconBg.heightAnchor.constraint(equalToConstant: 30),

            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),

            labels.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 10),
            labels.trailingAnchor.constraint(equalTo: card.contentView.layoutMarginsGuide.trailingAnchor),
            labels.topAnchor.constraint(equalTo: card.contentView.layoutMarginsGuide.topAnchor),
            labels.bottomAnchor.constraint(equalTo: card.contentView.layoutMarginsGuide.bottomAnchor)
        ])

        feedbackWrapper = shadowWrapper
        feedbackCard = card
        feedbackIcon = icon
        feedbackTitle = title
        feedbackSubtitle = subtitle

        return shadowWrapper
    }

    private func handleSharedURL() {
        // Safety net: avoid hanging share UI if provider never resolves.
        // Keep a small buffer so slower providers still complete normally.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.closeExtension()
        }

        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let attachments = item.attachments
        else {
            closeExtension()
            return
        }

        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier
        let textTypeAlt = UTType.text.identifier
        let propertyListType = UTType.propertyList.identifier

        // Try public.url first (YouTube, Safari, etc.)
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(urlType) {
                provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] data, error in
                    let urlString = self?.extractURLString(from: data)
                    DispatchQueue.main.async {
                        self?.storeSilentlyIfValid(urlString: urlString)
                    }
                }
                return
            }
        }

        // Fallback: public.plain-text (Facebook, Instagram, TikTok, etc.)
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(textType) || provider.hasItemConformingToTypeIdentifier(textTypeAlt) {
                let selectedTextType = provider.hasItemConformingToTypeIdentifier(textType)
                    ? textType
                    : textTypeAlt
                provider.loadItem(forTypeIdentifier: selectedTextType, options: nil) { [weak self] data, error in
                    let urlString = self?.extractURLString(from: data)
                    DispatchQueue.main.async {
                        self?.storeSilentlyIfValid(urlString: urlString)
                    }
                }
                return
            }
        }

        // Fallback for apps that share dictionaries/property lists.
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(propertyListType) {
                provider.loadItem(forTypeIdentifier: propertyListType, options: nil) { [weak self] data, error in
                    let urlString = self?.extractURLString(from: data)
                    DispatchQueue.main.async {
                        self?.storeSilentlyIfValid(urlString: urlString)
                    }
                }
                return
            }
        }

        closeExtension()
    }

    private func extractURLString(from data: NSSecureCoding?) -> String? {
        if let url = data as? URL {
            return url.absoluteString
        }
        if let str = data as? String {
            return firstURL(in: str)
        }
        if let dict = data as? [String: Any] {
            for value in dict.values {
                if let nested = extractURLString(fromAny: value) {
                    return nested
                }
            }
        }
        if let array = data as? [Any] {
            for value in array {
                if let nested = extractURLString(fromAny: value) {
                    return nested
                }
            }
        }
        return nil
    }

    private func extractURLString(fromAny value: Any) -> String? {
        if let url = value as? URL {
            return url.absoluteString
        }
        if let str = value as? String {
            return firstURL(in: str)
        }
        if let dict = value as? [String: Any] {
            for v in dict.values {
                if let nested = extractURLString(fromAny: v) {
                    return nested
                }
            }
        }
        if let array = value as? [Any] {
            for v in array {
                if let nested = extractURLString(fromAny: v) {
                    return nested
                }
            }
        }
        return nil
    }

    private func firstURL(in text: String) -> String? {
        if let parsed = URL(string: text),
           let scheme = parsed.scheme?.lowercased(),
           (scheme == "http" || scheme == "https") {
            return parsed.absoluteString
        }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        return matches?.first?.url?.absoluteString
    }

    private func storeSilentlyIfValid(urlString: String?) {
        guard
            let rawURL = urlString,
            let parsed = URL(string: rawURL),
            let scheme = parsed.scheme?.lowercased(),
            (scheme == "http" || scheme == "https")
        else {
            closeExtension()
            return
        }

        if let defaults = UserDefaults(suiteName: appGroupId) {
            var urls = defaults.stringArray(forKey: silentShareInboxKey) ?? []
            if !urls.contains(rawURL) {
                urls.append(rawURL)
                defaults.set(urls, forKey: silentShareInboxKey)
                defaults.synchronize()
            }
        }

        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.prepare()
        haptic.impactOccurred(intensity: 0.65)
        AudioServicesPlaySystemSound(inboxPlopSound)

        showQuickAddedFeedbackAndClose()
    }

    private func showQuickAddedFeedbackAndClose() {
        let wrapper = buildFeedbackCardIfNeeded()
        if let appIcon = loadAppIconImage() {
            feedbackIcon?.image = appIcon
            feedbackIcon?.tintColor = nil
            feedbackIcon?.alpha = 0.95
        } else {
            feedbackIcon?.image = UIImage(systemName: "bookmark.fill")
            feedbackIcon?.tintColor = UIColor.white.withAlphaComponent(0.95)
            feedbackIcon?.alpha = 1
        }
        feedbackTitle?.text = "Ajouté à Reelr"
        feedbackSubtitle?.text = "Inbox mis à jour"

        UIView.animate(withDuration: 0.14, delay: 0, options: [.curveEaseOut], animations: {
            wrapper.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        }) { _ in
            wrapper.transform = .identity
        }

        UIView.animate(withDuration: 0.2, delay: 0.82, options: [.curveEaseIn], animations: {
            self.feedbackCard?.alpha = 0
            wrapper.transform = CGAffineTransform(translationX: 0, y: -6).scaledBy(x: 0.99, y: 0.99)
        }) { _ in
            self.closeExtension()
        }
    }

    private func closeExtension() {
        if didComplete { return }
        didComplete = true
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

