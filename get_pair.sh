
bash get_segs.sh ~/ctk_testsets/already_processed/sucessful_raw/crawl_cestina_pro_cizince/translations/$1/uk/*.html uk;  bash get_segs.sh ~/ctk_testsets/already_processed/sucessful_raw/crawl_cestina_pro_cizince/translations/$1/cs/*.html cs
path=$(basename ~/ctk_testsets/already_processed/sucessful_raw/crawl_cestina_pro_cizince/translations/$1/cs/*.html)
#path="${path%.html}"
paste $path.cs.txt $path.uk.txt
