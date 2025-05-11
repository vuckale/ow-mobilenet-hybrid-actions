use base64;
use image;
use std::io::{self, Cursor, Read};
use tract_tensorflow::prelude::*;
use serde_json::Value;
use anyhow::Result;

const MODEL_BYTES: &[u8] = include_bytes!("./mobilenet_v2_1.4_224_frozen.pb");
const LABELS: &str = include_str!("./mobilenet_labels.txt");

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
    // Get base64 image string
    let image_base64 = json
        .get("image")
        .ok_or_else(|| anyhow::anyhow!("Expected 'image' parameter with base64 data"))?
        .as_str()
        .ok_or_else(|| anyhow::anyhow!("Expected 'image' to be a string"))?;

    // Decode base64 to bytes
    let image_bytes = base64::decode(image_base64)
        .map_err(|e| anyhow::anyhow!("Failed to decode base64 image: {}", e))?;

    // Load and preprocess image
    let img = image::load_from_memory(&image_bytes)?;
    let resized = img.resize_exact(224, 224, image::imageops::FilterType::Triangle);

    let mut input = Vec::new();
    for pixel in resized.to_rgb8().pixels() {
        input.push(pixel[0] as f32 / 255.0);
        input.push(pixel[1] as f32 / 255.0);
        input.push(pixel[2] as f32 / 255.0);
    }

    // Load model
    let model = tract_tensorflow::tensorflow()
        .model_for_read(&mut Cursor::new(MODEL_BYTES))?
        .with_input_fact(0, InferenceFact::dt_shape(f32::datum_type(), tvec!(1, 224, 224, 3)))?
        .into_optimized()?
        .into_runnable()?;

    // Run inference
    let input = tract_ndarray::Array4::from_shape_vec((1, 224, 224, 3), input)?.into_tensor();
    let result = model.run(tvec!(input.into()))?;

    let output_tensor = &result[0];
    let array_view = output_tensor.to_array_view::<f32>()?;
    let best = array_view
        .iter()
        .enumerate()
        .max_by(|a, b| a.1.partial_cmp(b.1).unwrap())
        .unwrap();

    let labels: Vec<String> = LABELS.lines().map(String::from).collect();
    Ok(serde_json::json!({
        "label": labels[best.0],
        "confidence": best.1
    }))
}
