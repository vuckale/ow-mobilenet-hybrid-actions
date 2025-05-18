#!/bin/sh

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <image_path>" >&2
  exit 1
fi

IMAGE_PATH="$1"

if [ ! -f "$IMAGE_PATH" ]; then
  echo "Error: File '$IMAGE_PATH' not found." >&2
  exit 1
fi

# Get the filename without extension
BASENAME=$(basename "$IMAGE_PATH")
FILENAME="${BASENAME%.*}"

# Output JSON file path
OUTPUT_FILE="../inputs/${FILENAME}.json"

# Encode image to base64 (no line wrapping)
BASE64_DATA=$(base64 -w 0 "$IMAGE_PATH")

# Write JSON to file
printf '{ "image": "%s" }\n' "$BASE64_DATA" > "$OUTPUT_FILE"

echo "Saved JSON to: $OUTPUT_FILE"
