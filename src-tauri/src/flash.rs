// iOS Flashlight FFI bridge
// These symbols are exported from flash.swift via @_cdecl

#[cfg(target_os = "ios")]
extern "C" {
    /// Turn flashlight on
    pub fn flash_toggle_on() -> bool;
    /// Turn flashlight off
    pub fn flash_toggle_off() -> bool;
}
