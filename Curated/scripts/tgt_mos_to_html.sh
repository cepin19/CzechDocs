set -ex
html_input=../data/html/$1.html
mos=../data/mos/$1.mos
src=cs
../../tikal.sh -lm ${html_input}  -sl ${src} -tl ${src} -ie utf8 -oe utf8 -overtrg -from $mos -to $(basename $1.out) -seg ../../config/defaultSegmentation.srx

