#!/usr/bin/env python3
"""
Generate statistics for the Curated dataset for research paper.
Counts documents, segments, words, tags per language.
"""

import os
import re
import argparse
from collections import defaultdict
from pathlib import Path
import json
from urllib.parse import urlparse


def count_tags(text):
    """Count number of markup tags in text."""
    return text.count('<')


def extract_tag_types(text):
    """Extract all tag types from text."""
    tag_pattern = r'<(/?)([a-zA-Z][a-zA-Z0-9]*)[^>]*>'
    matches = re.findall(tag_pattern, text)
    return [tag_name for _, tag_name in matches]


def count_words(text):
    """Count words in text (simple space-based split)."""
    # Remove tags first for word count
    text_notags = re.sub(r'<[^>]+>', '', text)
    # Decode entities
    text_notags = text_notags.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
    # Count words
    words = text_notags.strip().split()
    return len(words)


def detect_language_from_path(filepath):
    """Extract language code from file path."""
    # Pattern: .../lang/filename or filename.lang.ext
    parts = Path(filepath).parts
    
    # Check if there's a language directory (e.g., /cs/, /uk/, /en/)
    lang_codes = ['cs', 'uk', 'en', 'ru', 'vi', 'vn', 'de', 'fr', 'hu', 'bg', 'ro', 'pl', 'es', 'ar', 'mn', 'sr']
    for part in parts:
        if part in lang_codes:
            return part
    
    # Check filename pattern (e.g., file.uk.html or file.mos.cs)
    filename = Path(filepath).name
    for lang in lang_codes:
        if f'.{lang}.' in filename or filename.endswith(f'.{lang}'):
            return lang
    
    return 'unknown'


def get_document_origin(doc_path, data_path):
    """Extract document origin (website domain) from URL file."""
    # doc_path is a Path object for a document directory (e.g., data/html/html_10)
    # Look for URL file in any language subdirectory
    
    url_files = list(doc_path.rglob("url"))
    if not url_files:
        return 'unknown'
    
    # Read first URL file found
    try:
        with open(url_files[0], 'r', encoding='utf-8') as f:
            url = f.read().strip().split('\n')[0]  # First line
            
        # Extract domain from URL
        parsed = urlparse(url)
        domain = parsed.netloc
        
        # Remove www. prefix
        if domain.startswith('www.'):
            domain = domain[4:]
        
        return domain
    except Exception as e:
        return 'unknown'


def analyze_mos_file(filepath):
    """Analyze a MOS file and return statistics."""
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            lines = [line.strip() for line in f if line.strip()]
        
        stats = {
            'segments': len(lines),
            'tags': sum(count_tags(line) for line in lines),
            'words': sum(count_words(line) for line in lines),
            'segments_with_tags': sum(1 for line in lines if '<' in line),
            'avg_words_per_segment': sum(count_words(line) for line in lines) / max(1, len(lines)),
            'avg_tags_per_segment': sum(count_tags(line) for line in lines) / max(1, len(lines)),
        }
        return stats
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return None


def analyze_plaintext_file(filepath):
    """Analyze a plaintext file and return statistics including empty segments."""
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            all_lines = [line.rstrip('\n') for line in f]
        
        non_empty_lines = [line for line in all_lines if line.strip()]
        empty_lines = [line for line in all_lines if not line.strip()]
        
        stats = {
            'total_segments': len(all_lines),
            'non_empty_segments': len(non_empty_lines),
            'empty_segments': len(empty_lines),
            'words': sum(count_words(line) for line in non_empty_lines),
            'avg_words_per_segment': sum(count_words(line) for line in non_empty_lines) / max(1, len(non_empty_lines)),
        }
        return stats
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return None


def analyze_html_file(filepath):
    """Analyze an HTML file and return basic statistics."""
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # Remove scripts and styles
        content = re.sub(r'<script[^>]*>.*?</script>', '', content, flags=re.IGNORECASE | re.DOTALL)
        content = re.sub(r'<style[^>]*>.*?</style>', '', content, flags=re.IGNORECASE | re.DOTALL)
        
        stats = {
            'chars': len(content),
            'tags': count_tags(content),
            'words': count_words(content),
        }
        return stats
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return None


def main():
    parser = argparse.ArgumentParser(
        description="Generate dataset statistics for research paper from Curated directory"
    )
    parser.add_argument("--curated-dir", default="Curated",
                       help="Path to Curated directory (default: Curated)")
    parser.add_argument("--output-json", default="curated_stats.json",
                       help="Output JSON file with detailed statistics")
    parser.add_argument("--output-latex", default="curated_stats.tex",
                       help="Output LaTeX table file")
    parser.add_argument("--output-md", default="curated_stats.md",
                       help="Output Markdown report file")
    args = parser.parse_args()
    
    curated_path = Path(args.curated_dir)
    
    # Statistics containers
    stats_by_lang = defaultdict(lambda: {
        'documents': 0,
        'mos_files': 0,
        'plaintext_files': 0,
        'html_files': 0,
        'pdf_files': 0,
        'docx_files': 0,
        'segments': 0,
        'empty_segments': 0,
        'non_empty_segments': 0,
        'words': 0,
        'tags': 0,
        'segments_with_tags': 0,
        'segment_lengths': [],  # For distribution analysis
        'tag_types': [],  # For tag type distribution
    })
    
    document_pairs = defaultdict(set)  # Track parallel documents
    all_tag_types = defaultdict(int)  # Global tag type counts
    document_origins = defaultdict(int)  # Track document sources by domain
    
    # Note: No longer tracking manual/semimanual distinction
    # All files are in data/ directory now
    
    print("=" * 70)
    print("CURATED DATASET STATISTICS GENERATOR")
    print("=" * 70)
    print(f"\nScanning directory: {curated_path.absolute()}")
    print()
    
    # Define data path (all files now in data/ directory)
    data_path = curated_path / "data"
    
    # Process plaintext files for segment counts (includes all sources: HTML, DOCX, PDF)
    print("Processing plaintext files...")
    plaintext_files = list(data_path.rglob("*.txt")) if data_path.exists() else []
    print(f"Found {len(plaintext_files)} plaintext files")
    
    for plaintext_file in plaintext_files:
        lang = detect_language_from_path(plaintext_file)
        if lang == 'unknown':
            continue
        
        stats = analyze_plaintext_file(plaintext_file)
        if stats:
            stats_by_lang[lang]['plaintext_files'] += 1
            stats_by_lang[lang]['segments'] += stats['non_empty_segments']
            stats_by_lang[lang]['non_empty_segments'] += stats['non_empty_segments']
            stats_by_lang[lang]['empty_segments'] += stats['empty_segments']
            stats_by_lang[lang]['words'] += stats['words']
            
            # Store segment statistics for distribution (non-empty only)
            with open(plaintext_file, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    line = line.strip()
                    if line:
                        words_in_seg = count_words(line)
                        stats_by_lang[lang]['segment_lengths'].append(words_in_seg)
    
    # Process MOS files for tag statistics (HTML, DOCX, and now PDF)
    print("\nProcessing MOS files (for tag statistics)...")
    mos_files = list(data_path.rglob("*.mos")) if data_path.exists() else []
    print(f"Found {len(mos_files)} MOS files (includes HTML, DOCX, and PDF)")
    print(f"  Note: PDFs now use pdf2docx pipeline to generate MOS with XLIFF tags")
    
    for mos_file in mos_files:
        lang = detect_language_from_path(mos_file)
        if lang == 'unknown':
            print(f"  Warning: Could not detect language for {mos_file}")
            continue
        
        # All files are now in data/ directory (no manual/semimanual distinction)
        path_str = str(mos_file)
        doc_type = 'data'
        
        stats = analyze_mos_file(mos_file)
        if stats:
            stats_by_lang[lang]['mos_files'] += 1
            stats_by_lang[lang]['tags'] += stats['tags']
            stats_by_lang[lang]['segments_with_tags'] += stats['segments_with_tags']
            
            # Extract tag types
            with open(mos_file, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    line = line.strip()
                    if line:
                        # Extract tag types
                        tag_types = extract_tag_types(line)
                        stats_by_lang[lang]['tag_types'].extend(tag_types)
                        for tag_type in tag_types:
                            all_tag_types[tag_type] += 1
    
    # Process HTML files for additional counts
    print("\nProcessing HTML files...")
    html_files = list(data_path.rglob("*.html")) if data_path.exists() else []
    print(f"Found {len(html_files)} HTML files")
    
    for html_file in html_files:
        lang = detect_language_from_path(html_file)
        if lang == 'unknown':
            continue
        
        stats_by_lang[lang]['html_files'] += 1
        stats_by_lang[lang]['documents'] += 1
    
    # Process PDF files
    print("\nProcessing PDF files...")
    pdf_files = list(data_path.rglob("*.pdf")) if data_path.exists() else []
    print(f"Found {len(pdf_files)} PDF files")
    
    for pdf_file in pdf_files:
        lang = detect_language_from_path(pdf_file)
        if lang == 'unknown':
            continue
        
        stats_by_lang[lang]['pdf_files'] += 1
        stats_by_lang[lang]['documents'] += 1
    
    # Process DOCX/DOC files (excluding intermediate docx_from_pdf/)
    print("\nProcessing DOCX/DOC files...")
    docx_files = []
    if data_path.exists():
        all_docx = list(data_path.rglob("*.docx")) + list(data_path.rglob("*.doc"))
        # Filter out files from docx_from_pdf directory (intermediate PDF conversion files)
        docx_files = [f for f in all_docx if 'docx_from_pdf' not in str(f)]
    print(f"Found {len(docx_files)} DOCX/DOC files")
    print(f"  Note: Excluding intermediate DOCX files from docx_from_pdf/ directory")
    
    for docx_file in docx_files:
        lang = detect_language_from_path(docx_file)
        if lang == 'unknown':
            continue
        
        stats_by_lang[lang]['docx_files'] += 1
        stats_by_lang[lang]['documents'] += 1
    
    # Print statistics
    print("\n" + "=" * 70)
    print("DATASET STATISTICS BY LANGUAGE")
    print("=" * 70)
    print()
    
    # Sort languages by number of segments (descending)
    sorted_langs = sorted(stats_by_lang.items(), 
                         key=lambda x: x[1]['segments'], 
                         reverse=True)
    
    total_stats = defaultdict(int)
    
    for lang, stats in sorted_langs:
        print(f"\n{lang.upper():^70}")
        print("-" * 70)
        print(f"  Total source files:            {stats['documents']:>10,}")
        print(f"    - HTML files:                {stats['html_files']:>10,}")
        print(f"    - PDF files:                 {stats['pdf_files']:>10,}")
        print(f"    - DOCX files:                {stats['docx_files']:>10,}")
        print(f"  Processed files:")
        print(f"    - MOS files (with tags):     {stats['mos_files']:>10,}")
        print(f"    - Plaintext files:           {stats['plaintext_files']:>10,}")
        total_segs = stats['segments'] + stats['empty_segments']
        print(f"  Segments (from plaintext):")
        print(f"    - Total segments:            {total_segs:>10,}")
        print(f"    - Non-empty:                 {stats['segments']:>10,}")
        print(f"    - Empty:                     {stats['empty_segments']:>10,}")
        if total_segs > 0:
            empty_pct = 100 * stats['empty_segments'] / total_segs
            print(f"    - Empty %:                   {empty_pct:>9.1f}%")
        print(f"  Segments with tags (MOS):      {stats['segments_with_tags']:>10,}  ({100*stats['segments_with_tags']/max(1,stats['segments']):.1f}%)")
        print(f"  Total words:                   {stats['words']:>10,}")
        print(f"  Total tags:                    {stats['tags']:>10,}")
        if stats['segments'] > 0:
            print(f"  Avg words per segment:         {stats['words']/stats['segments']:>10.1f}")
            print(f"  Avg tags per segment:          {stats['tags']/stats['segments']:>10.1f}")
        
        # Add to totals (skip list fields)
        for key in stats:
            if key not in ['segment_lengths', 'tag_types']:
                total_stats[key] += stats[key]
    
    # Calculate percentiles for segment length distribution
    all_segment_lengths = []
    for lang_stats in stats_by_lang.values():
        all_segment_lengths.extend(lang_stats['segment_lengths'])
    all_segment_lengths.sort()
    
    # Print totals
    print("\n" + "=" * 70)
    print(f"{'TOTAL ACROSS ALL LANGUAGES':^70}")
    print("=" * 70)
    print(f"  Total languages:               {len(stats_by_lang):>10}")
    print(f"  Total documents:               {total_stats['documents']:>10,}")
    print(f"    - HTML files:                {total_stats['html_files']:>10,}")
    print(f"    - PDF files:                 {total_stats['pdf_files']:>10,}")
    print(f"    - DOCX files:                {total_stats['docx_files']:>10,}")
    print(f"  Total MOS files:               {total_stats['mos_files']:>10,}")
    print(f"  Total segments:                {total_stats['segments']:>10,}")
    print(f"  Segments with tags:            {total_stats['segments_with_tags']:>10,}  ({100*total_stats['segments_with_tags']/max(1,total_stats['segments']):.1f}%)")
    print(f"  Total words:                   {total_stats['words']:>10,}")
    print(f"  Total tags:                    {total_stats['tags']:>10,}")
    print(f"  Avg words per segment:         {total_stats['words']/max(1,total_stats['segments']):>10.1f}")
    print(f"  Avg tags per segment:          {total_stats['tags']/max(1,total_stats['segments']):>10.1f}")
    
    # Note: Manual/semimanual distinction removed - all files in data/ now
    
    # Segment length distribution
    print(f"\n  Segment length distribution (words):")
    print(f"    Min:                         {min(all_segment_lengths) if all_segment_lengths else 0:>10}")
    print(f"    25th percentile:             {percentile(all_segment_lengths, 25):>10.1f}")
    print(f"    Median (50th):               {percentile(all_segment_lengths, 50):>10.1f}")
    print(f"    75th percentile:             {percentile(all_segment_lengths, 75):>10.1f}")
    print(f"    95th percentile:             {percentile(all_segment_lengths, 95):>10.1f}")
    print(f"    Max:                         {max(all_segment_lengths) if all_segment_lengths else 0:>10}")
    
    # Count all unique document IDs from all sources (not just MOS)
    # AND populate document_pairs from all sources
    all_document_ids = set()
    if data_path.exists():
        # HTML documents
        if (data_path / "html").exists():
            for doc_dir in (data_path / "html").iterdir():
                if doc_dir.is_dir():
                    all_document_ids.add(doc_dir.name)
                    # Add languages for this document
                    for lang_dir in doc_dir.iterdir():
                        if lang_dir.is_dir():
                            lang = lang_dir.name
                            document_pairs[doc_dir.name].add(lang)
        
        # DOCX documents
        if (data_path / "docx").exists():
            for doc_dir in (data_path / "docx").iterdir():
                if doc_dir.is_dir():
                    all_document_ids.add(doc_dir.name)
                    # Add languages for this document
                    for lang_dir in doc_dir.iterdir():
                        if lang_dir.is_dir():
                            lang = lang_dir.name
                            document_pairs[doc_dir.name].add(lang)
        
        # PDF documents
        if (data_path / "pdf").exists():
            for doc_dir in (data_path / "pdf").iterdir():
                if doc_dir.is_dir():
                    all_document_ids.add(doc_dir.name)
                    # Add languages for this document
                    for lang_dir in doc_dir.iterdir():
                        if lang_dir.is_dir():
                            lang = lang_dir.name
                            document_pairs[doc_dir.name].add(lang)
    
    # Document pair statistics
    print("\n" + "=" * 70)
    print("PARALLEL DOCUMENT STATISTICS")
    print("=" * 70)
    print(f"  Total unique document IDs:     {len(all_document_ids):>10,}")
    print(f"    - From HTML sources:         {len([d for d in all_document_ids if d.startswith('html_')]):>10,}")
    print(f"    - From DOCX sources:         {len([d for d in all_document_ids if d.startswith('docx_')]):>10,}")
    print(f"    - From PDF sources:          {len([d for d in all_document_ids if d.startswith('pdf_')]):>10,}")
    print(f"  Document IDs with MOS files:   {len(document_pairs):>10,}")
    print(f"    (All document types: HTML, DOCX, PDF with tags)")
    
    lang_pair_counts = defaultdict(int)
    for doc_name, langs in document_pairs.items():
        if len(langs) >= 2:
            for lang1 in langs:
                for lang2 in langs:
                    if lang1 < lang2:  # Avoid counting both cs-uk and uk-cs
                        pair = f"{lang1}-{lang2}"
                        lang_pair_counts[pair] += 1
    
    if lang_pair_counts:
        print(f"\n  Document pairs by language combination:")
        for pair, count in sorted(lang_pair_counts.items(), key=lambda x: x[1], reverse=True):
            print(f"    {pair:>10}: {count:>5} parallel documents")
    
    # Document origin statistics
    print("\n" + "=" * 70)
    print("DOCUMENT ORIGINS (by website/source)")
    print("=" * 70)
    
    # Analyze origins from URL files
    if data_path.exists():
        # Check HTML documents
        for html_dir in (data_path / "html").iterdir() if (data_path / "html").exists() else []:
            if html_dir.is_dir():
                origin = get_document_origin(html_dir, data_path)
                document_origins[origin] += 1
        
        # Check DOCX documents
        for docx_dir in (data_path / "docx").iterdir() if (data_path / "docx").exists() else []:
            if docx_dir.is_dir():
                origin = get_document_origin(docx_dir, data_path)
                document_origins[origin] += 1
        
        # Check PDF documents  
        for pdf_dir in (data_path / "pdf").iterdir() if (data_path / "pdf").exists() else []:
            if pdf_dir.is_dir():
                origin = get_document_origin(pdf_dir, data_path)
                document_origins[origin] += 1
    
    if document_origins:
        print(f"  Total unique sources:          {len(document_origins):>10}")
        print(f"\n  Documents by source:")
        for domain, count in sorted(document_origins.items(), key=lambda x: x[1], reverse=True):
            if domain != 'unknown':
                print(f"    {domain:<40} {count:>5} documents")
        
        if document_origins.get('unknown', 0) > 0:
            print(f"    {'(unknown/no URL file)':<40} {document_origins['unknown']:>5} documents")
    else:
        print("  No URL files found")
    
    # Tag type statistics
    print("\n" + "=" * 70)
    print("TAG TYPE DISTRIBUTION")
    print("=" * 70)
    print(f"  Unique tag types:              {len(all_tag_types):>10}")
    print(f"\n  Most common tags:")
    for tag_type, count in sorted(all_tag_types.items(), key=lambda x: x[1], reverse=True)[:15]:
        print(f"    <{tag_type}>:                      {count:>10,}  ({100*count/sum(all_tag_types.values()):.1f}%)")
    
    # Prepare JSON-safe version (remove large lists)
    json_safe_stats = {}
    for lang, stats in stats_by_lang.items():
        json_safe_stats[lang] = {
            'documents': stats['documents'],
            'mos_files': stats['mos_files'],
            'html_files': stats['html_files'],
            'segments': stats['segments'],
            'words': stats['words'],
            'tags': stats['tags'],
            'segments_with_tags': stats['segments_with_tags'],
            'avg_words_per_segment': stats['words'] / max(1, stats['segments']),
            'avg_tags_per_segment': stats['tags'] / max(1, stats['segments']),
            'tag_type_count': len(set(stats['tag_types'])),
        }
    
    # Save detailed JSON
    output_data = {
        'by_language': json_safe_stats,
        'totals': {k: v for k, v in total_stats.items() if not isinstance(v, list)},
        'languages': list(stats_by_lang.keys()),
        'num_languages': len(stats_by_lang),
        'document_pairs': {k: list(v) for k, v in list(document_pairs.items())[:100]},  # Limit for JSON size
        'lang_pair_counts': dict(lang_pair_counts),
        'tag_type_distribution': dict(sorted(all_tag_types.items(), key=lambda x: x[1], reverse=True)[:50]),
        'segment_length_distribution': {
            'min': min(all_segment_lengths) if all_segment_lengths else 0,
            'p25': percentile(all_segment_lengths, 25),
            'median': percentile(all_segment_lengths, 50),
            'p75': percentile(all_segment_lengths, 75),
            'p95': percentile(all_segment_lengths, 95),
            'max': max(all_segment_lengths) if all_segment_lengths else 0,
        },
        # Note: manual/semimanual distinction removed
    }
    
    with open(args.output_json, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)
    print(f"\n📊 Detailed statistics saved to: {args.output_json}")
    
    # Generate LaTeX tables
    generate_latex_table(sorted_langs, total_stats, all_tag_types, all_segment_lengths, args.output_latex, lang_pair_counts, document_origins)
    print(f"📝 LaTeX tables saved to: {args.output_latex}")
    
    # Generate Markdown report
    generate_markdown_report(sorted_langs, total_stats, all_tag_types, all_segment_lengths, lang_pair_counts, args.output_md, document_origins)
    print(f"📄 Markdown report saved to: {args.output_md}")
    
    print("\n" + "=" * 70)
    print("✅ Statistics generation complete!")
    print("=" * 70)
    print(f"\n📁 Output files:")
    print(f"   - {args.output_json} (JSON data)")
    print(f"   - {args.output_latex} (LaTeX tables)")
    print(f"   - {args.output_md} (Markdown report)")


def percentile(data, p):
    if not data:
        return 0
    k = (len(data) - 1) * p / 100
    f = int(k)
    c = f + 1 if f + 1 < len(data) else f
    return data[f] + (k - f) * (data[c] - data[f])


def generate_markdown_report(sorted_langs, total_stats, all_tag_types, all_segment_lengths, lang_pair_counts, output_file, document_origins=None):
    """Generate a Markdown report for the dataset."""
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# Curated Dataset Statistics\n\n")
        f.write("*Auto-generated statistics for research paper*\n\n")
        
        f.write("## Dataset Overview\n\n")
        f.write(f"- **Languages**: {len(sorted_langs)}\n")
        f.write(f"- **Total Documents**: {total_stats['documents']:,}\n")
        f.write(f"  - HTML: {total_stats['html_files']:,}\n")
        f.write(f"  - PDF: {total_stats['pdf_files']:,}\n")
        f.write(f"  - DOCX: {total_stats['docx_files']:,}\n")
        f.write(f"- **Total Translatable Segments**: {total_stats['segments']:,}\n")
        f.write(f"- **Segments with Markup Tags**: {total_stats['segments_with_tags']:,} ({100*total_stats['segments_with_tags']/total_stats['segments']:.1f}%)\n")
        f.write(f"- **Total Words**: {total_stats['words']:,}\n")
        f.write(f"- **Total Markup Tags**: {total_stats['tags']:,}\n\n")
        
        f.write("## Statistics by Language\n\n")
        f.write("| Language | Total Docs | HTML | PDF | DOCX | Segments | With Tags | Words |\n")
        f.write("|----------|-----------|------|-----|------|----------|-----------|-------|\n")
        for lang, stats in sorted_langs:
            f.write(f"| {lang.upper()} | {stats['documents']:,} | {stats['html_files']:,} | ")
            f.write(f"{stats['pdf_files']:,} | {stats['docx_files']:,} | {stats['segments']:,} | ")
            f.write(f"{stats['segments_with_tags']:,} | {stats['words']:,} |\n")
        f.write(f"| **Total** | **{total_stats['documents']:,}** | **{total_stats['html_files']:,}** | ")
        f.write(f"**{total_stats['pdf_files']:,}** | **{total_stats['docx_files']:,}** | ")
        f.write(f"**{total_stats['segments']:,}** | **{total_stats['segments_with_tags']:,}** | ")
        f.write(f"**{total_stats['words']:,}** |\n\n")
        
        f.write("## Segment Length Distribution\n\n")
        f.write("| Percentile | Words per Segment |\n")
        f.write("|------------|------------------|\n")
        f.write(f"| Minimum | {min(all_segment_lengths) if all_segment_lengths else 0} |\n")
        f.write(f"| 25th | {percentile(all_segment_lengths, 25):.1f} |\n")
        f.write(f"| Median | {percentile(all_segment_lengths, 50):.1f} |\n")
        f.write(f"| 75th | {percentile(all_segment_lengths, 75):.1f} |\n")
        f.write(f"| 95th | {percentile(all_segment_lengths, 95):.1f} |\n")
        f.write(f"| Maximum | {max(all_segment_lengths) if all_segment_lengths else 0} |\n\n")
        
        f.write("## Parallel Documents\n\n")
        if lang_pair_counts:
            f.write("| Language Pair | Documents |\n")
            f.write("|---------------|----------|\n")
            for pair, count in sorted(lang_pair_counts.items(), key=lambda x: x[1], reverse=True):
                f.write(f"| {pair.upper()} | {count} |\n")
            f.write("\n")
        
        f.write("## Tag Type Distribution\n\n")
        f.write(f"**Unique tag types**: {len(all_tag_types)}\n\n")
        f.write("| Tag | Count | Percentage |\n")
        f.write("|-----|-------|------------|\n")
        total_tag_instances = sum(all_tag_types.values())
        for tag_type, count in sorted(all_tag_types.items(), key=lambda x: x[1], reverse=True):
            f.write(f"| `<{tag_type}>` | {count:,} | {100*count/total_tag_instances:.1f}% |\n")
        f.write("\n")
        
        f.write("## Key Statistics for Paper\n\n")
        f.write(f"- Dataset contains **{len(sorted_langs)} languages**: " + ", ".join([l.upper() for l, _ in sorted_langs]) + "\n")
        f.write(f"- **{total_stats['segments']:,}** translatable segments across all languages\n")
        f.write(f"- **{total_stats['segments_with_tags']:,}** segments ({100*total_stats['segments_with_tags']/total_stats['segments']:.1f}%) contain markup tags\n")
        f.write(f"- Average segment length: **{total_stats['words']/total_stats['segments']:.1f} words**\n")
        f.write(f"- Average tags per segment: **{total_stats['tags']/total_stats['segments']:.1f}**\n")
        f.write(f"- Median segment length: **{percentile(all_segment_lengths, 50):.1f} words**\n")
        f.write(f"- **{len(all_tag_types)} unique tag types** (mainly XLIFF format)\n\n")
        
        # Document origins
        if document_origins and len(document_origins) > 1:
            f.write("## Document Origins\n\n")
            f.write(f"Documents were collected from **{len([d for d in document_origins if d != 'unknown'])} unique sources**:\n\n")
            f.write("| Source Website | Documents |\n")
            f.write("|----------------|----------|\n")
            for domain, count in sorted(document_origins.items(), key=lambda x: x[1], reverse=True):
                if domain != 'unknown':
                    f.write(f"| {domain} | {count} |\n")
            if document_origins.get('unknown', 0) > 0:
                f.write(f"| (unknown/no URL) | {document_origins['unknown']} |\n")
            f.write("\n")
            
            # Categorize by domain type
            gov_domains = {d: c for d, c in document_origins.items() if '.gov.' in d or d.endswith('.gov.cz') or d.endswith('.gov.ua')}
            edu_domains = {d: c for d, c in document_origins.items() if 'cestina' in d or 'czech' in d}
            info_domains = {d: c for d, c in document_origins.items() if 'prague' in d or 'info' in d}
            
            if gov_domains or edu_domains or info_domains:
                f.write("### By Domain Type\n\n")
                if gov_domains:
                    f.write(f"- **Government sites** ({sum(gov_domains.values())} docs): " + ", ".join(gov_domains.keys()) + "\n")
                if edu_domains:
                    f.write(f"- **Educational sites** ({sum(edu_domains.values())} docs): " + ", ".join(edu_domains.keys()) + "\n")
                if info_domains:
                    f.write(f"- **Information portals** ({sum(info_domains.values())} docs): " + ", ".join(info_domains.keys()) + "\n")
                f.write("\n")
        
        # Note: Document type breakdown removed (no manual/semimanual distinction)


def generate_latex_table(sorted_langs, total_stats, all_tag_types, all_segment_lengths, output_file, lang_pair_counts=None, document_origins=None):
    """Generate LaTeX tables for the paper."""
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("% Dataset statistics tables\n")
        f.write("% Auto-generated by count_curated_stats.py\n\n")
        
        # Main statistics table (without "With Tags" column)
        f.write("\\begin{table}[ht]\n")
        f.write("\\centering\n")
        f.write("\\caption{Dataset Statistics by Language}\n")
        f.write("\\label{tab:dataset_stats}\n")
        f.write("\\begin{tabular}{lrrrrr}\n")
        f.write("\\toprule\n")
        f.write("Language & Documents & Segments & Words & Tags & Avg Words/Seg \\\\\n")
        f.write("\\midrule\n")
        
        for lang, stats in sorted_langs:
            docs = stats['documents']  # Total documents (HTML + PDF + DOCX)
            segs = stats['segments']
            words = stats['words']
            tags = stats['tags']
            avg_words = stats['words'] / max(1, stats['segments'])
            
            f.write(f"{lang.upper()} & {docs:,} & {segs:,} & {words:,} & {tags:,} & {avg_words:.1f} \\\\\n")
        
        f.write("\\midrule\n")
        f.write(f"\\textbf{{Total}} & \\textbf{{{total_stats['documents']:,}}} & ")
        f.write(f"\\textbf{{{total_stats['segments']:,}}} & ")
        f.write(f"\\textbf{{{total_stats['words']:,}}} & ")
        f.write(f"\\textbf{{{total_stats['tags']:,}}} & ")
        f.write(f"\\textbf{{{total_stats['words']/max(1,total_stats['segments']):.1f}}} \\\\\n")
        f.write("\\bottomrule\n")
        f.write("\\end{tabular}\n")
        f.write("\\end{table}\n")
        
        # Language pairs table
        if lang_pair_counts:
            f.write("\n\n")
            f.write("% Parallel documents by language pair\n")
            f.write("\\begin{table}[ht]\n")
            f.write("\\centering\n")
            f.write("\\caption{Parallel Documents by Language Pair}\n")
            f.write("\\label{tab:language_pairs}\n")
            f.write("\\begin{tabular}{lr}\n")
            f.write("\\toprule\n")
            f.write("Language Pair & Documents \\\\\n")
            f.write("\\midrule\n")
            
            # Sort by count descending and show top pairs
            sorted_pairs = sorted(lang_pair_counts.items(), key=lambda x: x[1], reverse=True)
            for pair, count in sorted_pairs[:15]:  # Show top 15 pairs
                pair_upper = pair.upper().replace('-', '--')  # Escape hyphen for LaTeX
                f.write(f"{pair_upper} & {count:,} \\\\\n")
            
            f.write("\\bottomrule\n")
            f.write("\\end{tabular}\n")
            f.write("\\end{table}\n")
        
        # Document origins table
        if document_origins:
            f.write("\n\n")
            f.write("% Document sources/origins\n")
            f.write("\\begin{table}[ht]\n")
            f.write("\\centering\n")
            f.write("\\caption{Document Sources by Website}\n")
            f.write("\\label{tab:document_origins}\n")
            f.write("\\begin{tabular}{lr}\n")
            f.write("\\toprule\n")
            f.write("Source Website & Documents \\\\\n")
            f.write("\\midrule\n")
            
            # Sort by count descending
            sorted_origins = sorted(document_origins.items(), key=lambda x: x[1], reverse=True)
            for domain, count in sorted_origins:
                if domain != 'unknown':
                    # Escape underscores and other special chars for LaTeX
                    domain_escaped = domain.replace('_', '\\_').replace('#', '\\#').replace('%', '\\%')
                    f.write(f"{domain_escaped} & {count:,} \\\\\n")
            
            if document_origins.get('unknown', 0) > 0:
                f.write("\\midrule\n")
                f.write(f"Unknown/No URL & {document_origins['unknown']:,} \\\\\n")
            
            f.write("\\bottomrule\n")
            f.write("\\end{tabular}\n")
            f.write("\\end{table}\n")
        
        # Add summary statistics table
        f.write("\n\n")
        f.write("% Summary statistics\n")
        f.write("\\begin{table}[ht]\n")
        f.write("\\centering\n")
        f.write("\\caption{Summary Statistics}\n")
        f.write("\\label{tab:dataset_summary}\n")
        f.write("\\begin{tabular}{lr}\n")
        f.write("\\toprule\n")
        f.write("Metric & Count \\\\\n")
        f.write("\\midrule\n")
        f.write(f"Languages & {len(sorted_langs)} \\\\\n")
        f.write(f"Total Documents & {total_stats['documents']:,} \\\\\n")
        f.write(f"Total Segments & {total_stats['segments']:,} \\\\\n")
        f.write(f"Segments with Tags & {total_stats['segments_with_tags']:,} ({100*total_stats['segments_with_tags']/max(1,total_stats['segments']):.1f}\\%) \\\\\n")
        f.write(f"Total Words & {total_stats['words']:,} \\\\\n")
        f.write(f"Total Tags & {total_stats['tags']:,} \\\\\n")
        f.write(f"Avg Words/Segment & {total_stats['words']/max(1,total_stats['segments']):.1f} \\\\\n")
        f.write(f"Avg Tags/Segment & {total_stats['tags']/max(1,total_stats['segments']):.1f} \\\\\n")
        f.write("\\bottomrule\n")
        f.write("\\end{tabular}\n")
        f.write("\\end{table}\n")


if __name__ == '__main__':
    main()

