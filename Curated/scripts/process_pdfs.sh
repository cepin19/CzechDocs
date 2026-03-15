#!/bin/bash
set -euo pipefail

# Process all PDFs in manual directory to MOS format
# Uses Python script for text extraction and segmentation

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}"

# Options
DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--force]"
            exit 1
            ;;
    esac
done

# Counters
total_processed=0
total_skipped=0
total_errors=0
total_segments=0

echo "======================================================================="
echo "PDF TO PLAINTEXT CONVERTER"
echo "======================================================================="
echo "Extracting text from PDFs and converting to plaintext format"
echo "(PDFs have no markup tags, so they go to plaintext/ not mos/)"
if [ "$DRY_RUN" = true ]; then
    echo "⚠️  DRY RUN MODE - No files will be created"
fi
echo ""

# Find all PDF files in data directory
pdf_count=$(find ../data/pdf -name "*.pdf" 2>/dev/null | wc -l)
echo "Found ${pdf_count} PDF files in data/pdf/"
echo ""

if [ "${pdf_count}" -eq 0 ]; then
    echo "No PDF files to process"
    exit 0
fi

# Process each PDF
find ../data/pdf -name "*.pdf" 2>/dev/null | sort | while read -r pdf_file; do
    # Extract components from path
    # Pattern: ../data/pdf/NUMBER/LANG/filename.pdf
    rel_path="${pdf_file#../data/pdf/}"
    base_dir="$(dirname "${rel_path}")"          # e.g. "10/cs"
    doc_id="$(echo "${base_dir}" | cut -d'/' -f1)"   # e.g. "10"
    lang="$(echo "${base_dir}" | cut -d'/' -f2)"     # e.g. "cs"
    filename="$(basename "${pdf_file}" .pdf)"
    
    # Output path - PDFs go to plaintext/ not mos/
    plaintext_dir="../data/plaintext/${doc_id}/${lang}"
    plaintext_file="${plaintext_dir}/${filename}.txt"
    
    # Skip if already exists (unless --force)
    if [ "$FORCE" = false ] && [ -f "${plaintext_file}" ]; then
        echo "  ⏭️  Skipping ${pdf_file} (already exists)"
        ((total_skipped++)) || true
        continue
    fi
    
    echo "  📄 Processing ${pdf_file}"
    echo "     Language: ${lang}"
    echo "     → Plaintext: ${plaintext_file}"
    
    if [ "$DRY_RUN" = true ]; then
        echo "     [DRY RUN] Would process this file"
        ((total_processed++)) || true
        continue
    fi
    
    # Create output directory
    mkdir -p "${plaintext_dir}"
    
    # Run Python script to extract and segment
    if python3 pdf_to_mos.py "${pdf_file}" "${plaintext_file}" --lang "${lang}" 2>&1; then
        if [ -f "${plaintext_file}" ]; then
            seg_count=$(wc -l < "${plaintext_file}")
            total_segments=$((total_segments + seg_count))
            echo "     ✅ Success: ${seg_count} segments"
            ((total_processed++)) || true
        else
            echo "     ❌ Error: Plaintext file not created"
            ((total_errors++)) || true
        fi
    else
        echo "     ❌ Error: PDF extraction failed"
        ((total_errors++)) || true
    fi
    echo ""
done

# Summary
echo "======================================================================="
echo "PROCESSING COMPLETE"
echo "======================================================================="
echo "  ✅ Successfully processed: ${total_processed} files"
echo "  📊 Total segments extracted: ${total_segments}"
echo "  ⏭️  Skipped (already done): ${total_skipped} files"
echo "  ❌ Errors encountered:     ${total_errors} files"
echo ""

if [ "${total_processed}" -gt 0 ]; then
    avg_segments=$((total_segments / total_processed))
    echo "  Average segments per PDF: ${avg_segments}"
    echo ""
    echo "Output directory: data/plaintext/"
    echo "Plaintext files created: ${total_processed}"
    echo ""
    echo "Note: PDF files are now in plaintext/ directory (no markup tags)"
    echo ""
    echo "Run dataset statistics to see updated counts:"
    echo "  cd ../.. && python count_curated_stats.py"
fi
echo ""

