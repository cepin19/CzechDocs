#!/usr/bin/env python3
# Modified from Salesforce eval script to work with plaintext files instead of JSON

import os
import re
import random
import argparse
from lxml import etree


def convertToXML(string: str):
    try:
        return etree.fromstring(string)
    except Exception:
        return None


def matchXML(trans: etree._Element, gold: etree._Element):
    if trans.tag != gold.tag:
        return False

    trans = list(trans.iterchildren())
    gold = list(gold.iterchildren())

    if len(trans) != len(gold):
        return False

    for (t, g) in zip(trans, gold):
        if not matchXML(t, g):
            return False
    return True


eng_regex = r"[.,'/:a-zA-Z$]*[A-Z]+[.,'/:a-zA-Z$]*"
num_regex = r"[0-9.,'/:]*[0-9]+[0-9.,'/:]*"


def num_tech_eval(translation, target, total_trans, total_gold, correct_trans, correct_gold, english_term):
    trans_num = re.findall(num_regex, translation)
    gold_num = re.findall(num_regex, target)

    trans_english_term = [elm for elm in re.findall(eng_regex, translation) if elm in english_term]
    gold_english_term = [elm for elm in re.findall(eng_regex, target) if elm in english_term]

    trans = trans_num + trans_english_term
    gold = gold_num + gold_english_term

    total_trans += len(trans)
    total_gold += len(gold)

    def convert(lst):
        res = set()
        check = {}
        for n in lst:
            index = check.get(n, 1)
            res.add(f"{n}__{index}")
            check[n] = index + 1
        return res

    trans = convert(trans)
    gold = convert(gold)

    for n in trans:
        if n in gold:
            correct_trans += 1

    for n in gold:
        if n in trans:
            correct_gold += 1

    return total_trans, correct_trans, total_gold, correct_gold


def de_escape(string: str):
    return string.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")


def main():
    parser = argparse.ArgumentParser(description="Evaluate translation vs. reference using plaintext input files.")
    parser.add_argument("--target", required=True, help="Path to the reference text file (one segment per line).")
    parser.add_argument("--translation", required=True, help="Path to the translation text file (one segment per line).")
    parser.add_argument("--english_term", default="", help="Optional path to English term list (one per line).")
    parser.add_argument("--lang", default="en", help="Language code for BLEU evaluation.")
    args = parser.parse_args()

    assert os.path.exists(args.target), f"Missing target file: {args.target}"
    assert os.path.exists(args.translation), f"Missing translation file: {args.translation}"

    # Load files
    with open(args.target, "r", encoding="utf-8") as f:
        gold_lines = [l.strip() for l in f]# if l.strip()]
    with open(args.translation, "r", encoding="utf-8") as f:
        trans_lines = [l.strip() for l in f]# if l.strip()]

    assert len(gold_lines) == len(trans_lines), "Target and translation files must have the same number of lines."

    if args.english_term and os.path.exists(args.english_term):
        with open(args.english_term, "r", encoding="utf-8") as f:
            english_term = set([l.strip() for l in f if l.strip()])
        total_trans = total_gold = correct_trans = correct_gold = 0
    else:
        english_term = None

    tagTypeList = [
        "ph", "xref", "uicontrol", "b", "codeph", "parmname", "i", "title",
        "menucascade", "varname", "userinput", "filepath", "term", "systemoutput",
        "cite", "li", "ul", "p", "note", "indexterm", "u", "fn", "g", "x", "ex", "bx"
    ]
    tagBegList = [f"<{t}>" for t in tagTypeList]
    tagEndList = [f"</{t}>" for t in tagTypeList]
    tagList = tagBegList + tagEndList

    DUMMY = "####DUMMY###SEPARATOR###DUMMY###"
    suffix = f"eval_test_{random.randint(0, 100000000000000)}"
    os.makedirs(suffix, exist_ok=True)

    f_trans_without_tags = open(os.path.join(suffix, "trans.txt"), "w", encoding="utf-8")
    f_trans_with_tags = open(os.path.join(suffix, "trans_struct.txt"), "w", encoding="utf-8")
    f_gold_without_tags = open(os.path.join(suffix, "gold.txt"), "w", encoding="utf-8")
    f_gold_with_tags = open(os.path.join(suffix, "gold_struct.txt"), "w", encoding="utf-8")

    xml_acc = xml_match = 0
    total_ref_tags = 0
    total_hyp_tags = 0
    segments_with_tags_in_ref = 0
    segments_with_tags_in_hyp = 0
    segments_both_have_tags = 0
    segments_both_no_tags = 0
    segments_ref_has_hyp_missing = 0

    for translation, target in zip(trans_lines, gold_lines):
        # Count tags in original strings
        ref_tag_count = target.count('<')
        hyp_tag_count = translation.count('<')
        total_ref_tags += ref_tag_count
        total_hyp_tags += hyp_tag_count
        
        # Track segment-level tag presence
        ref_has_tags = ref_tag_count > 0
        hyp_has_tags = hyp_tag_count > 0
        
        if ref_has_tags:
            segments_with_tags_in_ref += 1
        if hyp_has_tags:
            segments_with_tags_in_hyp += 1
        if ref_has_tags and hyp_has_tags:
            segments_both_have_tags += 1
        if not ref_has_tags and not hyp_has_tags:
            segments_both_no_tags += 1
        if ref_has_tags and not hyp_has_tags:
            segments_ref_has_hyp_missing += 1
        
        xml_elm_target = convertToXML(f"<ROOT>{target}</ROOT>")
        xml_elm_translation = convertToXML(f"<ROOT>{translation}</ROOT>")
        assert xml_elm_target is not None

        match = False
        if xml_elm_translation is not None:
            xml_acc += 1
            if matchXML(xml_elm_translation, xml_elm_target):
                xml_match += 1
                match = True

        for tag in tagList:
            target = target.replace(tag, DUMMY)
            translation = translation.replace(tag, DUMMY)
        target = de_escape(target)
        translation = de_escape(translation)

        target = target.split(DUMMY)
        translation = translation.split(DUMMY)

        if english_term is not None:
            total_trans, correct_trans, total_gold, correct_gold = num_tech_eval(
                "".join(translation),
                "".join(target),
                total_trans,
                total_gold,
                correct_trans,
                correct_gold,
                english_term,
            )

        f_trans_without_tags.write("".join(translation) + "\n")
        f_gold_without_tags.write("".join(target) + "\n")

        if match and len(target) == len(translation):
            for t, g in zip(translation, target):
                f_trans_with_tags.write(t + "\n")
                f_gold_with_tags.write(g + "\n")
        else:
            for g in target:
                f_trans_with_tags.write("\n")
                f_gold_with_tags.write(g + "\n")

    # Print tag statistics first
    print("=" * 60)
    print("TAG STATISTICS")
    print("=" * 60)
    print(f"Total segments: {len(gold_lines)}")
    print(f"  - Both have tags: {segments_both_have_tags}")
    print(f"  - Both have NO tags: {segments_both_no_tags}")
    print(f"  - Ref has tags, Hyp missing: {segments_ref_has_hyp_missing}")
    print(f"  - Hyp has tags, Ref missing: {segments_with_tags_in_hyp - segments_both_have_tags}")
    print()
    print(f"Reference segments with tags: {segments_with_tags_in_ref} ({100*segments_with_tags_in_ref/len(gold_lines):.1f}%)")
    print(f"Hypothesis segments with tags: {segments_with_tags_in_hyp} ({100*segments_with_tags_in_hyp/len(gold_lines):.1f}%)")
    print()
    print(f"Total tags in reference: {total_ref_tags}")
    print(f"Total tags in hypothesis: {total_hyp_tags}")
    if total_ref_tags > 0:
        tag_preservation_rate = 100 * total_hyp_tags / total_ref_tags
        print(f"Tag preservation rate: {tag_preservation_rate:.1f}% ({total_hyp_tags}/{total_ref_tags})")
    
    # Warnings
    print()
    if total_ref_tags == 0:
        print("⚠️  WARNING: Reference has NO tags - tag accuracy metrics are not meaningful")
        print("   This is expected for tag-removal baseline approaches (8-10)")
    elif total_hyp_tags == 0:
        print(f"⚠️  WARNING: Hypothesis has NO tags but reference has {total_ref_tags} tags!")
        print(f"   Translation lost ALL {segments_ref_has_hyp_missing} segments with tags!")
        print("   This is ONLY expected for approach 11 (ignore prompt) or tag removal approaches")
    elif segments_ref_has_hyp_missing > 0:
        print(f"⚠️  WARNING: {segments_ref_has_hyp_missing} segments lost their tags during translation")
        print(f"   Tag preservation: {total_hyp_tags}/{total_ref_tags} = {100*total_hyp_tags/total_ref_tags:.1f}%")
    
    # XML Metrics
    print()
    print("=" * 60)
    print("XML STRUCTURE METRICS")
    print("=" * 60)
    print(f"XML structure accuracy: {100*xml_acc/len(gold_lines):.2f}%")
    print(f"  (Percentage of hypothesis segments that are valid XML)")
    print(f"XML matching accuracy:  {100*xml_match/len(gold_lines):.2f}%")
    print(f"  (Percentage of segments where XML structure matches reference)")
    
    if total_ref_tags == 0 and total_hyp_tags == 0:
        print("  ℹ️  Note: Both files have no tags - 100% matching means no tag errors but")
        print("           doesn't indicate good tag handling (nothing to handle)")
    elif segments_both_no_tags > 0 and xml_match > 0:
        print(f"  ℹ️  Note: {segments_both_no_tags} segments matched because both had no tags")
    
    print()

    if english_term is not None:
        print(f"NE&NUM precision: {100*correct_trans/total_trans:.2f}%")
        print(f"NE&NUM recall:    {100*correct_gold/total_gold:.2f}%")

    f_trans_without_tags.close()
    f_trans_with_tags.close()
    f_gold_without_tags.close()
    f_gold_with_tags.close()

    # Calculate BLEU scores
    bleu_result = os.system(f"./scripts/calc_bleu.sh {args.lang} {suffix} 2> {os.path.join(suffix, 'TMP')}")
    
    if bleu_result == 0 and os.path.exists(os.path.join(suffix, "bleu.txt")):
        try:
            with open(os.path.join(suffix, "bleu.txt"), "r", encoding="utf-8") as f:
                bleu = float(f.readline().split()[2][:-1])
            with open(os.path.join(suffix, "bleu_struct.txt"), "r", encoding="utf-8") as f:
                bleu_struct = float(f.readline().split()[2][:-1])
            print("BLEU:", bleu)
            print("XML BLEU:", bleu_struct)
        except (IndexError, ValueError) as e:
            print(f"Warning: Could not parse BLEU scores: {e}")
    else:
        print("Warning: BLEU calculation script failed or is not available")

    os.system(f"rm -r {suffix}")


if __name__ == "__main__":
    main()

