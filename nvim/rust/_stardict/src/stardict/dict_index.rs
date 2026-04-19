use super::consult_option::ConsultOption;
use super::sd_error::SdError;
use edit_distance;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::Path;

#[derive(Debug, PartialEq, Eq)]
pub(crate) struct IndexItem {
    pub word: String,
    pub offset: usize,
    pub length: usize,
}

#[derive(Debug, Default)]
pub(crate) struct DictIndex {
    items: Vec<IndexItem>,
}

impl DictIndex {
    pub fn read_from_file<P, F>(&mut self, filename: P, read_usize: F) -> Result<(), SdError>
    where
        P: AsRef<Path>,
        F: Fn(&mut BufReader<File>) -> Result<usize, SdError>,
    {
        let file = File::open(filename)?;
        let mut reader = BufReader::new(file);
        let mut word_buffer = vec![];

        loop {
            let word_bytes = reader.read_until(0, &mut word_buffer)?;
            if let Some(b'\0') = word_buffer.last() {
                word_buffer.pop();
            }
            if word_bytes == 0 {
                break;
            }

            let word = String::from_utf8(word_buffer.clone())?;
            word_buffer.clear();

            self.items.push(IndexItem {
                word,
                offset: read_usize(&mut reader)?,
                length: read_usize(&mut reader)?,
            });
        }

        Ok(())
    }

    pub(crate) fn consult_exact(&self, word: &str) -> Option<&IndexItem> {
        let lower = word.to_lowercase();
        self.items
            .iter()
            .find(|item| item.word.to_lowercase() == lower)
    }

    pub(crate) fn consult_fuzzy(&self, word: &str, option: &ConsultOption) -> Vec<&IndexItem> {
        let lower = word.to_lowercase();
        let n_word_chars = lower.chars().count();
        let max_dist = option.max_dist;

        let mut result: Vec<(&IndexItem, usize)> = self
            .items
            .iter()
            .filter_map(|item| {
                let item_word = &item.word.to_lowercase();
                let n_item_word_chars = item_word.chars().count();

                if n_word_chars.abs_diff(n_item_word_chars) >= max_dist {
                    return None;
                }

                let dist = edit_distance::edit_distance(&lower, item_word);

                if dist <= max_dist && dist < n_word_chars && dist < n_item_word_chars {
                    Some((item, dist))
                } else {
                    None
                }
            })
            .collect();

        result.sort_by(|a, b| {
            let order = a.1.cmp(&b.1);

            if order != std::cmp::Ordering::Equal {
                return order;
            }

            a.0.word.cmp(&b.0.word)
        });

        result
            .iter()
            .take(option.max_item)
            .map(|item| item.0)
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use crate::stardict::{dict_index::*, util};

    #[test]
    fn read_idx() {
        let mut idx_path = util::get_stardict_dir().unwrap();
        idx_path.push("stardict-langdao-ec-gb-2.4.2");
        idx_path.push("langdao-ec-gb.idx");

        let mut idx = DictIndex::default();
        idx.read_from_file(idx_path, util::read_u32).unwrap();

        assert_eq!(
            idx.items[0],
            IndexItem {
                word: "a".to_string(),
                offset: 0,
                length: 132,
            }
        )
    }
}
