use tauri::Manager;

// iOS native flashlight bridge
#[cfg(target_os = "ios")]
mod flash;

/// Turn flashlight on. Returns true on success.
#[tauri::command]
fn flash_on() -> bool {
    #[cfg(target_os = "ios")]
    { unsafe { flash::flash_toggle_on() } }

    #[cfg(not(target_os = "ios"))]
    { false }
}

/// Turn flashlight off. Returns true on success.
#[tauri::command]
fn flash_off() -> bool {
    #[cfg(target_os = "ios")]
    { unsafe { flash::flash_toggle_off() } }

    #[cfg(not(target_os = "ios"))]
    { false }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![flash_on, flash_off])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
