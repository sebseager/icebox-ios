//
//  ShareViewController.swift
//  IceboxShare
//
//  The share sheet is the product's front door (spec §5). This controller
//  just hosts the SwiftUI card; all behavior lives in ShareView.
//

import SwiftUI

#if os(iOS)
import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let host = UIHostingController(rootView: ShareView(extensionContext: extensionContext))
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }
}

#elseif os(macOS)
import AppKit

final class ShareViewController: NSViewController {
    override func loadView() {
        view = NSView()
        preferredContentSize = NSSize(width: 420, height: 480)

        let host = NSHostingController(rootView: ShareView(extensionContext: extensionContext))
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
}
#endif
