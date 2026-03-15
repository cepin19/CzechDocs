set -ex
html_input=../data/html/$1.html
xlf=../data/xliff/$1.html.xlf
src=cs
mkdir -p tmp
cp ../data/xliff/$1.html.xlf tmp/
cp ../data/html/$1.html tmp/
../../tikal.sh -m tmp/$(basename $1).html.xlf   -sl ${src}  -seg ../../config/defaultSegmentation.srx

