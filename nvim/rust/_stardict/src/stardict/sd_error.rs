#[derive(Debug, thiserror::Error)]
pub(crate) enum SdError {
    #[error("No dz file.")]
    NoDzError,
    #[error("No idx file.")]
    NoIdxError,
    #[error("No ifo file.")]
    NoIfoError,
    #[error("The error type of I/O operations.")]
    IoError(#[from] std::io::Error),
    #[error("A possible error value when converting a String from a UTF-8 byte vector.")]
    FromUtf8Error(#[from] std::string::FromUtf8Error),
    #[error("An error that occurred during parsing or compiling a regular expression.")]
    RegexError(#[from] regex::Error),
    #[error("An error when parsing .ifo file")]
    ParseInfoError(&'static str),
}
