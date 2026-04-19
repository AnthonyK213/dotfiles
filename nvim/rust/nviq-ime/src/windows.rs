use crate::typedef::*;
use winapi::um::winuser;

pub(crate) fn get_input_source() -> Source {
    unsafe {
        let hwnd = winuser::GetForegroundWindow();
        if !hwnd.is_null() {
            let thread_id = winuser::GetWindowThreadProcessId(hwnd, std::ptr::null_mut());
            let current_layout = winuser::GetKeyboardLayout(thread_id) as usize;
            (current_layout & 0x0000FFFF) as Source
        } else {
            NVIQ_IME_LAYOUT_NONE
        }
    }
}

pub(crate) fn set_input_source(source: Source) {
    unsafe {
        let hwnd = winuser::GetForegroundWindow();
        if !hwnd.is_null() {
            let current_layout =
                winapi::shared::minwindef::LPARAM::try_from(source & NVIQ_IME_MASK_LAYOUT);
            if let Ok(lparam) = current_layout {
                winuser::PostMessageA(hwnd, winuser::WM_INPUTLANGCHANGEREQUEST, 0, lparam);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_sets_current_input_source_to_en_us() {
        set_input_source(NVIQ_IME_LAYOUT_US);
        std::thread::sleep(std::time::Duration::from_secs(2));
        assert_eq!(NVIQ_IME_LAYOUT_US, get_input_source());
    }

    #[test]
    fn it_gets_current_input_source_multiple_times() {
        for _ in 0..10 {
            get_input_source();
        }
    }

    #[test]
    fn it_sets_current_input_source_multiple_times() {
        for _ in 0..10 {
            set_input_source(NVIQ_IME_LAYOUT_US);
        }
    }
}
