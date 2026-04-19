use futures::AsyncWrite;
use nvim_rs::{Buffer, Neovim, error::CallError};
use rmpv::Value;
use std::path::PathBuf;

#[allow(unused)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogLevels {
    Trace = 0,
    Debug,
    Info,
    Warn,
    Error,
    Off,
}

pub async fn notify<W>(
    neovim: &Neovim<W>,
    message: &str,
    level: LogLevels,
) -> Result<(), Box<CallError>>
where
    W: AsyncWrite + Send + Unpin + 'static,
{
    let mut chunk = vec![Value::from(message)];
    if level == LogLevels::Warn {
        chunk.push(Value::from("WarningMsg"));
    };
    let chunks = vec![Value::from(chunk)];
    let options = vec![(Value::from("err"), Value::from(level == LogLevels::Error))];
    neovim.echo(chunks, true, options).await
}

pub async fn buf_get_root<W>(
    neovim: &Neovim<W>,
    buffer: &Buffer<W>,
) -> Result<PathBuf, Box<CallError>>
where
    W: AsyncWrite + Send + Unpin + 'static,
{
    let name = buffer.get_name().await?;
    let mut buf_root = PathBuf::from(name);
    if buf_root.pop() {
        Ok(buf_root)
    } else {
        let cwd = neovim.call_function("getcwd", vec![]).await?;
        if let Some(cwd_path) = cwd.as_str() {
            Ok(PathBuf::from(cwd_path.to_string()))
        } else {
            Err(Box::new(CallError::WrongValueType(cwd)))
        }
    }
}

pub async fn buf_get_all_text<W>(buffer: &Buffer<W>) -> Result<String, Box<CallError>>
where
    W: AsyncWrite + Send + Unpin + 'static,
{
    let line_count = buffer.line_count().await?;
    let lines = buffer.get_lines(0, line_count, true).await?;
    Ok(lines.join("\n"))
}
