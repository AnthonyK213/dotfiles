#[derive(Debug)]
pub struct ConsultOption {
    /// Whether to enable fuzzy matching.
    pub fuzzy: bool,
    /// Whether to enable parallel search.
    pub parallel: bool,
    /// Max edit distance on fuzzy matching.
    pub max_dist: usize,
    /// Max count of consulting result per dict.
    pub max_item: usize,
}

impl Default for ConsultOption {
    fn default() -> Self {
        Self {
            fuzzy: false,
            parallel: false,
            max_dist: 3,
            max_item: 10,
        }
    }
}
