#!/usr/bin/env bash

INPUT_DIR="input_screenshots"
OUTPUT_BASE="resized_screenshots"

# Define device resolutions
# Format: device_name:portrait_resolution:landscape_resolution
DEVICES=(
    "iphone_6_5:1242x2688:2688x1242"
    "iphone_5_5:1242x2208:2208x1242"
    "ipad_11:1668x2388:2388x1668"
    "android_phone:1080x1920:1920x1080"
    "android_phablet:1242x2208:2208x1242"
    "macos:1280x800:1280x800"
)

# Create output directories
mkdir -p "$OUTPUT_BASE/ipad_12_9"
for device_info in "${DEVICES[@]}"; do
    device_name=$(echo "$device_info" | cut -d':' -f1)
    mkdir -p "$OUTPUT_BASE/$device_name"
done

index=1
for file in "$INPUT_DIR"/*.png; do
    echo "Processing: $file"

    # Get image dimensions
    dimensions=$(identify -format "%w %h" "$file")
    width=$(echo $dimensions | cut -d' ' -f1)
    height=$(echo $dimensions | cut -d' ' -f2)

    # Decide orientation
    if (( width > height )); then
        orientation="landscape"
    else
        orientation="portrait"
    fi

    echo "Detected $orientation ($width x $height)"

    # Copy original to iPad 12.9 folder
    cp "$file" "$OUTPUT_BASE/ipad_12_9/ipad_12_9_screenshot_${index}.png"

    for device_info in "${DEVICES[@]}"; do
        device_name=$(echo "$device_info" | cut -d':' -f1)
        portrait_res=$(echo "$device_info" | cut -d':' -f2)
        landscape_res=$(echo "$device_info" | cut -d':' -f3)

        if [[ "$orientation" == "portrait" ]]; then
            target_res="$portrait_res"
        else
            target_res="$landscape_res"
        fi

        output_file="$OUTPUT_BASE/$device_name/${device_name}_screenshot_${index}.png"
        magick "$file" -resize "$target_res" "$output_file"
        echo "✔️  $device_name -> $target_res"
    done

    echo "---"
    index=$((index+1))
done

echo "✅ All screenshots resized and saved in '$OUTPUT_BASE'"
