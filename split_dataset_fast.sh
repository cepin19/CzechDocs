#!/bin/bash
set -euo pipefail

# Fast dataset split using rsync and include/exclude patterns

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
echo "Validation set: ${#VALID_HTML_IDS[@]} HTML documents"
echo "Test set: All remaining documents"
echo ""

# Clean existing
rm -rf "${VALID_DIR}" "${TEST_DIR}"

# Create base structure
mkdir -p "${VALID_DIR}/data/"{html,docx,pdf,mos,plaintext,xliff}
mkdir -p "${TEST_DIR}/data/"{html,docx,pdf,mos,plaintext,xliff}

echo "Validation IDs: ${VALID_HTML_IDS[@]}"
echo ""

# Counters
valid_count=0
test_html_count=0

echo "Splitting HTML documents..."

# Process validation set
for doc_id in "${VALID_HTML_IDS[@]}"; do
    if [ -d "Curated/data/html/${doc_id}" ]; then
        echo "  ✓ VALID: ${doc_id}"
        cp -r "Curated/data/html/${doc_id}" "${VALID_DIR}/data/html/" 2>/dev/null || true
        cp -r "Curated/data/mos/${doc_id}" "${VALID_DIR}/data/mos/" 2>/dev/null || true
        cp -r "Curated/data/plaintext/${doc_id}" "${VALID_DIR}/data/plaintext/" 2>/dev/null || true
        cp -r "Curated/data/xliff/${doc_id}" "${VALID_DIR}/data/xliff/" 2>/dev/null || true
        ((valid_count++))
    fi
done

# Process test set (HTML documents not in validation)
for html_dir in Curated/data/html/html_*; do
    if [ ! -d "${html_dir}" ]; then
        continue
    fi
    
    doc_id=$(basename "${html_dir}")
    
    # Check if in validation set
    is_valid=false
    for valid_id in "${VALID_HTML_IDS[@]}"; do
        if [ "${doc_id}" = "${valid_id}" ]; then
            is_valid=true
            break
        fi
    done
    
    if [ "${is_valid}" = false ]; then
        echo "  → TEST: ${doc_id}"
        cp -r "${html_dir}" "${TEST_DIR}/data/html/" 2>/dev/null || true
        cp -r "Curated/data/mos/${doc_id}" "${TEST_DIR}/data/mos/" 2>/dev/null || true
        cp -r "Curated/data/plaintext/${doc_id}" "${TEST_DIR}/data/plaintext/" 2>/dev/null || true
        cp -r "Curated/data/xliff/${doc_id}" "${TEST_DIR}/data/xliff/" 2>/dev/null || true
        ((test_html_count++))
    fi
done

echo ""
echo "Copying all DOCX documents to TEST..."
cp -r Curated/data/docx/docx_* "${TEST_DIR}/data/docx/" 2>/dev/null || true
test_docx_count=$(ls -d Curated/data/docx/docx_* 2>/dev/null | wc -l)
for doc_id in $(ls Curated/data/docx/ | grep "^docx_"); do
    cp -r "Curated/data/mos/${doc_id}" "${TEST_DIR}/data/mos/" 2>/dev/null || true
    cp -r "Curated/data/plaintext/${doc_id}" "${TEST_DIR}/data/plaintext/" 2>/dev/null || true
    cp -r "Curated/data/xliff/${doc_id}" "${TEST_DIR}/data/xliff/" 2>/dev/null || true
done

echo ""
echo "Copying all PDF documents to TEST..."
cp -r Curated/data/pdf/pdf_* "${TEST_DIR}/data/pdf/" 2>/dev/null || true
test_pdf_count=$(ls -d Curated/data/pdf/pdf_* 2>/dev/null | wc -l)
for doc_id in $(ls Curated/data/pdf/ | grep "^pdf_"); do
    cp -r "Curated/data/plaintext/${doc_id}" "${TEST_DIR}/data/plaintext/" 2>/dev/null || true
done

# Copy scripts
echo ""
echo "Copying scripts..."
cp -r Curated/scripts "${VALID_DIR}/" 2>/dev/null || true
cp -r Curated/scripts "${TEST_DIR}/" 2>/dev/null || true

echo ""
echo "======================================================================="
echo "SPLIT COMPLETE"
echo "======================================================================="
echo ""
echo "VALIDATION SET (${VALID_DIR}):"
echo "  HTML documents:     ${valid_count}"
echo ""
echo "TEST SET (${TEST_DIR}):"
echo "  HTML documents:     ${test_html_count}"
echo "  DOCX documents:     ${test_docx_count}"
echo "  PDF documents:      ${test_pdf_count}"
echo "  Total:              $((test_html_count + test_docx_count + test_pdf_count))"
echo ""

# Generate statistics
echo "Generating statistics..."
python count_curated_stats.py --curated-dir "${VALID_DIR}" \
       --output-json "${VALID_DIR}_stats.json" \
       --output-latex "${VALID_DIR}_stats.tex" \
       --output-md "${VALID_DIR}_stats.md" 2>&1 | grep -E "(languages|documents|segments)" || true

python count_curated_stats.py --curated-dir "${TEST_DIR}" \
       --output-json "${TEST_DIR}_stats.json" \
       --output-latex "${TEST_DIR}_stats.tex" \
       --output-md "${TEST_DIR}_stats.md" 2>&1 | grep -E "(languages|documents|segments)" || true

echo ""
echo "======================================================================="
echo "✅ DATASET SPLIT COMPLETE"
echo "======================================================================="
echo ""
echo "Validation set: ${VALID_DIR}/ (20 HTML docs)"
echo "Test set: ${TEST_DIR}/ (remaining docs)"
echo ""
echo "Statistics saved:"
echo "  - ${VALID_DIR}_stats.md"
echo "  - ${TEST_DIR}_stats.md"
echo ""

