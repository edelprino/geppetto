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
    let chat = std::fs::read_to_string("chats/first.md").unwrap();
    let chat: Vec<&str> = chat.split("---").collect();
    let chat: Vec<&str> = chat.iter().map(|x| x.trim()).collect();
    let chat: Vec<MarkdownChatMessage> = chat
        .iter()
        .map(|x| MarkdownChatMessage::from_string(x).unwrap())
        .collect();
    let chat: Vec<ChatMessage> = chat.iter().map(|x| x.to_chat_message()).collect();
    let api_key = std::env::var("OPENAI_API_KEY")?;
    let gpt = ChatGPT::new(api_key)?;
    let stream = gpt.send_history_streaming(&chat).await?;
    stream
        .for_each(|each| async move {
            match each {
                ResponseChunk::Content {
                    delta,
                    response_index: _,
                } => {
                    // Printing part of response without the newline
                    print!("{delta}");
                    // Manually flushing the standard output, as `print` macro does not do that
                    stdout().lock().flush().unwrap();
                }
                _ => {}
            }
        })
        .await;
    println!();
    Ok(())
}
