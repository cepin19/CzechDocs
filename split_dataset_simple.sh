#!/bin/bash
set -euo pipefail

# Simple dataset split into validation and test sets

cd /home/cepin/ctk_testsets

# Output directories
VALID_DIR="Curated_valid"
TEST_DIR="Curated_test"

# Fixed validation set: 20 HTML document IDs
VALID_IDS="html_12 html_13 html_18 html_19 html_2 html_21 html_25 html_26 html_28 html_43 html_45 html_46 html_47 html_49 html_57 html_59 html_62 html_65 html_70 html_76"

echo "==================================================================="
echo "DATASET SPLIT"
echo "==================================================================="
echo "Validation: 20 HTML docs"
echo "Test: Remaining docs"
echo ""

# Clean and create
rm -rf "${VALID_DIR}" "${TEST_DIR}"
mkdir -p "${VALID_DIR}/data" "${TEST_DIR}/data"

# Copy full structure first
echo "Copying base structure..."
cp -r Curated/data/docx "${TEST_DIR}/data/" 2>/dev/null || mkdir -p "${TEST_DIR}/data/docx"
cp -r Curated/data/pdf "${TEST_DIR}/data/" 2>/dev/null || mkdir -p "${TEST_DIR}/data/pdf"
cp -r Curated/scripts "${VALID_DIR}/" 2>/dev/null || true
cp -r Curated/scripts "${TEST_DIR}/" 2>/dev/null || true

# Create subdirectories
for dir in html mos plaintext xliff; do
    mkdir -p "${VALID_DIR}/data/${dir}" "${TEST_DIR}/data/${dir}"
done

echo "Splitting HTML documents..."
valid_count=0
test_count=0

for html_dir in Curated/data/html/html_*; do
    doc_id=$(basename "${html_dir}")
    
    if echo "${VALID_IDS}" | grep -qw "${doc_id}"; then
        # Validation
        cp -r "${html_dir}" "${VALID_DIR}/data/html/"
        cp -r "Curated/data/mos/${doc_id}" "${VALID_DIR}/data/mos/" 2>/dev/null || true
        cp -r "Curated/data/plaintext/${doc_id}" "${VALID_DIR}/data/plaintext/" 2>/dev/null || true
        cp -r "Curated/data/xliff/${doc_id}" "${VALID_DIR}/data/xliff/" 2>/dev/null || true
        ((valid_count++))
        echo "  ✓ VALID: ${doc_id}"
    else
        # Test
        cp -r "${html_dir}" "${TEST_DIR}/data/html/"
        cp -r "Curated/data/mos/${doc_id}" "${TEST_DIR}/data/mos/" 2>/dev/null || true
        cp -r "Curated/data/plaintext/${doc_id}" "${TEST_DIR}/data/plaintext/" 2>/dev/null || true
        cp -r "Curated/data/xliff/${doc_id}" "${TEST_DIR}/data/xliff/" 2>/dev/null || true
        ((test_count++))
        echo "  → TEST: ${doc_id}"
    fi
done

# Copy DOCX MOS/plaintext/xliff
echo ""
echo "Copying DOCX derived files to TEST..."
for doc_id in docx_1 docx_2 docx_91 docx_92 docx_93; do
    cp -r "Curated/data/mos/${doc_id}" "${TEST_DIR}/data/mos/" 2>/dev/null || true
    cp -r "Curated/data/plaintext/${doc_id}" "${TEST_DIR}/data/plaintext/" 2>/dev/null || true
    cp -r "Curated/data/xliff/${doc_id}" "${TEST_DIR}/data/xliff/" 2>/dev/null || true
done

# Copy PDF plaintext
echo "Copying PDF plaintext to TEST..."
for pdf_dir in Curated/data/plaintext/pdf_*; do
    if [ -d "${pdf_dir}" ]; then
        cp -r "${pdf_dir}" "${TEST_DIR}/data/plaintext/" 2>/dev/null || true
    fi
done

echo ""
echo "==================================================================="
echo "SPLIT COMPLETE"
echo "==================================================================="
echo ""
echo "VALIDATION SET:"
echo "  Location: ${VALID_DIR}/"
echo "  HTML documents: ${valid_count}"
echo "  Document IDs: ${VALID_IDS}"
echo ""
echo "TEST SET:"
echo "  Location: ${TEST_DIR}/"
echo "  HTML documents: ${test_count}"
echo "  DOCX documents: 5"
echo "  PDF documents: 19"
echo "  Total: $((test_count + 5 + 19))"
echo ""

# Count files
echo "File counts:"
echo "  VALID HTML dirs: $(ls -d ${VALID_DIR}/data/html/html_* 2>/dev/null | wc -l)"
echo "  VALID MOS dirs: $(ls -d ${VALID_DIR}/data/mos/html_* 2>/dev/null | wc -l)"
echo "  TEST HTML dirs: $(ls -d ${TEST_DIR}/data/html/html_* 2>/dev/null | wc -l)"
echo "  TEST total dirs: $(ls -d ${TEST_DIR}/data/{html,mos,plaintext}/*/  2>/dev/null | wc -l)"
echo ""
echo "Run statistics:"
echo "  python count_curated_stats.py --curated-dir ${VALID_DIR}"
echo "  python count_curated_stats.py --curated-dir ${TEST_DIR}"
echo ""

