use super::consult_option::ConsultOption;
use super::consult_result::ConsultResult;
use super::dictionary::Dictionary;
use rayon::prelude::*;

#[derive(Debug)]
pub struct Library {
    dicts: Vec<Dictionary>,
}

impl Library {
    pub fn new(dict_dir: &str) -> Self {
        let mut dicts = Vec::new();

        if let Ok(read_dir) = std::fs::read_dir(dict_dir) {
            for entry in read_dir {
                if let Ok(ent) = entry {
                    let path = ent.path();
                    if !path.is_dir() {
                        continue;
                    }
                    if let Ok(dict) = Dictionary::new(path) {
                        dicts.push(dict);
                    }
                }
            }
        }

        Self { dicts }
    }

    pub fn dict_count(&self) -> usize {
        self.dicts.len()
    }

    pub fn consult(&self, word: &str, option: &ConsultOption) -> Vec<ConsultResult<'_>> {
        if option.parallel {
            self.dicts
                .par_iter()
                .flat_map_iter(|dict| dict.consult(word, &option))
                .collect()
        } else {
            self.dicts
                .iter()
                .flat_map(|dict| dict.consult(word, &option))
                .collect()
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::stardict::{consult_option::ConsultOption, library::Library, util};

    #[test]
    fn look_up_exact() {
        let dicts = Library::new(util::get_stardict_dir().unwrap().to_str().unwrap());
        let mut option = ConsultOption::default();

        option.fuzzy = false;

        let consult_en = dicts.consult("search", &option);
        assert_eq!(1, consult_en.len());
        assert_eq!("search", consult_en[0].word);

        let consult_zh = dicts.consult("搜索", &option);
        assert_eq!(1, consult_zh.len());
        assert_eq!("搜索", consult_zh[0].word);
    }

    #[test]
    fn look_up_fuzzy() {
        let dicts = Library::new(util::get_stardict_dir().unwrap().to_str().unwrap());
        let mut option = ConsultOption::default();

        option.fuzzy = true;
        option.max_dist = 3;

        let consult_en = dicts.consult("zearch", &option);
        assert_eq!(10, consult_en.len());
        assert_eq!("search", consult_en[0].word);
    }
}
