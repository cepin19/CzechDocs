#!/bin/bash
set -ex
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd ${SCRIPT_DIR}
moses=../moses-scripts/
m4loc=../m4loc
src=$2
base_out=$(basename ${1})
./tikal.sh -xm ${1} -sl ${src} -to ${base_out}.mos
perl -CSDA -plE 's/[^\S\t]/ /g' ${base_out}.mos.${src}  > ${base_out}.mos.${src}.spaces
perl $m4loc/xliff/remove_markup.pm < ${base_out}.mos.${src}.spaces > ${base_out}.${src}.txt

