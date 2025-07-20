extern crate serde_json;

use serde_derive::{Deserialize, Serialize};
use serde_json::{Error, Value};
use std::process::{Command, Stdio};
use std::io::Write;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
struct Output {
    body: String,
}

fn quick_ping() -> Result<Value, Error> {
    serde_json::to_value(Output {
        body: "pong".to_string(),
    })
}

pub fn main(args: Value) -> Result<Value, Error> {
    if args
        .get("ping")
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
    {
        return quick_ping();
    }
    // convert input JSON to string
    let input_json = match serde_json::to_string(&args) {
        Ok(json_str) => json_str,
        Err(e) => {
            return serde_json::to_value(Output {
                body: format!("Failed to serialize input JSON: {}", e),
            });
        }
    };
    // run the mobilenet binary, piping input JSON into stdin
    let output_str = match Command::new("./mobilenet-oc-l")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .and_then(|mut child| {
            if let Some(stdin) = child.stdin.as_mut() {
                stdin.write_all(input_json.as_bytes())?;
            }

            let output = child.wait_with_output()?;
            Ok(output)
        }) {
        Ok(output) => {
            if output.status.success() {
                String::from_utf8_lossy(&output.stdout).to_string()
            } else {
                format!(
                    "Binary exited with error: {}",
                    String::from_utf8_lossy(&output.stderr)
                )
            }
        }
        Err(e) => format!("Failed to execute binary: {}", e),
    };
    // return the result
    let response = Output {
        body: format!("Mobilenet output:\n{}", output_str),
    };
    serde_json::to_value(response)
}
