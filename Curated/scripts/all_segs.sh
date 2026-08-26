#!/bin/bash
set -xeuo pipefail

# --- CONFIGURATION ---
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${SCRIPT_DIR}"

moses=../../moses-scripts/
m4loc=../../m4loc
DATA_ROOTS=("../data/valid" "../data/split" "../data")

# --- MAIN LOOP ---
for DATA_ROOT in "${DATA_ROOTS[@]}"; do
    HTML_DIR="${DATA_ROOT}/html"
    DOCX_DIR="${DATA_ROOT}/docx"
    MOS_DIR="${DATA_ROOT}/mos"
    XLIFF_DIR="${DATA_ROOT}/xliff"

    # --- PREPARE OUTPUT TREE ---
    if [ -d "${HTML_DIR}" ] || [ -d "${DOCX_DIR}" ]; then
        mkdir -p "${MOS_DIR}"
    fi

    if [ -d "${HTML_DIR}" ]; then
        find "${HTML_DIR}" -type f -name '*.html' | while read -r html_file; do
            # Compute mirrored output path
            rel_path="${html_file#${HTML_DIR}/}"         # e.g. "10/cs/Dobrovolnictví.html"
            base_dir="$(dirname "${rel_path}")"          # e.g. "10/cs"
            base_name="$(basename "${rel_path}" .html)"  # e.g. "Dobrovolnictví"
            lang="${base_dir##*/}"                       # e.g. "cs"

            out_dir="${MOS_DIR}/${base_dir}"
            out_xlf_dir="${XLIFF_DIR}/${base_dir}"
            mkdir -p "${out_dir}"
            mkdir -p "${out_xlf_dir}"

            echo "Processing ${html_file} → ${out_dir}/${base_name}.mos.${lang}"

            # Run tikal.sh
            ../../tikal.sh -xm "${html_file}" -sl "${lang}" -tl "${lang}" -ie utf8 -oe utf8 -seg ../../config/defaultSegmentation.srx -to "${out_dir}/${base_name}.mos"
            ../../tikal.sh -x "${html_file}" -sl "${lang}" -od "${out_xlf_dir}"

            # Normalize spaces
            perl -CSDA -plE 's/[^\S\t]/ /g' \
                "${out_dir}/${base_name}.mos.${lang}" \
                > "${out_dir}/${base_name}.mos.${lang}.spaces"
#    rm "${out_dir}/${base_name}.mos.${lang}"
#    mv "${out_dir}/${base_name}.mos.${lang}.spaces" "${out_dir}/${base_name}.mos"
            mv "${out_dir}/${base_name}.mos.${lang}" "${out_dir}/${base_name}.mos"
        done
    fi

    if [ -d "${DOCX_DIR}" ]; then
        find "${DOCX_DIR}" -type f -name '*.docx' | while read -r docx_file; do
            # Compute mirrored output path
            rel_path="${docx_file#${DOCX_DIR}/}"         # e.g. "docx_1/cs/Foo.cs.docx"
            base_dir="$(dirname "${rel_path}")"          # e.g. "docx_1/cs"
            base_name="$(basename "${rel_path}" .docx)"  # e.g. "Foo.cs"
            lang="${base_dir##*/}"                       # e.g. "cs"

            out_dir="${MOS_DIR}/${base_dir}"
            out_xlf_dir="${XLIFF_DIR}/${base_dir}"
            mkdir -p "${out_dir}"
            mkdir -p "${out_xlf_dir}"

            echo "Processing ${docx_file} → ${out_dir}/${base_name}.mos.${lang}"

            # Run tikal.sh
            ../../tikal.sh -xm "${docx_file}" -sl "${lang}" -tl "${lang}" -ie utf8 -oe utf8 -seg ../../config/defaultSegmentation.srx -to "${out_dir}/${base_name}.mos"
            ../../tikal.sh -x "${docx_file}" -sl "${lang}" -od "${out_xlf_dir}"

            # Normalize spaces
            perl -CSDA -plE 's/[^\S\t]/ /g' \
                "${out_dir}/${base_name}.mos.${lang}" \
                > "${out_dir}/${base_name}.mos.${lang}.spaces"
            mv "${out_dir}/${base_name}.mos.${lang}" "${out_dir}/${base_name}.mos"
        done
    fi
done

