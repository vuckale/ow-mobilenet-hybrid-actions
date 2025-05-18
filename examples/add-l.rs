use std::io::{self, Read};
use serde_json::Value;
use anyhow::Result;

fn main() -> Result<()> {
    // Read stdin
    let mut buffer = String::new();
    io::stdin().read_to_string(&mut buffer)?;
    let input_json: Value = serde_json::from_str(&buffer)?;
    let result = func(input_json)?;
    println!("{}", serde_json::to_string_pretty(&result)?);
    Ok(())
}

fn func(json: Value) -> Result<Value> {
    // Extract parameters
    let param1 = json
        .get("param1")
        .ok_or_else(|| anyhow::anyhow!("Expected 'param1' to be present"))?
        .as_i64()
        .ok_or_else(|| anyhow::anyhow!("Expected 'param1' to be an i64"))?;

    let param2 = json
        .get("param2")
        .ok_or_else(|| anyhow::anyhow!("Expected 'param2' to be present"))?
        .as_i64()
        .ok_or_else(|| anyhow::anyhow!("Expected 'param2' to be an i64"))?;

    Ok(serde_json::json!({ "result": param1 + param2 }))
}
