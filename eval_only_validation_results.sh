#!/bin/bash
# Evaluation-Only Script for Validation Results
# Assumes translations are already completed in validation_results/
# Only runs evaluations and collects scores

set -e

# Parse command line arguments
RESULTS_DIR="validation_results"
FILTER_APPROACHES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --results-dir)
            RESULTS_DIR="$2"
            shift 2
            ;;
        *)
            # Treat as approach filter
            FILTER_APPROACHES+=("$1")
            shift
            ;;
    esac
done

SCORES_CSV="${RESULTS_DIR}/scores.csv"
SUMMARY_FILE="${RESULTS_DIR}/summary.txt"
EVAL_LOG="${RESULTS_DIR}/eval_only.log"

echo "================================================================"
echo "VALIDATION RESULTS - EVALUATION ONLY"
echo "================================================================"
echo ""
echo "This script evaluates existing translations in ${RESULTS_DIR}/"
echo "No new translations will be generated."
echo ""

if [ ${#FILTER_APPROACHES[@]} -gt 0 ]; then
    echo "⚡ FILTERING: Only evaluating approaches matching: ${FILTER_APPROACHES[*]}"
    echo ""
fi

# Check if results directory exists
if [ ! -d "${RESULTS_DIR}" ]; then
    echo "❌ Error: ${RESULTS_DIR}/ directory not found"
    echo "   Please run eval_validation_set.sh first to generate translations"
    exit 1
fi

# Initialize CSV with header
echo "doc_id,lang,approach,bleu,bleu_notags,xml_struct_acc,xml_match_acc,ne_num_prec,ne_num_rec,tag_acc,tag_preservation,avg_char_diff,incons_pct" > "${SCORES_CSV}"

# Counter
total_docs=0
total_evals=0
total_approaches=0

# Create temporary directory for corpus-level BLEU
CORPUS_DIR="${RESULTS_DIR}/corpus_bleu_tmp"
mkdir -p "${CORPUS_DIR}"

# Track approaches for corpus-level BLEU
declare -A approach_translations_tags
declare -A approach_translations_notags
declare -A approach_refs_tags
declare -A approach_refs_notags

# Start logging
exec > >(tee -a "${EVAL_LOG}") 2>&1

echo "Scanning ${RESULTS_DIR} for document directories..."
echo ""

# Find all document directories
for doc_dir in ${RESULTS_DIR}/html_*_uk2cs; do
    if [ ! -d "$doc_dir" ]; then
        continue
    fi
    
    doc_id=$(basename "$doc_dir" | sed 's/_uk2cs$//')
    total_docs=$((total_docs + 1))
    
    echo "================================================================"
    echo "DOCUMENT ${total_docs}: ${doc_id}"
    echo "================================================================"
    
    # Find reference files
    # Try multiple patterns: .ref_mos.cs or .mos.cs (reference)
    ref_mos=$(find "$doc_dir" -name "*.ref_mos.cs" -type f | head -1)
    if [ -z "$ref_mos" ]; then
        ref_mos=$(find "$doc_dir" -name "*.mos.cs" -type f | grep -v "\.out_" | head -1)
    fi
    
    ref_mos_notags=$(find "$doc_dir" -name "*.ref_mos.cs.notags" -type f | head -1)
    if [ -z "$ref_mos_notags" ]; then
        ref_mos_notags=$(find "$doc_dir" -name "*.mos.cs.notags" -type f | grep -v "\.out_" | head -1)
    fi
    
    if [ -z "$ref_mos" ]; then
        echo "  ⚠️  No reference MOS file found, skipping"
        continue
    fi
    
    echo "  Reference: $(basename "$ref_mos")"
    
    # Create notags reference if it doesn't exist
    if [ ! -f "$ref_mos_notags" ]; then
        echo "  → Creating notags reference..."
	ref_mos_notags="$ref_mos".notags
        python3 remove_tags.py "$ref_mos" "$ref_mos_notags" --decode-entities
    fi
    
    # Find all translation outputs
    # Pattern: *.out_<approach_name>.mos, *.out_<approach_name>_mos, or plaintext files
    # Use array to handle filenames with spaces
    mapfile -t translation_files < <(find "$doc_dir" -type f \( -name "*.out_*.mos" -o -name "*.out_*_mos" -o -name "*_plaintext" -o -name "*.llm_seg_by_seg_plaintext" \) ! -name "*.notags" | sort)
    
    if [ ${#translation_files[@]} -eq 0 ]; then
        echo "  ⚠️  No translation files found"
        continue
    fi
    
    echo "  Found ${#translation_files[@]} translation files"
    echo ""
    
    # Process each translation
    approach_num=0
    for trans_file in "${translation_files[@]}"; do
        approach_num=$((approach_num + 1))
        
        # Extract approach name from filename
        basename_trans=$(basename "$trans_file")
        # Remove .mos extension and extract approach name
        # Handle both .mos files and plaintext files (no .mos extension)
        if [[ "$basename_trans" =~ _plaintext$ ]]; then
            # Plaintext file: extract from _plaintext or llm_seg_by_seg_plaintext
            approach_name=$(echo "$basename_trans" | sed 's/.*\.\(out_\)\?//' | sed 's/^out_//')
        else
            # MOS file: extract from .out_NAME.mos or .out_NAME_mos
            approach_name=$(echo "$basename_trans" | sed 's/.*\.out_//; s/\.mos$//')
        fi
        
        # Filter approaches if specified
        if [ ${#FILTER_APPROACHES[@]} -gt 0 ]; then
            match_found=false
            for filter in "${FILTER_APPROACHES[@]}"; do
                # Check if filter matches approach number or approach name (case-insensitive substring)
                if [ "$filter" = "$approach_num" ] || echo "$approach_name" | grep -iq "$filter"; then
                    match_found=true
                    break
                fi
            done
            
            if [ "$match_found" = false ]; then
                echo "  ⏭️  Skipping approach ${approach_num}: ${approach_name} (not in filter)"
                continue
            fi
        fi
        
        total_evals=$((total_evals + 1))
        
        echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Approach ${approach_num}: ${approach_name}"
        echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Translation: $(basename "$trans_file")"
        
        # Create notags version if it doesn't exist
        trans_file_notags="${trans_file}.notags"
        if [ ! -f "$trans_file_notags" ]; then
            python3 remove_tags.py "$trans_file" "$trans_file_notags" --decode-entities 2>/dev/null || echo "    (Could not create notags version)"
        fi
        
        # Temporary files for evaluation output
        eval_with_tags_out=$(mktemp)
        eval_notags_out=$(mktemp)
        tag_placement_out=$(mktemp)
        sacrebleu_with_tags_out=$(mktemp)
        sacrebleu_notags_out=$(mktemp)
        
        # Evaluate WITH tags
        echo "    → Evaluating with tags..."
        python3 eval_raw.py \
            --target "$ref_mos" \
            --translation "$trans_file" \
            --lang cs \
            --english_term scripts/english_terms.json \
            > "$eval_with_tags_out" 2>&1 || echo "    (Evaluation failed)"
        
        # BLEU with tags using sacrebleu
        echo "    → Computing BLEU with tags (sacrebleu)..."
        if command -v sacrebleu &> /dev/null; then
            sacrebleu "$ref_mos" -i "$trans_file" -m bleu -b -w 2 \
                > "$sacrebleu_with_tags_out" 2>&1 || echo "    (sacrebleu failed)"
        else
            echo "    (sacrebleu not installed)"
        fi
        
        # Evaluate WITHOUT tags (pure translation quality)
        echo "    → Evaluating without tags..."
        if [ -f "$trans_file_notags" ] && [ -f "$ref_mos_notags" ]; then
            python3 eval_raw.py \
                --target "$ref_mos_notags" \
                --translation "$trans_file_notags" \
                --lang cs \
                > "$eval_notags_out" 2>&1 || echo "    (Evaluation failed)"
            
            # BLEU without tags using sacrebleu
            echo "    → Computing BLEU without tags (sacrebleu)..."
            if command -v sacrebleu &> /dev/null; then
                sacrebleu "$ref_mos_notags" -i "$trans_file_notags" -m bleu -b -w 2 \
                    > "$sacrebleu_notags_out" 2>&1 || echo "    (sacrebleu failed)"
            fi
        fi
        
        # Evaluate tag placement
    #    echo "    → Evaluating tag placement..."
     #   if command -v evaluate-markup-tags &> /dev/null; then
      #      evaluate-markup-tags "$ref_mos" "$trans_file" --permissive \
       #         > "$tag_placement_out" 2>&1 || echo "    (Tag placement evaluation skipped)"
        #fi
        
        # Extract scores using Python
        python3 <<EOFPYTHON
import re
import sys

doc_id = "${doc_id}"
lang = "cs"
approach = "${approach_name}"

# Read evaluation outputs
try:
    with open("$eval_with_tags_out", 'r') as f:
        eval_with_tags = f.read()
except:
    eval_with_tags = ""

try:
    with open("$eval_notags_out", 'r') as f:
        eval_notags = f.read()
except:
    eval_notags = ""

try:
    with open("$tag_placement_out", 'r') as f:
        tag_placement = f.read()
except:
    tag_placement = ""

try:
    with open("$sacrebleu_with_tags_out", 'r') as f:
        sacrebleu_with_tags = f.read()
except:
    sacrebleu_with_tags = ""

try:
    with open("$sacrebleu_notags_out", 'r') as f:
        sacrebleu_notags = f.read()
except:
    sacrebleu_notags = ""

# Extract scores
def extract_score(text, pattern, default="N/A"):
    match = re.search(pattern, text)
    return match.group(1) if match else default

# BLEU scores from sacrebleu (preferred)
# sacrebleu outputs just the score as a float
bleu = extract_score(sacrebleu_with_tags, r'^([\d.]+)$', "N/A")
if bleu == "N/A":
    # Fallback to eval_raw.py BLEU
    bleu = extract_score(eval_with_tags, r'BLEU\s*=\s*([\d.]+)')

bleu_notags = extract_score(sacrebleu_notags, r'^([\d.]+)$', "N/A")
if bleu_notags == "N/A":
    # Fallback to eval_raw.py BLEU
    bleu_notags = extract_score(eval_notags, r'BLEU\s*=\s*([\d.]+)')

# XML Structure/Matching
xml_struct = extract_score(eval_with_tags, r'XML Structure Accuracy:\s*([\d.]+)%')
xml_match = extract_score(eval_with_tags, r'XML Matching Accuracy:\s*([\d.]+)%')

# NE&NUM
ne_prec = extract_score(eval_with_tags, r'NE&NUM Precision:\s*([\d.]+)%')
ne_rec = extract_score(eval_with_tags, r'NE&NUM Recall:\s*([\d.]+)%')

# Tag accuracy
tag_acc = extract_score(tag_placement, r'accuracy:\s*([\d.]+)')

# Tag preservation
tag_pres = extract_score(eval_with_tags, r'Tag preservation rate:\s*([\d.]+)%')

# Character difference
char_diff = extract_score(eval_with_tags, r'Average Character Difference:\s*([\d.]+)')

# Inconsistent sentences
incons = extract_score(eval_with_tags, r'Inconsistent Sentences Percentage:\s*([\d.]+)%')

# Write to CSV
with open("${SCORES_CSV}", 'a') as csv:
    approach_clean = approach.replace(',', ';')
    csv.write(f"{doc_id},cs,{approach_clean},{bleu},{bleu_notags},{xml_struct},{xml_match},{ne_prec},{ne_rec},{tag_acc},{tag_pres},{char_diff},{incons}\n")

print(f"    ✓ BLEU={bleu} (with tags), {bleu_notags} (without tags)")
if tag_acc != "N/A":
    print(f"    ✓ Tag accuracy={tag_acc}, Tag preservation={tag_pres}%")
EOFPYTHON
        
        # Collect files for corpus-level BLEU
        # Append translations and references to approach-specific files
        # Use quotes to handle filenames with spaces
        if [ -f "$trans_file" ]; then
            cat "$trans_file" >> "${CORPUS_DIR}/${approach_name}.translations.tags"
            cat "$ref_mos" >> "${CORPUS_DIR}/${approach_name}.references.tags"
        fi
        if [ -f "$trans_file_notags" ] && [ -f "$ref_mos_notags" ]; then
            cat "$trans_file_notags" >> "${CORPUS_DIR}/${approach_name}.translations.notags"
            cat "$ref_mos_notags" >> "${CORPUS_DIR}/${approach_name}.references.notags"
        fi
        
        # Clean up temp files
        #rm -f "$eval_with_tags_out" "$eval_notags_out" "$tag_placement_out" "$sacrebleu_with_tags_out" "$sacrebleu_notags_out"
        
        echo ""
    done
    
    total_approaches=$((total_approaches + approach_num))
    echo ""
done

echo ""
echo "================================================================"
echo "EVALUATION COMPLETE"
echo "================================================================"
echo ""
echo "Statistics:"
echo "  Documents evaluated:  ${total_docs}"
echo "  Total evaluations:    ${total_evals}"
if [ ${#FILTER_APPROACHES[@]} -gt 0 ]; then
    echo "  Filter applied:       ${FILTER_APPROACHES[*]}"
fi
if [ $total_docs -gt 0 ]; then
    echo "  Avg approaches/doc:   $((total_evals / total_docs))"
fi
echo ""
echo "Output files:"
echo "  Scores CSV: ${SCORES_CSV}"
echo "  Eval log:   ${EVAL_LOG}"
echo ""

# Compute corpus-level BLEU scores
echo "Computing corpus-level BLEU scores (all documents combined)..."
CORPUS_BLEU_CSV="${RESULTS_DIR}/corpus_bleu.csv"
echo "approach,corpus_bleu_with_tags,corpus_bleu_without_tags,num_segments_tags,num_segments_notags" > "${CORPUS_BLEU_CSV}"

for approach_file in "${CORPUS_DIR}"/*.translations.tags; do
    if [ ! -f "$approach_file" ]; then
        continue
    fi
    
    approach_name=$(basename "$approach_file" .translations.tags)
    trans_tags="${CORPUS_DIR}/${approach_name}.translations.tags"
    ref_tags="${CORPUS_DIR}/${approach_name}.references.tags"
    trans_notags="${CORPUS_DIR}/${approach_name}.translations.notags"
    ref_notags="${CORPUS_DIR}/${approach_name}.references.notags"
    
    # Count segments
    num_segs_tags=$(wc -l < "$trans_tags" 2>/dev/null || echo "0")
    num_segs_notags=$(wc -l < "$trans_notags" 2>/dev/null || echo "0")
    
    # Compute BLEU with tags
    bleu_tags="N/A"
    if [ -f "$trans_tags" ] && [ -f "$ref_tags" ] && command -v sacrebleu &> /dev/null; then
        bleu_tags=$(sacrebleu "$ref_tags" -i "$trans_tags" -m bleu -b -w 2 2>/dev/null || echo "N/A")
    fi
    
    # Compute BLEU without tags
    bleu_notags="N/A"
    if [ -f "$trans_notags" ] && [ -f "$ref_notags" ] && command -v sacrebleu &> /dev/null; then
        bleu_notags=$(sacrebleu "$ref_notags" -i "$trans_notags" -m bleu -b -w 2 2>/dev/null || echo "N/A")
    fi
    
    echo "${approach_name},${bleu_tags},${bleu_notags},${num_segs_tags},${num_segs_notags}" >> "${CORPUS_BLEU_CSV}"
    echo "  ${approach_name}: BLEU=${bleu_tags} (with tags), ${bleu_notags} (without tags) [${num_segs_tags} segments]"
done

echo ""

# Clean up corpus directory
rm -rf "${CORPUS_DIR}"

# Generate summary statistics
echo "Generating summary statistics..."

python3 <<EOFPYTHON
import pandas as pd
import sys

csv_file = "${RESULTS_DIR}/scores.csv"
corpus_bleu_file = "${RESULTS_DIR}/corpus_bleu.csv"
summary_file = "${RESULTS_DIR}/summary.txt"

try:
    df = pd.read_csv(csv_file)
    
    # Try to load corpus BLEU scores
    corpus_bleu_df = None
    try:
        corpus_bleu_df = pd.read_csv(corpus_bleu_file)
    except:
        pass
    
    # Convert numeric columns
    numeric_cols = ['bleu', 'bleu_notags', 'xml_struct_acc', 'xml_match_acc', 
                    'ne_num_prec', 'ne_num_rec', 'tag_acc', 'tag_preservation',
                    'avg_char_diff', 'incons_pct']
    
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors='coerce')
    
    with open(summary_file, 'w') as f:
        f.write("=" * 80 + "\n")
        f.write("VALIDATION SET - EVALUATION SUMMARY (EVALUATION ONLY)\n")
        f.write("=" * 80 + "\n\n")
        
        # Overall statistics
        f.write("OVERALL STATISTICS\n")
        f.write("-" * 80 + "\n")
        num_docs = df['doc_id'].nunique() if len(df) > 0 else 0
        num_evals = len(df)
        f.write(f"Total documents:         {num_docs}\n")
        f.write(f"Total evaluations:       {num_evals}\n")
        f.write(f"Languages:               {', '.join(df['lang'].unique()) if len(df) > 0 else 'N/A'}\n")
        f.write(f"Unique approaches:       {df['approach'].nunique() if len(df) > 0 else 0}\n")
        if num_docs > 0:
            f.write(f"Evaluations per doc:     {num_evals / num_docs:.1f}\n")
        else:
            f.write(f"Evaluations per doc:     N/A\n")
        f.write("\n")
        
        # List all approaches
        f.write("APPROACHES EVALUATED\n")
        f.write("-" * 80 + "\n")
        for i, approach in enumerate(sorted(df['approach'].unique()), 1):
            count = len(df[df['approach'] == approach])
            f.write(f"{i:2d}. {approach} ({count} docs)\n")
        f.write("\n")
        
        # Average scores by approach
        f.write("AVERAGE SCORES BY APPROACH\n")
        f.write("-" * 80 + "\n")
        f.write("\nSorted by BLEU (with tags):\n\n")
        
        by_approach = df.groupby('approach')[numeric_cols].mean().sort_values('bleu', ascending=False)
        
        # Format table
        f.write(f"{'Approach':<40} {'BLEU':<8} {'BLEU-NT':<8} {'TagAcc':<8} {'TagPres':<8}\n")
        f.write("-" * 80 + "\n")
        for approach, row in by_approach.iterrows():
            bleu = f"{row['bleu']:.2f}" if pd.notna(row['bleu']) else "N/A"
            bleu_nt = f"{row['bleu_notags']:.2f}" if pd.notna(row['bleu_notags']) else "N/A"
            tag_acc = f"{row['tag_acc']:.2f}" if pd.notna(row['tag_acc']) else "N/A"
            tag_pres = f"{row['tag_preservation']:.1f}" if pd.notna(row['tag_preservation']) else "N/A"
            f.write(f"{approach:<40} {bleu:<8} {bleu_nt:<8} {tag_acc:<8} {tag_pres:<8}\n")
        f.write("\n")
        
        # Detailed statistics table
        f.write("DETAILED STATISTICS BY APPROACH\n")
        f.write("-" * 80 + "\n\n")
        f.write(by_approach.to_string())
        f.write("\n\n")
        
        # Tag-aware vs tag-free comparison
        f.write("TAG-AWARE VS TAG-FREE COMPARISON\n")
        f.write("-" * 80 + "\n")
        f.write("Average BLEU score difference (with tags - without tags):\n\n")
        
        df['bleu_diff'] = df['bleu'] - df['bleu_notags']
        by_approach_diff = df.groupby('approach')['bleu_diff'].mean().sort_values()
        
        for approach, diff in by_approach_diff.items():
            if pd.notna(diff):
                impact = "hurt" if diff < 0 else "helped"
                f.write(f"  {approach:<40} {diff:+.2f} (tags {impact})\n")
        f.write("\n")
        
        # Overall averages
        f.write("OVERALL AVERAGES (ALL APPROACHES)\n")
        f.write("-" * 80 + "\n")
        overall = df[numeric_cols].mean()
        for col in numeric_cols:
            if pd.notna(overall[col]):
                f.write(f"{col:<25} {overall[col]:.2f}\n")
        f.write("\n")
        
        # Add corpus-level BLEU scores section
        if corpus_bleu_df is not None and len(corpus_bleu_df) > 0:
            f.write("=" * 80 + "\n")
            f.write("CORPUS-LEVEL BLEU SCORES (All Documents Combined)\n")
            f.write("=" * 80 + "\n\n")
            f.write("These scores are computed across ALL segments from ALL documents,\n")
            f.write("giving a single BLEU score per approach for the entire corpus.\n\n")
            
            f.write(f"{'Approach':<50} {'BLEU (tags)':<15} {'BLEU (notags)':<15} {'Segments':<10}\n")
            f.write("-" * 90 + "\n")
            
            # Sort by BLEU without tags (descending)
            for _, row in corpus_bleu_df.sort_values('corpus_bleu_without_tags', ascending=False, na_position='last').iterrows():
                try:
                    bleu_tags = f"{float(row['corpus_bleu_with_tags']):.2f}" if pd.notna(row['corpus_bleu_with_tags']) else "N/A"
                except:
                    bleu_tags = str(row['corpus_bleu_with_tags']) if pd.notna(row['corpus_bleu_with_tags']) else "N/A"
                
                try:
                    bleu_notags = f"{float(row['corpus_bleu_without_tags']):.2f}" if pd.notna(row['corpus_bleu_without_tags']) else "N/A"
                except:
                    bleu_notags = str(row['corpus_bleu_without_tags']) if pd.notna(row['corpus_bleu_without_tags']) else "N/A"
                
                segs = int(row['num_segments_tags']) if pd.notna(row['num_segments_tags']) else 0
                f.write(f"{row['approach']:<50} {bleu_tags:<15} {bleu_notags:<15} {segs:<10}\n")
            f.write("\n")
        
    print(f"✓ Summary statistics saved to {summary_file}")
    if corpus_bleu_df is not None:
        print(f"✓ Corpus-level BLEU scores included in summary")
    
except Exception as e:
    print(f"⚠️  Error generating summary: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOFPYTHON

echo ""
echo "To view results:"
echo "  cat ${SUMMARY_FILE}"
echo "  column -t -s, ${SCORES_CSV} | less -S"
echo "  cat ${RESULTS_DIR}/corpus_bleu.csv"
echo ""
echo "================================================================"

