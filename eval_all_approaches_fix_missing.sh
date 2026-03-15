#!/bin/bash
set -x

input_html=$1
ref_html=$2
lang=${3:-cs}  # Default to Czech

b=$(basename "$input_html")

# Create output directory if it doesn't exist
mkdir -p out_fix_missing

# Copy input files for reference
cp "$input_html" out_fix_missing/"$b".input_html
cp "$ref_html" out_fix_missing/"$b".ref_html

# Extract reference MOS segments
./tikal.sh -xm "$ref_html" -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -seg ./config/defaultSegmentation.srx -to out_fix_missing/"$b".ref_mos

# Extract source MOS segments
./tikal.sh -xm "$input_html" -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -seg ./config/defaultSegmentation.srx -to out_fix_missing/"$b".mos

# echo "=========================================="
# echo "APPROACH 1: Direct LLM on full HTML file"
# echo "=========================================="
# #cat "$input_html" | python oai_client.py --full > out_fix_missing/"$b".out_llm_full
# echo "Evaluating with eval_raw.py..."
# ##python eval_raw.py --target out_fix_missing/"$b".ref_html --translation out_fix_missing/"$b".out_llm_full --lang "$lang" --english_term scripts/english_terms.json
# echo "Evaluating tag placement accuracy..."
# ##evaluate-markup-tags out_fix_missing/"$b".ref_html out_fix_missing/"$b".out_llm_full --permissive 2>/dev/null || echo "  (Tag placement evaluation skipped - library not available)"

# echo ""
# echo "=========================================="
# echo "APPROACH 2: LLM on all HTML lines"
# echo "=========================================="
# #cat "$input_html" | python oai_client.py > out_fix_missing/"$b".out_llm_line_by_line_html
# #convert to mos and eval
# ./tikal.sh -lm "$input_html" -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -overtrg -from out_fix_missing/"$b".out_llm_line_by_line_html -to out_fix_missing/"$b".out_llm_line_by_line_html.mos -seg ./config/defaultSegmentation.srx
# echo "--- Evaluation WITH tags ---"
# #python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_llm_line_by_line_html.mos --lang "$lang" --english_term scripts/english_terms.json
# echo "Tag placement accuracy..."
# #evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_llm_line_by_line_html.mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
# echo ""
# echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
# python remove_tags.py out_fix_missing/"$b".out_llm_line_by_line_html.mos out_fix_missing/"$b".out_llm_line_by_line_html.mos.notags --decode-entities
# #python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".out_llm_line_by_line_html.mos.notags --lang "$lang" 


# echo ""
# echo "=========================================="
# echo "APPROACH 2: LLM on all MOS segments (full)"
# echo "=========================================="
#cat out_fix_missing/"$b".mos."$lang" | python oai_client.py --full > out_fix_missing/"$b".out_llm_full_mos
# ./tikal.sh -lm "$input_html" -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -overtrg -from out_fix_missing/"$b".out_llm_full_mos -to out_fix_missing/"$b".out_llm_full_html -seg ./config/defaultSegmentation.srx
# echo "Evaluating segments..."
# ##python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_llm_full_mos --lang "$lang" --english_term scripts/english_terms.json
# echo "Tag placement accuracy..."
# ##evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_llm_full_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"

echo ""
echo "=========================================="
echo "APPROACH 5: Lindat full HTML file"
echo "=========================================="
cat "$input_html" | python translate_lindat_file.py --src uk --tgt "$lang" --model gpt-4.1-nano > out_fix_missing/"$b".out_lindat_full_html
# convert  output to mos for evaluation
cp out_fix_missing/"$b".out_lindat_full_html out_fix_missing/"$b".out_lindat_full_html.html
./tikal.sh -xm out_fix_missing/"$b".out_lindat_full_html.html -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -seg ./config/defaultSegmentation.srx -to out_fix_missing/"$b".out_lindat_full_html.mos
mv  out_fix_missing/"$b".out_lindat_full_html.mos."$lang" out_fix_missing/"$b".out_lindat_full_html.mos
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_lindat_full_html.mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_lindat_full_html.mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py out_fix_missing/"$b".out_lindat_full_html.mos out_fix_missing/"$b".out_lindat_full_html.mos.notags --decode-entities
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".out_lindat_full_html.mos.notags --lang "$lang" 

exit

echo ""
echo "=========================================="
echo "APPROACH 3: LLM segment-by-segment MOS"
echo "=========================================="
cat out_fix_missing/"$b".mos."$lang" | python oai_client.py > out_fix_missing/"$b".out_llm_seg_by_seg_mos
cp out_fix_missing/"$b".out_llm_seg_by_seg_mos out_fix_missing/"$b".out_llm_seg_by_seg_mos.mos
./tikal.sh -lm "$input_html" -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -overtrg -from out_fix_missing/"$b".out_llm_seg_by_seg_mos -to out_fix_missing/"$b".out_llm_seg_by_seg_mos.html -seg ./config/defaultSegmentation.srx
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_llm_seg_by_seg_mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_llm_seg_by_seg_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py out_fix_missing/"$b".out_llm_seg_by_seg_mos out_fix_missing/"$b".out_llm_seg_by_seg_mos.notags --decode-entities
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".out_llm_seg_by_seg_mos.notags --lang "$lang" 

echo ""
echo "=========================================="
echo "APPROACH 4: LLM segment-by-segment MOS with context"
echo "=========================================="
cat out_fix_missing/"$b".mos."$lang" | python oai_client.py --context 1 > out_fix_missing/"$b".out_llm_context_mos
cp out_fix_missing/"$b".out_llm_context_mos out_fix_missing/"$b".out_llm_context_mos.mos
./tikal.sh -lm "$input_html" -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -overtrg -from out_fix_missing/"$b".out_llm_context_mos -to out_fix_missing/"$b".out_llm_context_mos.html -seg ./config/defaultSegmentation.srx
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_llm_context_mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_llm_context_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py out_fix_missing/"$b".out_llm_context_mos out_fix_missing/"$b".out_llm_context_mos.notags --decode-entities
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".out_llm_context_mos.notags --lang "$lang"

echo ""
echo "=========================================="
echo "APPROACH 5: Lindat full HTML file"
echo "=========================================="
cat "$input_html" | python translate_lindat_file.py --src uk --tgt "$lang" --model gpt-4.1-nano > out_fix_missing/"$b".out_lindat_full_html
# convert  output to mos for evaluation
cp out_fix_missing/"$b".out_lindat_full_html out_fix_missing/"$b".out_lindat_full_html.html
./tikal.sh -xm out_fix_missing/"$b".out_lindat_full_html.html -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -seg ./config/defaultSegmentation.srx -to out_fix_missing/"$b".out_lindat_full_html.mos
mv  out_fix_missing/"$b".out_lindat_full_html.mos."$lang" out_fix_missing/"$b".out_lindat_full_html.mos
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_lindat_full_html.mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_lindat_full_html.mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py out_fix_missing/"$b".out_lindat_full_html.mos out_fix_missing/"$b".out_lindat_full_html.mos.notags --decode-entities
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".out_lindat_full_html.mos.notags --lang "$lang" 


# echo ""
# echo "=========================================="
# echo "APPROACH 6: Lindat HTML segment-by-segment, handle tags"
# echo "=========================================="
# #cat "$input_html" | python translate_lindat_file.py --src uk --tgt "$lang" --model gpt-4.1-nano > out_fix_missing/"$b".out_lindat_seg_by_seg_html
# cp out_fix_missing/"$b".out_lindat_seg_by_seg_html out_fix_missing/"$b".out_lindat_seg_by_seg_html.html
# ./tikal.sh -xm out_fix_missing/"$b".out_lindat_seg_by_seg_html.html -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -seg ./config/defaultSegmentation.srx -to out_fix_missing/"$b".out_lindat_seg_by_seg_html.mos
# mv  out_fix_missing/"$b".out_lindat_seg_by_seg_html.mos."$lang" out_fix_missing/"$b".out_lindat_seg_by_seg_html.mos
# echo "--- Evaluation WITH tags ---"
# #python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_lindat_seg_by_seg_html.mos --lang "$lang" --english_term scripts/english_terms.json
# echo "Tag placement accuracy..."
# #evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_lindat_seg_by_seg_html.mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
# echo ""
# echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
# python remove_tags.py out_fix_missing/"$b".out_lindat_seg_by_seg_html.mos out_fix_missing/"$b".out_lindat_seg_by_seg_html.mos.notags --decode-entities
# #python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".out_lindat_seg_by_seg_html.mos.notags --lang "$lang" 

#  echo ""
#  echo "=========================================="
#  echo "APPROACH 7: Lindat HTML segment-by-segment, do not handle tags"
#  echo "=========================================="
# # #read html line by line
# cat "$input_html" | while read -r line; do echo "$line" | python lindat_client.py --src uk --tgt "$lang" --model gpt-4.1-nano; done > out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_html
# cp out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_html out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_html.html
# ./tikal.sh -xm out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_html.html -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -seg ./config/defaultSegmentation.srx -to out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos
# mv  out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos."$lang" out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos
# echo "--- Evaluation WITH tags ---"
# #python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos --lang "$lang" --english_term scripts/english_terms.json
# echo "Tag placement accuracy..."
# #evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
# echo ""
# echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
# python remove_tags.py out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos.notags --decode-entities
# #python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos.notags --lang "$lang" 



echo ""
echo "=========================================="
echo "APPROACH 8: Lindat Plaintext Segment-by-Segment (no tag handling)"
echo "=========================================="
echo "Removes all tags/scripts/styles, translates pure text via Lindat API"
python remove_tags.py out_fix_missing/"$b".mos."$lang" out_fix_missing/"$b".mos."$lang".notags --decode-entities
if true ; then
cat out_fix_missing/"$b".mos."$lang".notags | while read -r line; do 
    if [ -n "$line" ]; then
        echo "$line" | python lindat_client.py --src uk --tgt "$lang" --model gpt-4.1-nano 2>/dev/null || echo "$line"
    else
        echo ""
    fi
done > out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_plaintext
fi
echo "Evaluating segments (plaintext only)..."
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_plaintext --lang "$lang" 2>/dev/null || echo "Evaluation skipped - different segment counts"
# Bleu score with tags using sacrebleu
sacrebleu out_fix_missing/"$b".ref_mos."$lang" -i out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_plaintext   -m bleu -b -w 2 
# Plaintext BLEU score using sacrebleu, tags removed before scoring in both hypothesis and reference
python remove_tags.py out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_plaintext out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_plaintext.notags
python remove_tags.py out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".ref_mos."$lang".notags
sacrebleu ./out_fix_missing/"$b".ref_mos."$lang".notags  -i  ./out_fix_missing/"$b".out_lindat_seg_by_seg_no_tags_handling_plaintext.notags    -m bleu -b -w 2 


echo ""
echo "=========================================="
echo "APPROACH 9: Tag Removal + LLM Translation"                                                                                                                                                                                                
echo "=========================================="
echo "This approach removes tags before translation to measure impact of tags on quality"
python remove_tags.py out_fix_missing/"$b".mos."$lang" out_fix_missing/"$b".mos."$lang".notags --decode-entities
python remove_tags.py out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".ref_mos."$lang".notags --decode-entities
cat out_fix_missing/"$b".mos."$lang".notags | python oai_client.py > out_fix_missing/"$b".llm_seg_by_seg_plaintext
echo "Evaluating segments (without tags, entities decoded)..."
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".llm_seg_by_seg_plaintext --lang "$lang"
# Bleu score with tags using sacrebleu
sacrebleu out_fix_missing/"$b".ref_mos."$lang" -i out_fix_missing/"$b".llm_seg_by_seg_plaintext   -m bleu -b -w 2 
# Plaintext BLEU score using sacrebleu, tags removed before scoring in both hypothesis and reference
python remove_tags.py out_fix_missing/"$b".llm_seg_by_seg_plaintext out_fix_missing/"$b".llm_seg_by_seg_plaintext.notags
python remove_tags.py out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".ref_mos."$lang".notags
sacrebleu ./out_fix_missing/"$b".ref_mos."$lang".notags  -i  ./out_fix_missing/"$b".llm_seg_by_seg_plaintext.notags    -m bleu -b -w 2 

translate_only_prompt="Translate from {src_lang} to {tgt_lang}. Only print out the translation without any explanations. If the source should not be translated (e.g. it is a piece of code, technical term, filename, or a name of a company), simply copy it to the output. Do not try to interpret unusual inputs, if the input is not in {src_lang}, do not translate it. Source text: {text} Translation: "
echo ""
echo "APPROACH 11: LLM with translate only Prompt"
echo "=========================================="
cat out_fix_missing/"$b".mos."$lang" | python oai_client.py --prompt "$translate_only_prompt" > out_fix_missing/"$b".out_llm_translate_only_prompt_mos
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_llm_translate_only_prompt_mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_llm_translate_only_prompt_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".ref_mos."$lang".notags --decode-entities
python remove_tags.py out_fix_missing/"$b".out_llm_translate_only_prompt_mos out_fix_missing/"$b".out_llm_translate_only_prompt_mos.notags --decode-entities
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".out_llm_translate_only_prompt_mos.notags --lang "$lang"


exit


echo ""
echo "=========================================="
echo "APPROACH 10: Tag Removal + LLM with Context"
echo "=========================================="
cat out_fix_missing/"$b".mos."$lang".notags | python oai_client.py --context 1 > out_fix_missing/"$b".llm_seg_by_seg_plaintext_context_mos
echo "Evaluating segments (without tags, entities decoded, with context)..."
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".llm_seg_by_seg_plaintext_context_mos --lang "$lang"

echo ""
echo "=========================================="
echo "PROMPT VARIATION APPROACHES (from tags_eval)"
echo "=========================================="

# Define prompts as per tags_eval/localization-xml-mt/eval.sh
ignore_prompt="Translate the following sentence from ${lang} to Ukrainian and ignore all the markup tags in the source, do not transfer them into the translation. Do not add any explanations, make sure to only output one single line with the translated sentence and nothing else. Source sentence: {text} Ukrainian translation: "
enforce_prompt="Translate the following sentence from ${lang} to Ukrainian, including correctly transferring the markup from the source sentence into the translation. Do not add any explanations, make sure to only output one single line with the translated sentence and nothing else. Source sentence: {text} Ukrainian translation: "

echo ""
echo "APPROACH 11: LLM with 'Ignore Tags' Prompt"
echo "=========================================="
cat out_fix_missing/"$b".mos."$lang" | python oai_client.py --prompt-override "$ignore_prompt" > out_fix_missing/"$b".out_llm_translate_only_prompt_mos
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_llm_translate_only_prompt_mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_llm_translate_only_prompt_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py out_fix_missing/"$b".out_llm_translate_only_prompt_mos out_fix_missing/"$b".out_llm_translate_only_prompt_mos.notags --decode-entities
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".out_llm_translate_only_prompt_mos.notags --lang "$lang"

echo ""
echo "APPROACH 12: LLM with 'Enforce Tags' Prompt"
echo "=========================================="
cat out_fix_missing/"$b".mos."$lang" | python oai_client.py --prompt-override "$enforce_prompt" > out_fix_missing/"$b".out_llm_enforce_prompt_mos
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_llm_enforce_prompt_mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_llm_enforce_prompt_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py out_fix_missing/"$b".out_llm_enforce_prompt_mos out_fix_missing/"$b".out_llm_enforce_prompt_mos.notags --decode-entities
#python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".out_llm_enforce_prompt_mos.notags --lang "$lang"

echo ""
echo "=========================================="
echo "ALTERNATIVE MODEL APPROACHES (if available)"
echo "=========================================="

# Check if translate_lindat_llm.py is available for multi-model testing
if [ -f "tags_eval/localization-xml-mt/translate_lindat_llm.py" ]; then
    echo "APPROACH 13: TowerInstruct Model (tags=True mode)"
    echo "=========================================="
    cat out_fix_missing/"$b".mos."$lang" | python tags_eval/localization-xml-mt/translate_lindat_llm.py "$lang" uk TowerInstruct-7B-v0.2 True "" > out_fix_missing/"$b".out_tower_tags_mos 2>/dev/null || echo "TowerInstruct not available, skipping"
    if [ -f out_fix_missing/"$b".out_tower_tags_mos ] && [ -s out_fix_missing/"$b".out_tower_tags_mos ]; then
        echo "--- Evaluation WITH tags ---"
        #python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_tower_tags_mos --lang "$lang" --english_term scripts/english_terms.json
        echo "Tag placement accuracy..."
        #evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_tower_tags_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
        echo ""
        echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
        python remove_tags.py out_fix_missing/"$b".out_tower_tags_mos out_fix_missing/"$b".out_tower_tags_mos.notags --decode-entities
        #python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".out_tower_tags_mos.notags --lang "$lang"
    fi
    
    echo ""
    echo "APPROACH 14: TowerInstruct Model (tags=False mode)"
    echo "=========================================="
    cat out_fix_missing/"$b".mos."$lang" | python tags_eval/localization-xml-mt/translate_lindat_llm.py "$lang" uk TowerInstruct-7B-v0.2 False "" > out_fix_missing/"$b".out_tower_notags_mos 2>/dev/null || echo "TowerInstruct not available, skipping"
    if [ -f out_fix_missing/"$b".out_tower_notags_mos ] && [ -s out_fix_missing/"$b".out_tower_notags_mos ]; then
        echo "--- Evaluation WITH tags ---"
        #python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_tower_notags_mos --lang "$lang" --english_term scripts/english_terms.json
        echo "Tag placement accuracy..."
        #evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_tower_notags_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
        echo ""
        echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
        python remove_tags.py out_fix_missing/"$b".out_tower_notags_mos out_fix_missing/"$b".out_tower_notags_mos.notags --decode-entities
        #python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".out_tower_notags_mos.notags --lang "$lang"
    fi
    
    echo ""
    echo "APPROACH 15: EuroLLM Model"
    echo "=========================================="
    cat out_fix_missing/"$b".mos."$lang" | python tags_eval/localization-xml-mt/translate_lindat_llm.py "$lang" uk EuroLLM-9B-Instruct False "" > out_fix_missing/"$b".out_eurollm_mos 2>/dev/null || echo "EuroLLM not available, skipping"
    if [ -f out_fix_missing/"$b".out_eurollm_mos ] && [ -s out_fix_missing/"$b".out_eurollm_mos ]; then
        echo "--- Evaluation WITH tags ---"
        #python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang" --translation out_fix_missing/"$b".out_eurollm_mos --lang "$lang" --english_term scripts/english_terms.json
        echo "Tag placement accuracy..."
        #evaluate-markup-tags out_fix_missing/"$b".ref_mos."$lang" out_fix_missing/"$b".out_eurollm_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
        echo ""
        echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
        python remove_tags.py out_fix_missing/"$b".out_eurollm_mos out_fix_missing/"$b".out_eurollm_mos.notags --decode-entities
        #python eval_raw.py --target out_fix_missing/"$b".ref_mos."$lang".notags --translation out_fix_missing/"$b".out_eurollm_mos.notags --lang "$lang"
    fi
else
    echo "translate_lindat_llm.py not available - skipping alternative model approaches"
fi

echo ""
echo "=========================================="
echo "JSON-BASED EVALUATION (Salesforce Format)"
echo "=========================================="
# Convert to JSON format for Salesforce evaluation pipeline
if [ -f "scripts/convert2json.py" ]; then
    echo "Converting to JSON format..."
    
    # Convert best LLM approach to JSON
    python scripts/convert2json.py --input out_fix_missing/"$b".mos."$lang" --output out_fix_missing/"$b".source.json --split dev --lang "$lang" --type source
    python scripts/convert2json.py --input out_fix_missing/"$b".ref_mos."$lang" --output out_fix_missing/"$b".target.json --split dev --lang "$lang" --type target
    
    # Evaluate best performing approaches with JSON-based evaluator
    for approach in "out_llm_context_mos" "out_llm_seg_by_seg_mos" "out_llm_full_mos"; do
        if [ -f "out_fix_missing/${b}.${approach}" ]; then
            echo "Evaluating ${approach} with Salesforce JSON evaluator..."
            python scripts/convert2json.py --input out_fix_missing/"$b"."${approach}" --output out_fix_missing/"$b"."${approach}".json --split dev --lang "$lang" --type translation
            python scripts/evaluate.py --target out_fix_missing/"$b".target.json --translation out_fix_missing/"$b"."${approach}".json --english_term scripts/english_terms.json 2>/dev/null || echo "Note: Some evaluation metrics may require additional dependencies"
        fi
    done
else
    echo "JSON conversion tools not available, skipping Salesforce format evaluation"
fi

echo ""
echo "=========================================="
echo "SUMMARY: Comparison Across All Approaches"
echo "=========================================="
echo "Results saved in out_fix_missing/ directory:"
echo ""
echo "Core Approaches (1-10):"
echo "  1. Direct LLM:            out_fix_missing/${b}.out_llm_full"
echo "  2. LLM full MOS:          out_fix_missing/${b}.out_llm_full_mos"
echo "  3. LLM seg-by-seg:        out_fix_missing/${b}.out_llm_seg_by_seg_mos"
echo "  4. LLM + context:         out_fix_missing/${b}.out_llm_context_mos"
echo "  5. Lindat full HTML:      out_fix_missing/${b}.out_lindat_full_html"
echo "  6. Lindat full MOS:       out_fix_missing/${b}.out_lindat_full_mos"
echo "  7. Lindat seg-by-seg:     out_fix_missing/${b}.out_lindat_seg_by_seg_mos"
echo "  8. Lindat plaintext:      out_fix_missing/${b}.out_lindat_seg_by_seg_no_tags_handling_plaintext"
echo "  9. LLM no tags:           out_fix_missing/${b}.llm_seg_by_seg_plaintext"
echo "  10. LLM no tags+context:  out_fix_missing/${b}.llm_seg_by_seg_plaintext_context_mos"
echo ""
echo "Prompt Variation Approaches (11-12):"
echo "  11. Ignore prompt:        out_fix_missing/${b}.out_llm_translate_only_prompt_mos"
echo "  12. Enforce prompt:       out_fix_missing/${b}.out_llm_enforce_prompt_mos"
echo ""
echo "Alternative Model Approaches (13-15, if available):"
echo "  13. TowerInstruct (tags=True):  out_fix_missing/${b}.out_tower_tags_mos"
echo "  14. TowerInstruct (tags=False): out_fix_missing/${b}.out_tower_notags_mos"
echo "  15. EuroLLM:                    out_fix_missing/${b}.out_eurollm_mos"
echo ""
echo "HTML Reconstructions:"
echo "  - out_fix_missing/${b}.out_*_html files (for full document viewing)"
echo ""
echo "Tag-free baseline files:"
echo "  - out_fix_missing/${b}.mos.${lang}.notags (source without tags)"
echo "  - out_fix_missing/${b}.ref_mos.${lang}.notags (reference without tags)"
echo ""
echo "Recommended comparisons:"
echo "  - Compare 3 vs 9: Measure BLEU impact of tags"
echo "  - Compare 4 vs 10: Does context help more with/without tags?"
echo "  - Compare 3 vs 11 vs 12: Do explicit tag instructions help?"
echo "  - Compare 3 vs 13: Does XML wrapping (tags=True) help?"
echo "  - Compare 4 vs 12: Best context-aware vs best prompt"
echo "  - Compare 8 vs 9: Lindat plaintext vs LLM plaintext"
echo ""
echo "Total Approaches Evaluated: 15"
echo "Evaluation Complete!"
echo "=========================================="
