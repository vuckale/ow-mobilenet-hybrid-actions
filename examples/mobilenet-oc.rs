use image::io::Reader as ImageReader;
use tract_tensorflow::prelude::*;
use std::error::Error;
use std::io::Cursor;
use base64;

// Include model and labels at compile time
const MODEL_BYTES: &[u8] = include_bytes!("mobilenet_v2_1.4_224_frozen.pb");
const LABELS: &str = include_str!("mobilenet_labels.txt");

#[cfg(feature = "wasm")]
ow_wasm_action_mobilenet_oc::pass_json!(func);
#[cfg(not(feature = "wasm"))]
ow_wasm_action_mobilenet_oc::json_args!(func);
fn func(json: serde_json::Value) -> Result<serde_json::Value, anyhow::Error> {
    // Get base64 image data from input parameter
    let image_base64 = json
        .get("image")
        .ok_or_else(|| anyhow::anyhow!("Expected 'image' parameter with base64 data"))?
        .as_str()
        .ok_or_else(|| anyhow::anyhow!("Expected 'image' to be a string"))?;

    // Decode base64 to bytes
    let image_bytes = base64::decode(image_base64)
        .map_err(|e| anyhow::anyhow!("Failed to decode base64 image: {}", e))?;

    // Load the pre-trained MobileNet model from embedded bytes
    let model = tract_tensorflow::tensorflow()
        .model_for_read(&mut Cursor::new(MODEL_BYTES))?
        .with_input_fact(0, InferenceFact::dt_shape(f32::datum_type(), tvec!(1, 224, 224, 3)))?
        .into_optimized()?
        .into_runnable()?;

    // Load and preprocess the image from decoded bytes
    let img = image::load_from_memory(&image_bytes)?;
    let resized = img.resize_exact(224, 224, image::imageops::FilterType::Triangle);
    
    // Convert image to RGB float tensor
    let mut input = Vec::new();
    for pixel in resized.to_rgb8().pixels() {
        input.push(pixel[0] as f32 / 255.0);
        input.push(pixel[1] as f32 / 255.0);
        input.push(pixel[2] as f32 / 255.0);
    }

    // Create tensor from input data
    let input = tract_ndarray::Array4::from_shape_vec((1, 224, 224, 3), input)?;
    let input = input.into_tensor();
    // Convert tensor to TValue before running
    let input = input.into();
    
    // Run inference
    let result = model.run(tvec!(input))?;
    
    // Get the top prediction
    let output_tensor = &result[0];
    let array_view = output_tensor.to_array_view::<f32>()?;
    let best = array_view
        .iter()
        .enumerate()
        .max_by(|a, b| a.1.partial_cmp(b.1).unwrap())
        .unwrap();

    // Parse labels from embedded string
    let labels: Vec<String> = LABELS.lines().map(String::from).collect();

    // Return both the label and confidence score
    Ok(serde_json::json!({
        "label": labels[best.0],
        "confidence": best.1
    }))
}
