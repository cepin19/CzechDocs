#!/bin/bash
set -euo pipefail

# Split Curated dataset into validation and test sets
# Validation: 20 randomly selected HTML documents (fixed IDs below)
# Test: All remaining documents (HTML, DOCX, PDF)

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}"

# Output directories
VALID_DIR="Curated_valid"
TEST_DIR="Curated_test"

# Fixed validation set: 20 randomly selected HTML document IDs
# Selected randomly on 2025-10-22, now fixed for reproducibility
VALID_HTML_IDS=(
    "html_12"
    "html_13"
    "html_18"
    "html_19"
    "html_2"
    "html_21"
    "html_25"
    "html_26"
    "html_28"
    "html_43"
    "html_45"
    "html_46"
    "html_47"
    "html_49"
    "html_57"
    "html_59"
    "html_62"
    "html_65"
    "html_70"
    "html_76"
)

echo "======================================================================="
echo "DATASET SPLIT: VALIDATION / TEST"
echo "======================================================================="
echo ""
echo "Creating validation and test sets from Curated/"
echo ""
echo "Validation set: ${#VALID_HTML_IDS[@]} HTML documents (fixed selection)"
echo "Test set: All remaining documents (HTML, DOCX, PDF)"
echo ""

# Clean and create output directories
rm -rf "${VALID_DIR}" "${TEST_DIR}"
mkdir -p "${VALID_DIR}/data" "${TEST_DIR}/data"

# Copy directory structure
for subdir in html docx pdf mos plaintext xliff; do
    mkdir -p "${VALID_DIR}/data/${subdir}" "${TEST_DIR}/data/${subdir}"
done

# Copy scripts directory
if [ -d "Curated/scripts" ]; then
    cp -r "Curated/scripts" "${VALID_DIR}/"
    cp -r "Curated/scripts" "${TEST_DIR}/"
fi

# Counters
valid_html=0
valid_total_files=0
test_html=0
test_docx=0
test_pdf=0
test_total_files=0

echo "======================================================================="
echo "STEP 1: Processing HTML documents"
echo "======================================================================="
echo ""

# Process all HTML documents
for html_doc in Curated/data/html/html_*; do
    if [ ! -d "${html_doc}" ]; then
        continue
    fi
    
    doc_id=$(basename "${html_doc}")
    
    # Check if this document is in the validation set
    is_valid=false
    for valid_id in "${VALID_HTML_IDS[@]}"; do
        if [ "${doc_id}" = "${valid_id}" ]; then
            is_valid=true
            break
        fi
    done
    
    if [ "${is_valid}" = true ]; then
        # Copy to validation set
        echo "  ✓ VALID: ${doc_id}"
        cp -r "${html_doc}" "${VALID_DIR}/data/html/"
        
        # Copy corresponding MOS files
        if [ -d "Curated/data/mos/${doc_id}" ]; then
            cp -r "Curated/data/mos/${doc_id}" "${VALID_DIR}/data/mos/"
        fi
        
        # Copy corresponding plaintext files
        if [ -d "Curated/data/plaintext/${doc_id}" ]; then
            cp -r "Curated/data/plaintext/${doc_id}" "${VALID_DIR}/data/plaintext/"
        fi
        
        # Copy corresponding XLIFF files
        if [ -d "Curated/data/xliff/${doc_id}" ]; then
            cp -r "Curated/data/xliff/${doc_id}" "${VALID_DIR}/data/xliff/"
        fi
        
        ((valid_html++))
    else
        # Copy to test set
        echo "  → TEST: ${doc_id}"
        cp -r "${html_doc}" "${TEST_DIR}/data/html/"
        
        # Copy corresponding MOS files
        if [ -d "Curated/data/mos/${doc_id}" ]; then
            cp -r "Curated/data/mos/${doc_id}" "${TEST_DIR}/data/mos/"
        fi
        
        # Copy corresponding plaintext files
        if [ -d "Curated/data/plaintext/${doc_id}" ]; then
            cp -r "Curated/data/plaintext/${doc_id}" "${TEST_DIR}/data/plaintext/"
        fi
        
        # Copy corresponding XLIFF files
        if [ -d "Curated/data/xliff/${doc_id}" ]; then
            cp -r "Curated/data/xliff/${doc_id}" "${TEST_DIR}/data/xliff/"
        fi
        
        ((test_html++))
    fi
done

echo ""
echo "======================================================================="
echo "STEP 2: Processing DOCX documents (all go to TEST)"
echo "======================================================================="
echo ""

# All DOCX documents go to test set
for docx_doc in Curated/data/docx/docx_*; do
    if [ ! -d "${docx_doc}" ]; then
        continue
    fi
    
    doc_id=$(basename "${docx_doc}")
    echo "  → TEST: ${doc_id}"
    
    cp -r "${docx_doc}" "${TEST_DIR}/data/docx/"
    
    # Copy corresponding files
    if [ -d "Curated/data/mos/${doc_id}" ]; then
        cp -r "Curated/data/mos/${doc_id}" "${TEST_DIR}/data/mos/"
    fi
    if [ -d "Curated/data/plaintext/${doc_id}" ]; then
        cp -r "Curated/data/plaintext/${doc_id}" "${TEST_DIR}/data/plaintext/"
    fi
    if [ -d "Curated/data/xliff/${doc_id}" ]; then
        cp -r "Curated/data/xliff/${doc_id}" "${TEST_DIR}/data/xliff/"
    fi
    
    ((test_docx++))
done

echo ""
echo "======================================================================="
echo "STEP 3: Processing PDF documents (all go to TEST)"
echo "======================================================================="
echo ""

# All PDF documents go to test set
for pdf_doc in Curated/data/pdf/pdf_*; do
    if [ ! -d "${pdf_doc}" ]; then
        continue
    fi
    
    doc_id=$(basename "${pdf_doc}")
    echo "  → TEST: ${doc_id}"
    
    cp -r "${pdf_doc}" "${TEST_DIR}/data/pdf/"
    
    # Copy corresponding plaintext files
    if [ -d "Curated/data/plaintext/${doc_id}" ]; then
        cp -r "Curated/data/plaintext/${doc_id}" "${TEST_DIR}/data/plaintext/"
    fi
    
    ((test_pdf++))
done

echo ""
echo "======================================================================="
echo "SPLIT COMPLETE"
echo "======================================================================="
echo ""
echo "VALIDATION SET (${VALID_DIR}):"
echo "  HTML documents:     ${valid_html}"
echo "  Total documents:    ${valid_html}"
echo ""
echo "TEST SET (${TEST_DIR}):"
echo "  HTML documents:     ${test_html}"
echo "  DOCX documents:     ${test_docx}"
echo "  PDF documents:      ${test_pdf}"
echo "  Total documents:    $((test_html + test_docx + test_pdf))"
echo ""
echo "Output directories created:"
echo "  - ${VALID_DIR}/data/"
echo "  - ${TEST_DIR}/data/"
echo ""

# Generate statistics for each set
echo "Generating statistics for validation set..."
if [ -d "${VALID_DIR}" ]; then
    python count_curated_stats.py --curated-dir "${VALID_DIR}" \
           --output-json "${VALID_DIR}_stats.json" \
           --output-latex "${VALID_DIR}_stats.tex" \
           --output-md "${VALID_DIR}_stats.md" 2>/dev/null || echo "  (statistics generation skipped)"
fi

echo "Generating statistics for test set..."
if [ -d "${TEST_DIR}" ]; then
    python count_curated_stats.py --curated-dir "${TEST_DIR}" \
           --output-json "${TEST_DIR}_stats.json" \
           --output-latex "${TEST_DIR}_stats.tex" \
           --output-md "${TEST_DIR}_stats.md" 2>/dev/null || echo "  (statistics generation skipped)"
fi

echo ""
echo "======================================================================="
echo "✅ DATASET SPLIT COMPLETE"
echo "======================================================================="
echo ""
echo "Validation set:"
echo "  - 20 HTML documents (randomly selected, fixed for reproducibility)"
echo "  - Location: ${VALID_DIR}/"
echo "  - Statistics: ${VALID_DIR}_stats.md"
echo ""
echo "Test set:"
echo "  - Remaining HTML documents (~34)"
echo "  - All DOCX documents (5)"
echo "  - All PDF documents (19)"
echo "  - Location: ${TEST_DIR}/"
echo "  - Statistics: ${TEST_DIR}_stats.md"
echo ""
echo "The validation set IDs are fixed in this script for reproducibility."
echo "To regenerate with different random selection, modify the VALID_HTML_IDS array."
echo ""

