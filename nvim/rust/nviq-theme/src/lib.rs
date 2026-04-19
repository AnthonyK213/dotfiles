use std::ffi::c_int;

const NVIQ_THEME_DARK: c_int = 0;
const NVIQ_THEME_LIGHT: c_int = 1;
const NVIQ_THEME_UNSPECIFIED: c_int = 2;
const NVIQ_THEME_ERROR: c_int = -1;

#[unsafe(no_mangle)]
pub extern "C" fn nviq_theme_detect() -> c_int {
    match std::panic::catch_unwind(|| {
        if let Ok(mode) = dark_light::detect() {
            match mode {
                dark_light::Mode::Dark => NVIQ_THEME_DARK,
                dark_light::Mode::Light => NVIQ_THEME_LIGHT,
                dark_light::Mode::Unspecified => NVIQ_THEME_UNSPECIFIED,
            }
        } else {
            NVIQ_THEME_ERROR
        }
    }) {
        Ok(err_code) => err_code,
        Err(_) => NVIQ_THEME_ERROR,
    }
}
