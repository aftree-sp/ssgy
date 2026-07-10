import AVFoundation
import UIKit

/// Flashlight controller singleton
@objc class FlashController: NSObject {
    @objc static let shared = FlashController()
    private override init() {}

    /// Attempt to turn torch on at full brightness
    @objc func turnOn() -> Bool {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch
        else { return false }
        do {
            try device.lockForConfiguration()
            try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }

    /// Turn torch off
    @objc func turnOff() -> Bool {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch
        else { return false }
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

// MARK: - C FFI (for Rust bridge)

@_cdecl("flash_toggle_on")
func flashToggleOn() -> Bool {
    // Keep idle timer disabled to prevent screen dimming
    DispatchQueue.main.async {
        UIApplication.shared.isIdleTimerDisabled = true
    }
    return FlashController.shared.turnOn()
}

@_cdecl("flash_toggle_off")
func flashToggleOff() -> Bool {
    // Re-enable idle timer when flashlight is off
    DispatchQueue.main.async {
        UIApplication.shared.isIdleTimerDisabled = false
    }
    return FlashController.shared.turnOff()
}
