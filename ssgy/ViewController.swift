import UIKit
import AVFoundation

// MARK: - Flashlight Controller

final class FlashController {
    static let shared = FlashController()
    private init() {}

    func turnOn() -> Bool {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return false }
        do {
            try device.lockForConfiguration()
            try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }

    func turnOff() -> Bool {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return false }
        do {
            try device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }
}

// MARK: - ViewController

final class ViewController: UIViewController {

    // MARK: State
    private var interval: TimeInterval = 0.5
    private var isStrobing = false
    private var flashState = false
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "strobe", qos: .userInteractive)

    // MARK: UI Elements
    private let statusLabel = UILabel()
    private let statusDot = UIView()
    private let slider = UISlider()
    private let valueLabel = UILabel()
    private let startBtn = UIButton(type: .system)
    private let stopBtn  = UIButton(type: .system)
    private let glassPanel = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupGlassPanel()
        setupStatusBar()
        setupSlider()
        setupButtons()
        applyConstraints()
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    // MARK: - Background (Liquid Glass gradient)

    private func setupBackground() {
        let grad = CAGradientLayer()
        grad.colors = [
            UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1).cgColor,
            UIColor(red: 0.0, green: 0.0, blue: 0.02, alpha: 1).cgColor,
        ]
        grad.locations = [0, 1]
        grad.frame = view.bounds
        view.layer.insertSublayer(grad, at: 0)

        // subtle animated shine
        let shine = CAGradientLayer()
        shine.colors = [
            UIColor.white.withAlphaComponent(0).cgColor,
            UIColor.white.withAlphaComponent(0.03).cgColor,
            UIColor.white.withAlphaComponent(0).cgColor,
        ]
        shine.locations = [0, 0.5, 1]
        shine.startPoint = CGPoint(x: 0, y: 0)
        shine.endPoint   = CGPoint(x: 1, y: 1)
        shine.frame = view.bounds
        view.layer.insertSublayer(shine, at: 1)

        let anim = CABasicAnimation(keyPath: "transform.translation.x")
        anim.fromValue = -view.bounds.width
        anim.toValue   = view.bounds.width
        anim.duration  = 6
        anim.repeatCount = .infinity
        shine.add(anim, forKey: "shine")
    }

    // MARK: - Glass Panel (frosted glass container)

    private func setupGlassPanel() {
        glassPanel.layer.cornerRadius = 28
        glassPanel.clipsToBounds = true
        glassPanel.layer.borderWidth = 0.5
        glassPanel.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        glassPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(glassPanel)
    }

    // MARK: - Status

    private func setupStatusBar() {
        statusDot.backgroundColor = UIColor.systemGray3
        statusDot.layer.cornerRadius = 5
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        glassPanel.contentView.addSubview(statusDot)

        statusLabel.text = "就绪"
        statusLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        statusLabel.textColor = UIColor.systemGray
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        glassPanel.contentView.addSubview(statusLabel)
    }

    // MARK: - Slider

    private func setupSlider() {
        slider.minimumValue = 0.1
        slider.maximumValue = 1.0
        slider.value = Float(interval)
        slider.minimumTrackTintColor = UIColor.systemRed
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.15)
        slider.thumbTintColor = UIColor.white
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        glassPanel.contentView.addSubview(slider)

        let minLabel = makeTickLabel("1.0s")
        let maxLabel = makeTickLabel("0.1s")
        glassPanel.contentView.addSubview(minLabel)
        glassPanel.contentView.addSubview(maxLabel)

        valueLabel.text = "0.5s"
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 34, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        glassPanel.contentView.addSubview(valueLabel)

        // store for constraints
        objc_setAssociatedObject(self, "minLabel", minLabel, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, "maxLabel", maxLabel, .OBJC_ASSOCIATION_RETAIN)
    }

    private func makeTickLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        l.textColor = UIColor.systemGray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    @objc private func sliderChanged() {
        // snap to nearest 0.05
        let raw = Double(slider.value)
        interval = round(raw / 0.05) * 0.05
        slider.value = Float(interval)
        valueLabel.text = String(format: "%.1fs", interval)
    }

    // MARK: - Buttons

    private func setupButtons() {
        // Start
        startBtn.setTitle("开始", for: .normal)
        startBtn.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        startBtn.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.25)
        startBtn.tintColor = .systemGreen
        startBtn.layer.cornerRadius = 18
        startBtn.clipsToBounds = true
        startBtn.layer.borderWidth = 0.5
        startBtn.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.4).cgColor
        startBtn.translatesAutoresizingMaskIntoConstraints = false
        startBtn.addTarget(self, action: #selector(didTapStart), for: .touchUpInside)
        glassPanel.contentView.addSubview(startBtn)

        // Stop
        stopBtn.setTitle("停止", for: .normal)
        stopBtn.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        stopBtn.backgroundColor = UIColor.systemRed.withAlphaComponent(0.25)
        stopBtn.tintColor = .systemRed
        stopBtn.layer.cornerRadius = 18
        stopBtn.clipsToBounds = true
        stopBtn.layer.borderWidth = 0.5
        stopBtn.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.4).cgColor
        stopBtn.translatesAutoresizingMaskIntoConstraints = false
        stopBtn.addTarget(self, action: #selector(didTapStop), for: .touchUpInside)
        stopBtn.isEnabled = false
        stopBtn.alpha = 0.4
        glassPanel.contentView.addSubview(stopBtn)
    }

    // MARK: - Layout

    private func applyConstraints() {
        guard let minL = objc_getAssociatedObject(self, "minLabel") as? UILabel,
              let maxL = objc_getAssociatedObject(self, "maxLabel") as? UILabel else { return }

        NSLayoutConstraint.activate([
            // Glass panel
            glassPanel.centerYAnchor.constraint(equalTo: view.centerY),
            glassPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            glassPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // Status
            statusDot.topAnchor.constraint(equalTo: glassPanel.topAnchor, constant: 32),
            statusDot.centerXAnchor.constraint(equalTo: glassPanel.centerXAnchor, constant: -20),
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),

            statusLabel.centerYAnchor.constraint(equalTo: statusDot.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 8),

            // Value display
            valueLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
            valueLabel.centerXAnchor.constraint(equalTo: glassPanel.centerXAnchor),

            // Slider
            slider.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 28),
            slider.leadingAnchor.constraint(equalTo: glassPanel.leadingAnchor, constant: 28),
            slider.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -28),

            // Tick labels
            minL.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 4),
            minL.leadingAnchor.constraint(equalTo: slider.leadingAnchor),
            maxL.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 4),
            maxL.trailingAnchor.constraint(equalTo: slider.trailingAnchor),

            // Buttons
            startBtn.topAnchor.constraint(equalTo: minL.bottomAnchor, constant: 32),
            startBtn.leadingAnchor.constraint(equalTo: glassPanel.leadingAnchor, constant: 20),
            startBtn.trailingAnchor.constraint(equalTo: glassPanel.centerXAnchor, constant: -8),
            startBtn.heightAnchor.constraint(equalToConstant: 56),
            startBtn.bottomAnchor.constraint(equalTo: glassPanel.bottomAnchor, constant: -28),

            stopBtn.topAnchor.constraint(equalTo: startBtn.topAnchor),
            stopBtn.leadingAnchor.constraint(equalTo: glassPanel.centerXAnchor, constant: 8),
            stopBtn.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -20),
            stopBtn.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    // MARK: - Strobe Logic

    @objc private func didTapStart() {
        guard !isStrobing else { return }
        isStrobing = true
        flashState = false
        updateUI(running: true)

        // keep screen on
        UIApplication.shared.isIdleTimerDisabled = true

        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(5))
        t.setEventHandler { [weak self] in
            guard let self = self, self.isStrobing else { return }
            self.flashState.toggle()
            if self.flashState {
                _ = FlashController.shared.turnOn()
            } else {
                _ = FlashController.shared.turnOff()
            }
        }
        t.resume()
        timer = t

        // turn on immediately
        _ = FlashController.shared.turnOn()
        flashState = true
    }

    @objc private func didTapStop() {
        isStrobing = false
        timer?.cancel()
        timer = nil
        _ = FlashController.shared.turnOff()
        flashState = false
        UIApplication.shared.isIdleTimerDisabled = false
        updateUI(running: false)
    }

    private func updateUI(running: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.startBtn.isEnabled = !running
            self.stopBtn.isEnabled  = running
            self.startBtn.alpha     = running ? 0.4 : 1
            self.stopBtn.alpha      = running ? 1 : 0.4
            self.slider.isEnabled   = !running
            self.statusDot.backgroundColor = running ? UIColor.systemGreen : UIColor.systemGray3
            self.statusLabel.text   = running ? "爆闪中" : "就绪"
        }
    }
}
