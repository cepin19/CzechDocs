"""
HTML Segment Alignment Interface - FastAPI backend
Serves MOS segments, OpenAI translations, and refresh for MOS file generation.
Uses MOS format for alignment (no XLIFF).
"""
import logging
import os
import subprocess
from pathlib import Path
import json

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from openai import OpenAI
from sacrebleu import sentence_chrf

# Paths relative to Curated/
BASE = Path(__file__).resolve().parent.parent
HTML_DIR = BASE / "data" / "html"
HTML_REEXPORTED_DIR = BASE / "data" / "html_reexported"
DOCX_DIR = BASE / "data" / "docx"
DOCX_REEXPORTED_DIR = BASE / "data" / "docx_reexported"
MOS_DIR = BASE / "data" / "mos"
MOS_REEXPORTED_DIR = BASE / "data" / "mos_reexported"
MT_CACHE_DIR = BASE / "data" / "mt_cache"
XLIFF_DIR = BASE / "data" / "xliff"
SCRIPTS_DIR = BASE / "scripts"
ALL_SEGS_SCRIPT = SCRIPTS_DIR / "all_segs.sh"
TIKAL_SCRIPT = BASE.parent / "tikal.sh"
SEGMENTATION_SRX = BASE.parent / "config" / "defaultSegmentation.srx"

# OpenAI client - uses OPENAI_API_KEY from env
client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY", "")) if os.environ.get("OPENAI_API_KEY") else None

app = FastAPI(title="HTML Segment Aligner")


# --- Discovery ---
def discover_documents():
    """Find all document sets (original from MOS, reexported from html_reexported)."""
    docs = []
    if MOS_DIR.exists():
        for doc_path in sorted(MOS_DIR.iterdir()):
            if not doc_path.is_dir():
                continue
            doc_id = doc_path.name
            langs = []
            base_name = None
            for sub in sorted(doc_path.iterdir()):
                if not sub.is_dir():
                    continue
                lang = sub.name
                mos_files = list(sub.glob("*.mos"))
                if mos_files:
                    langs.append(lang)
                    if base_name is None:
                        base_name = mos_files[0].stem
            if base_name and langs:
                docs.append({
                    "doc_id": doc_id,
                    "base_name": base_name,
                    "languages": sorted(langs),
                    "reexported": False,
                })
    if HTML_REEXPORTED_DIR.exists():
        for doc_path in sorted(HTML_REEXPORTED_DIR.iterdir()):
            if not doc_path.is_dir():
                continue
            doc_id = doc_path.name
            langs = []
            base_name = None
            for sub in sorted(doc_path.iterdir()):
                if not sub.is_dir():
                    continue
                lang = sub.name
                html_files = list(sub.glob("*.html"))
                if html_files:
                    langs.append(lang)
                    if base_name is None:
                        base_name = html_files[0].stem
            if base_name and langs:
                docs.append({
                    "doc_id": doc_id,
                    "base_name": base_name,
                    "languages": sorted(langs),
                    "reexported": True,
                })
    return docs


def _get_mos_file(doc_path: Path, lang: str) -> Path | None:
    """Return the .mos file in doc_path/lang/ (assumes one document per lang subdir)."""
    lang_dir = doc_path / lang
    if not lang_dir.is_dir():
        return None
    mos_files = list(lang_dir.glob("*.mos"))
    return mos_files[0] if mos_files else None


def ensure_reexported_mos(doc_id: str) -> None:
    """Generate MOS from reexported HTML/DOCX for doc_id into mos_reexported."""
    html_root = HTML_REEXPORTED_DIR / doc_id
    docx_root = DOCX_REEXPORTED_DIR / doc_id
    if html_root.exists():
        reexport_root = html_root
    elif docx_root.exists():
        reexport_root = docx_root
    else:
        raise HTTPException(404, f"Reexported document {doc_id} not found in html_reexported or docx_reexported")
    if not TIKAL_SCRIPT.exists():
        raise HTTPException(503, "tikal.sh not found; cannot generate MOS for reexported")
    mos_root = MOS_REEXPORTED_DIR / doc_id
    mos_root.mkdir(parents=True, exist_ok=True)
    for lang_dir in sorted(reexport_root.iterdir()):
        if not lang_dir.is_dir():
            continue
        lang = lang_dir.name
        out_lang_dir = mos_root / lang
        out_lang_dir.mkdir(parents=True, exist_ok=True)
        for html_file in lang_dir.glob("*.html"):
            base_name = html_file.stem
            out_mos = out_lang_dir / f"{base_name}.mos"
            cmd = [str(TIKAL_SCRIPT), "-xm", str(html_file), "-sl", lang, "-tl", lang, "-ie", "utf8", "-oe", "utf8"]
            if SEGMENTATION_SRX.exists():
                cmd.extend(["-seg", str(SEGMENTATION_SRX)])
            cmd.extend(["-to", str(out_lang_dir / f"{base_name}.mos")])
            try:
                proc = subprocess.run(cmd, cwd=str(BASE), capture_output=True, text=True, timeout=120)
                if proc.returncode != 0:
                    log.warning("Tikal -xm failed for %s: %s", html_file, proc.stderr or proc.stdout)
                    continue
                mos_lang = out_lang_dir / f"{base_name}.mos.{lang}"
                if mos_lang.exists():
                    mos_lang.rename(out_mos)
            except subprocess.TimeoutExpired:
                log.warning("Tikal -xm timed out for %s", html_file)
            except Exception as e:
                log.exception("Tikal -xm error for %s: %s", html_file, e)


def load_segments(doc_id: str, base_name: str | None = None, languages: list[str] | None = None, reexported: bool = False):
    """Load aligned segments from mos files. Returns {lang: [seg1, seg2, ...]}. If reexported, uses mos_reexported and ensures MOS exists."""
    if reexported:
        ensure_reexported_mos(doc_id)
        doc_path = MOS_REEXPORTED_DIR / doc_id
    else:
        doc_path = MOS_DIR / doc_id
    if not doc_path.exists():
        raise HTTPException(404, f"Document {doc_id} not found")
    result = {}
    all_langs = sorted([d.name for d in doc_path.iterdir() if d.is_dir()]) if not languages else sorted(languages)
    for lang in all_langs:
        mos_file = _get_mos_file(doc_path, lang)
        if mos_file is None:
            continue
        with open(mos_file, encoding="utf-8") as f:
            result[lang] = [line.rstrip("\n") for line in f]
    return result


# --- MOS-based Alignment ---
def load_mos_alignment(doc_id: str, languages: list[str] | None = None, reexported: bool = False) -> dict[str, list[str]]:
    """Load MOS segments per language. If reexported, uses mos_reexported and ensures MOS exists."""
    if reexported:
        ensure_reexported_mos(doc_id)
        doc_path = MOS_REEXPORTED_DIR / doc_id
    else:
        doc_path = MOS_DIR / doc_id
    if not doc_path.exists():
        raise HTTPException(404, f"Document {doc_id} not found")
    result = {}
    all_langs = sorted([d.name for d in doc_path.iterdir() if d.is_dir()]) if not languages else sorted(languages)
    for lang in all_langs:
        mos_file = _get_mos_file(doc_path, lang)
        if mos_file is None:
            continue
        with open(mos_file, encoding="utf-8") as f:
            result[lang] = [line.rstrip("\n") for line in f]
    return result


def compute_alignment_subset(
    doc_id: str, languages: list[str] | None = None, reexported: bool = False
) -> dict:
    """Report segment counts per language (no common subset; each language can have different count)."""
    mos_data = load_mos_alignment(doc_id, languages, reexported)
    if not mos_data:
        raise HTTPException(404, f"No MOS data for {doc_id}")
    counts = {lang: len(mos_data[lang]) for lang in mos_data}
    max_count = max(counts.values()) if counts else 0
    # Row indices for the grid (0 .. max_count-1); grid shows all rows, each column has its own length
    ordered_ids = [str(i) for i in range(max_count)]
    return {
        "doc_id": doc_id,
        "languages": list(mos_data.keys()),
        "counts_per_lang": counts,
        "common_count": max_count,
        "common_ids": ordered_ids,
    }


def get_aligned_segments(
    doc_id: str,
    languages: list[str] | None = None,
    exclude_ids: list[str] | None = None,
    reexported: bool = False,
) -> dict:
    """Return full segment list per language (no padding). Each lang has its own length; grid rows = max length."""
    mos_data = load_mos_alignment(doc_id, languages, reexported)
    if not mos_data:
        raise HTTPException(404, f"No MOS data for {doc_id}")
    max_count = max(len(mos_data[lang]) for lang in mos_data)
    ordered_ids = [str(i) for i in range(max_count)]
    if exclude_ids:
        exclude_set = set(exclude_ids)
        ordered_ids = [i for i in ordered_ids if i not in exclude_set]
    # Return full segment list per language (no padding): segments[lang][i] only defined for i < len(lang)
    segments_by_lang = {lang: list(mos_data[lang]) for lang in mos_data}
    return {"tu_ids": ordered_ids, "segments": segments_by_lang}


# --- API ---
@app.get("/api/documents")
def list_documents():
    return discover_documents()


@app.get("/api/segments")
def get_segments(doc_id: str, base_name: str | None = None, languages: str | None = None, reexported: bool = False):
    """Get aligned segments. reexported=True uses html_reexported (MOS created if missing)."""
    lang_list = [x.strip() for x in languages.split(",")] if languages else None
    return load_segments(doc_id, base_name, lang_list, reexported)


@app.get("/api/alignment/subset")
def api_alignment_subset(doc_id: str, languages: str | None = None, reexported: bool = False):
    lang_list = [x.strip() for x in languages.split(",")] if languages else None
    return compute_alignment_subset(doc_id, lang_list, reexported)


@app.get("/api/alignment/segments")
def api_alignment_segments(
    doc_id: str,
    languages: str | None = None,
    exclude_ids: str | None = None,
    reexported: bool = False,
):
    lang_list = [x.strip() for x in languages.split(",")] if languages else None
    excl = [x.strip() for x in exclude_ids.split(",") if x.strip()] if exclude_ids else None
    return get_aligned_segments(doc_id, lang_list, excl, reexported)


class TranslateRequest(BaseModel):
    texts: list[str]
    source_lang: str
    target_lang: str


def lang_name(code: str) -> str:
    names = {"cs": "Czech", "en": "English", "uk": "Ukrainian", "ru": "Russian", "vi": "Vietnamese"}
    return names.get(code, code)


def _load_mt_cache(src_code: str, tgt_code: str) -> dict:
    """Load or initialize MT cache for a given language pair."""
    MT_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_path = MT_CACHE_DIR / f"{src_code}_to_{tgt_code}.json"
    if cache_path.exists():
        try:
            with open(cache_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict) and "by_text" in data:
                    return data
        except Exception:
            log.warning("Failed to load MT cache %s, recreating", cache_path)
    return {"by_text": {}}


def _save_mt_cache(src_code: str, tgt_code: str, cache: dict) -> None:
    MT_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_path = MT_CACHE_DIR / f"{src_code}_to_{tgt_code}.json"
    try:
        with open(cache_path, "w", encoding="utf-8") as f:
            json.dump(cache, f, ensure_ascii=False, indent=2)
    except Exception as e:
        log.warning("Failed to save MT cache %s: %s", cache_path, e)


def _mt_translate_with_cache(texts: list[str], src_code: str, tgt_code: str) -> dict:
    """
    Translate texts from src_code to tgt_code with caching on disk.
    Cache key is the full source text; identical segments are never re-translated.
    """
    if not client:
        raise HTTPException(503, "OpenAI API key not configured. Set OPENAI_API_KEY.")

    src_name = lang_name(src_code)
    tgt_name = lang_name(tgt_code)
    log.info("Translate (cached): %s -> %s, %d segments", src_code, tgt_code, len(texts))

    prompt_template = (
        f"Translate from {src_name} to {tgt_name}. Preserve markup tags (e.g. <g id=\"1\">...</g>) in the output. "
        "Output ONLY the translation, one line per input line. If a line should not be translated, copy it unchanged."
    )

    cache = _load_mt_cache(src_code, tgt_code)
    by_text: dict = cache.get("by_text", {})

    results = []
    debug = []
    updated = False

    for i, text in enumerate(texts):
        if not text.strip():
            results.append("")
            debug.append({"idx": i, "input": text, "output": "", "prompt": "", "raw": ""})
            continue
        try:
            if text in by_text:
                out = by_text[text]
                raw = out
                full_prompt = ""
            else:
                full_prompt = f"{prompt_template}\n\nSource: {text}"
                log.info("OpenAI MT request [%s->%s, idx=%d]", src_code, tgt_code, i)
                resp = client.chat.completions.create(
                    model="gpt-4.1-nano",
                    messages=[{"role": "user", "content": full_prompt}],
                    temperature=0.1,
                )
                raw = resp.choices[0].message.content
                out = raw.strip().replace("\n", " ")
                by_text[text] = out
                updated = True
            results.append(out)
            debug.append({"idx": i, "input": text, "output": out, "prompt": full_prompt, "raw": raw})
        except Exception as e:
            log.exception("OpenAI MT error [%s->%s] at segment %d", src_code, tgt_code, i)
            results.append(text)
            debug.append({"idx": i, "input": text, "output": text, "error": str(e)})
    cache["by_text"] = by_text
    if updated:
        _save_mt_cache(src_code, tgt_code, cache)
    return {"translations": results, "debug": debug}


@app.post("/api/translate")
def translate_segments(req: TranslateRequest):
    """Translate a batch of segments via OpenAI API with on-disk caching."""
    resp = _mt_translate_with_cache(req.texts, req.source_lang, req.target_lang)
    return resp


class ChrFRequest(BaseModel):
    references: list[str]
    hypotheses: list[str]


@app.post("/api/chrf")
def api_chrf(req: ChrFRequest):
    """Compute chrF scores for lists of reference and hypothesis segments."""
    refs = req.references
    hyps = req.hypotheses
    if len(refs) != len(hyps):
        raise HTTPException(400, "references and hypotheses must have same length")
    scores = []
    for r, h in zip(refs, hyps):
        try:
            score = sentence_chrf(h, [r])
            scores.append(score.score)
        except Exception:
            scores.append(0.0)
    return {"scores": scores, "average": sum(scores) / len(scores) if scores else 0}


class TranslateAllRequest(BaseModel):
    """Translate all documents so future per-doc translations can reuse the cache."""
    reexported: bool = False


@app.post("/api/translate_all")
def translate_all_documents(req: TranslateAllRequest):
    """
    MT-translate all documents for caching.

    For each document (original or reexported, depending on `reexported` flag),
    we treat the first language as the MT target and translate all other
    languages into it, using the same caching mechanism as /api/translate.
    """
    docs = discover_documents()
    # Filter by reexported flag
    docs = [d for d in docs if bool(d.get("reexported")) == bool(req.reexported)]
    if not docs:
        raise HTTPException(404, "No documents to translate for the requested mode")

    translated_pairs: list[dict] = []
    for d in docs:
        doc_id = d["doc_id"]
        langs = d.get("languages") or []
        if not langs:
            continue
        target_lang = sorted(langs)[0]
        try:
            segs = load_segments(doc_id, d.get("base_name"), langs, reexported=req.reexported)
        except HTTPException as e:
            log.warning("Skipping %s: %s", doc_id, e.detail)
            continue
        for src_lang in sorted(l for l in langs if l != target_lang):
            texts = segs.get(src_lang) or []
            if not texts:
                continue
            log.info("MT all: %s (%s -> %s), %d segments", doc_id, src_lang, target_lang, len(texts))
            _mt_translate_with_cache(texts, src_lang, target_lang)
            translated_pairs.append({"doc_id": doc_id, "source_lang": src_lang, "target_lang": target_lang})

    return {"status": "ok", "translated": translated_pairs}


class MosApplyRequest(BaseModel):
    doc_id: str
    exclude_ids: list[str] = []
    merges: list[dict] = []
    edits: list[dict] = []
    insert_after: list[str] = []
    remove_in_lang: list[dict] = []
    first_lang: str | None = None
    reexported: bool = False


def _align_to_first_lang(lines: list[str], first_lang_lines: list[str]) -> list[str]:
    """Expand or trim lines to match first_lang count; fill with empty."""
    n_ref = len(first_lang_lines)
    n = len(lines)
    if n >= n_ref:
        return lines[:n_ref]
    return lines + [""] * (n_ref - n)


def _apply_mos_edits(
    lines: list[str],
    exclude_ids: set[str],
    merges: list[dict],
    edits_map: dict[int, str] | None = None,
    insert_after: set[int] | None = None,
    remove_indices: set[int] | None = None,
) -> list[str]:
    """
    Apply exclude, merge, edits, and inserts.
    Excluded / per-language-removed / merge-source segments are omitted from the
    output (lines are deleted from the MOS, not replaced with empty lines).
    """
    n = len(lines)
    exclude_set = {int(x) for x in exclude_ids if x.isdigit()}
    insert_after_set = insert_after or set()
    remove_set = remove_indices or set()
    merge_from_to: dict[int, int] = {}
    for m in merges:
        fid, iid = m.get("from_id"), m.get("into_id")
        if fid is None or iid is None:
            continue
        try:
            fi, ii = int(fid), int(iid)
            if 0 <= fi < n and 0 <= ii < n and fi != ii:
                merge_from_to[fi] = ii
        except ValueError:
            pass

    def all_sources_into(root: int) -> list[int]:
        result_j = []
        for j in range(n):
            if j not in merge_from_to:
                continue
            k = merge_from_to[j]
            while k in merge_from_to and k != root:
                k = merge_from_to[k]
            if k == root:
                result_j.append(j)
        return sorted(result_j)

    result: list[str] = []
    if -1 in insert_after_set:
        result.append("")
    for i in range(n):
        # Omit excluded, per-lang removed, and merge-source segments entirely (no line in output).
        if i in exclude_set or i in remove_set or i in merge_from_to:
            continue

        def seg(j: int) -> str:
            if edits_map is not None and j in edits_map:
                return edits_map[j]
            return lines[j]

        parts = [seg(i)]
        for j in all_sources_into(i):
            if j != i:
                parts.append(seg(j))
        text = " ".join(parts).strip()
        if edits_map is not None and i in edits_map:
            text = edits_map[i]

        result.append(text)
        if i in insert_after_set:
            result.append("")
    return result


@app.post("/api/mos/apply")
def api_mos_apply(req: MosApplyRequest):
    if req.reexported:
        ensure_reexported_mos(req.doc_id)
        doc_path = MOS_REEXPORTED_DIR / req.doc_id
        out_doc_id = req.doc_id
        out_doc_path = MOS_REEXPORTED_DIR / out_doc_id
    else:
        doc_path = MOS_DIR / req.doc_id
        out_doc_id = f"{req.doc_id}_remerged"
        out_doc_path = MOS_DIR / out_doc_id
    if not doc_path.exists():
        raise HTTPException(404, f"Document {req.doc_id} not found")
    exclude_set = set(req.exclude_ids)
    insert_after_set: set[int] = set()
    for x in req.insert_after:
        try:
            insert_after_set.add(int(x))
        except ValueError:
            pass
    edits_by_lang: dict[str, dict[int, str]] = {}
    for e in req.edits:
        lang = e.get("lang")
        idx = e.get("idx")
        text = e.get("text", "")
        if lang is None or idx is None:
            continue
        try:
            i = int(idx)
            edits_by_lang.setdefault(lang, {})[i] = text
        except ValueError:
            pass
    remove_by_lang: dict[str, set[int]] = {}
    for r in req.remove_in_lang:
        lang = r.get("lang")
        idx = r.get("idx")
        if lang is None or idx is None:
            continue
        try:
            remove_by_lang.setdefault(lang, set()).add(int(idx))
        except ValueError:
            pass
    all_langs = sorted(d.name for d in doc_path.iterdir() if d.is_dir())
    first_lang = req.first_lang if req.first_lang in all_langs else (all_langs[0] if all_langs else None)
    first_lang_lines: list[str] | None = None
    if first_lang:
        first_mos = _get_mos_file(doc_path, first_lang)
        if first_mos:
            with open(first_mos, encoding="utf-8") as f:
                first_lang_lines = [line.rstrip("\n") for line in f]
    out_doc_path.mkdir(parents=True, exist_ok=True)

    for lang_dir in sorted(doc_path.iterdir(), key=lambda d: (0 if d.name == first_lang else 1, d.name)):
        if not lang_dir.is_dir():
            continue
        mos_files = list(lang_dir.glob("*.mos"))
        if not mos_files:
            continue
        mos_path = mos_files[0]
        with open(mos_path, encoding="utf-8") as f:
            lines = [line.rstrip("\n") for line in f]
        edits_map = edits_by_lang.get(lang_dir.name)
        remove_indices = remove_by_lang.get(lang_dir.name)
        # Do NOT pad/trim other languages to match first language; keep original segment counts.
        new_lines = _apply_mos_edits(lines, exclude_set, req.merges, edits_map, insert_after_set, remove_indices)
        out_lang_dir = out_doc_path / lang_dir.name
        out_lang_dir.mkdir(parents=True, exist_ok=True)
        out_mos_path = out_lang_dir / mos_path.name
        with open(out_mos_path, "w", encoding="utf-8") as f:
            f.write("\n".join(new_lines) + ("\n" if new_lines else ""))
        # Debug: print edited MOS contents to stdout after each apply.
        try:
            print(f"=== MOS AFTER APPLY ({lang_dir.name}): {out_mos_path} ===", flush=True)
            for line in new_lines:
                print(line)
            print("=== END MOS ===", flush=True)
        except Exception as e:
            # Do not fail apply if debug printing breaks for any reason.
            log.warning("Failed to print MOS for debug: %s", e)
    return {"status": "ok", "message": f"Applied edits to {out_doc_id}"}


@app.post("/api/refresh")
def refresh_mos():
    if not ALL_SEGS_SCRIPT.exists():
        raise HTTPException(404, f"Script not found: {ALL_SEGS_SCRIPT}")
    try:
        proc = subprocess.run(
            ["bash", str(ALL_SEGS_SCRIPT)],
            cwd=str(SCRIPTS_DIR),
            capture_output=True,
            text=True,
            timeout=600,
        )
        if proc.returncode != 0:
            raise HTTPException(500, f"Refresh failed: {proc.stderr or proc.stdout}")
        return {"status": "ok", "output": proc.stdout or ""}
    except subprocess.TimeoutExpired:
        raise HTTPException(504, "Refresh timed out")
    except Exception as e:
        raise HTTPException(500, str(e))


@app.post("/api/reexport")
def reexport_original(doc_id: str, reexported: bool = False):
    """Re-export by merging MOS back into HTML using tikal -lm (no XLIFF)."""
    if not TIKAL_SCRIPT.exists():
        raise HTTPException(404, f"tikal script not found at {TIKAL_SCRIPT}")
    # Base ID without optional _remerged suffix (e.g. html_20_remerged -> html_20, docx_91_remerged -> docx_91)
    base_id = doc_id.split("_remerged")[0]
    is_docx = base_id.startswith("docx_")
    if reexported:
        ensure_reexported_mos(doc_id)
        mos_root = MOS_REEXPORTED_DIR / doc_id
    else:
        remerged = MOS_DIR / f"{doc_id}_remerged"
        mos_root = remerged if remerged.exists() else (MOS_DIR / doc_id)
    if not mos_root.exists():
        raise HTTPException(404, f"MOS not found for {doc_id}")

    # Determine first language and use its skeleton document as the template for ALL languages.
    all_langs = sorted(d.name for d in mos_root.iterdir() if d.is_dir())
    if not all_langs:
        raise HTTPException(404, f"No language subdirs in MOS for {doc_id}")
    first_lang = all_langs[0]
    if is_docx:
        skeleton_lang_root = DOCX_DIR / base_id / first_lang
        if not skeleton_lang_root.is_dir():
            raise HTTPException(404, f"Skeleton DOCX not found for first language {first_lang} of {base_id}")
        out_root = DOCX_REEXPORTED_DIR / base_id
    else:
        skeleton_lang_root = HTML_DIR / doc_id / first_lang
        if not skeleton_lang_root.is_dir():
            raise HTTPException(404, f"Skeleton HTML not found for first language {first_lang} of {doc_id}")
        out_root = HTML_REEXPORTED_DIR / doc_id
    out_root.mkdir(parents=True, exist_ok=True)

    merged_count = 0
    for lang_dir in sorted(mos_root.iterdir()):
        if not lang_dir.is_dir():
            continue
        lang = lang_dir.name
        out_lang_dir = out_root / lang
        out_lang_dir.mkdir(parents=True, exist_ok=True)
        for mos_path in lang_dir.glob("*.mos"):
            base_name = mos_path.stem
            # Always use first language HTML as the template, regardless of target language.
            skeleton_html = skeleton_lang_root / f"{base_name}.html"
            if not skeleton_html.exists():
                log.warning("Skeleton HTML missing: %s", skeleton_html)
                continue
            out_html = out_lang_dir / f"{base_name}.html"
            cmd = [
                str(TIKAL_SCRIPT),
                "-lm", str(skeleton_html),
                "-from", str(mos_path),
                "-to", str(out_html),
                "-sl", lang,
                "-tl", lang,
                "-ie", "utf8",
                "-oe", "utf8",
                "-overtrg",
            ]
            if SEGMENTATION_SRX.exists():
                cmd.extend(["-seg", str(SEGMENTATION_SRX)])
            try:
                proc = subprocess.run(cmd, cwd=str(BASE), capture_output=True, text=True, timeout=120)
                if proc.returncode != 0:
                    # Surface Tikal errors to the caller so the UI can show them.
                    raise HTTPException(500, f"Tikal -lm failed for {mos_path}: {proc.stderr or proc.stdout}")
                merged_count += 1
            except subprocess.TimeoutExpired:
                raise HTTPException(504, f"Tikal -lm timed out for {mos_path}")
            except Exception as e:
                # Any unexpected error should also break the API so it's visible in the UI.
                raise HTTPException(500, f"Tikal -lm error for {mos_path}: {e}")

    # After reexport, regenerate MOS for the reexported HTML/DOCX so the UI can load
    # aligned segments directly from the updated originals. Any failure here should
    # also surface as an error to the caller.
    ensure_reexported_mos(doc_id if not is_docx else base_id)

    return {
        "status": "ok",
        "message": f"Re-exported {doc_id} ({merged_count} file(s) merged from MOS and MOS regenerated from reexported HTML)",
    }


# Serve static frontend
static = Path(__file__).parent / "static"
if static.exists():
    app.mount("/static", StaticFiles(directory=str(static)), name="static")


@app.get("/")
def index():
    p = Path(__file__).parent / "static" / "index.html"
    if p.exists():
        return FileResponse(p)
    return {"message": "HTML Segment Aligner API. Open /static/index.html or configure static."}
