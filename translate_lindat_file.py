import sys
import argparse
import requests
import uuid
import html


def translate_text(src_lang, tgt_lang, text, model, prompt, base_url):
    """
    Translate a full HTML document using the specified translation API.

    Parameters:
        src_lang (str): Source language code.
        tgt_lang (str): Target language code.
        text (str): The HTML text to translate.
        model (str): The model identifier.
        prompt (str or None): Optional prompt for the translation.
        base_url (str): Base URL for the translation API.

    Returns:
        str: The translated HTML if successful, or an error message.
    """
    url = f"{base_url}/{model}"

    # Send the entire HTML document as a file
    files = {
        'input_text': (
            f'doc{uuid.uuid4().hex}.html',
            text,
            'text/html'
        )
    }
    data = {"src": src_lang, "tgt": tgt_lang}
    if prompt:
        data["prompt"] = prompt
    #else:
    #    data["prompt"] = "Translate the following HTML document from {src} to {tgt}: {sentence}"
   # print(data)
    #print(files)
    response = requests.post(url, files=files, data=data)
    response.encoding = "utf-8"

    if response.status_code == 200:
        return response.text.strip()
    else:
        return f"Error: {response.status_code} - {response.text}"


def main():
    parser = argparse.ArgumentParser(
        description="Translate a full HTML file using a translation API."
    )
    parser.add_argument("--src", default="en",
                        help="Source language (default: en)")
    parser.add_argument("--tgt", default="fr",
                        help="Target language (default: fr)")
    parser.add_argument("--model", default="TowerInstruct-7B-v0.2",
                        help="Model identifier (default: TowerInstruct-7B-v0.2)")
#    parser.add_argument("--prompt", default="Translate the source text at the end of the prompt from {src} to {tgt}. Only print out the translation without any explanations. If the source should not be translated (e.g. it is a piece of code, technical term, filename, or a name of a company), simply copy it to the output. Do not try to interpret unusual inputs, if the input is not in {src}, do not translate it. Transfer all the markup tags from source into the appropriate places in the target. Source text: {sentence} Translation: ",
 
    #help="Optional prompt for translation.")
    parser.add_argument("--prompt", default="Translate from {src} to {tgt}, without adding any explanations, copy the untranslatable content to the output: {sentence} ")
    parser.add_argument("--base-url", default="http://localhost:5001/api/v2/models",
                        help="Base URL for the translation API (default: http://localhost:5001/api/v2/models)")
    parser.add_argument("input_file", nargs="?", type=argparse.FileType("r"),
                        default=sys.stdin,
                        help="Input HTML file to read from (default: standard input)")

    args = parser.parse_args()

    # Read full HTML file
    text = args.input_file.read()

    try:
        translated_text = translate_text(
            src_lang=args.src,
            tgt_lang=args.tgt,
            text=text,
            model=args.model,
            prompt=args.prompt,
            base_url=args.base_url
        )
        print(translated_text)
    except Exception as e:
        print(f"Exception during translation: {e}", file=sys.stderr)
        print("ERROR", file=sys.stderr)


if __name__ == "__main__":
    main()

