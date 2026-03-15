#!/usr/bin/env python3
"""
Extract text from PDFs and convert to MOS format.
Uses multiple extraction methods to handle different PDF types.
"""

import sys
import re
from pathlib import Path
import argparse

try:
    import pdfplumber
    HAS_PDFPLUMBER = True
except ImportError:
    HAS_PDFPLUMBER = False

try:
    from PyPDF2 import PdfReader
    HAS_PYPDF2 = True
except ImportError:
    HAS_PYPDF2 = False

try:
    from pdfminer.high_level import extract_text as pdfminer_extract
    HAS_PDFMINER = True
except ImportError:
    HAS_PDFMINER = False


def extract_text_pdfplumber(pdf_path):
    """Extract text using pdfplumber (best for layout preservation)."""
    try:
        with pdfplumber.open(pdf_path) as pdf:
            text = ""
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n"
            return text
    except Exception as e:
        print(f"pdfplumber failed: {e}", file=sys.stderr)
        return None


def extract_text_pypdf2(pdf_path):
    """Extract text using PyPDF2 (fallback method)."""
    try:
        reader = PdfReader(pdf_path)
        text = ""
        for page in reader.pages:
            page_text = page.extract_text()
            if page_text:
                text += page_text + "\n"
        return text
    except Exception as e:
        print(f"PyPDF2 failed: {e}", file=sys.stderr)
        return None


def extract_text_pdfminer(pdf_path):
    """Extract text using pdfminer (most robust for difficult PDFs)."""
    try:
        text = pdfminer_extract(pdf_path)
        return text
    except Exception as e:
        print(f"pdfminer failed: {e}", file=sys.stderr)
        return None


def extract_text(pdf_path):
    """Try multiple extraction methods in order of preference."""
    methods = []
    
    if HAS_PDFPLUMBER:
        methods.append(('pdfplumber', extract_text_pdfplumber))
    if HAS_PDFMINER:
        methods.append(('pdfminer', extract_text_pdfminer))
    if HAS_PYPDF2:
        methods.append(('PyPDF2', extract_text_pypdf2))
    
    if not methods:
        print("ERROR: No PDF extraction library available!", file=sys.stderr)
        print("Install one of: pdfplumber, PyPDF2, or pdfminer.six", file=sys.stderr)
        return None
    
    for method_name, method_func in methods:
        print(f"Trying {method_name}...", file=sys.stderr)
        text = method_func(pdf_path)
        if text and len(text.strip()) > 50:  # Require substantial text
            print(f"Success with {method_name}: {len(text)} chars", file=sys.stderr)
            return text
    
    print("All extraction methods failed or returned insufficient text", file=sys.stderr)
    return None


def segment_text(text):
    """
    Segment text into translatable units similar to MOS format.
    Produces smaller segments suitable for translation.
    """
    if not text:
        return []
    
    segments = []
    
    # First pass: split on obvious boundaries
    # Split on multiple newlines (paragraph breaks)
    paragraphs = re.split(r'\n\n+', text)
    
    for para in paragraphs:
        para = para.strip()
        if not para:
            continue
        
        # Further split each paragraph
        # Split on single newlines (line breaks in PDF)
        lines = para.split('\n')
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # Very short lines (headings, bullets) -> keep as is
            if len(line) < 80:
                if line:
                    segments.append(line)
                continue
            
            # For longer lines, split on sentence boundaries
            # Look for . ! ? followed by space
            # Use a more aggressive split to create shorter segments
            
            # First try splitting on period followed by space
            sentences = re.split(r'([.!?]+\s+)', line)
            
            current = ""
            for i, part in enumerate(sentences):
                if not part.strip():
                    continue
                
                current += part
                
                # If this is a sentence boundary marker
                if re.match(r'^[.!?]+\s+$', part):
                    if current.strip():
                        segments.append(current.strip())
                        current = ""
                # If current segment is getting too long (>200 chars), split it
                elif len(current) > 200 and ',' in current:
                    # Try to split on comma
                    parts = current.rsplit(',', 1)
                    if len(parts) == 2 and len(parts[0]) > 50:
                        segments.append(parts[0].strip() + ',')
                        current = parts[1].strip()
            
            if current.strip():
                segments.append(current.strip())
    
    # Post-process: remove empty, deduplicate consecutive identical segments
    clean_segments = []
    prev = None
    for seg in segments:
        seg = seg.strip()
        if len(seg) < 3:  # Too short
            continue
        if seg == prev:  # Duplicate
            continue
        clean_segments.append(seg)
        prev = seg
    
    return clean_segments


def pdf_to_plaintext(pdf_path, output_path, lang=None):
    """
    Convert PDF to plaintext format (not MOS, as PDFs have no tags).
    
    Args:
        pdf_path: Path to PDF file
        output_path: Path to output plaintext file
        lang: Language code (for naming)
    
    Returns:
        Number of segments extracted, or -1 on error
    """
    pdf_path = Path(pdf_path)
    output_path = Path(output_path)
    
    if not pdf_path.exists():
        print(f"ERROR: PDF not found: {pdf_path}", file=sys.stderr)
        return -1
    
    # Extract text
    text = extract_text(pdf_path)
    
    if not text:
        print(f"ERROR: Could not extract text from {pdf_path}", file=sys.stderr)
        return -1
    
    # Segment
    segments = segment_text(text)
    
    if not segments:
        print(f"ERROR: No segments extracted from {pdf_path}", file=sys.stderr)
        return -1
    
    # Write to MOS format
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        for segment in segments:
            f.write(segment + '\n')
    
    print(f"✓ Created {output_path}: {len(segments)} segments", file=sys.stderr)
    
    return len(segments)


def main():
    parser = argparse.ArgumentParser(
        description='Extract text from PDFs and convert to plaintext format'
    )
    parser.add_argument('pdf_file', help='Input PDF file')
    parser.add_argument('output_file', help='Output plaintext file')
    parser.add_argument('--lang', help='Language code (optional)', default='unknown')
    
    args = parser.parse_args()
    
    num_segments = pdf_to_plaintext(args.pdf_file, args.output_file, args.lang)
    
    if num_segments < 0:
        sys.exit(1)
    
    print(f"Extracted {num_segments} segments")
    sys.exit(0)


if __name__ == '__main__':
    main()

