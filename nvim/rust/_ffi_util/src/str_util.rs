use std::ffi::{CStr, CString, c_char};

pub fn cstr_to_string(cstr: *const c_char) -> Result<String, std::str::Utf8Error> {
    Ok(unsafe { CStr::from_ptr(cstr) }.to_str()?.to_owned())
}

pub fn cstr_free(cstr: *mut c_char) {
    if !cstr.is_null() {
        unsafe {
            drop(CString::from_raw(cstr));
        }
    }
}
