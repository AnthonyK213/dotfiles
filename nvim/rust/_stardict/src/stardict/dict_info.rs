use super::sd_error::SdError;
use regex::Regex;
use std::fs::File;
use std::io::{self, BufRead};
use std::path::Path;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum DictVersion {
    None,
    V242,
    V300,
}

impl From<&str> for DictVersion {
    fn from(value: &str) -> Self {
        match value {
            "2.4.2" => Self::V242,
            "3.0.0" => Self::V300,
            _ => Self::None,
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub(crate) struct DictInfo {
    pub version: DictVersion,
    pub wordcount: usize,
    pub idxfilesize: usize,
    pub idxoffsetbits: usize,
    pub bookname: String,
    pub author: String,
    pub description: String,
    pub date: String,
    pub sametypesequence: String,
}

impl Default for DictInfo {
    fn default() -> Self {
        Self {
            version: DictVersion::None,
            wordcount: 0,
            idxfilesize: 0,
            idxoffsetbits: 0,
            bookname: "unknown".into(),
            author: "unknown".into(),
            description: "unknown".into(),
            date: "unknown".into(),
            sametypesequence: "unknown".into(),
        }
    }
}

impl DictInfo {
    pub fn read_from_file<P>(&mut self, filename: P) -> Result<(), SdError>
    where
        P: AsRef<Path>,
    {
        let re = Regex::new(r"^(\w+)=(.+)$")?;
        let lines = read_lines(filename)?;

        for line in lines {
            if let Ok(l) = line {
                if let Some(c) = re.captures(&l) {
                    self.set_field(&c[1], &c[2])?;
                }
            }
        }

        Ok(())
    }

    fn set_field(&mut self, field: &str, value: &str) -> Result<(), SdError> {
        match field {
            "version" => {
                self.version = value.into();
                if self.version == DictVersion::None {
                    return Err(SdError::ParseInfoError("version"));
                }
            }
            "wordcount" => {
                self.wordcount = value
                    .parse()
                    .map_err(|_| SdError::ParseInfoError("wordcount"))?
            }
            "idxfilesize" => {
                self.idxfilesize = value
                    .parse()
                    .map_err(|_| SdError::ParseInfoError("idxfilesize"))?
            }
            "idxoffsetbits" => {
                self.idxoffsetbits = value
                    .parse()
                    .map_err(|_| SdError::ParseInfoError("idxoffsetbits"))?
            }
            "bookname" => {
                self.bookname = value
                    .parse()
                    .map_err(|_| SdError::ParseInfoError("bookname"))?
            }
            "author" => {
                self.author = value
                    .parse()
                    .map_err(|_| SdError::ParseInfoError("author"))?
            }
            "description" => {
                self.description = value
                    .parse()
                    .map_err(|_| SdError::ParseInfoError("description"))?
            }
            "date" => self.date = value.parse().map_err(|_| SdError::ParseInfoError("date"))?,
            "sametypesequence" => {
                self.sametypesequence = value
                    .parse()
                    .map_err(|_| SdError::ParseInfoError("sametypesequence"))?
            }
            _ => {}
        }

        match self.version {
            DictVersion::V242 => self.idxoffsetbits = 32,
            DictVersion::V300 => {
                if self.idxoffsetbits != 32 || self.idxoffsetbits != 64 {
                    return Err(SdError::ParseInfoError("invalid idxoffsetbits"));
                }
            }
            DictVersion::None => return Err(SdError::ParseInfoError("no version info")),
        }

        Ok(())
    }
}

fn read_lines<P>(filename: P) -> io::Result<io::Lines<io::BufReader<File>>>
where
    P: AsRef<Path>,
{
    let file = File::open(filename)?;
    Ok(io::BufReader::new(file).lines())
}

#[cfg(test)]
mod tests {
    use crate::stardict::dict_info::{DictInfo, DictVersion};
    use crate::stardict::util;

    #[test]
    fn read_ifo() {
        let mut ifo_path = util::get_stardict_dir().unwrap();
        ifo_path.push("stardict-langdao-ec-gb-2.4.2");
        ifo_path.push("langdao-ec-gb.ifo");

        let mut ifo = DictInfo::default();
        ifo.read_from_file(ifo_path).unwrap();

        assert_eq!(
            ifo,
            DictInfo {
                version: DictVersion::V242,
                wordcount: 435468,
                idxfilesize: 10651674,
                idxoffsetbits: 32,
                bookname: "朗道英汉字典5.0".into(),
                author: "上海朗道电脑科技发展有限公司".into(),
                description: "罗小辉破解文件格式，胡正制作转换程序。".into(),
                date: "2003.08.26".into(),
                sametypesequence: "m".into(),
            }
        )
    }
}
