#!/usr/bin/env python3
"""
Remove XML/HTML tags from text while preserving the plain text content.
Handles HTML-specific elements like scripts, styles, and comments.
Based on tags_eval/markup-transfer-scripts/preprocess/remove_tags.py
"""

import sys
import re
import argparse
import html as html_module


def parse_args():
    parser = argparse.ArgumentParser(
        description="Remove XML/HTML tags from text, preserving plain content."
    )
    parser.add_argument("input", nargs="?", type=argparse.FileType("r"), 
                       default=sys.stdin, help="Input file (default: stdin)")
    parser.add_argument("output", nargs="?", type=argparse.FileType("w"), 
                       default=sys.stdout, help="Output file (default: stdout)")
    parser.add_argument("--keep-html-blocks", action="store_true",
                       help="Keep script/style blocks (only remove tags)")
    parser.add_argument("--decode-entities", action="store_true",
                       help="Decode HTML entities like &amp; &lt; &gt;")
    parser.add_argument("--preserve-whitespace", action="store_true",
                       help="Preserve multiple spaces and line breaks")
    return parser.parse_args()


def remove_html_blocks(text: str, keep_blocks: bool = False) -> str:
    """
    Remove HTML block elements (script, style) and their content.
    Also removes HTML comments.
    """
    if keep_blocks:
        return text
    
    # Remove script blocks (case-insensitive, handles attributes)
    text = re.sub(r'<script[^>]*>.*?</script>', '', text, flags=re.IGNORECASE | re.DOTALL)
    
    # Remove style blocks (case-insensitive, handles attributes)
    text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.IGNORECASE | re.DOTALL)
    
    # Remove HTML comments
    text = re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)
    
    # Remove CDATA sections
    text = re.sub(r'<!\[CDATA\[.*?\]\]>', '', text, flags=re.DOTALL)
    
    # Remove DOCTYPE declarations
    text = re.sub(r'<!DOCTYPE[^>]*>', '', text, flags=re.IGNORECASE)
    
    return text


def extract_tags(sentence: str) -> str:
    """Remove all XML/HTML tags from a sentence and return plain text."""
    # Simple regex approach: remove all tags (opening, closing, self-closing)
    # This handles tags with attributes better than the stack-based approach
    
    # Remove all tags: <tag>, </tag>, <tag attr="value">, <tag/>
    result = re.sub(r'<[^>]+>', '', sentence)
    
    return result


def process_text(text: str, decode_entities: bool = False, 
                 preserve_whitespace: bool = False) -> str:
    """
    Post-process the cleaned text.
    """
    # Decode HTML entities if requested
    if decode_entities:
        text = html_module.unescape(text)
    
    # Normalize whitespace if not preserving
    if not preserve_whitespace:
        # Replace multiple spaces with single space
        text = re.sub(r' +', ' ', text)
        # Replace tabs with spaces
        text = text.replace('\t', ' ')
    
    return text


if __name__ == '__main__':
    args = parse_args()
    
    # Read all content first to handle multi-line blocks (script, style, comments)
    full_text = args.input.read()
    
    # Step 1: Remove HTML block elements (scripts, styles, comments) from full text
    full_text = remove_html_blocks(full_text, keep_blocks=args.keep_html_blocks)
    
    # Step 2: Process line by line for tag removal and output
    # Use splitlines() to avoid extra blank line at the end
    lines = full_text.splitlines()
    
    for i, line in enumerate(lines):
        # Remove inline tags
        plain_text = extract_tags(line)
        
        # Step 3: Post-process (decode entities, normalize whitespace)
        plain_text = process_text(plain_text, 
                                  decode_entities=args.decode_entities,
                                  preserve_whitespace=args.preserve_whitespace)
        
        args.output.write(plain_text)
        # Add newline except after the last line to match input line count
        if i < len(lines) - 1 or full_text.endswith('\n'):
            args.output.write('\n')
    
    if args.input != sys.stdin:
        args.input.close()
    if args.output != sys.stdout:
        args.output.close()

