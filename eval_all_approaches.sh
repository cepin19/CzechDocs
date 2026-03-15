#!/bin/bash
set -x

input_html=$1
ref_html=$2
lang=${3:-cs}  # Default to Czech
model=${4:-gpt-4.1-nano}  # Default model
out_suffix=${5:-}  # Optional output suffix for model-specific directories
base_url=${6:-https://api.openai.com/v1}  # Default OpenAI API endpoint

b=$(basename "$input_html")

# If model-specific suffix provided, use it for output directory
if [ -n "$out_suffix" ]; then
    OUT_DIR="out_${out_suffix}"
else
    OUT_DIR="out"
fi

# Extract model name after slash for lindat (e.g., "meta-llama/Llama-3-70b" → "Llama-3-70b")
if [[ "$model" == *"/"* ]]; then
    lindat_model="${model##*/}"
else
    lindat_model="$model"
fi

echo "Configuration:"
echo "  Model: ${model}"
echo "  Lindat model: ${lindat_model}"
echo "  Base URL: ${base_url}"
echo "  Output dir: ${OUT_DIR}"
echo ""

# Create output directory if it doesn't exist
mkdir -p "${OUT_DIR}"

# Copy input files for reference
cp "$input_html" "${OUT_DIR}/$b.input_html"
cp "$ref_html" "${OUT_DIR}/$b.ref_html"

# Extract reference MOS segments
./tikal.sh -xm "$ref_html" -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -seg ./config/defaultSegmentation.srx -to "${OUT_DIR}/$b.ref_mos"

# Extract source MOS segments
./tikal.sh -xm "$input_html" -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -seg ./config/defaultSegmentation.srx -to "${OUT_DIR}/$b.mos"

# echo "=========================================="
# echo "APPROACH 1: Direct LLM on full HTML file"
# echo "=========================================="
# #cat "$input_html" | python oai_client.py --model "$model" --base-url "$base_url" --full > ${OUT_DIR}/"$b".out_llm_full
# echo "Evaluating with eval_raw.py..."
# ##python eval_raw.py --target ${OUT_DIR}/"$b".ref_html --translation ${OUT_DIR}/"$b".out_llm_full --lang "$lang" --english_term scripts/english_terms.json
# echo "Evaluating tag placement accuracy..."
# ##evaluate-markup-tags ${OUT_DIR}/"$b".ref_html ${OUT_DIR}/"$b".out_llm_full --permissive 2>/dev/null || echo "  (Tag placement evaluation skipped - library not available)"

# echo ""
# echo "=========================================="
# echo "APPROACH 2: LLM on all HTML lines"
# echo "=========================================="
# #cat "$input_html" | python oai_client.py --model "$model" --base-url "$base_url" > ${OUT_DIR}/"$b".out_llm_line_by_line_html
# #convert to mos and eval
# ./tikal.sh -lm "$input_html" -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -overtrg -from ${OUT_DIR}/"$b".out_llm_line_by_line_html -to ${OUT_DIR}/"$b".out_llm_line_by_line_html.mos -seg ./config/defaultSegmentation.srx
# echo "--- Evaluation WITH tags ---"
# #python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_llm_line_by_line_html.mos --lang "$lang" --english_term scripts/english_terms.json
# echo "Tag placement accuracy..."
# #evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_llm_line_by_line_html.mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
# echo ""
# echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
# python remove_tags.py ${OUT_DIR}/"$b".out_llm_line_by_line_html.mos ${OUT_DIR}/"$b".out_llm_line_by_line_html.mos.notags --decode-entities
# #python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_llm_line_by_line_html.mos.notags --lang "$lang" 


# echo ""
# echo "=========================================="
# echo "APPROACH 2: LLM on all MOS segments (full)"
# echo "=========================================="
#cat ${OUT_DIR}/"$b".mos."$lang" | python oai_client.py --model "$model" --base-url "$base_url" --full > ${OUT_DIR}/"$b".out_llm_full_mos
# ./tikal.sh -lm "$input_html" -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -overtrg -from ${OUT_DIR}/"$b".out_llm_full_mos -to ${OUT_DIR}/"$b".out_llm_full_html -seg ./config/defaultSegmentation.srx
# echo "Evaluating segments..."
# ##python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_llm_full_mos --lang "$lang" --english_term scripts/english_terms.json
# echo "Tag placement accuracy..."
# ##evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_llm_full_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"


translate_only_prompt="Translate from {src_lang} to {tgt_lang}, without adding any explanations, copy the untranslatable content to the output: {text}"
echo ""
echo "APPROACH 11: LLM with translate only Prompt"
echo "=========================================="
cat ${OUT_DIR}/"$b".mos."$lang" | python oai_client.py --model "$model" --base-url "$base_url" --prompt "$translate_only_prompt" > ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".ref_mos."$lang".notags --decode-entities
python remove_tags.py ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos.notags --decode-entities
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos.notags --lang "$lang"


exit


echo ""
echo "=========================================="
echo "APPROACH 5: Lindat full HTML file"
echo "=========================================="
cat "$input_html" | python translate_lindat_file.py --src uk --tgt "$lang" --model "$lindat_model" > ${OUT_DIR}/"$b".out_lindat_full_html
# convert  output to mos for evaluation
cp ${OUT_DIR}/"$b".out_lindat_full_html ${OUT_DIR}/"$b".out_lindat_full_html.html
./tikal.sh -xm ${OUT_DIR}/"$b".out_lindat_full_html.html -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -seg ./config/defaultSegmentation.srx -to ${OUT_DIR}/"$b".out_lindat_full_html.mos
mv  ${OUT_DIR}/"$b".out_lindat_full_html.mos."$lang" ${OUT_DIR}/"$b".out_lindat_full_html.mos
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_lindat_full_html.mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_lindat_full_html.mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py ${OUT_DIR}/"$b".out_lindat_full_html.mos ${OUT_DIR}/"$b".out_lindat_full_html.mos.notags --decode-entities
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_lindat_full_html.mos.notags --lang "$lang" 

exit


echo ""
echo "=========================================="
echo "APPROACH 3: LLM segment-by-segment MOS"
echo "=========================================="
echo "Model: ${model}"
cat "${OUT_DIR}/$b.mos.$lang" | python oai_client.py --model "$model" --base-url "$base_url" --model "$model" > "${OUT_DIR}/$b.out_llm_seg_by_seg_mos"
cp ${OUT_DIR}/"$b".out_llm_seg_by_seg_mos ${OUT_DIR}/"$b".out_llm_seg_by_seg_mos.mos
./tikal.sh -lm "$input_html" -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -overtrg -from ${OUT_DIR}/"$b".out_llm_seg_by_seg_mos -to ${OUT_DIR}/"$b".out_llm_seg_by_seg_mos.html -seg ./config/defaultSegmentation.srx
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_llm_seg_by_seg_mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_llm_seg_by_seg_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py ${OUT_DIR}/"$b".out_llm_seg_by_seg_mos ${OUT_DIR}/"$b".out_llm_seg_by_seg_mos.notags --decode-entities
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_llm_seg_by_seg_mos.notags --lang "$lang" 

echo ""
echo "=========================================="
echo "APPROACH 4: LLM segment-by-segment MOS with context"
echo "=========================================="
echo "Model: ${model}"
cat "${OUT_DIR}/$b.mos.$lang" | python oai_client.py --model "$model" --base-url "$base_url" --model "$model" --context 1 > "${OUT_DIR}/$b.out_llm_context_mos"
cp ${OUT_DIR}/"$b".out_llm_context_mos ${OUT_DIR}/"$b".out_llm_context_mos.mos
./tikal.sh -lm "$input_html" -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -overtrg -from ${OUT_DIR}/"$b".out_llm_context_mos -to ${OUT_DIR}/"$b".out_llm_context_mos.html -seg ./config/defaultSegmentation.srx
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_llm_context_mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_llm_context_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py ${OUT_DIR}/"$b".out_llm_context_mos ${OUT_DIR}/"$b".out_llm_context_mos.notags --decode-entities
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_llm_context_mos.notags --lang "$lang"

echo ""
echo "=========================================="
echo "APPROACH 5: Lindat full HTML file"
echo "=========================================="
cat "$input_html" | python translate_lindat_file.py --src uk --tgt "$lang" --model "$lindat_model" > ${OUT_DIR}/"$b".out_lindat_full_html
# convert  output to mos for evaluation
cp ${OUT_DIR}/"$b".out_lindat_full_html ${OUT_DIR}/"$b".out_lindat_full_html.html
./tikal.sh -xm ${OUT_DIR}/"$b".out_lindat_full_html.html -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -seg ./config/defaultSegmentation.srx -to ${OUT_DIR}/"$b".out_lindat_full_html.mos
mv  ${OUT_DIR}/"$b".out_lindat_full_html.mos."$lang" ${OUT_DIR}/"$b".out_lindat_full_html.mos
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_lindat_full_html.mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_lindat_full_html.mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py ${OUT_DIR}/"$b".out_lindat_full_html.mos ${OUT_DIR}/"$b".out_lindat_full_html.mos.notags --decode-entities
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_lindat_full_html.mos.notags --lang "$lang" 


# echo ""
# echo "=========================================="
# echo "APPROACH 6: Lindat HTML segment-by-segment, handle tags"
# echo "=========================================="
# #cat "$input_html" | python translate_lindat_file.py --src uk --tgt "$lang" --model "$lindat_model" > ${OUT_DIR}/"$b".out_lindat_seg_by_seg_html
# cp ${OUT_DIR}/"$b".out_lindat_seg_by_seg_html ${OUT_DIR}/"$b".out_lindat_seg_by_seg_html.html
# ./tikal.sh -xm ${OUT_DIR}/"$b".out_lindat_seg_by_seg_html.html -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -seg ./config/defaultSegmentation.srx -to ${OUT_DIR}/"$b".out_lindat_seg_by_seg_html.mos
# mv  ${OUT_DIR}/"$b".out_lindat_seg_by_seg_html.mos."$lang" ${OUT_DIR}/"$b".out_lindat_seg_by_seg_html.mos
# echo "--- Evaluation WITH tags ---"
# #python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_lindat_seg_by_seg_html.mos --lang "$lang" --english_term scripts/english_terms.json
# echo "Tag placement accuracy..."
# #evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_lindat_seg_by_seg_html.mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
# echo ""
# echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
# python remove_tags.py ${OUT_DIR}/"$b".out_lindat_seg_by_seg_html.mos ${OUT_DIR}/"$b".out_lindat_seg_by_seg_html.mos.notags --decode-entities
# #python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_lindat_seg_by_seg_html.mos.notags --lang "$lang" 

#  echo ""
#  echo "=========================================="
#  echo "APPROACH 7: Lindat HTML segment-by-segment, do not handle tags"
#  echo "=========================================="
# # #read html line by line
# cat "$input_html" | while read -r line; do echo "$line" | python lindat_client.py --src uk --tgt "$lang" --model "$lindat_model"; done > ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_html
# cp ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_html ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_html.html
# ./tikal.sh -xm ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_html.html -sl "$lang" -tl "$lang" -ie utf8 -oe utf8 -seg ./config/defaultSegmentation.srx -to ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos
# mv  ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos."$lang" ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos
# echo "--- Evaluation WITH tags ---"
# #python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos --lang "$lang" --english_term scripts/english_terms.json
# echo "Tag placement accuracy..."
# #evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
# echo ""
# echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
# python remove_tags.py ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos.notags --decode-entities
# #python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_html.mos.notags --lang "$lang" 



echo ""
echo "=========================================="
echo "APPROACH 8: Lindat Plaintext Segment-by-Segment (no tag handling)"
echo "=========================================="
echo "Removes all tags/scripts/styles, translates pure text via Lindat API"
python remove_tags.py ${OUT_DIR}/"$b".mos."$lang" ${OUT_DIR}/"$b".mos."$lang".notags --decode-entities
if true ; then
cat ${OUT_DIR}/"$b".mos."$lang".notags | while read -r line; do 
    if [ -n "$line" ]; then
        echo "$line" | python lindat_client.py --src uk --tgt "$lang" --model "$lindat_model" 2>/dev/null || echo "$line"
    else
        echo ""
    fi
done > ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_plaintext
fi
echo "Evaluating segments (plaintext only)..."
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_plaintext --lang "$lang" 2>/dev/null || echo "Evaluation skipped - different segment counts"
# Bleu score with tags using sacrebleu
sacrebleu ${OUT_DIR}/"$b".ref_mos."$lang" -i ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_plaintext   -m bleu -b -w 2 
# Plaintext BLEU score using sacrebleu, tags removed before scoring in both hypothesis and reference
python remove_tags.py ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_plaintext ${OUT_DIR}/"$b".out_lindat_seg_by_seg_no_tags_handling_plaintext.notags
python remove_tags.py ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".ref_mos."$lang".notags
sacrebleu ./out/"$b".ref_mos."$lang".notags  -i  ./out/"$b".out_lindat_seg_by_seg_no_tags_handling_plaintext.notags    -m bleu -b -w 2 


echo ""
echo "=========================================="
echo "APPROACH 9: Tag Removal + LLM Translation"                                                                                                                                                                                                
echo "=========================================="
echo "This approach removes tags before translation to measure impact of tags on quality"
python remove_tags.py ${OUT_DIR}/"$b".mos."$lang" ${OUT_DIR}/"$b".mos."$lang".notags --decode-entities
python remove_tags.py ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".ref_mos."$lang".notags --decode-entities
cat ${OUT_DIR}/"$b".mos."$lang".notags | python oai_client.py --model "$model" --base-url "$base_url" > ${OUT_DIR}/"$b".llm_seg_by_seg_plaintext
echo "Evaluating segments (without tags, entities decoded)..."
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".llm_seg_by_seg_plaintext --lang "$lang"
# Bleu score with tags using sacrebleu
sacrebleu ${OUT_DIR}/"$b".ref_mos."$lang" -i ${OUT_DIR}/"$b".llm_seg_by_seg_plaintext   -m bleu -b -w 2 
# Plaintext BLEU score using sacrebleu, tags removed before scoring in both hypothesis and reference
python remove_tags.py ${OUT_DIR}/"$b".llm_seg_by_seg_plaintext ${OUT_DIR}/"$b".llm_seg_by_seg_plaintext.notags
python remove_tags.py ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".ref_mos."$lang".notags
sacrebleu ./out/"$b".ref_mos."$lang".notags  -i  ./out/"$b".llm_seg_by_seg_plaintext.notags    -m bleu -b -w 2 

translate_only_prompt="Translate from {src_lang} to {tgt_lang}. Only print out the translation without any explanations. If the source should not be translated (e.g. it is a piece of code, technical term, filename, or a name of a company), simply copy it to the output. Do not try to interpret unusual inputs, if the input is not in {src_lang}, do not translate it. Source text: {text} Translation: "
echo ""
echo "APPROACH 11: LLM with translate only Prompt"
echo "=========================================="
cat ${OUT_DIR}/"$b".mos."$lang" | python oai_client.py --model "$model" --base-url "$base_url" --prompt "$translate_only_prompt" > ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".ref_mos."$lang".notags --decode-entities
python remove_tags.py ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos.notags --decode-entities
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos.notags --lang "$lang"


exit


echo ""
echo "=========================================="
echo "APPROACH 10: Tag Removal + LLM with Context"
echo "=========================================="
cat ${OUT_DIR}/"$b".mos."$lang".notags | python oai_client.py --model "$model" --base-url "$base_url" --context 1 > ${OUT_DIR}/"$b".llm_seg_by_seg_plaintext_context_mos
echo "Evaluating segments (without tags, entities decoded, with context)..."
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".llm_seg_by_seg_plaintext_context_mos --lang "$lang"

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
cat ${OUT_DIR}/"$b".mos."$lang" | python oai_client.py --model "$model" --base-url "$base_url" --prompt-override "$ignore_prompt" > ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos.notags --decode-entities
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_llm_translate_only_prompt_mos.notags --lang "$lang"

echo ""
echo "APPROACH 12: LLM with 'Enforce Tags' Prompt"
echo "=========================================="
cat ${OUT_DIR}/"$b".mos."$lang" | python oai_client.py --model "$model" --base-url "$base_url" --prompt-override "$enforce_prompt" > ${OUT_DIR}/"$b".out_llm_enforce_prompt_mos
echo "--- Evaluation WITH tags ---"
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_llm_enforce_prompt_mos --lang "$lang" --english_term scripts/english_terms.json
echo "Tag placement accuracy..."
#evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_llm_enforce_prompt_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
echo ""
echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
python remove_tags.py ${OUT_DIR}/"$b".out_llm_enforce_prompt_mos ${OUT_DIR}/"$b".out_llm_enforce_prompt_mos.notags --decode-entities
#python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_llm_enforce_prompt_mos.notags --lang "$lang"

echo ""
echo "=========================================="
echo "ALTERNATIVE MODEL APPROACHES (if available)"
echo "=========================================="

# Check if translate_lindat_llm.py is available for multi-model testing
if [ -f "tags_eval/localization-xml-mt/translate_lindat_llm.py" ]; then
    echo "APPROACH 13: TowerInstruct Model (tags=True mode)"
    echo "=========================================="
    cat ${OUT_DIR}/"$b".mos."$lang" | python tags_eval/localization-xml-mt/translate_lindat_llm.py "$lang" uk TowerInstruct-7B-v0.2 True "" > ${OUT_DIR}/"$b".out_tower_tags_mos 2>/dev/null || echo "TowerInstruct not available, skipping"
    if [ -f ${OUT_DIR}/"$b".out_tower_tags_mos ] && [ -s ${OUT_DIR}/"$b".out_tower_tags_mos ]; then
        echo "--- Evaluation WITH tags ---"
        #python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_tower_tags_mos --lang "$lang" --english_term scripts/english_terms.json
        echo "Tag placement accuracy..."
        #evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_tower_tags_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
        echo ""
        echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
        python remove_tags.py ${OUT_DIR}/"$b".out_tower_tags_mos ${OUT_DIR}/"$b".out_tower_tags_mos.notags --decode-entities
        #python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_tower_tags_mos.notags --lang "$lang"
    fi
    
    echo ""
    echo "APPROACH 14: TowerInstruct Model (tags=False mode)"
    echo "=========================================="
    cat ${OUT_DIR}/"$b".mos."$lang" | python tags_eval/localization-xml-mt/translate_lindat_llm.py "$lang" uk TowerInstruct-7B-v0.2 False "" > ${OUT_DIR}/"$b".out_tower_notags_mos 2>/dev/null || echo "TowerInstruct not available, skipping"
    if [ -f ${OUT_DIR}/"$b".out_tower_notags_mos ] && [ -s ${OUT_DIR}/"$b".out_tower_notags_mos ]; then
        echo "--- Evaluation WITH tags ---"
        #python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_tower_notags_mos --lang "$lang" --english_term scripts/english_terms.json
        echo "Tag placement accuracy..."
        #evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_tower_notags_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
        echo ""
        echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
        python remove_tags.py ${OUT_DIR}/"$b".out_tower_notags_mos ${OUT_DIR}/"$b".out_tower_notags_mos.notags --decode-entities
        #python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_tower_notags_mos.notags --lang "$lang"
    fi
    
    echo ""
    echo "APPROACH 15: EuroLLM Model"
    echo "=========================================="
    cat ${OUT_DIR}/"$b".mos."$lang" | python tags_eval/localization-xml-mt/translate_lindat_llm.py "$lang" uk EuroLLM-9B-Instruct False "" > ${OUT_DIR}/"$b".out_eurollm_mos 2>/dev/null || echo "EuroLLM not available, skipping"
    if [ -f ${OUT_DIR}/"$b".out_eurollm_mos ] && [ -s ${OUT_DIR}/"$b".out_eurollm_mos ]; then
        echo "--- Evaluation WITH tags ---"
        #python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang" --translation ${OUT_DIR}/"$b".out_eurollm_mos --lang "$lang" --english_term scripts/english_terms.json
        echo "Tag placement accuracy..."
        #evaluate-markup-tags ${OUT_DIR}/"$b".ref_mos."$lang" ${OUT_DIR}/"$b".out_eurollm_mos --permissive 2>/dev/null || echo "  (Tag placement skipped)"
        echo ""
        echo "--- Evaluation WITHOUT tags (pure translation quality) ---"
        python remove_tags.py ${OUT_DIR}/"$b".out_eurollm_mos ${OUT_DIR}/"$b".out_eurollm_mos.notags --decode-entities
        #python eval_raw.py --target ${OUT_DIR}/"$b".ref_mos."$lang".notags --translation ${OUT_DIR}/"$b".out_eurollm_mos.notags --lang "$lang"
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
    python scripts/convert2json.py --input ${OUT_DIR}/"$b".mos."$lang" --output ${OUT_DIR}/"$b".source.json --split dev --lang "$lang" --type source
    python scripts/convert2json.py --input ${OUT_DIR}/"$b".ref_mos."$lang" --output ${OUT_DIR}/"$b".target.json --split dev --lang "$lang" --type target
    
    # Evaluate best performing approaches with JSON-based evaluator
    for approach in "out_llm_context_mos" "out_llm_seg_by_seg_mos" "out_llm_full_mos"; do
        if [ -f "out/${b}.${approach}" ]; then
            echo "Evaluating ${approach} with Salesforce JSON evaluator..."
            python scripts/convert2json.py --input ${OUT_DIR}/"$b"."${approach}" --output ${OUT_DIR}/"$b"."${approach}".json --split dev --lang "$lang" --type translation
            python scripts/evaluate.py --target ${OUT_DIR}/"$b".target.json --translation ${OUT_DIR}/"$b"."${approach}".json --english_term scripts/english_terms.json 2>/dev/null || echo "Note: Some evaluation metrics may require additional dependencies"
        fi
    done
else
    echo "JSON conversion tools not available, skipping Salesforce format evaluation"
fi

echo ""
echo "=========================================="
echo "SUMMARY: Comparison Across All Approaches"
echo "=========================================="
echo "Results saved in ${OUT_DIR}/ directory:"
echo ""
echo "Core Approaches (1-10):"
echo "  1. Direct LLM:            ${OUT_DIR}/${b}.out_llm_full"
echo "  2. LLM full MOS:          ${OUT_DIR}/${b}.out_llm_full_mos"
echo "  3. LLM seg-by-seg:        ${OUT_DIR}/${b}.out_llm_seg_by_seg_mos"
echo "  4. LLM + context:         ${OUT_DIR}/${b}.out_llm_context_mos"
echo "  5. Lindat full HTML:      ${OUT_DIR}/${b}.out_lindat_full_html"
echo "  6. Lindat full MOS:       ${OUT_DIR}/${b}.out_lindat_full_mos"
echo "  7. Lindat seg-by-seg:     ${OUT_DIR}/${b}.out_lindat_seg_by_seg_mos"
echo "  8. Lindat plaintext:      ${OUT_DIR}/${b}.out_lindat_seg_by_seg_no_tags_handling_plaintext"
echo "  9. LLM no tags:           ${OUT_DIR}/${b}.llm_seg_by_seg_plaintext"
echo "  10. LLM no tags+context:  ${OUT_DIR}/${b}.llm_seg_by_seg_plaintext_context_mos"
echo ""
echo "Prompt Variation Approaches (11-12):"
echo "  11. Ignore prompt:        ${OUT_DIR}/${b}.out_llm_translate_only_prompt_mos"
echo "  12. Enforce prompt:       ${OUT_DIR}/${b}.out_llm_enforce_prompt_mos"
echo ""
echo "Alternative Model Approaches (13-15, if available):"
echo "  13. TowerInstruct (tags=True):  ${OUT_DIR}/${b}.out_tower_tags_mos"
echo "  14. TowerInstruct (tags=False): ${OUT_DIR}/${b}.out_tower_notags_mos"
echo "  15. EuroLLM:                    ${OUT_DIR}/${b}.out_eurollm_mos"
echo ""
echo "HTML Reconstructions:"
echo "  - ${OUT_DIR}/${b}.out_*_html files (for full document viewing)"
echo ""
echo "Tag-free baseline files:"
echo "  - ${OUT_DIR}/${b}.mos.${lang}.notags (source without tags)"
echo "  - ${OUT_DIR}/${b}.ref_mos.${lang}.notags (reference without tags)"
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
