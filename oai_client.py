import openai
import sys
import os
import argparse

import re
skip_regexes=[r"^\..{3}$"]
# Read input from stdin

def translate_text(src_lang, tgt_lang, text, model, prompt, client):
    """
    Translate text using the Chat Completions API.

    Parameters:
        src_lang (str): Source language code.
        tgt_lang (str): Target language code.
        text (str): The text to translate.
        model (str): The model identifier.
        prompt (str): The prompt template for translation.
        client: OpenAI client instance.

    Returns:
        str: The translated text if successful, or an error message.
    """
    user_message = prompt.format(src_lang=src_lang, tgt_lang=tgt_lang, text=text)
    
    messages = [
        {"role": "user", "content": user_message}
    ]
    
    response = client.chat.completions.create(
        model=model,
        messages=messages,
        temperature=0.05
    )
    
    print(user_message, file=sys.stderr)
    translated_text = response.choices[0].message.content
    print(translated_text, file=sys.stderr)
    
    return translated_text

def matches_any_regex(text: str, regex_list: list[str]) -> bool:
    """
    Check if the given text matches any regex in the list.

    :param text: The input string to check.
    :param regex_list: List of regex patterns (as strings).
    :return: True if any regex matches, False otherwise.
    """
    for pattern in regex_list:
        if re.search(pattern, text):
            return True
def main():
    parser = argparse.ArgumentParser(
        description="Translate a block of text using a translation API."
    )
    parser.add_argument("--src", default="Ukrainian",
                        help="Source language (default: en)")
    parser.add_argument("--tgt", default="Czech",
                        help="Target language (default: fr)")
    parser.add_argument("--model", default="gpt-4.1-nano",
                        help="Model identifier")
    parser.add_argument("--prompt", default="Translate from {src_lang} to {tgt_lang}. Only print out the translation without any explanations. If the source should not be translated (e.g. it is a piece of code, technical term, filename, or a name of a company), simply copy it to the output. Do not try to interpret unusual inputs, if the input is not in {src_lang}, do not translate it. If there are any markup tags (e.g. HTML), transfer all the markup tags from source into the appropriate places in the target. Source text: {text} Translation: ",
                        help="Optional prompt for translation.")
    parser.add_argument("--base-url", default="https://api.openai.com/v1",
                        help="Base URL for the translation API (default: https://api.openai.com/v1)")
    parser.add_argument("--full", action="store_true",
                        help="Process entire input as a single block instead of line by line")
    parser.add_argument("--context", type=int, default=0,
                        help="Enable context-aware mode: shows entire document and all previous translations for consistency (any value > 0 enables this, default: 0)")
    parser.add_argument("--prompt-override", dest="prompt_override", default=None,
                        help="Override the default prompt with a custom one. Use {text} placeholder for the text to translate.")
    parser.add_argument("input_file", nargs="?", type=argparse.FileType("r"),
                        default=sys.stdin,
                        help="Input file to read from (default: standard input)")
    args = parser.parse_args()
    
    print(args.prompt,file=sys.stderr)
    client = openai.OpenAI(
    # This is the default and can be omitted
    base_url=args.base_url,
    api_key=os.environ.get("OPENAI_API_KEY",api_key),
)

    # Read the entire content from the input (file or stdin)
    try:
        if args.full:
            # Process entire input as one block
            text = args.input_file.read()
            if text.strip():
                translated_text = translate_text(
                    src_lang=args.src,
                    tgt_lang=args.tgt,
                    text=text,
                    model=args.model,
                    prompt=args.prompt,
                    client=client
                )
                print(translated_text.strip())
        else:
            # Process line by line (original behavior)
            if args.context > 0:
                # Read all lines first for context-based processing
                lines = [line.rstrip('\n') for line in args.input_file]
                translated_lines = []  # Keep track of all translations so far
                
                for i, line in enumerate(lines):
                    if line.strip()=='':
                        print()
                        translated_lines.append('')
                        continue
                    if line.strip() in ['.pdf','.png']:
                        print(line.strip())
                        translated_lines.append(line.strip())
                        continue
                    if matches_any_regex(line.strip(),skip_regexes):
                        print(line.strip())
                        translated_lines.append(line.strip())
                        continue
                    
                    # Build full context with translations so far
                    context_text = "Full source text for context:\n"
                    context_text += "=" * 50 + "\n"
                    for j, src_line in enumerate(lines):
                        marker = " >>> " if j == i else "     "
                        context_text += f"{marker}{j+1}. {src_line}\n"
                    
                    if translated_lines:
                        context_text += "\n" + "=" * 50 + "\n"
                        context_text += "Translations completed so far:\n"
                        context_text += "=" * 50 + "\n"
                        for j, trans_line in enumerate(translated_lines):
                            context_text += f"     {j+1}. {trans_line}\n"
                    
                    context_text += "\n" + "=" * 50 + "\n"
                    context_text += f"Now translate line {i+1} marked with '>>>':\n"
                    context_text += f"{lines[i]}\n"
                    
                    # Use a context-aware prompt
                    context_prompt = f"You are translating a document from {args.src} to {args.tgt}. Use the full context and previous translations to maintain consistency. Only output the translation of line {i+1}, nothing else.\n\n{context_text}\n\nTranslation of line {i+1}:"
                    
                    translated_text = translate_text(
                        src_lang=args.src,
                        tgt_lang=args.tgt,
                        text=context_text,
                        model=args.model,
                        prompt=context_prompt,
                        client=client
                    )
                    result = translated_text.strip()
                    print(result.replace('\n', ' ').strip())
                    translated_lines.append(result.replace('\n', ' ').strip())
            else:
                # Original line-by-line without context
                for line in args.input_file:
                    if line.strip()=='':
                        print()
                        continue
                    if matches_any_regex(line.strip(),skip_regexes):
                        print(line.strip())
                        continue
                    translated_text = translate_text(
                        src_lang=args.src,
                        tgt_lang=args.tgt,
                        text=line,
                        model=args.model,
                        prompt=args.prompt,
                        client=client
                    )
                    print(translated_text.replace('\n','').strip())
    except Exception as e:
        print(f"Exception during translation: {e}", file=sys.stderr)
        print("ERROR", file=sys.stderr)

if __name__ == "__main__":
    main()




