use std::path::Path;

pub(crate) fn is_relative_path(input: &str) -> bool {
    if input.starts_with("http://")
        || input.starts_with("https://")
        || input.starts_with("file://")
        || input.starts_with("//")
    {
        return false;
    }

    let p = Path::new(input);
    p.is_relative() && !p.is_absolute() && url::Url::parse(input).is_err()
}
