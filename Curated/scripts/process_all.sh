#!/bin/bash
set -euo pipefail

# Unified script to process all source documents (HTML, DOCX, PDF)
# Creates XLIFF, MOS (with tags), and plaintext (without tags) versions

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}"

# --- CONFIGURATION ---
HTML_DIR="../data/html"
DOCX_DIR="../data/docx"
PDF_DIR="../data/pdf"
DOCX_FROM_PDF_DIR="../data/docx_from_pdf"
MOS_DIR="../data/mos"
PLAINTEXT_DIR="../data/plaintext"
XLIFF_DIR="../data/xliff"

# Processing options
DRY_RUN=false
SKIP_EXISTING=true
VERBOSE=false

# Parse arguments
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
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--force] [--verbose]"
            exit 1
            ;;
    esac
done

# Counters
total_html_processed=0
total_docx_processed=0
total_pdf_processed=0
total_skipped=0
total_errors=0
total_xliff=0
total_mos=0
total_plaintext=0

echo "======================================================================="
echo "UNIFIED DOCUMENT PROCESSING SCRIPT"
echo "======================================================================="
echo "Processing all source documents to XLIFF, MOS, and plaintext formats"
if [ "$DRY_RUN" = true ]; then
    echo "⚠️  DRY RUN MODE - No files will be created"
fi
echo ""

# Create output directories
if [ "$DRY_RUN" = false ]; then
    mkdir -p "${MOS_DIR}" "${PLAINTEXT_DIR}" "${XLIFF_DIR}" "${DOCX_FROM_PDF_DIR}"
fi

# ============================================================================
# PROCESS HTML FILES
# ============================================================================
echo "======================================================================="
echo "STEP 1: Processing HTML files"
echo "======================================================================="
echo ""

if [ -d "${HTML_DIR}" ]; then
    html_count=$(find "${HTML_DIR}" -name "*.html" | wc -l)
    echo "Found ${html_count} HTML files"
    echo ""
    
    find "${HTML_DIR}" -name "*.html" | sort | while read -r html_file; do
        # Extract path components
        # Pattern: ../data/html/html_NUMBER/LANG/filename.html
        rel_path="${html_file#${HTML_DIR}/}"
        doc_id=$(echo "${rel_path}" | cut -d'/' -f1)     # e.g. "html_10"
        lang=$(echo "${rel_path}" | cut -d'/' -f2)       # e.g. "cs"
        filename=$(basename "${html_file}" .html)
        
        # Output paths
        mos_file="${MOS_DIR}/${doc_id}/${lang}/${filename}.mos"
        plaintext_file="${PLAINTEXT_DIR}/${doc_id}/${lang}/${filename}.txt"
        xliff_dir="${XLIFF_DIR}/${doc_id}/${lang}"
        
        # Skip if all outputs exist
        if [ "$SKIP_EXISTING" = true ]; then
            if [ -f "${mos_file}" ] && [ -f "${plaintext_file}" ]; then
                [ "$VERBOSE" = true ] && echo "  ⏭️  Skipping ${doc_id}/${lang}/${filename}"
                ((total_skipped++)) || true
                continue
            fi
        fi
        
        echo "  📄 ${doc_id}/${lang}/${filename}"
        
        if [ "$DRY_RUN" = true ]; then
            echo "     [DRY RUN] Would process"
            ((total_html_processed++)) || true
            continue
        fi
        
        # Create output directories
        mkdir -p "$(dirname "${mos_file}")" "$(dirname "${plaintext_file}")" "${xliff_dir}"
        
        # Step 1: Extract to MOS with XLIFF tags
        if ../../tikal.sh -xm "${html_file}" -sl "${lang}" -tl "${lang}" \
                -ie utf8 -oe utf8 -seg ../../config/defaultSegmentation.srx \
                -to "${MOS_DIR}/${doc_id}/${lang}/${filename}.mos" \
                2>/dev/null; then
            
            # Normalize spaces and rename
            if [ -f "${MOS_DIR}/${doc_id}/${lang}/${filename}.mos.${lang}" ]; then
                perl -CSDA -plE 's/[^\S\t]/ /g' \
                    "${MOS_DIR}/${doc_id}/${lang}/${filename}.mos.${lang}" \
                    > "${MOS_DIR}/${doc_id}/${lang}/${filename}.mos.${lang}.spaces" 2>/dev/null || true
                mv "${MOS_DIR}/${doc_id}/${lang}/${filename}.mos.${lang}" "${mos_file}"
                [ "$VERBOSE" = true ] && echo "     ✓ MOS created"
                ((total_mos++)) || true
            fi
        else
            echo "     ⚠️  MOS extraction failed"
        fi
        
        # Step 2: Extract to XLIFF
        if ../../tikal.sh -x "${html_file}" -sl "${lang}" -od "${xliff_dir}" 2>/dev/null; then
            [ "$VERBOSE" = true ] && echo "     ✓ XLIFF created"
            ((total_xliff++)) || true
        fi
        
        # Step 3: Convert MOS to plaintext
        if [ -f "${mos_file}" ]; then
            if python3 ../../remove_tags.py "${mos_file}" "${plaintext_file}" --decode-entities 2>/dev/null; then
                [ "$VERBOSE" = true ] && echo "     ✓ Plaintext created"
                ((total_plaintext++)) || true
            fi
        fi
        
        ((total_html_processed++)) || true
    done
else
    echo "⚠️  HTML directory not found: ${HTML_DIR}"
fi

echo ""

# ============================================================================
# PROCESS DOCX FILES
# ============================================================================
echo "======================================================================="
echo "STEP 2: Processing DOCX files"
echo "======================================================================="
echo ""

if [ -d "${DOCX_DIR}" ]; then
    docx_count=$(find "${DOCX_DIR}" -name "*.docx" -o -name "*.doc" | wc -l)
    echo "Found ${docx_count} DOCX/DOC files"
    echo ""
    
    find "${DOCX_DIR}" -name "*.docx" -o -name "*.doc" | sort | while read -r docx_file; do
        # Extract path components
        # Pattern: ../data/docx/docx_NUMBER/LANG/filename.docx
        rel_path="${docx_file#${DOCX_DIR}/}"
        doc_id=$(echo "${rel_path}" | cut -d'/' -f1)     # e.g. "docx_1"
        lang=$(echo "${rel_path}" | cut -d'/' -f2)       # e.g. "cs"
        filename=$(basename "${docx_file}")
        basename_noext="${filename%.*}"
        
        # Output paths
        mos_file="${MOS_DIR}/${doc_id}/${lang}/${basename_noext}.mos"
        plaintext_file="${PLAINTEXT_DIR}/${doc_id}/${lang}/${basename_noext}.txt"
        xliff_dir="${XLIFF_DIR}/${doc_id}/${lang}"
        
        # Skip if all outputs exist
        if [ "$SKIP_EXISTING" = true ]; then
            if [ -f "${mos_file}" ] && [ -f "${plaintext_file}" ]; then
                [ "$VERBOSE" = true ] && echo "  ⏭️  Skipping ${doc_id}/${lang}/${basename_noext}"
                ((total_skipped++)) || true
                continue
            fi
        fi
        
        echo "  📄 ${doc_id}/${lang}/${basename_noext}"
        
        if [ "$DRY_RUN" = true ]; then
            echo "     [DRY RUN] Would process"
            ((total_docx_processed++)) || true
            continue
        fi
        
        # Create output directories
        mkdir -p "$(dirname "${mos_file}")" "$(dirname "${plaintext_file}")" "${xliff_dir}"
        
        # Step 1: Extract to MOS with XLIFF tags
        if ../../tikal.sh -xm "${docx_file}" -sl "${lang}" -tl "${lang}" \
                -ie utf8 -oe utf8 -seg ../../config/defaultSegmentation.srx \
                -to "${MOS_DIR}/${doc_id}/${lang}/${basename_noext}.mos" \
                2>/dev/null; then
            
            # Normalize spaces and rename
            if [ -f "${MOS_DIR}/${doc_id}/${lang}/${basename_noext}.mos.${lang}" ]; then
                perl -CSDA -plE 's/[^\S\t]/ /g' \
                    "${MOS_DIR}/${doc_id}/${lang}/${basename_noext}.mos.${lang}" \
                    > "${MOS_DIR}/${doc_id}/${lang}/${basename_noext}.mos.${lang}.spaces" 2>/dev/null || true
                mv "${MOS_DIR}/${doc_id}/${lang}/${basename_noext}.mos.${lang}" "${mos_file}"
                [ "$VERBOSE" = true ] && echo "     ✓ MOS created"
                ((total_mos++)) || true
            fi
        else
            echo "     ⚠️  MOS extraction failed"
        fi
        
        # Step 2: Extract to XLIFF
        if ../../tikal.sh -x "${docx_file}" -sl "${lang}" -od "${xliff_dir}" 2>/dev/null; then
            [ "$VERBOSE" = true ] && echo "     ✓ XLIFF created"
            ((total_xliff++)) || true
        fi
        
        # Step 3: Convert MOS to plaintext
        if [ -f "${mos_file}" ]; then
            if python3 ../../remove_tags.py "${mos_file}" "${plaintext_file}" --decode-entities 2>/dev/null; then
                [ "$VERBOSE" = true ] && echo "     ✓ Plaintext created"
                ((total_plaintext++)) || true
            fi
        fi
        
        ((total_docx_processed++)) || true
    done
else
    echo "⚠️  DOCX directory not found: ${DOCX_DIR}"
fi

echo ""

# ============================================================================
# PROCESS PDF FILES (via DOCX → MOS pipeline)
# ============================================================================
echo "======================================================================="
echo "STEP 3: Processing PDF files (via PDF→DOCX→MOS)"
echo "======================================================================="
echo ""

if [ -d "${PDF_DIR}" ]; then
    pdf_count=$(find "${PDF_DIR}" -name "*.pdf" | wc -l)
    echo "Found ${pdf_count} PDF files"
    echo "Using pdf2docx pipeline for XLIFF tag generation"
    echo ""
    
    find "${PDF_DIR}" -name "*.pdf" | sort | while read -r pdf_file; do
        # Extract path components
        # Pattern: ../data/pdf/pdf_NUMBER/LANG/filename.pdf
        rel_path="${pdf_file#${PDF_DIR}/}"
        doc_id=$(echo "${rel_path}" | cut -d'/' -f1)     # e.g. "pdf_8"
        lang=$(echo "${rel_path}" | cut -d'/' -f2)       # e.g. "cs"
        filename=$(basename "${pdf_file}" .pdf)
        
        # Output paths (now same as HTML/DOCX)
        mos_file="${MOS_DIR}/${doc_id}/${lang}/${filename}.mos"
        plaintext_file="${PLAINTEXT_DIR}/${doc_id}/${lang}/${filename}.txt"
        docx_file="${DOCX_FROM_PDF_DIR}/${doc_id}/${lang}/${filename}.docx"
        xliff_dir="${XLIFF_DIR}/${doc_id}/${lang}"
        
        # Skip if all outputs exist
        if [ "$SKIP_EXISTING" = true ]; then
            if [ -f "${mos_file}" ] && [ -f "${plaintext_file}" ] && [ -f "${docx_file}" ]; then
                [ "$VERBOSE" = true ] && echo "  ⏭️  Skipping ${doc_id}/${lang}/${filename}"
                ((total_skipped++)) || true
                continue
            fi
        fi
        
        echo "  📄 ${doc_id}/${lang}/${filename}"
        
        if [ "$DRY_RUN" = true ]; then
            echo "     [DRY RUN] Would process via DOCX"
            ((total_pdf_processed++)) || true
            continue
        fi
        
        # Create output directories
        mkdir -p "$(dirname "${mos_file}")" "$(dirname "${plaintext_file}")" "$(dirname "${docx_file}")" "${xliff_dir}"
        
        # Step 1: Convert PDF→DOCX→MOS using new pipeline (with --keep-docx)
        if python3 pdf_to_mos_via_docx.py "${pdf_file}" "${mos_file}" --lang "${lang}" --keep-docx 2>&1 | grep -q "CONVERSION COMPLETE"; then
            [ "$VERBOSE" = true ] && echo "     ✓ MOS created (with tags)"
            ((total_mos++)) || true
            
            # Step 2: Move intermediate DOCX to docx_from_pdf directory
            # pdf_to_mos_via_docx.py creates DOCX in same dir as MOS with .docx extension
            temp_docx="${mos_file%.*}.docx"
            if [ -f "${temp_docx}" ]; then
                mv "${temp_docx}" "${docx_file}"
                [ "$VERBOSE" = true ] && echo "     ✓ Intermediate DOCX saved"
            fi
            
            # Step 3: Convert MOS to plaintext (remove tags)
            if [ -f "${mos_file}" ]; then
                if python3 ../../remove_tags.py "${mos_file}" "${plaintext_file}" --decode-entities 2>/dev/null; then
                    [ "$VERBOSE" = true ] && echo "     ✓ Plaintext created"
                    ((total_plaintext++)) || true
                fi
            fi
            
            ((total_pdf_processed++)) || true
        else
            echo "     ⚠️  PDF→MOS conversion failed, trying direct extraction..."
            
            # Fallback to direct text extraction
            if python3 pdf_to_mos.py "${pdf_file}" "${plaintext_file}" --lang "${lang}" 2>&1 | grep -q "Extracted"; then
                [ "$VERBOSE" = true ] && echo "     ✓ Plaintext extracted (fallback)"
                ((total_plaintext++)) || true
                ((total_pdf_processed++)) || true
            else
                echo "     ❌ All PDF extraction methods failed"
                ((total_errors++)) || true
            fi
        fi
    done
else
    echo "⚠️  PDF directory not found: ${PDF_DIR}"
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo "======================================================================="
echo "PROCESSING COMPLETE"
echo "======================================================================="
echo ""
echo "Files processed:"
echo "  ✅ HTML files:     ${total_html_processed}"
echo "  ✅ DOCX files:     ${total_docx_processed}"
echo "  ✅ PDF files:      ${total_pdf_processed}"
echo "  ⏭️  Skipped:       ${total_skipped}"
echo "  ❌ Errors:         ${total_errors}"
echo ""
echo "Outputs created:"
echo "  📝 XLIFF files:    ${total_xliff} (HTML/DOCX)"
echo "  🏷️  MOS files:      ${total_mos} (HTML/DOCX/PDF with XLIFF tags)"
echo "  📄 Plaintext files: ${total_plaintext} (all sources, no tags)"
echo ""
echo "Output locations:"
echo "  - ${XLIFF_DIR}        (for CAT tools - HTML/DOCX)"
echo "  - ${MOS_DIR}          (with XLIFF tags for tag-aware evaluation - all types)"
echo "  - ${PLAINTEXT_DIR}    (no tags for plain text evaluation - all types)"
echo "  - ${DOCX_FROM_PDF_DIR} (intermediate DOCX files from PDF conversion)"
echo ""

# Show file counts
if [ "$DRY_RUN" = false ]; then
    echo "File counts in directories:"
    [ -d "${MOS_DIR}" ] && echo "  MOS files:           $(find "${MOS_DIR}" -name "*.mos" 2>/dev/null | wc -l)"
    [ -d "${PLAINTEXT_DIR}" ] && echo "  Plaintext files:     $(find "${PLAINTEXT_DIR}" -name "*.txt" 2>/dev/null | wc -l)"
    [ -d "${XLIFF_DIR}" ] && echo "  XLIFF files:         $(find "${XLIFF_DIR}" -name "*.xlf" 2>/dev/null | wc -l)"
    [ -d "${DOCX_FROM_PDF_DIR}" ] && echo "  DOCX from PDF files: $(find "${DOCX_FROM_PDF_DIR}" -name "*.docx" 2>/dev/null | wc -l)"
    echo ""
fi

echo "Generate dataset statistics:"
echo "  cd ../.. && python count_curated_stats.py"
echo ""
echo "======================================================================="
echo "✅ All source documents processed!"
echo "======================================================================="
echo ""
echo "You now have:"
echo "  - XLIFF files (for CAT tools - HTML/DOCX)"
echo "  - MOS files with XLIFF tags (for tag-aware MT evaluation - ALL formats)"
echo "  - Plaintext files without tags (for plain text evaluation & tag cost analysis)"
echo "  - Intermediate DOCX files (from PDF conversion for reference/debugging)"
echo ""
echo "Note: PDFs use pdf2docx pipeline to preserve structure and generate tags"
echo "      Intermediate DOCX files are saved in docx_from_pdf/ directory"
echo ""

