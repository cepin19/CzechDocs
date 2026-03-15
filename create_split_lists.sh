#!/bin/bash
set -euo pipefail

# Create lists of validation and test document IDs
# Much faster than copying files - just creates reference lists

cd /home/cepin/ctk_testsets

# Fixed validation set: 20 HTML document IDs
# Selected randomly on 2025-10-22, now fixed for reproducibility
cat > valid_ids.txt <<'EOF'
html_12
html_13
html_18
html_19
html_2
html_21
html_25
html_26
html_28
html_43
html_45
html_46
html_47
html_49
html_57
html_59
html_62
html_65
html_70
html_76
EOF

echo "======================================================================="
echo "DATASET SPLIT LISTS CREATED"
echo "======================================================================="
echo ""
echo "Validation IDs saved to: valid_ids.txt (20 HTML documents)"
echo ""

# Create test set list (all non-validation documents)
{
    # HTML documents not in validation
    for html_dir in Curated/data/html/html_*; do
        doc_id=$(basename "${html_dir}")
        if ! grep -qx "${doc_id}" valid_ids.txt; then
            echo "${doc_id}"
        fi
    done
    
    # All DOCX documents
    for docx_dir in Curated/data/docx/docx_*; do
        if [ -d "${docx_dir}" ]; then
            basename "${docx_dir}"
        fi
    done
    
    # All PDF documents
    for pdf_dir in Curated/data/pdf/pdf_*; do
        if [ -d "${pdf_dir}" ]; then
            basename "${pdf_dir}"
        fi
    done
} | sort > test_ids.txt

echo "Test IDs saved to: test_ids.txt"
echo ""

# Show counts
valid_count=$(wc -l < valid_ids.txt)
test_count=$(wc -l < test_ids.txt)

echo "Counts:"
echo "  Validation: ${valid_count} documents"
echo "  Test: ${test_count} documents"
echo "  Total: $((valid_count + test_count)) documents"
echo ""

# Show which validation IDs are in which language pairs
echo "Validation set document analysis:"
echo "  Documents with CS-UK parallel:"
cs_uk_count=0
for doc_id in $(cat valid_ids.txt); do
    if [ -d "Curated/data/html/${doc_id}/cs" ] && [ -d "Curated/data/html/${doc_id}/uk" ]; then
        ((cs_uk_count++))
    fi
done
echo "    ${cs_uk_count} documents"

echo ""
echo "Usage:"
echo "  # Get file paths for validation set"
echo "  while read id; do find Curated/data/html/\$id -name '*.html'; done < valid_ids.txt"
echo ""
echo "  # Get file paths for test set"
echo "  while read id; do find Curated/data -path \"*\$id/*\" -type f; done < test_ids.txt"
echo ""
echo "======================================================================="
echo "✅ Split lists created"
echo "======================================================================="
echo ""

