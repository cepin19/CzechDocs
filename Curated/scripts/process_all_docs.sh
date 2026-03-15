#!/bin/bash
set -euo pipefail

# Enhanced script to process HTML and DOCX files from data/ directory
# Creates MOS (segmented) and XLIFF files for evaluation
# Handles Okapi Tikal extraction for all supported formats

# --- CONFIGURATION ---
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}"

# File extensions to process (Okapi Tikal supports all these)
FILE_EXTENSIONS=("html" "docx" "doc")

# Moses and m4loc paths  
moses=../../moses-scripts/
m4loc=../../m4loc

# Directories (now unified under data/)
HTML_DIR="../data/html"
DOCX_DIR="../data/docx"
MOS_DIR="../data/mos"
XLIFF_DIR="../data/xliff"

# Processing options
DRY_RUN=false
SKIP_EXISTING=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            SKIP_EXISTING=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--force]"
            exit 1
            ;;
    esac
done

# Counters for statistics
total_processed=0
total_skipped=0
total_errors=0

echo "======================================================================="
echo "DOCUMENT PROCESSING SCRIPT"
echo "======================================================================="
echo "Processing HTML and DOCX files from data/ directory to MOS and XLIFF formats"
if [ "$DRY_RUN" = true ]; then
    echo "⚠️  DRY RUN MODE - No files will be modified"
fi
echo ""

# Setup output directories
if [ "$DRY_RUN" = false ]; then
    mkdir -p "${MOS_DIR}" "${XLIFF_DIR}"
fi

# --- PROCESS EACH FILE TYPE ---
for ext in "${FILE_EXTENSIONS[@]}"; do
    echo ""
    echo "======================================================================="
    echo "Processing *.${ext} files"
    echo "======================================================================="
    
    # Determine source directory
    if [ "${ext}" = "html" ]; then
        SOURCE_DIR="${HTML_DIR}"
    else
        SOURCE_DIR="${DOCX_DIR}"
    fi
    
    if [ ! -d "${SOURCE_DIR}" ]; then
        echo "⚠️  Skipping ${ext} - directory ${SOURCE_DIR} not found"
        continue
    fi
    
    # Find all files with this extension
    file_count=$(find "${SOURCE_DIR}" -type f -name "*.${ext}" 2>/dev/null | wc -l)
    echo "Found ${file_count} *.${ext} files"
    
    if [ "${file_count}" -eq 0 ]; then
        continue
    fi
    
    find "${SOURCE_DIR}" -type f -name "*.${ext}" 2>/dev/null | sort | while read -r input_file; do
            # Compute relative path and extract components
            # Path pattern: ../data/html/NUMBER/LANG/file.html
            rel_path="${input_file#${SOURCE_DIR}/}"
            
            base_dir_path="$(dirname "${rel_path}")"     # e.g. "10/cs"
            file_name="$(basename "${rel_path}")"        # e.g. "Dobrovolnictví.html"
            base_name="${file_name%.*}"                  # Remove extension
            lang="${base_dir_path##*/}"                  # Extract language code
            
            # Create output directories
            out_mos_dir="${MOS_DIR}/${base_dir_path}"
            out_xlf_dir="${XLIFF_DIR}/${base_dir_path}"
            mkdir -p "${out_mos_dir}" "${out_xlf_dir}"
            
            # Output file paths
            mos_output="${out_mos_dir}/${base_name}.mos"
            mos_lang_output="${out_mos_dir}/${base_name}.mos.${lang}"
            mos_spaces_output="${mos_lang_output}.spaces"
            
            # Skip if already processed (unless --force)
            if [ "$SKIP_EXISTING" = true ]; then
                if [ -f "${mos_output}" ] || [ -f "${mos_lang_output}" ]; then
                    echo "  ⏭️  Skipping ${input_file} (already exists)"
                    ((total_skipped++)) || true
                    continue
                fi
            fi
            
            # Check if language code looks valid
            if [ "${#lang}" -gt 3 ]; then
                echo "  ⚠️  Warning: Unusual language code '${lang}' for ${input_file}"
            fi
            
            echo "  📄 Processing ${input_file}"
            echo "     Language: ${lang}"
            echo "     → MOS: ${mos_output}"
            echo "     → XLIFF: ${out_xlf_dir}/"
            
            if [ "$DRY_RUN" = true ]; then
                echo "     [DRY RUN] Would process this file"
                ((total_processed++)) || true
                continue
            fi
            
            # Process with Tikal (-xm for segmentation)
            if ../../tikal.sh -xm "${input_file}" -sl "${lang}" -tl "${lang}" -ie utf8 -oe utf8 -seg ../../config/defaultSegmentation.srx -to "${out_mos_dir}/${base_name}.mos" 2>&1 | grep -q -v "DONE"; then
                # Extract to XLIFF as well (-x for XLIFF extraction)
                ../../tikal.sh -x "${input_file}" -sl "${lang}" -od "${out_xlf_dir}" 2>/dev/null || echo "     ⚠️  XLIFF extraction failed (non-critical)"
                
                # Check if MOS file was created
                if [ -f "${mos_lang_output}" ]; then
                    # Normalize spaces
                    if perl -CSDA -plE 's/[^\S\t]/ /g' "${mos_lang_output}" > "${mos_spaces_output}" 2>/dev/null; then
                        # Rename to standard .mos extension
                        mv "${mos_lang_output}" "${mos_output}"
                        echo "     ✅ Success: ${mos_output}"
                        
                        # Show segment count
                        seg_count=$(wc -l < "${mos_output}")
                        echo "        Segments: ${seg_count}"
                        ((total_processed++)) || true
                    else
                        echo "     ⚠️  Warning: Space normalization failed"
                        mv "${mos_lang_output}" "${mos_output}"
                        ((total_processed++)) || true
                    fi
                else
                    echo "     ❌ Error: MOS file not created (${mos_lang_output})"
                    ((total_errors++)) || true
                fi
            else
                echo "     ❌ Error: Tikal processing failed for ${input_file}"
                ((total_errors++)) || true
            fi
        done
done

# --- SUMMARY ---
echo ""
echo "======================================================================="
echo "PROCESSING COMPLETE"
echo "======================================================================="
echo "  ✅ Successfully processed: ${total_processed} files"
echo "  ⏭️  Skipped (already done): ${total_skipped} files"
echo "  ❌ Errors encountered:     ${total_errors} files"
echo ""
echo "Output directories:"
if [ -d "${MOS_DIR}" ]; then
    mos_count=$(find "${MOS_DIR}" -name "*.mos" 2>/dev/null | wc -l)
    echo "  - data/mos/:    ${mos_count} MOS files"
fi
if [ -d "${XLIFF_DIR}" ]; then
    xlf_count=$(find "${XLIFF_DIR}" -name "*.xlf" 2>/dev/null | wc -l)
    echo "  - data/xliff/:  ${xlf_count} XLIFF files"
fi
echo ""
echo "Run dataset statistics to see updated counts:"
echo "  python ../../count_curated_stats.py"
echo ""

