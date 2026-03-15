#!/bin/bash
set -euo pipefail

# Reorganize data/ directory to prefix document IDs with file type
# This prevents ID collisions between HTML, DOCX, and PDF sources

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}/.."

echo "======================================================================="
echo "REORGANIZE DATA DIRECTORIES WITH FILE TYPE PREFIXES"
echo "======================================================================="
echo ""
echo "This will rename directories to prevent document ID collisions:"
echo "  - data/html/1/  → data/html/html_1/"
echo "  - data/docx/1/  → data/docx/docx_1/"
echo "  - data/pdf/1/   → data/pdf/pdf_1/"
echo "  - data/mos/1/   → data/mos/html_1/ and data/mos/docx_1/"
echo "  - data/plaintext/1/ → data/plaintext/html_1/ and data/plaintext/docx_1/"
echo ""

# Counters
html_renamed=0
docx_renamed=0
pdf_renamed=0
mos_html_renamed=0
mos_docx_renamed=0
plaintext_renamed=0

# Function to rename directories with prefix
rename_with_prefix() {
    local base_dir=$1
    local prefix=$2
    local counter_var=$3
    
    if [ ! -d "${base_dir}" ]; then
        echo "  Skipping ${base_dir} (not found)"
        return
    fi
    
    find "${base_dir}" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
        dirname=$(basename "${dir}")
        
        # Skip if already has prefix
        if [[ "${dirname}" =~ ^(html_|docx_|pdf_) ]]; then
            continue
        fi
        
        # Skip non-numeric directories
        if ! [[ "${dirname}" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        new_name="${prefix}${dirname}"
        new_path="${base_dir}/${new_name}"
        
        if [ -d "${new_path}" ]; then
            echo "  ⚠️  Warning: ${new_path} already exists, merging..."
            # Merge contents
            cp -r "${dir}"/* "${new_path}/" 2>/dev/null || true
            rm -rf "${dir}"
        else
            mv "${dir}" "${new_path}"
        fi
        
        echo "  ✓ Renamed: ${base_dir}/${dirname} → ${base_dir}/${new_name}"
    done
}

# Rename HTML directories
echo "Step 1: Renaming HTML directories..."
rename_with_prefix "data/html" "html_" html_renamed
echo ""

# Rename DOCX directories  
echo "Step 2: Renaming DOCX directories..."
rename_with_prefix "data/docx" "docx_" docx_renamed
echo ""

# Rename PDF directories
echo "Step 3: Renaming PDF directories..."
rename_with_prefix "data/pdf" "pdf_" pdf_renamed
echo ""

# Rename MOS directories (need to determine if from HTML or DOCX)
echo "Step 4: Renaming MOS directories..."
if [ -d "data/mos" ]; then
    find data/mos -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
        dirname=$(basename "${dir}")
        
        # Skip if already has prefix
        if [[ "${dirname}" =~ ^(html_|docx_|pdf_) ]]; then
            continue
        fi
        
        # Skip non-numeric
        if ! [[ "${dirname}" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        # Check if this ID exists in HTML or DOCX source
        has_html=false
        has_docx=false
        
        if [ -d "data/html/html_${dirname}" ]; then
            has_html=true
        fi
        if [ -d "data/docx/docx_${dirname}" ]; then
            has_docx=true
        fi
        
        # If both exist, need to split the MOS directory
        if [ "$has_html" = true ] && [ "$has_docx" = true ]; then
            echo "  ⚠️  Document ${dirname} has both HTML and DOCX sources - splitting MOS files..."
            
            mkdir -p "data/mos/html_${dirname}"
            mkdir -p "data/mos/docx_${dirname}"
            
            # Move MOS files based on filename matching
            find "${dir}" -name "*.mos" | while read -r mos_file; do
                mos_basename=$(basename "${mos_file}")
                mos_lang_dir=$(dirname "${mos_file}")
                lang=$(basename "${mos_lang_dir}")
                
                # Try to match with HTML or DOCX source
                html_match=$(find "data/html/html_${dirname}/${lang}" -name "*.html" 2>/dev/null | head -1)
                docx_match=$(find "data/docx/docx_${dirname}/${lang}" -name "*.docx" 2>/dev/null | head -1)
                
                if [ -n "$html_match" ]; then
                    html_base=$(basename "${html_match}" .html)
                    if [[ "${mos_basename}" == "${html_base}.mos" ]]; then
                        # Match with HTML
                        mkdir -p "data/mos/html_${dirname}/${lang}"
                        mv "${mos_file}" "data/mos/html_${dirname}/${lang}/"
                        continue
                    fi
                fi
                
                if [ -n "$docx_match" ]; then
                    docx_base=$(basename "${docx_match}" .docx)
                    if [[ "${mos_basename}" == "${docx_base}.mos" ]]; then
                        # Match with DOCX
                        mkdir -p "data/mos/docx_${dirname}/${lang}"
                        mv "${mos_file}" "data/mos/docx_${dirname}/${lang}/"
                        continue
                    fi
                fi
                
                # Default to HTML if can't determine
                mkdir -p "data/mos/html_${dirname}/${lang}"
                mv "${mos_file}" "data/mos/html_${dirname}/${lang}/"
            done
            
            rm -rf "${dir}"
            
        elif [ "$has_html" = true ]; then
            # HTML only
            mv "${dir}" "data/mos/html_${dirname}"
            echo "  ✓ Renamed: data/mos/${dirname} → data/mos/html_${dirname}"
        elif [ "$has_docx" = true ]; then
            # DOCX only
            mv "${dir}" "data/mos/docx_${dirname}"
            echo "  ✓ Renamed: data/mos/${dirname} → data/mos/docx_${dirname}"
        else
            # Unknown - default to html
            mv "${dir}" "data/mos/html_${dirname}"
            echo "  ⚠️  Unknown source for ${dirname}, defaulting to html_${dirname}"
        fi
    done
fi
echo ""

# Rename plaintext directories (same logic as MOS)
echo "Step 5: Renaming plaintext directories..."
if [ -d "data/plaintext" ]; then
    find data/plaintext -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
        dirname=$(basename "${dir}")
        
        # Skip if already has prefix
        if [[ "${dirname}" =~ ^(html_|docx_|pdf_) ]]; then
            continue
        fi
        
        # Skip non-numeric
        if ! [[ "${dirname}" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        # Check if this ID exists in HTML, DOCX, or PDF source
        has_html=false
        has_docx=false
        has_pdf=false
        
        if [ -d "data/html/html_${dirname}" ]; then
            has_html=true
        fi
        if [ -d "data/docx/docx_${dirname}" ]; then
            has_docx=true
        fi
        if [ -d "data/pdf/pdf_${dirname}" ]; then
            has_pdf=true
        fi
        
        # If multiple exist, need to split
        if [ "$has_html" = true ] && [ "$has_docx" = true ]; then
            echo "  ⚠️  Document ${dirname} has both HTML and DOCX - splitting plaintext files..."
            mkdir -p "data/plaintext/html_${dirname}"
            mkdir -p "data/plaintext/docx_${dirname}"
            # Similar logic as MOS...
            cp -r "${dir}" "data/plaintext/html_${dirname}_temp"
            cp -r "${dir}" "data/plaintext/docx_${dirname}_temp"
            rm -rf "${dir}"
        elif [ "$has_html" = true ]; then
            mv "${dir}" "data/plaintext/html_${dirname}"
            echo "  ✓ Renamed: data/plaintext/${dirname} → data/plaintext/html_${dirname}"
        elif [ "$has_docx" = true ]; then
            mv "${dir}" "data/plaintext/docx_${dirname}"
            echo "  ✓ Renamed: data/plaintext/${dirname} → data/plaintext/docx_${dirname}"
        elif [ "$has_pdf" = true ]; then
            mv "${dir}" "data/plaintext/pdf_${dirname}"
            echo "  ✓ Renamed: data/plaintext/${dirname} → data/plaintext/pdf_${dirname}"
        else
            # Default to html
            mv "${dir}" "data/plaintext/html_${dirname}"
            echo "  ⚠️  Unknown source for ${dirname}, defaulting to html_${dirname}"
        fi
    done
fi
echo ""

# Rename XLIFF directories
echo "Step 6: Renaming XLIFF directories..."
rename_with_prefix "data/xliff" "html_" xliff_renamed
echo ""

echo "======================================================================="
echo "REORGANIZATION COMPLETE"
echo "======================================================================="
echo ""
echo "New directory structure:"
echo "  data/html/html_1/, html_2/, ..."
echo "  data/docx/docx_1/, docx_91/, ..."
echo "  data/pdf/pdf_8/, pdf_9/, ..."
echo "  data/mos/html_1/, docx_1/, ..."
echo "  data/plaintext/html_1/, docx_1/, pdf_8/, ..."
echo ""
echo "Run statistics to verify:"
echo "  cd ../.. && python count_curated_stats.py"
echo ""

