use actix_files::NamedFile;
use actix_web::http::header;
use actix_web::{App, Error, HttpRequest, HttpResponse, HttpServer, Responder, web};
use actix_ws::{Message, Session};
use futures_util::StreamExt as _;
use nvim_rs::{Handler, Neovim, error::LoopError};
use rmpv::Value;
use rust_embed::RustEmbed;
use serde::Serialize;
use std::path::{Component, PathBuf};
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::{sync::Mutex, sync::RwLock, task::JoinHandle};

mod cmark;
mod nvim;
mod util;

type Writer = nvim_rs::compat::tokio::Compat<tokio::fs::File>;

static NVIQ_MDP_LOCAL_HOST: &str = "127.0.0.1";

#[allow(unused)]
#[derive(Serialize)]
#[serde(tag = "action")]
enum Payload {
    None,
    Update { text: String },
    Scroll { line: u32 },
}

#[derive(Clone)]
struct NeovimHandler {
    pub current_dir: Arc<RwLock<PathBuf>>,
    session: Arc<Mutex<Option<Session>>>,
    port: Arc<RwLock<u16>>,
    renderer: Arc<Mutex<cmark::CmarkRenderer>>,
    throttle_update: Arc<Mutex<SystemTime>>,
    debounce_update: Arc<Mutex<SystemTime>>,
    throttle_scroll: Arc<Mutex<SystemTime>>,
    debounce_scroll: Arc<Mutex<SystemTime>>,
}

impl NeovimHandler {
    pub fn new() -> Self {
        Self {
            current_dir: Arc::new(RwLock::new(PathBuf::default())),
            session: Arc::new(Mutex::new(None)),
            port: Arc::new(RwLock::new(0)),
            renderer: Arc::new(Mutex::new(cmark::CmarkRenderer::new())),
            throttle_update: Arc::new(Mutex::new(UNIX_EPOCH)),
            debounce_update: Arc::new(Mutex::new(UNIX_EPOCH)),
            throttle_scroll: Arc::new(Mutex::new(UNIX_EPOCH)),
            debounce_scroll: Arc::new(Mutex::new(UNIX_EPOCH)),
        }
    }

    async fn set_session(&self, session: Session) {
        let mut s = self.session.lock().await;
        *s = Some(session);
    }

    async fn set_port(&self, port: u16) {
        let mut p = self.port.write().await;
        *p = port;
    }

    pub async fn open(&self) -> anyhow::Result<()> {
        let port = self.port.read().await;
        if *port > 0 {
            webbrowser::open(&format!("http://{}:{}", NVIQ_MDP_LOCAL_HOST, *port))?;
        }
        Ok(())
    }

    pub async fn update(&self, neovim: &Neovim<<Self as Handler>::Writer>) -> anyhow::Result<()> {
        let mut session = self.session.lock().await;
        if let Some(session) = &mut *session {
            let buffer = neovim.get_current_buf().await?;

            let buf_root = nvim::buf_get_root(neovim, &buffer).await?;
            let mut current_dir = self.current_dir.write().await;
            *current_dir = buf_root;

            let markdown = nvim::buf_get_all_text(&buffer).await?;

            let mut renderer = self.renderer.lock().await;
            let md_html = renderer.render(&markdown);

            let payload = Payload::Update { text: md_html };
            let payload_string = serde_json::to_string(&payload)?;
            session.text(payload_string).await?;
        }
        Ok(())
    }

    pub async fn scroll(&self, line: u32) -> anyhow::Result<()> {
        let mut session = self.session.lock().await;
        if let Some(session) = &mut *session {
            let payload = Payload::Scroll { line };
            let payload_string = serde_json::to_string(&payload)?;
            session.text(payload_string).await?;
        }
        Ok(())
    }
}

#[async_trait::async_trait]
impl Handler for NeovimHandler {
    type Writer = Writer;

    async fn handle_request(
        &self,
        name: String,
        args: Vec<Value>,
        neovim: Neovim<Self::Writer>,
    ) -> Result<Value, Value> {
        match name.as_ref() {
            "open" => {
                let _ = self.open().await;
                Ok(Value::Nil)
            }
            "update" => {
                let mut throttle = self.throttle_update.lock().await;
                let now = SystemTime::now();
                if let Ok(elapsed) = now.duration_since(*throttle) {
                    if elapsed >= Duration::from_millis(200) {
                        *throttle = now;
                        let _ = self.update(&neovim).await;
                    } else {
                        drop(throttle);
                        let mut debounce = self.debounce_update.lock().await;
                        *debounce = now;
                        let handler = self.clone();
                        let neovim_clone = neovim.clone();
                        let debounce_clone = debounce.clone();
                        tokio::spawn(async move {
                            tokio::time::sleep(Duration::from_millis(500)).await;
                            let debounce = handler.debounce_update.lock().await;
                            if *debounce == debounce_clone {
                                let _ = handler.update(&neovim_clone).await;
                            }
                        });
                    }
                }
                Ok(Value::Nil)
            }
            "scroll" => {
                if let Some(&Value::Integer(line)) = args.get(0) {
                    if let Some(lnum) = line.as_u64() {
                        let mut throttle = self.throttle_scroll.lock().await;
                        let now = SystemTime::now();
                        if let Ok(elapsed) = now.duration_since(*throttle) {
                            if elapsed >= Duration::from_millis(100) {
                                *throttle = now;
                                let _ = self.scroll(lnum as u32).await;
                            } else {
                                drop(throttle);
                                let mut debounce = self.debounce_scroll.lock().await;
                                *debounce = now;
                                let handler = self.clone();
                                let debounce_clone = debounce.clone();
                                tokio::spawn(async move {
                                    tokio::time::sleep(Duration::from_millis(200)).await;
                                    let debounce = handler.debounce_scroll.lock().await;
                                    if *debounce == debounce_clone {
                                        let _ = handler.scroll(lnum as u32).await;
                                    }
                                });
                            }
                        }
                    }
                }
                Ok(Value::Nil)
            }
            _ => Ok(Value::Nil),
        }
    }
}

#[derive(Clone)]
struct NeovimClient {
    pub neovim: Neovim<Writer>,
    pub handler: NeovimHandler,
}

impl NeovimClient {
    pub async fn new(
        handler: NeovimHandler,
    ) -> anyhow::Result<(Self, JoinHandle<Result<(), Box<LoopError>>>)> {
        let (neovim, io_handler) = nvim_rs::create::tokio::new_parent(handler.clone()).await?;

        Ok((Self { neovim, handler }, io_handler))
    }

    pub async fn run(&self, io_handler: JoinHandle<Result<(), Box<LoopError>>>) {
        match io_handler.await {
            Err(join_err) => eprintln!("Error joining IO loop: {}", join_err),
            Ok(Err(err)) => {
                if !err.is_reader_error() {
                    let _ = nvim::notify(
                        &self.neovim,
                        &format!("Error: {}", err),
                        nvim::LogLevels::Error,
                    )
                    .await;
                }

                if !err.is_channel_closed() {
                    eprintln!("Error: {}", err);
                }
            }
            Ok(Ok(())) => {}
        }
    }

    pub async fn update(&self) {
        let _ = self.handler.update(&self.neovim).await;
    }
}

fn port_is_available(port: u16) -> bool {
    match std::net::TcpListener::bind((NVIQ_MDP_LOCAL_HOST, port)) {
        Ok(_) => true,
        Err(_) => false,
    }
}

fn get_available_port() -> Option<u16> {
    (8080..9000).find(|port| port_is_available(*port))
}

async fn index() -> HttpResponse {
    let template = include_str!("index.html");

    HttpResponse::Ok()
        .content_type("text/html; charset=utf-8")
        .body(template)
}

async fn ws_index(
    req: HttpRequest,
    stream: web::Payload,
    client: web::Data<NeovimClient>,
) -> Result<HttpResponse, Error> {
    let (res, session, mut stream) = actix_ws::handle(&req, stream)?;
    client.handler.set_session(session.clone()).await;

    actix_web::rt::spawn(async move {
        while let Some(Ok(msg)) = stream.next().await {
            match msg {
                Message::Text(text) => {
                    if text == "update" {
                        client.update().await;
                    }
                }
                _ => {}
            }
        }
    });

    Ok(res)
}

#[derive(RustEmbed)]
#[folder = "static_assets/"]
struct Asset;

#[actix_web::get("/static/{_:.*}")]
async fn static_handler(path: web::Path<String>) -> HttpResponse {
    let path = path.into_inner();
    match Asset::get(&path) {
        Some(content) => {
            let mime = mime_guess::from_path(&path).first_or_octet_stream();
            HttpResponse::Ok()
                .content_type(mime.as_ref())
                .body(content.data.into_owned())
        }
        None => HttpResponse::NotFound().body("404 Not Found"),
    }
}

#[actix_web::get("/api/images/{filename:.*}")]
async fn local_image_handler(
    req: HttpRequest,
    path: web::Path<String>,
    data: web::Data<NeovimClient>,
) -> impl Responder {
    if !util::is_relative_path(path.as_str()) {
        return Err(actix_web::error::ErrorForbidden("Relative paths only"));
    }

    let file_path = PathBuf::from(path.into_inner());

    if file_path
        .components()
        .any(|c| matches!(c, Component::ParentDir))
    {
        return Err(actix_web::error::ErrorForbidden("Access Denied"));
    }

    let buf_root = data.handler.current_dir.read().await;
    let full_path = buf_root.join(file_path);

    match NamedFile::open(&full_path) {
        Ok(named_file) => {
            let mut res = named_file.into_response(&req);
            let headers = res.headers_mut();

            headers.insert(
                header::CACHE_CONTROL,
                header::HeaderValue::from_static(
                    "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0",
                ),
            );
            headers.insert(header::PRAGMA, header::HeaderValue::from_static("no-cache"));
            headers.insert(header::EXPIRES, header::HeaderValue::from_static("0"));

            Ok(res)
        }
        Err(e) => {
            eprintln!("Failed to read file: {:?}. Target path: {:?}", e, full_path);
            Err(actix_web::error::ErrorNotFound(format!(
                "File not found: {:?}",
                e
            )))
        }
    }
}

#[actix_web::main]
async fn main() -> anyhow::Result<()> {
    let handler = NeovimHandler::new();
    let (client, io_handler) = NeovimClient::new(handler).await?;

    let port = match get_available_port() {
        Some(p) => p,
        None => {
            let err_msg = "No available port";
            let _ = nvim::notify(&client.neovim, err_msg, nvim::LogLevels::Error).await;
            return Err(anyhow::anyhow!(err_msg));
        }
    };

    client.handler.set_port(port).await;
    let client_app_data = client.clone();

    let server = HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(client_app_data.clone()))
            .service(web::resource("/").to(index))
            .service(static_handler)
            .service(local_image_handler)
            .route("/ws", web::get().to(ws_index))
            .default_service(web::route().to(index))
    })
    .workers(2)
    .bind((NVIQ_MDP_LOCAL_HOST, port))?;

    let _ = client.handler.open().await?;

    tokio::select! {
        _ = client.run(io_handler) => {},
        _ = server.run() => {},
    }

    Ok(())
}
