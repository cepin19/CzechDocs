#!/bin/bash
set -euo pipefail

# Convert all MOS files (with tags) to plaintext (without tags)
# Also move PDF extractions from mos/ to plaintext/

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}"

echo "======================================================================="
echo "CONVERT TO PLAINTEXT"
echo "======================================================================="
echo "Creating plaintext versions of all MOS documents"
echo ""

# Counters
total_converted=0

MOS_DIR="../data/mos"
PLAINTEXT_DIR="../data/plaintext"

echo "Converting MOS files (HTML/DOCX with tags) to plaintext..."
echo ""

if [ ! -d "${MOS_DIR}" ]; then
    echo "ERROR: ${MOS_DIR} not found"
    exit 1
fi

# Create plaintext directory
mkdir -p "${PLAINTEXT_DIR}"

# Find all MOS files
find "${MOS_DIR}" -name "*.mos" | while read -r mos_file; do
    # Extract relative path
    rel_path="${mos_file#${MOS_DIR}/}"
    plaintext_file="${PLAINTEXT_DIR}/${rel_path%.mos}.txt"
    
    # Create output directory
    mkdir -p "$(dirname "${plaintext_file}")"
    
    # Convert using remove_tags.py
    if python3 ../../remove_tags.py "${mos_file}" "${plaintext_file}" --decode-entities 2>/dev/null; then
        echo "  ✓ Converted: ${rel_path}"
        ((total_converted++)) || true
    else
        echo "  ❌ Failed: ${rel_path}"
    fi
done

echo ""
echo "======================================================================="
echo "CONVERSION COMPLETE"
echo "======================================================================="
echo "  ✓ MOS files converted to plaintext: ${total_converted}"
echo ""
echo "Directory structure:"
echo "  - data/plaintext/  (plaintext versions, no tags)"
echo "  - data/mos/        (original with XLIFF tags)"
echo ""
echo "Run dataset statistics:"
echo "  cd ../.. && python count_curated_stats.py"
echo ""

