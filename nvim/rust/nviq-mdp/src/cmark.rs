use crate::util;
use pulldown_cmark::{CodeBlockKind, Event, Options, Parser, Tag, html};
use std::ops::Range;

const NVIQ_MDP_DATA_SOURCE_LINE: &str = "data-source-line";

fn is_block_tag(tag: &Tag) -> bool {
    matches!(
        tag,
        Tag::Paragraph | Tag::Heading { .. } | Tag::Item | Tag::CodeBlock(_)
    )
}

fn render_with_line_numbers<'a>(
    markdown: &'a str,
    event: Event<'a>,
    range: Range<usize>,
) -> Event<'a> {
    match &event {
        Event::Start(tag) if is_block_tag(tag) => {
            // FIXME: Bad performance...
            let line = markdown[..range.start].lines().count() + 1;
            if let Tag::CodeBlock(CodeBlockKind::Fenced(lang)) = tag
                && lang.as_ref() == "mermaid"
            {
                let mermaid = format!(
                    "<pre {}=\"{}\" class=\"mermaid-container\"><code class=\"mermaid\">",
                    NVIQ_MDP_DATA_SOURCE_LINE, line
                );
                Event::Html(mermaid.into())
            } else {
                let mut buf = String::new();
                html::push_html(&mut buf, std::iter::once(event.clone()));
                if buf.ends_with('>') {
                    let insert_pos = buf.len() - 1;
                    buf.insert_str(
                        insert_pos,
                        &format!(" {}=\"{}\"", NVIQ_MDP_DATA_SOURCE_LINE, line),
                    );
                }
                Event::Html(buf.into())
            }
        }
        _ => event,
    }
}

fn process_image_source(event: Event) -> Event {
    if let Event::Start(Tag::Image {
        link_type,
        mut dest_url,
        title,
        id,
    }) = event
    {
        if util::is_relative_path(&dest_url) {
            dest_url = format!("/api/images/{}", dest_url).into();
        }

        return Event::Start(Tag::Image {
            link_type,
            dest_url,
            title,
            id,
        });
    }
    event
}

pub struct CmarkRenderer {
    html_cleaner: ammonia::Builder<'static>,
}

impl CmarkRenderer {
    pub fn new() -> Self {
        let mut html_cleaner = ammonia::Builder::default();
        html_cleaner
            .add_generic_attributes(&[NVIQ_MDP_DATA_SOURCE_LINE])
            .add_tag_attributes("code", &["class"])
            .add_tag_attributes("pre", &["class"])
            .add_tag_attributes("p", &["align"])
            .add_tags(&["span", "div"])
            .add_tag_attributes("span", &["class"])
            .add_tag_attributes("div", &["class"]);

        Self { html_cleaner }
    }

    pub fn render(&mut self, markdown: &str) -> String {
        let mut options = Options::empty();
        options.insert(Options::ENABLE_FOOTNOTES);
        options.insert(Options::ENABLE_MATH);
        options.insert(Options::ENABLE_TABLES);
        options.insert(Options::ENABLE_TASKLISTS);

        let parser = Parser::new_ext(markdown, options)
            .into_offset_iter()
            .map(|(event, range)| render_with_line_numbers(markdown, event, range))
            .map(process_image_source);

        let mut html_output = String::new();
        html::push_html(&mut html_output, parser);

        self.html_cleaner.clean(&html_output).to_string()
    }
}
