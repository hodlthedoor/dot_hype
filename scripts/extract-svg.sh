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

# Extract SVG content using a simpler approach
python3 -c "
import re
import sys

# Read the output file
with open('scripts/svg_output.log', 'r') as f:
    content = f.read()

# Find all SVG sections
pattern = r'=== SVG START ===\s*FILENAME:\s*(\S+)\s*CONTENT:\s*(.*?)=== SVG END ==='
matches = re.findall(pattern, content, re.DOTALL)

for filename, svg_content in matches:
    # Clean up the SVG content (remove line breaks and extra spaces)
    svg_content = re.sub(r'\s+', ' ', svg_content.strip())
    svg_content = svg_content.replace('> <', '><')
    
    # Write to file
    with open(f'scripts/test-svg/{filename}', 'w') as f:
        f.write(svg_content)
    
    print(f'✓ Generated: {filename}')
    print(f'  Size: {len(svg_content)} characters')
"

# Clean up temporary log file
rm scripts/svg_output.log

echo ""
echo "SVGs generated successfully in scripts/test-svg/"
ls -la scripts/test-svg/

echo ""
echo "Verification - First 100 characters of each file:"
for file in scripts/test-svg/*.svg; do
    if [ -f "$file" ]; then
        echo "$(basename "$file"): $(head -c 100 "$file")..."
    fi
done 