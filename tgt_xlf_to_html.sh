set -ex
html_input=semimanual/html/$1.html
xlf=semimanual/xliff/$1.html.xlf
src=cs
cp semimanual/xliff/$1.html.xlf tmp/
cp semimanual/html/$1.html tmp/
../tikal.sh -m tmp/$(basename $1).html.xlf   -sl ${src}  -seg ../config/defaultSegmentation.srx

