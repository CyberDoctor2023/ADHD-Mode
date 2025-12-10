import Cocoa
import AVFoundation

final class OverlayController: NSObject {
    // MARK: - 可调参数
    private let displayText = "🟢 进入 ADHD 专属工作模式"
    private let textSize: CGFloat = 80

    private let targetVeilAlpha: CGFloat = 0.6  // 背景黑度(0.5~0.7)
    private let fadeIn:  TimeInterval = 1.0
    private let hold:    TimeInterval = 3.0
    private let fadeOut: TimeInterval = 0.8
    private let absGuard:TimeInterval = 5.0

    // MARK: - UI & 状态
    private var windows: [NSWindow] = []
    private var veilViews: [NSView] = []

    // MARK: - 音频：预加载并复用（避免“啪/卡顿”）
    private var tipPlayer: AVAudioPlayer?

    // 仅创建一次播放器；优先 m4a，其次 mp3/aac
    private func prepareTipPlayer() {
        if tipPlayer != nil { return }
        for ext in ["m4a","mp3","aac"] {
            if let url = Bundle.main.url(forResource: "adhdtip", withExtension: ext) {
                do {
                    let p = try AVAudioPlayer(contentsOf: url)
                    p.volume = 0.0                // 先静音，待会儿淡入
                    p.numberOfLoops = 0
                    p.prepareToPlay()             // 预解码，避免起播抖一下
                    tipPlayer = p
                    print("✅ tip prepared:", url.lastPathComponent, "dur:", p.duration)
                    return
                } catch {
                    print("❌ tip prepare error:", error.localizedDescription)
                }
            }
        }
        print("⚠️ adhdtip.(m4a/mp3/aac) not found in bundle")
    }

    // 平滑播放：从头、先静音开播，再在 0.18s 内淡入到目标音量
    private func playTipSmooth(volume: Float = 1.0, fade: TimeInterval = 0.18) {
        prepareTipPlayer()
        guard let p = tipPlayer else { return }
        p.currentTime = 0          // 每次从头
        p.volume = 0.0
        _ = p.play()
        p.setVolume(volume, fadeDuration: fade)
    }

    // MARK: - 覆盖层入口
    func start() {
        // 多屏创建全屏无边框窗口（盖住菜单栏/Dock）
        for screen in NSScreen.screens {
            let frame = screen.frame
            let win = NSWindow(contentRect: frame, styleMask: [.borderless],
                               backing: .buffered, defer: false, screen: screen)
            win.level = .screenSaver
            win.isOpaque = false
            win.backgroundColor = .clear
            win.ignoresMouseEvents = true
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            win.alphaValue = 1.0 // 不动 window alpha，保证文字锐利

            // 深色毛玻璃（文字放其上方，不会被模糊）
            let fx = NSVisualEffectView(frame: frame)
            if #available(macOS 10.14, *) { fx.material = .fullScreenUI } else { fx.material = .dark }
            fx.state = .active
            fx.blendingMode = .withinWindow
            fx.appearance = NSAppearance(named: .vibrantDark)
            fx.autoresizingMask = [.width, .height]

            // 黑色遮罩（只对这层做淡入/淡出，营造黑色高斯感）
            let veil = NSView(frame: frame)
            veil.wantsLayer = true
            veil.layer?.backgroundColor = NSColor.black.cgColor
            veil.alphaValue = 0.0
            veil.autoresizingMask = [.width, .height]

            // 中央文字（不被模糊）
            let label = NSTextField(labelWithString: displayText)
            label.alignment = .center
            label.textColor = .white
            label.font = NSFont.systemFont(ofSize: textSize, weight: .semibold)
            label.backgroundColor = .clear

            let container = NSView(frame: frame)
            container.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            container.autoresizingMask = [.width, .height]

            // 叠放顺序：毛玻璃 → 黑遮罩 → 文本
            let root = NSView(frame: frame)
            root.addSubview(fx)
            root.addSubview(veil)
            root.addSubview(container)

            win.contentView = root
            win.makeKeyAndOrderFront(nil)

            windows.append(win)
            veilViews.append(veil)
        }

        // 稍微错峰到 UI 建好后的下一拍，尽量避免与布局/动画抢资源
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.playTipSmooth(volume: 1.0, fade: 0.18)
        }

        // 入场：只动画遮罩的透明度（文字始终保持清晰）
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = fadeIn
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for v in veilViews { v.animator().alphaValue = targetVeilAlpha }
        } completionHandler: {
            // 停留 HOLD 秒后开始淡出
            Timer.scheduledTimer(withTimeInterval: self.hold, repeats: false) { _ in
                self.fadeOutAndCleanup()
            }
        }

        // 绝对 5 秒兜底清理（防极端异常）
        Timer.scheduledTimer(withTimeInterval: absGuard, repeats: false) { _ in
            self.cleanup()
        }
    }

    private func fadeOutAndCleanup() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = fadeOut
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for v in veilViews { v.animator().alphaValue = 0.0 }
        } completionHandler: {
            self.cleanup()
        }
    }

    private func cleanup() {
        // 如需强行停止音频（通常无需）
        // tipPlayer?.stop()   // 不置空以便下次复用更快

        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        veilViews.removeAll()

        NSApp.terminate(nil) // 一次性效果，用完即退；如需常驻请移除这行
    }
}
