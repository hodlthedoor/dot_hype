#!/bin/bash

# Create test-svg directory if it doesn't exist
mkdir -p scripts/test-svg

# Run the Foundry script and capture output
echo "Running Foundry script to generate SVGs..."
forge script script/GenerateSVG.s.sol --via-ir > scripts/svg_output.log 2>&1

# Check if the script ran successfully
if [ $? -ne 0 ]; then
    echo "Error: Foundry script failed to run"
    cat scripts/svg_output.log
    exit 1
fi

echo "Extracting SVGs from output..."

# Parse the output and extract SVGs
awk '
BEGIN { 
    in_svg = 0
    filename = ""
}
/=== SVG START ===/ { 
    in_svg = 1
    next
}
/FILENAME:/ { 
    if (in_svg) {
        filename = $2
        next
    }
}
/CONTENT:/ { 
    if (in_svg) {
        next
    }
}
/=== SVG END ===/ { 
    in_svg = 0
    filename = ""
    next
}
{
    if (in_svg && filename != "" && $0 != "CONTENT:") {
        print $0 > ("scripts/test-svg/" filename)
    }
}
' scripts/svg_output.log

# Clean up temporary log file
rm scripts/svg_output.log

echo "SVGs generated successfully in scripts/test-svg/"
ls -la scripts/test-svg/

echo ""
echo "Generated files:"
for file in scripts/test-svg/*.svg; do
    if [ -f "$file" ]; then
        echo "✓ $(basename "$file")"
        # Show first few lines to verify content
        echo "  Preview: $(head -n 1 "$file" | cut -c1-80)..."
    fi
done 