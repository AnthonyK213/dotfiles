use super::dict_index::IndexItem;
use super::sd_error::SdError;
use flate2::read::GzDecoder;
use std::fs::File;
use std::io::Read;
use std::path::Path;

#[derive(Debug, Default)]
pub(crate) struct DictContent {
    content: String,
}

impl DictContent {
    pub fn read_from_file<P: AsRef<Path>>(&mut self, filepath: P) -> Result<(), SdError> {
        let file = File::open(filepath)?;
        let mut dict = GzDecoder::new(file);
        dict.read_to_string(&mut self.content)?;
        Ok(())
    }

    pub fn get(&self, item: &IndexItem) -> &str {
        &self.content[item.offset..(item.offset + item.length)]
    }
}
