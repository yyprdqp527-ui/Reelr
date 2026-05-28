//
//  ShareViewController.swift
//  Reelrshare
//
//  Created by Anne-Gaêlle DAVAL on 28/05/2026.
//

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleSharedURL()
    }

    private func handleSharedURL() {
        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let attachments = item.attachments
        else {
            closeExtension()
            return
        }

        let urlType = UTType.url.identifier

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(urlType) {
                provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] data, error in
                    var urlString: String?

                    if let url = data as? URL {
                        urlString = url.absoluteString
                    } else if let str = data as? String {
                        urlString = str
                    }

                    if let rawURL = urlString,
                       let encoded = rawURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let appURL = URL(string: "reelr://add?url=\(encoded)") {
                        DispatchQueue.main.async {
                            self?.openMainApp(with: appURL)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self?.closeExtension()
                        }
                    }
                }
                return
            }
        }

        closeExtension()
    }

    private func openMainApp(with url: URL) {
        var responder: UIResponder? = self
        while let next = responder?.next {
            responder = next
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                break
            }
        }
        closeExtension()
    }

    private func closeExtension() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

