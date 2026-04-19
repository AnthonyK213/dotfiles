use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct ConsultResult<'a> {
    pub dict: &'a str,
    pub word: &'a str,
    pub definition: &'a str,
}
