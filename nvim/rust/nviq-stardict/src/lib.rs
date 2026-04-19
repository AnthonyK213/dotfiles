use _ffi_util::str_util;
use _stardict::{ConsultOption, Library};
use std::ffi::{CString, c_char};

#[unsafe(no_mangle)]
pub extern "C" fn nviq_stardict_library_new(dict_dir: *const c_char) -> *mut Library {
    match std::panic::catch_unwind(|| {
        if let Ok(dict_dir_str) = str_util::cstr_to_string(dict_dir) {
            let library = Box::new(Library::new(&dict_dir_str));
            Box::into_raw(library)
        } else {
            std::ptr::null_mut()
        }
    }) {
        Ok(library_ptr) => library_ptr,
        Err(_) => std::ptr::null_mut(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn nviq_stardict_library_lookup(
    library: *mut Library,
    word: *const c_char,
) -> *mut c_char {
    if library.is_null() || word.is_null() {
        return std::ptr::null_mut();
    }

    let result = std::panic::catch_unwind(|| {
        let lib_obj = unsafe { &mut *library };

        let word_str = match str_util::cstr_to_string(word) {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        };

        let mut options = ConsultOption::default();
        options.fuzzy = false;
        options.parallel = lib_obj.dict_count() > 2;
        options.max_dist = 3;
        options.max_item = 10;

        let mut results = lib_obj.consult(&word_str, &options);

        if results.is_empty() {
            options.fuzzy = true;
            results = lib_obj.consult(&word_str, &options);
        }

        let result_json = format!(
            "[{}]",
            results
                .iter()
                .flat_map(|res| serde_json::to_string(res))
                .collect::<Vec<String>>()
                .join(","),
        );

        if let Ok(res) = CString::new(result_json) {
            res.into_raw()
        } else {
            std::ptr::null_mut()
        }
    });

    match result {
        Ok(result_json) => result_json,
        Err(_) => std::ptr::null_mut(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn nviq_stardict_library_drop(library: *mut Library) {
    if !library.is_null() {
        unsafe {
            let _ = Box::from_raw(library);
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn nviq_stardict_cstr_free(cstr: *mut c_char) {
    _ffi_util::str_util::cstr_free(cstr);
}
