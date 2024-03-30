use std::io::{stdout, Write};

use anyhow::Result;
use chatgpt::{
    prelude::ChatGPT,
    types::{ChatMessage, ResponseChunk},
};

use futures_util::StreamExt;

#[derive(Debug)]
enum MarkdownChatMessage {
    FromUser(String),
    FromAssistant(String),
    System(String),
}

impl MarkdownChatMessage {
    fn from_string(s: &str) -> Result<MarkdownChatMessage> {
        let first_line = s.lines().next();
        let body = s.lines().skip(1).collect::<Vec<&str>>().join("\n");
        anyhow::ensure!(first_line.is_some(), "Empty string");
        let s = first_line.unwrap();
        if s.starts_with("### User") {
            Ok(MarkdownChatMessage::FromUser(body))
        } else if s.starts_with("### Assistant") {
            Ok(MarkdownChatMessage::FromAssistant(body))
        } else {
            Ok(MarkdownChatMessage::System(body))
        }
    }

    fn to_chat_message(&self) -> ChatMessage {
        match self {
            MarkdownChatMessage::FromUser(s) => ChatMessage {
                role: chatgpt::types::Role::User,
                content: s.clone(),
                #[cfg(feature = "functions")]
                function_call: None,
            },
            MarkdownChatMessage::FromAssistant(s) => ChatMessage {
                role: chatgpt::types::Role::Assistant,
                content: s.clone(),
                #[cfg(feature = "functions")]
                function_call: None,
            },
            MarkdownChatMessage::System(s) => ChatMessage {
                role: chatgpt::types::Role::System,
                content: s.clone(),
                #[cfg(feature = "functions")]
                function_call: None,
            },
        }
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let openai_api_key = std::env::var("OPENAI_API_KEY")?;
    let filename = std::env::args()
        .nth(1)
        .ok_or(anyhow::anyhow!("No filename provided"))?;
    let chat: Vec<ChatMessage> = std::fs::read_to_string(filename)?
        .split("---")
        .map(str::trim)
        .map(|x| MarkdownChatMessage::from_string(x).unwrap())
        .map(|x| x.to_chat_message())
        .collect();

    let chat_gpt = ChatGPT::new(openai_api_key)?;
    let stream = chat_gpt.send_history_streaming(&chat).await?;
    println!("### Assistant");
    stream
        .for_each(|each| async move {
            match each {
                ResponseChunk::Content {
                    delta,
                    response_index: _,
                } => {
                    print!("{delta}");
                    stdout().lock().flush().unwrap();
                }
                _ => {}
            }
        })
        .await;
    println!();
    println!("---");
    Ok(())
}
