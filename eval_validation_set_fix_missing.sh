#!/bin/bash
set -x

# Evaluate all validation documents
cd /home/cepin/ctk_testsets

VALID_DIR="splits/valid_fix_missing"
RESULTS_DIR="validation_results_fix_missing"
SUMMARY_FILE="${RESULTS_DIR}/summary.txt"
SCORES_CSV="${RESULTS_DIR}/scores.csv"

echo "================================================================"
echo "VALIDATION SET EVALUATION"
echo "================================================================"
echo ""
echo "Evaluating all documents in ${VALID_DIR}"
echo "Results will be saved to ${RESULTS_DIR}/"
echo ""

# Clean and create results directory
#rm -rf "${RESULTS_DIR}"
mkdir -p "${RESULTS_DIR}"

# Initialize CSV with header
echo "doc_id,lang,approach,bleu,xml_struct_acc,xml_match_acc,ne_num_prec,ne_num_rec,tag_acc,avg_char_diff,incons_pct,tag_preservation" > "${SCORES_CSV}"

# Counter
total_docs=0
total_evals=0

# Find all HTML document directories
for doc_dir in ${VALID_DIR}/data/html/html_*; do
    doc_id=$(basename "$doc_dir")
    
    # Check if both Ukrainian and Czech versions exist
    uk_dir="${doc_dir}/uk"
    cs_dir="${doc_dir}/cs"
    
    if [ ! -d "${uk_dir}" ]; then
        echo "⚠️  No Ukrainian version for ${doc_id}, skipping"
        continue
    fi
    
    if [ ! -d "${cs_dir}" ]; then
        echo "⚠️  No Czech version for ${doc_id}, skipping"
        continue
    fi
    
    # Get Ukrainian source HTML
    uk_html=$(find "${uk_dir}" -name "*.html" -type f | head -1)
    if [ -z "$uk_html" ]; then
        echo "⚠️  No Ukrainian HTML file for ${doc_id}, skipping"
        continue
    fi
    
    # Get Czech reference HTML
    cs_html=$(find "${cs_dir}" -name "*.html" -type f | head -1)
    if [ -z "$cs_html" ]; then
        echo "⚠️  No Czech HTML file for ${doc_id}, skipping"
        continue
    fi
    
    total_docs=$((total_docs + 1))
    
    echo ""
    echo "================================================================"
    echo "DOCUMENT ${total_docs}: ${doc_id}"
    echo "================================================================"
    echo "Source (UK): ${uk_html}"
    echo "Reference (CS): ${cs_html}"
    echo ""
    
    # Create output directory for this document
    out_dir="${RESULTS_DIR}/${doc_id}_uk2cs"
    mkdir -p "${out_dir}"
    
    # Run evaluation script (Ukrainian source → Czech reference)
    echo "  → Running eval_all_approaches.sh (uk→cs)..."
    
    # Capture output and move results
    if bash eval_all_approaches_fix_missing.sh "${uk_html}" "${cs_html}" "cs" > "${out_dir}/eval.log" 2>&1; then
            echo "  ✓ Evaluation completed"
            
            # Move output files to organized directory
            if [ -d "out_fix_missing" ]; then
                mv out_fix_missing/* "${out_dir}/" 2>/dev/null || true
            fi
            
            # Parse and extract scores from eval.log
            python3 <<EOF
import re
import sys

doc_id = "${doc_id}"
lang = "cs"
log_file = "${out_dir}/eval.log"

try:
    with open(log_file, 'r') as f:
        content = f.read()
    
    # Find all APPROACH sections
    approach_pattern = r'APPROACH (\d+): ([^\n]+)'
    approaches = re.findall(approach_pattern, content)
    
    # Extract BLEU scores
    bleu_pattern = r'BLEU\s*=\s*([\d.]+)'
    
    # For each approach, try to extract scores
    approach_sections = re.split(r'={40,}', content)
    
    with open("${SCORES_CSV}", 'a') as csv:
        for i, (num, name) in enumerate(approaches):
            # Find relevant section
            section_start = content.find(f"APPROACH {num}:")
            if section_start == -1:
                continue
            
            # Find next approach or end
            next_approach = content.find(f"APPROACH {int(num)+1}:", section_start + 1)
            if next_approach == -1:
                section = content[section_start:]
            else:
                section = content[section_start:next_approach]
            
            # Extract BLEU
            bleu_match = re.search(r'BLEU\s*=\s*([\d.]+)', section)
            bleu = bleu_match.group(1) if bleu_match else "N/A"
            
            # Extract XML structure accuracy
            xml_struct_match = re.search(r'XML Structure Accuracy:\s*([\d.]+)%', section)
            xml_struct = xml_struct_match.group(1) if xml_struct_match else "N/A"
            
            # Extract XML matching accuracy
            xml_match_match = re.search(r'XML Matching Accuracy:\s*([\d.]+)%', section)
            xml_match = xml_match_match.group(1) if xml_match_match else "N/A"
            
            # Extract NE&NUM precision/recall
            ne_prec_match = re.search(r'NE&NUM Precision:\s*([\d.]+)%', section)
            ne_prec = ne_prec_match.group(1) if ne_prec_match else "N/A"
            
            ne_rec_match = re.search(r'NE&NUM Recall:\s*([\d.]+)%', section)
            ne_rec = ne_rec_match.group(1) if ne_rec_match else "N/A"
            
            # Extract tag accuracy (from tag placement)
            tag_acc_match = re.search(r'accuracy:\s*([\d.]+)', section)
            tag_acc = tag_acc_match.group(1) if tag_acc_match else "N/A"
            
            # Extract average character difference
            char_diff_match = re.search(r'Average Character Difference:\s*([\d.]+)', section)
            char_diff = char_diff_match.group(1) if char_diff_match else "N/A"
            
            # Extract inconsistent sentences percentage
            incons_match = re.search(r'Inconsistent Sentences Percentage:\s*([\d.]+)%', section)
            incons = incons_match.group(1) if incons_match else "N/A"
            
            # Extract tag preservation rate
            tag_pres_match = re.search(r'Tag preservation rate:\s*([\d.]+)%', section)
            tag_pres = tag_pres_match.group(1) if tag_pres_match else "N/A"
            
            # Write to CSV
            approach_name_clean = name.strip().replace(',', ';')
            csv.write(f"{doc_id},{lang},{num}_{approach_name_clean},{bleu},{xml_struct},{xml_match},{ne_prec},{ne_rec},{tag_acc},{char_diff},{incons},{tag_pres}\n")
            
    print(f"  ✓ Scores extracted for {len(approaches)} approaches")

except Exception as e:
    print(f"  ⚠️  Error parsing scores: {e}", file=sys.stderr)
EOF
            
            total_evals=$((total_evals + 1))
        else
            echo "  ❌ Evaluation failed (see ${out_dir}/eval.log)"
        fi
        
        echo ""
done

echo ""
echo "================================================================"
echo "EVALUATION COMPLETE"
echo "================================================================"
echo ""
echo "Total documents evaluated: ${total_docs}"
echo "Total evaluations: ${total_evals}"
echo ""
echo "Results saved to:"
echo "  - Individual outputs: ${RESULTS_DIR}/<doc_id>_<lang>/"
echo "  - Scores CSV: ${SCORES_CSV}"
echo ""
echo "To view aggregated scores:"
echo "  column -t -s, ${SCORES_CSV} | less -S"
echo ""

# Generate summary statistics
python3 <<'EOFPYTHON'
import pandas as pd
import sys

csv_file = "validation_results/scores.csv"
summary_file = "validation_results/summary.txt"

try:
    df = pd.read_csv(csv_file)
    
    # Convert numeric columns
    numeric_cols = ['bleu', 'xml_struct_acc', 'xml_match_acc', 'ne_num_prec', 'ne_num_rec', 
                    'tag_acc', 'avg_char_diff', 'incons_pct', 'tag_preservation']
    
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors='coerce')
    
    with open(summary_file, 'w') as f:
        f.write("=" * 70 + "\n")
        f.write("VALIDATION SET - EVALUATION SUMMARY\n")
        f.write("=" * 70 + "\n\n")
        
        # Overall statistics
        f.write("OVERALL STATISTICS\n")
        f.write("-" * 70 + "\n")
        f.write(f"Total documents: {df['doc_id'].nunique()}\n")
        f.write(f"Total evaluations: {len(df)}\n")
        f.write(f"Languages: {', '.join(df['lang'].unique())}\n")
        f.write(f"Approaches: {df['approach'].nunique()}\n")
        f.write("\n")
        
        # Average scores by approach
        f.write("AVERAGE SCORES BY APPROACH\n")
        f.write("-" * 70 + "\n")
        
        by_approach = df.groupby('approach')[numeric_cols].mean()
        f.write(by_approach.to_string())
        f.write("\n\n")
        
        # Average scores by language
        f.write("AVERAGE SCORES BY LANGUAGE\n")
        f.write("-" * 70 + "\n")
        
        by_lang = df.groupby('lang')[numeric_cols].mean()
        f.write(by_lang.to_string())
        f.write("\n\n")
        
        # Best performing approaches (by BLEU)
        f.write("TOP 5 APPROACHES BY BLEU SCORE\n")
        f.write("-" * 70 + "\n")
        
        top_bleu = df.groupby('approach')['bleu'].mean().sort_values(ascending=False).head()
        for approach, score in top_bleu.items():
            f.write(f"{approach}: {score:.2f}\n")
        f.write("\n")
        
    print(f"✓ Summary statistics saved to {summary_file}")
    
except Exception as e:
    print(f"⚠️  Error generating summary: {e}", file=sys.stderr)
    sys.exit(1)
EOFPYTHON

echo "To view summary:"
echo "  cat ${SUMMARY_FILE}"
echo ""

