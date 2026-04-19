use super::consult_option::ConsultOption;
use super::consult_result::ConsultResult;
use super::dict_content::DictContent;
use super::dict_index::{DictIndex, IndexItem};
use super::dict_info::DictInfo;
use super::sd_error::SdError;
use super::util;
use std::path::{Path, PathBuf};

#[derive(Debug)]
pub(crate) struct Dictionary {
    content: DictContent,
    index: DictIndex,
    info: DictInfo,
}

impl Dictionary {
    pub fn new<P: AsRef<Path>>(dir: P) -> Result<Self, SdError> {
        let mut dz: Option<PathBuf> = None;
        let mut idx: Option<PathBuf> = None;
        let mut ifo: Option<PathBuf> = None;

        for entry in std::fs::read_dir(&dir)? {
            let path = entry?.path();

            if !path.is_file() {
                continue;
            }

            if let Some(ext) = path.extension() {
                match ext.to_str() {
                    Some("dz") => dz = Some(path),
                    Some("idx") => idx = Some(path),
                    Some("ifo") => ifo = Some(path),
                    _ => continue,
                }
            }
        }

        if dz.is_none() {
            return Err(SdError::NoDzError);
        }

        if idx.is_none() {
            return Err(SdError::NoIdxError);
        }

        if ifo.is_none() {
            return Err(SdError::NoIfoError);
        }

        let mut content = DictContent::default();
        let mut index = DictIndex::default();
        let mut info = DictInfo::default();

        content.read_from_file(dz.unwrap())?;
        info.read_from_file(ifo.unwrap())?;

        if info.idxoffsetbits == 32 {
            index.read_from_file(idx.unwrap(), util::read_u32)?;
        } else if info.idxoffsetbits == 64 {
            index.read_from_file(idx.unwrap(), util::read_u64)?;
        }

        Ok(Dictionary {
            content,
            index,
            info,
        })
    }

    pub fn consult<'a>(&'a self, word: &str, option: &ConsultOption) -> Vec<ConsultResult<'a>> {
        let to_result = |item: &&'a IndexItem| -> ConsultResult<'a> {
            let def = self.content.get(item);
            ConsultResult {
                dict: &self.info.bookname,
                word: &item.word,
                definition: &def,
            }
        };

        if option.fuzzy {
            self.index
                .consult_fuzzy(word, option)
                .iter()
                .map(to_result)
                .collect()
        } else {
            if let Some(item) = self.index.consult_exact(word) {
                vec![to_result(&item)]
            } else {
                vec![]
            }
        }
    }
}
