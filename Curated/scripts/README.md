# Curated/scripts - Processing Scripts

## Overview

This directory contains scripts for processing documents in the `data/` directory.

## Directory Structure

```
Curated/
├── data/
│   ├── html/       # Source HTML files
│   ├── docx/       # Source DOCX files
│   ├── pdf/        # Source PDF files
│   ├── mos/        # Segmented files with XLIFF tags
│   ├── plaintext/  # Plaintext files (tags removed)
│   └── xliff/      # XLIFF format files
└── scripts/        # Processing scripts (this directory)
```

## Scripts

### 1. `all_segs.sh`
Process all HTML files from `data/html/` to create MOS and XLIFF files.

**Usage**:
```bash
cd scripts
./all_segs.sh
```

**What it does**:
- Reads from: `../data/html/`
- Outputs to: `../data/mos/` and `../data/xliff/`
- Uses Okapi Tikal for segmentation
- Normalizes whitespace

### 2. `get_segs.sh`
Process a single HTML file to MOS format.

**Usage**:
```bash
cd scripts
./get_segs.sh path/to/file.html cs
```

**Arguments**:
- `$1`: Path to HTML file
- `$2`: Source language code (cs, uk, en, etc.)

### 3. `process_all_docs.sh`
Process all HTML and DOCX files to create MOS and XLIFF files.

**Usage**:
```bash
cd scripts
./process_all_docs.sh [--dry-run] [--force]
```

**Options**:
- `--dry-run`: Preview what would be processed
- `--force`: Reprocess even if output exists

**What it does**:
- Processes HTML files from `../data/html/`
- Processes DOCX files from `../data/docx/`
- Creates MOS files in `../data/mos/`
- Creates XLIFF files in `../data/xliff/`

### 4. `process_pdfs.sh`
Extract text from PDFs and convert to plaintext format.

**Usage**:
```bash
cd scripts
./process_pdfs.sh [--dry-run] [--force]
```

**What it does**:
- Reads PDFs from `../data/pdf/`
- Extracts text using pdfplumber/PyPDF2/pdfminer
- Segments into translatable units
- Outputs to `../data/plaintext/` (NOT mos/, since PDFs have no tags)

**Note**: PDFs produce plaintext only, not MOS format (no XLIFF tags).

### 5. `convert_to_plaintext.sh`
Convert all MOS files to plaintext by removing XLIFF tags.

**Usage**:
```bash
cd scripts
./convert_to_plaintext.sh
```

**What it does**:
- Reads from `../data/mos/`
- Removes XLIFF tags using `../../remove_tags.py`
- Outputs to `../data/plaintext/`
- Enables dual evaluation (with/without tags)

### 6. `tgt_xlf_to_html.sh`
Merge XLIFF translations back into HTML.

**Usage**:
```bash
cd scripts
./tgt_xlf_to_html.sh path/to/file
```

**What it does**:
- Reads XLIFF from `../data/xliff/`
- Reads HTML template from `../data/html/`
- Merges translations using Tikal

### 7. `tgt_mos_to_html.sh`
Merge MOS translations back into HTML.

**Usage**:
```bash
cd scripts
./tgt_mos_to_html.sh path/to/file
```

**What it does**:
- Reads MOS from `../data/mos/`
- Reads HTML template from `../data/html/`
- Merges translations using Tikal

## Typical Workflow

### Initial Setup (Process Source Documents)

```bash
cd Curated/scripts

# 1. Process HTML/DOCX files to create MOS with XLIFF tags
./process_all_docs.sh

# 2. Extract text from PDFs to plaintext (no tags)
./process_pdfs.sh

# 3. Convert all MOS files to plaintext versions
./convert_to_plaintext.sh

# 4. Generate statistics
cd ../..
python count_curated_stats.py
```

### After Adding New Documents

```bash
cd Curated/scripts

# Process only new files (skips existing)
./process_all_docs.sh
./process_pdfs.sh

# Update plaintext versions
./convert_to_plaintext.sh --force

# Regenerate statistics
cd ../..
python count_curated_stats.py
```

## File Paths

All scripts now work with the unified `data/` directory structure:

- **Input**: `../data/html/`, `../data/docx/`, `../data/pdf/`
- **Output (MOS)**: `../data/mos/` (HTML/DOCX with XLIFF tags)
- **Output (Plaintext)**: `../data/plaintext/` (all documents, no tags)
- **Output (XLIFF)**: `../data/xliff/` (for CAT tools)

## Path Changes from Old Structure

| Old Path | New Path |
|----------|----------|
| `semimanual/html/` | `../data/html/` |
| `manual/html/` | `../data/html/` |
| `semimanual/mos/` | `../data/mos/` |
| `manual/mos/` | `../data/mos/` |
| `manual/pdf/` | `../data/pdf/` |
| `../tikal.sh` | `../../tikal.sh` |
| `../config/` | `../../config/` |

## Requirements

- Okapi Tikal (`../../tikal.sh`)
- Python 3 with pdfplumber, PyPDF2, or pdfminer.six
- Perl (for whitespace normalization)
- `../../remove_tags.py` script

## Output

After running all scripts, you'll have:

- **267 MOS files** in `data/mos/` (HTML/DOCX with XLIFF tags)
- **322 plaintext files** in `data/plaintext/` (all documents, no tags)
- **XLIFF files** in `data/xliff/` (for CAT tools)

## Verification

```bash
# Count MOS files (should be 267)
find ../data/mos -name "*.mos" | wc -l

# Count plaintext files (should be 322)
find ../data/plaintext -name "*.txt" | wc -l

# Check for tags in MOS
head ../data/mos/10/cs/*.mos | grep '<g>'  # Should find tags

# Check plaintext has no tags
head ../data/plaintext/10/cs/*.txt | grep '<g>'  # Should find nothing
```

## Troubleshooting

**Error: "directory not found"**
- Solution: Run from `Curated/scripts/` directory
- Check that `../data/` exists

**Error: "tikal.sh not found"**
- Solution: Ensure `../../tikal.sh` exists
- Scripts expect to be in `Curated/scripts/`

**PDFs fail to process**
- Likely scanned images without text layer
- Only text-based PDFs can be extracted
- Consider OCR if needed

## Summary

All scripts have been updated to work with the reorganized `Curated/data/` structure:

✅ Paths updated from `manual/`  and `semimanual/` to `../data/`  
✅ Tikal paths updated: `../tikal.sh` → `../../tikal.sh`  
✅ Config paths updated: `../config/` → `../../config/`  
✅ Remove_tags paths updated: `../remove_tags.py` → `../../remove_tags.py`  
✅ Statistics paths updated: references to parent directory  

All scripts are now ready to use with the unified data structure! 📁✨

