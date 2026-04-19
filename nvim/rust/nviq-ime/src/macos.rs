use crate::typedef::*;
use core_foundation::array::{CFArray, CFArrayRef};
use core_foundation::base::{CFRelease, CFTypeRef, OSStatus, TCFType};
use core_foundation::dictionary::{CFDictionaryCreate, CFDictionaryRef};
use core_foundation::string::{CFString, CFStringRef};
use once_cell::sync::Lazy;
use std::collections::HashMap;
use std::sync::Mutex;

#[link(name = "Carbon", kind = "framework")]
unsafe extern "C" {
    fn TISCopyCurrentKeyboardInputSource() -> CFTypeRef;
    fn TISGetInputSourceProperty(input_source: CFTypeRef, property_key: CFStringRef) -> CFTypeRef;
    fn TISCreateInputSourceList(
        properties: CFDictionaryRef,
        include_all_installed: bool,
    ) -> CFArrayRef;
    fn TISSelectInputSource(input_source: CFTypeRef) -> OSStatus;
    static kTISPropertyInputSourceID: CFStringRef;
}

static SOURCE_ID_MAP: Lazy<HashMap<String, Source>> = Lazy::new(|| {
    let mut map = HashMap::new();
    map.insert(
        "com.apple.keylayout.ABC".to_string(),
        NVIQ_IME_LAYOUT_US | NVIQ_IME_METHOD_NONE,
    );
    map.insert(
        "com.apple.inputmethod.SCIM.ITABC".to_string(),
        NVIQ_IME_LAYOUT_CHINESE_SIMPLIFIED | NVIQ_IME_METHOD_PINYIN,
    );
    map.insert(
        "com.apple.inputmethod.SCIM.WBX".to_string(),
        NVIQ_IME_LAYOUT_CHINESE_SIMPLIFIED | NVIQ_IME_METHOD_WUBI,
    );
    map
});

static IME_SET_LOCK: Mutex<u32> = Mutex::new(0);

fn id_to_source(source_id: &String) -> Source {
    SOURCE_ID_MAP
        .get(source_id)
        .map_or(NVIQ_IME_LAYOUT_NONE | NVIQ_IME_METHOD_NONE, |&v| v)
}

fn source_to_id(source: Source) -> Option<&'static String> {
    SOURCE_ID_MAP
        .iter()
        .find_map(|(key, &val)| if val == source { Some(key) } else { None })
}

pub(crate) fn get_input_source() -> Source {
    unsafe {
        // FIXME: The input source won't update unless calling
        // TISSelectInputSource explicitly.
        let current_source_ref = TISCopyCurrentKeyboardInputSource();
        if current_source_ref.is_null() {
            return NVIQ_IME_LAYOUT_NONE;
        }

        let source_id_ref =
            TISGetInputSourceProperty(current_source_ref, kTISPropertyInputSourceID);
        let source_id = CFString::wrap_under_get_rule(source_id_ref as CFStringRef);
        let source_id_string = source_id.to_string();

        CFRelease(current_source_ref);

        id_to_source(&source_id_string)
    }
}

pub(crate) fn set_input_source(source: Source) {
    let _lock = IME_SET_LOCK.lock();

    let input_source_string = source_to_id(source);
    if input_source_string.is_none() {
        return;
    }

    unsafe {
        let input_source = CFString::new(input_source_string.unwrap());
        let input_source_ref = input_source.as_CFTypeRef();
        let filter = CFDictionaryCreate(
            std::ptr::null(),
            &(kTISPropertyInputSourceID as CFTypeRef),
            &input_source_ref,
            1,
            std::ptr::null(),
            std::ptr::null(),
        );

        let keyboards_ref = TISCreateInputSourceList(filter, false);
        if keyboards_ref.is_null() {
            return;
        }

        let keyboards = CFArray::<CFTypeRef>::wrap_under_create_rule(keyboards_ref);
        let selected = keyboards.get(0);
        if let Some(value) = selected {
            TISSelectInputSource(*value);
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
