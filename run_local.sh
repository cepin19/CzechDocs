#!/bin/bash
set -ex
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd ${SCRIPT_DIR}
moses=./moses-scripts/
m4loc=./m4loc

./tikal.sh -fc okf_openxml@img2 -xm -seg config/defaultSegmentation.srx ${1} -sl ${src} -to ${1}.mos
perl -CSDA -plE 's/[^\S\t]/ /g' ${1}.mos.${src}  > ${1}.mos.${src}.spaces
perl m4loc/xliff/remove_markup.pm < ${1}.mos.${src}.spaces > ${1}.txt
cat ${1}.txt | bash translate-lindat.sh   > ${1}.target

$moses/scripts/tokenizer/tokenizer.perl -l ${src} -no-escape < ${1}.txt > ${1}.tok
#python tok.py < ${1}.txt > ${1}.tok

./tikal.sh -fc okf_openxml@img2 -xm -seg config/defaultSegmentation.srx ${1} -sl  ${src}  -to ${1}.mos.tok
perl -CSDA -plE 's/[^\S\t]/ /g' ${1}.mos.tok.${src}  > ${1}.mos.tok.${src}.spaces

$moses/scripts/tokenizer/tokenizer.perl -l ${tgt} -no-escape < ${1}.target > ${1}.target.tok
#python tok.py < ${1}.target > ${1}.target.tok


#paste ${1}.tok ${1}.target.tok | sed 's/\t/ ||| /g' | sed 's/^ ||| $/empt ||| empt/g'| python3 $fa/force_align.py $fa_models.fwd_params $fa_models.fwd_err $fa_models.rev_params $fa_models.rev_err > ${1}.align
paste ${1}.tok ${1}.target.tok | sed 's/\t/ ||| /g' | sed 's/^ ||| $/empt ||| empt/g'| python3 $fa/force_align.py $fa_models.rev_params $fa_models.rev_err $fa_models.fwd_params $fa_models.fwd_err > ${1}.align

perl $m4loc/xliff/reinsert_wordalign.pm ${1}.mos.tok.${src}.spaces ${1}.align < ${1}.target.tok > ${1}.target.mos

#$moses/scripts/tokenizer/detokenizer.perl -l en < ${1}.target.mos > ${1}.target.mos.detok.1
#perl -pi -e 's| (<g.*?>) |\1|g' ${1}.target.mos # remove space after xliff tags added by previous script
#perl -pi -e 's| (<ex.*?>) |\1|g' ${1}.target.mos
#perl -pi -e 's| (<bx.*?>) |\1|g' ${1}.target.mos

#perl -pi -e 's| (</g.*?>) |\1|g' ${1}.target.mos 
#perl -pi -e 's| (</ex.*?>) |\1|g' ${1}.target.mos
#perl -pi -e 's| (</bx.*?>) |\1|g' ${1}.target.mos

#paste  ${1}.mos.en.spaces  ${1}.target.mos | python3 fix_spacing.py > ${1}.target.mos.fix
perl $m4loc/xliff/fix_markup_ws.pm  ${1}.mos.tok.${src}.spaces < ${1}.target.mos > ${1}.target.mos.fix
perl $m4loc/xliff/fix_markup_ws.pm  ${1}.target < ${1}.target.mos > ${1}.target.mos.fix

#sed -i 's/<lb id[^\/]*/<lb/g' ${1}.target.mos.fix # for some reason fix_markup_ws.pm adds id="" to lb tags which breaks further steps

###TODO: we need to detok as if no xliff markup is there
#$moses/scripts/tokenizer/detokenizer.perl -l ${tgt} < ${1}.target.mos.fix > ${1}.target.mos.detok


#TODO
 paste ${1}.target ${1}.target.mos.fix | python3 fix_fix_markup.py > ${1}.target.mos.detok.fix  #- splits back tokens wrongly joined by fix_markup
sed -i 's/\s*$/ /g' ${1}.target.mos.detok.fix
sed -i 's/ \(<[^>]>\) /\1 /g' ${1}.target.mos.detok.fix
sed -i 's/ \(<\/[^>]*>\) /\1 /g'  ${1}.target.mos.detok.fix
sed -i 's/ \(<[^>]*>\) / \1/g' ${1}.target.mos.detok.fix

./tikal.sh -lm ${1} -fc okf_openxml@img2 -sl ${src} -ie utf8 -oe utf8 -overtrg -from ${1}.target.mos.detok.fix -seg config/defaultSegmentation.srx

