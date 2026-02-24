import Cocoa

class FloatingCharacterPanel: NSPanel {

    static let shared = FloatingCharacterPanel()

    private var dismissWorkItem: DispatchWorkItem?
    private var imageHeightConstraint: NSLayoutConstraint?

    private let imageView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let messageLabel: NSTextField = {
        let tf = NSTextField(wrappingLabelWithString: "")
        tf.font = .systemFont(ofSize: 13, weight: .bold)
        tf.textColor = .white
        tf.alignment = .center
        tf.translatesAutoresizingMaskIntoConstraints = false
        let shadow = NSShadow()
        shadow.shadowColor = .black
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        tf.shadow = shadow
        return tf
    }()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 260),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setupPanel()
        setupViews()
        loadImage()
    }

    // MARK: - Setup

    private func setupPanel() {
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isMovableByWindowBackground = false
        alphaValue = 0
    }

    private func setupViews() {
        guard let contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor

        contentView.addSubview(imageView)
        contentView.addSubview(messageLabel)

        let heightConstraint = imageView.heightAnchor.constraint(equalToConstant: 200)
        imageHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 8),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            heightConstraint,
        ])
    }

    private func loadImage() {
        if let path = Bundle.main.path(forResource: "tatsu_icon_flying_dragon", ofType: "png") {
            imageView.image = NSImage(contentsOfFile: path)
        }
        resizePanel()
    }

    func updateImage(path: String) {
        imageView.image = NSImage(contentsOfFile: path)
        resizePanel()
    }

    private func resizePanel() {
        guard let image = imageView.image,
              let screen = NSScreen.main else { return }

        // ラベル領域の固定高さ（8pt gap + 2行テキスト）
        let labelHeight: CGFloat = 50

        // 画像の最大高さ = デスクトップ表示領域の半分 - ラベル分
        let maxImageHeight = screen.visibleFrame.height / 2 - labelHeight

        let naturalSize = image.size
        let scale = min(1.0, maxImageHeight / naturalSize.height)
        let imageHeight = naturalSize.height * scale
        let panelWidth  = naturalSize.width  * scale

        imageHeightConstraint?.constant = imageHeight
        messageLabel.preferredMaxLayoutWidth = panelWidth
        setContentSize(NSSize(width: panelWidth, height: imageHeight + labelHeight))
    }

    // MARK: - Show / Hide

    func show(for type: TimerModel.NotificationType) {
        DispatchQueue.main.async {
            self.messageLabel.stringValue = type.floatingMessage
            self.resizePanel()
            self.contentView?.layoutSubtreeIfNeeded()
            self.positionBottomRight()
            self.alphaValue = 0
            self.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                self.animator().alphaValue = 1
            }

            self.dismissWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.dismiss() }
            self.dismissWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: item)
        }
    }

    private func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    private func positionBottomRight() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let x = visible.maxX - frame.width
        let y = visible.minY
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Key / Main Window

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - NotificationType + message

extension TimerModel.NotificationType {
    var floatingMessage: String {
        switch self {
        case .standing: return "立ち上がる時間だよ！\n体を動かそう 🧍"
        case .walk:     return "散歩しよう！\n外の空気を吸ってリフレッシュ 🚶"
        }
    }
}
