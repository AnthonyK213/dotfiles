use std::fs::{self, File};
use std::io::{self, Cursor};
use std::path::Path;

fn fetch_zip_package(out_dir: &str, zip_dir: &str, url: &str) {
    let dir = Path::new(out_dir).join(zip_dir);
    if !dir.exists() {
        let resp = reqwest::blocking::get(url).expect("Can't download the package");
        let bytes = resp.bytes().expect("Failed to read data");
        let mut archive = zip::ZipArchive::new(Cursor::new(bytes)).expect("Invalid zip file");
        archive.extract(out_dir).expect("Failed to unzip");
    }
}

fn fetch_cdn(out_dir: &str, file_name: &str, url: &str) {
    let file_path = Path::new(out_dir).join(file_name);
    if !file_path.exists() {
        let mut resp = reqwest::blocking::get(url).expect("Can't connect to CDN");
        let mut file = File::create(file_path).unwrap();
        io::copy(&mut resp, &mut file).unwrap();
    }
}

fn main() {
    let out_dir = "static_assets";
    if !Path::new(out_dir).exists() {
        fs::create_dir_all(out_dir).unwrap();
    }

    // GitHub Markdown CSS
    fetch_zip_package(
        out_dir,
        "github-markdown-css-5.9.0",
        "https://github.com/sindresorhus/github-markdown-css/archive/refs/tags/v5.9.0.zip",
    );

    // KaTeX
    fetch_zip_package(
        out_dir,
        "katex",
        "https://github.com/KaTeX/KaTeX/releases/download/v0.16.40/katex.zip",
    );

    // Mermaid
    fetch_cdn(
        out_dir,
        "mermaid.min.js",
        "https://cdn.jsdelivr.net/npm/mermaid@11.13.0/dist/mermaid.min.js",
    );

    println!("cargo:rerun-if-changed=build.rs");
}
