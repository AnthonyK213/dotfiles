use super::sd_error::SdError;
use directories::BaseDirs;
use std::io::{BufReader, Read};
use std::path::PathBuf;

pub(crate) fn read_u32<R>(reader: &mut BufReader<R>) -> Result<usize, SdError>
where
    R: Read,
{
    let mut bytes = [0; 4];
    reader.read_exact(&mut bytes)?;
    Ok(u32::from_be_bytes(bytes) as usize)
}

pub(crate) fn read_u64<R>(reader: &mut BufReader<R>) -> Result<usize, SdError>
where
    R: Read,
{
    let mut bytes = [0; 8];
    reader.read_exact(&mut bytes)?;
    Ok(u64::from_be_bytes(bytes) as usize)
}

#[allow(unused)]
pub(crate) fn get_stardict_dir() -> Option<PathBuf> {
    if let Some(base_dirs) = BaseDirs::new() {
        let mut home = base_dirs.home_dir().to_path_buf();
        home.push(".stardict");
        home.push("dic");
        if home.is_dir() {
            return Some(home);
        }
    }
    None
}
