// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import GeckoView
import UIKit
import WebEngine

final class GeckoEngineView: UIView, EngineView {
    private let geckoView = GeckoView()
    private weak var renderedSession: GeckoEngineSession?

    override init(frame: CGRect) {
        super.init(frame: frame)
        geckoView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(geckoView)
        NSLayoutConstraint.activate([
            geckoView.topAnchor.constraint(equalTo: topAnchor),
            geckoView.leadingAnchor.constraint(equalTo: leadingAnchor),
            geckoView.bottomAnchor.constraint(equalTo: bottomAnchor),
            geckoView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(session: EngineSession) {
        guard let session = session as? GeckoEngineSession, session !== renderedSession else { return }

        renderedSession?.isActive = false
        geckoView.session = nil
        geckoView.session = session.geckoSession
        session.isActive = true
        renderedSession = session
    }
}
