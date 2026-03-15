# HTML Segment Aligner

Interface for viewing aligned HTML segments from MOS files side-by-side, with optional OpenAI translation.

## Setup

```bash
source /home/cepin/.bashrc
conda activate base
cd Curated/aligner
pip install -r requirements.txt
```

Set `OPENAI_API_KEY` for translation support:

```bash
export OPENAI_API_KEY=sk-...
```

## Run

```bash
source /home/cepin/.bashrc
conda activate base
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Open http://localhost:8000

## Features

- **Documents**: Lists all document sets from `data/mos/` (e.g. html_18 / Pomoc_cizincům)
- **Segments**: Displays aligned segments from MOS files, one row per segment index
- **Translate**: Translates all segments to the selected language via OpenAI API
- **Refresh MOS**: Runs `scripts/all_segs.sh` to regenerate MOS files from HTML (requires tikal.sh and dependencies)

## Refresh

The Refresh button runs `Curated/scripts/all_segs.sh`, which uses Okapi Tikal to convert HTML → MOS. Ensure `tikal.sh` and `config/defaultSegmentation.srx` are available relative to the script (see `all_segs.sh` for paths).
