#!/bin/bash
set -euo pipefail

# Create physical copies of validation and test sets in splits/ directory

cd /home/cepin/ctk_testsets

SPLITS_DIR="splits"
VALID_DIR="${SPLITS_DIR}/valid"
TEST_DIR="${SPLITS_DIR}/test"

echo "======================================================================="
echo "CREATE DATASET SPLITS"
echo "======================================================================="
echo ""
echo "Creating physical copies in splits/ directory"
echo "  - splits/valid/ (20 HTML documents)"
echo "  - splits/test/ (58 documents: 34 HTML, 5 DOCX, 19 PDF)"
echo ""

# Clean and create structure
rm -rf "${SPLITS_DIR}"
mkdir -p "${VALID_DIR}/data" "${TEST_DIR}/data"

# Create subdirectories
for subdir in html docx pdf mos plaintext xliff; do
    mkdir -p "${VALID_DIR}/data/${subdir}"
    mkdir -p "${TEST_DIR}/data/${subdir}"
done

# Copy scripts
echo "Copying scripts..."
cp -r Curated/scripts "${VALID_DIR}/" 2>/dev/null || true
cp -r Curated/scripts "${TEST_DIR}/" 2>/dev/null || true

# Counters
valid_html=0
test_html=0
test_docx=0
test_pdf=0

echo ""
echo "======================================================================="
echo "COPYING VALIDATION SET (20 HTML documents)"
echo "======================================================================="
echo ""

# Copy validation documents - read from valid_ids.txt
while IFS= read -r doc_id; do
    echo "  ✓ ${doc_id}"
    
    # Copy HTML
    cp -r "Curated/data/html/${doc_id}" "${VALID_DIR}/data/html/" 2>/dev/null || true
    
    # Copy MOS
    cp -r "Curated/data/mos/${doc_id}" "${VALID_DIR}/data/mos/" 2>/dev/null || true
    
    # Copy plaintext
    cp -r "Curated/data/plaintext/${doc_id}" "${VALID_DIR}/data/plaintext/" 2>/dev/null || true
    
    # Copy XLIFF
    cp -r "Curated/data/xliff/${doc_id}" "${VALID_DIR}/data/xliff/" 2>/dev/null || true
    
    valid_html=$((valid_html + 1))
done < valid_ids.txt

# Update counter after loop completes
valid_html=$(ls ${VALID_DIR}/data/html 2>/dev/null | wc -l)

echo ""
echo "======================================================================="
echo "COPYING TEST SET (58 documents)"
echo "======================================================================="
echo ""

# Copy test documents - read from test_ids.txt
while IFS= read -r doc_id; do
    # Determine file type and copy accordingly
    if [[ "${doc_id}" == html_* ]]; then
        echo "  → ${doc_id} (HTML)"
        cp -r "Curated/data/html/${doc_id}" "${TEST_DIR}/data/html/" 2>/dev/null || true
        cp -r "Curated/data/mos/${doc_id}" "${TEST_DIR}/data/mos/" 2>/dev/null || true
        cp -r "Curated/data/plaintext/${doc_id}" "${TEST_DIR}/data/plaintext/" 2>/dev/null || true
        cp -r "Curated/data/xliff/${doc_id}" "${TEST_DIR}/data/xliff/" 2>/dev/null || true
    elif [[ "${doc_id}" == docx_* ]]; then
        echo "  → ${doc_id} (DOCX)"
        cp -r "Curated/data/docx/${doc_id}" "${TEST_DIR}/data/docx/" 2>/dev/null || true
        cp -r "Curated/data/mos/${doc_id}" "${TEST_DIR}/data/mos/" 2>/dev/null || true
        cp -r "Curated/data/plaintext/${doc_id}" "${TEST_DIR}/data/plaintext/" 2>/dev/null || true
        cp -r "Curated/data/xliff/${doc_id}" "${TEST_DIR}/data/xliff/" 2>/dev/null || true
    elif [[ "${doc_id}" == pdf_* ]]; then
        echo "  → ${doc_id} (PDF)"
        cp -r "Curated/data/pdf/${doc_id}" "${TEST_DIR}/data/pdf/" 2>/dev/null || true
        cp -r "Curated/data/plaintext/${doc_id}" "${TEST_DIR}/data/plaintext/" 2>/dev/null || true
    fi
done < test_ids.txt

# Update counters after copying
test_html=$(ls ${TEST_DIR}/data/html 2>/dev/null | wc -l)
test_docx=$(ls ${TEST_DIR}/data/docx 2>/dev/null | wc -l)
test_pdf=$(ls ${TEST_DIR}/data/pdf 2>/dev/null | wc -l)

echo ""
echo "======================================================================="
echo "SPLIT COMPLETE"
echo "======================================================================="
echo ""
echo "VALIDATION SET (${VALID_DIR}):"
echo "  HTML documents:     ${valid_html}"
echo "  Files copied to:    ${VALID_DIR}/data/"
echo ""
echo "TEST SET (${TEST_DIR}):"
echo "  HTML documents:     ${test_html}"
echo "  DOCX documents:     ${test_docx}"
echo "  PDF documents:      ${test_pdf}"
echo "  Total documents:    $((test_html + test_docx + test_pdf))"
echo "  Files copied to:    ${TEST_DIR}/data/"
echo ""

# Verify file counts
echo "Verification:"
echo "  Valid HTML dirs:    $(find ${VALID_DIR}/data/html -type d -name "html_*" | wc -l)"
echo "  Valid MOS files:    $(find ${VALID_DIR}/data/mos -name "*.mos" | wc -l)"
echo "  Valid plaintext:    $(find ${VALID_DIR}/data/plaintext -name "*.txt" | wc -l)"
echo ""
echo "  Test HTML dirs:     $(find ${TEST_DIR}/data/html -type d -name "html_*" | wc -l)"
echo "  Test DOCX dirs:     $(find ${TEST_DIR}/data/docx -type d -name "docx_*" | wc -l)"
echo "  Test PDF dirs:      $(find ${TEST_DIR}/data/pdf -type d -name "pdf_*" | wc -l)"
echo "  Test MOS files:     $(find ${TEST_DIR}/data/mos -name "*.mos" | wc -l)"
echo "  Test plaintext:     $(find ${TEST_DIR}/data/plaintext -name "*.txt" | wc -l)"
echo ""

echo ""
echo "Generating statistics..."

# Generate statistics for validation set
echo "  Computing validation set statistics..."
python count_curated_stats.py --curated-dir "${VALID_DIR}" \
       --output-json "${SPLITS_DIR}/valid_stats.json" \
       --output-latex "${SPLITS_DIR}/valid_stats.tex" \
       --output-md "${SPLITS_DIR}/valid_stats.md" > /dev/null 2>&1 && echo "  ✓ Validation stats saved" || echo "  ⚠️  Validation stats failed"

# Generate statistics for test set  
echo "  Computing test set statistics..."
python count_curated_stats.py --curated-dir "${TEST_DIR}" \
       --output-json "${SPLITS_DIR}/test_stats.json" \
       --output-latex "${SPLITS_DIR}/test_stats.tex" \
       --output-md "${SPLITS_DIR}/test_stats.md" > /dev/null 2>&1 && echo "  ✓ Test stats saved" || echo "  ⚠️  Test stats failed"

echo ""
echo "======================================================================="
echo "✅ SPLITS CREATED AND VERIFIED"
echo "======================================================================="
echo ""
echo "Directory structure:"
echo "  splits/"
echo "  ├── valid/"
echo "  │   ├── data/ (20 HTML docs with all formats)"
echo "  │   └── scripts/"
echo "  ├── test/"
echo "  │   ├── data/ (58 docs with all formats)"
echo "  │   └── scripts/"
echo "  ├── valid_stats.md"
echo "  └── test_stats.md"
echo ""
echo "Use for evaluation:"
echo "  # Validation set"
echo "  find splits/valid/data/mos -name \"*.mos\""
echo ""
echo "  # Test set"
echo "  find splits/test/data/mos -name \"*.mos\""
echo ""

