#!/usr/bin/env python3
"""
Alternative PDF to MOS converter using pdf2docx.

This script converts PDF to DOCX first, then uses tikal.sh to convert DOCX to MOS.
This preserves more structure and formatting compared to direct text extraction.

Usage:
    python pdf_to_mos_via_docx.py <input.pdf> <output.mos>
"""

import sys
import os
import tempfile
import subprocess
from pathlib import Path


def pdf_to_docx(pdf_path, docx_path):
    """
    Convert PDF to DOCX using pdf2docx library.
    
    Args:
        pdf_path: Path to input PDF file
        docx_path: Path to output DOCX file
    
    Returns:
        True if successful, False otherwise
    """
    try:
        from pdf2docx import Converter
        
        print(f"Converting PDF to DOCX...")
        print(f"  Input: {pdf_path}")
        print(f"  Output: {docx_path}")
        
        cv = Converter(pdf_path)
        cv.convert(docx_path, start=0, end=None)
        cv.close()
        
        print(f"✓ PDF to DOCX conversion successful")
        return True
        
    except ImportError:
        print("Error: pdf2docx library not installed")
        print("Install with: pip install pdf2docx")
        return False
    except Exception as e:
        print(f"Error converting PDF to DOCX: {e}")
        return False


def docx_to_mos(docx_path, mos_path, tikal_path="../../tikal.sh", srx_path="../../config/defaultSegmentation.srx", lang="en"):
    """
    Convert DOCX to MOS using tikal.sh.
    
    Args:
        docx_path: Path to input DOCX file
        mos_path: Path to output MOS file
        tikal_path: Path to tikal.sh script
        srx_path: Path to segmentation rules
        lang: Language code
    
    Returns:
        True if successful, False otherwise
    """
    try:
        print(f"\nConverting DOCX to MOS...")
        print(f"  Input: {docx_path}")
        print(f"  Output: {mos_path}")
        
        # Check if tikal.sh exists
        if not os.path.exists(tikal_path):
            print(f"Error: tikal.sh not found at {tikal_path}")
            return False
        
        # Make tikal.sh executable
        os.chmod(tikal_path, 0o755)
        
        # Run tikal.sh to extract MOS
        cmd = [
            tikal_path,
            "-xm",  # Extract to MOS format
            docx_path,
            "-sl", lang,
            "-tl", lang,
            "-ie", "utf8",
            "-oe", "utf8",
            "-seg", srx_path,
            "-to", mos_path
        ]
        
        print(f"  Running: {' '.join(cmd)}")
        
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False
        )
        
        if result.returncode != 0:
            print(f"Warning: tikal.sh returned non-zero exit code: {result.returncode}")
            print(f"Stderr: {result.stderr}")
        
        # tikal.sh adds language extension to the output file
        mos_path_with_lang = f"{mos_path}.{lang}"
        
        # Check if MOS file was created (with or without language extension)
        actual_mos_path = None
        if os.path.exists(mos_path) and os.path.getsize(mos_path) > 0:
            actual_mos_path = mos_path
        elif os.path.exists(mos_path_with_lang) and os.path.getsize(mos_path_with_lang) > 0:
            actual_mos_path = mos_path_with_lang
            # Rename to remove language extension
            os.rename(mos_path_with_lang, mos_path)
            actual_mos_path = mos_path
            print(f"  Renamed {mos_path_with_lang} -> {mos_path}")
        
        if actual_mos_path:
            print(f"✓ DOCX to MOS conversion successful")
            
            # Count segments
            with open(actual_mos_path, 'r', encoding='utf-8', errors='ignore') as f:
                segments = [line.strip() for line in f if line.strip()]
            print(f"  Extracted {len(segments)} segments")
            
            return True
        else:
            print(f"Error: MOS file was not created or is empty")
            print(f"  Expected: {mos_path} or {mos_path_with_lang}")
            return False
        
    except Exception as e:
        print(f"Error converting DOCX to MOS: {e}")
        return False


def pdf_to_mos_via_docx(pdf_path, mos_path, keep_docx=False, tikal_path="../../tikal.sh", srx_path="../../config/defaultSegmentation.srx", lang="en"):
    """
    Convert PDF to MOS via intermediate DOCX conversion.
    
    Args:
        pdf_path: Path to input PDF file
        mos_path: Path to output MOS file
        keep_docx: If True, keep the intermediate DOCX file
        tikal_path: Path to tikal.sh script
        srx_path: Path to segmentation rules
        lang: Language code
    
    Returns:
        True if successful, False otherwise
    """
    # Create temporary DOCX file
    if keep_docx:
        # Keep DOCX in same directory as MOS
        mos_dir = os.path.dirname(mos_path)
        mos_name = os.path.splitext(os.path.basename(mos_path))[0]
        docx_path = os.path.join(mos_dir, f"{mos_name}.docx")
    else:
        # Use temporary file
        with tempfile.NamedTemporaryFile(suffix='.docx', delete=False) as tmp:
            docx_path = tmp.name
    
    try:
        print("=" * 70)
        print("PDF TO MOS CONVERSION (via DOCX)")
        print("=" * 70)
        print(f"Input PDF: {pdf_path}")
        print(f"Output MOS: {mos_path}")
        print(f"Intermediate DOCX: {docx_path}")
        print(f"Keep DOCX: {keep_docx}")
        print()
        
        # Step 1: PDF to DOCX
        if not pdf_to_docx(pdf_path, docx_path):
            return False
        
        # Step 2: DOCX to MOS
        if not docx_to_mos(docx_path, mos_path, tikal_path, srx_path, lang):
            return False
        
        print("\n" + "=" * 70)
        print("✓ CONVERSION COMPLETE")
        print("=" * 70)
        
        return True
        
    except Exception as e:
        print(f"Error in conversion pipeline: {e}")
        return False
        
    finally:
        # Clean up temporary DOCX if requested
        if not keep_docx and os.path.exists(docx_path):
            try:
                os.remove(docx_path)
                print(f"\nCleaned up temporary DOCX file")
            except:
                pass


def main():
    """Main entry point."""
    if len(sys.argv) < 3:
        print("Usage: python pdf_to_mos_via_docx.py <input.pdf> <output.mos> [--keep-docx] [--lang LANG]")
        print()
        print("Options:")
        print("  --keep-docx    Keep the intermediate DOCX file")
        print("  --lang LANG    Language code (default: en)")
        print()
        print("Example:")
        print("  python pdf_to_mos_via_docx.py document.pdf output.mos")
        print("  python pdf_to_mos_via_docx.py document.pdf output.mos --keep-docx --lang cs")
        sys.exit(1)
    
    pdf_path = sys.argv[1]
    mos_path = sys.argv[2]
    
    # Parse options
    keep_docx = '--keep-docx' in sys.argv
    lang = 'en'
    if '--lang' in sys.argv:
        try:
            lang_idx = sys.argv.index('--lang')
            lang = sys.argv[lang_idx + 1]
        except:
            pass
    
    # Validate input
    if not os.path.exists(pdf_path):
        print(f"Error: Input PDF not found: {pdf_path}")
        sys.exit(1)
    
    # Create output directory if needed
    os.makedirs(os.path.dirname(mos_path) or '.', exist_ok=True)
    
    # Run conversion
    success = pdf_to_mos_via_docx(pdf_path, mos_path, keep_docx=keep_docx, lang=lang)
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

