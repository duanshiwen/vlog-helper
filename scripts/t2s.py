#!/usr/bin/env python3
"""Traditional → Simplified Chinese converter using opencc.

Usage: python3 t2s.py input.json output.json
Reads whisper JSON, converts transcription text to Simplified Chinese, writes back.
"""
import json
import sys

try:
    from opencc import OpenCC
    cc = OpenCC('t2s')  # Traditional to Simplified
except ImportError:
    # opencc not installed, pass through unchanged
    cc = None

def convert_text(text):
    if cc is None:
        return text
    return cc.convert(text)

def main():
    if len(sys.argv) < 3:
        print("Usage: t2s.py input.json output.json", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Convert whisper JSON transcription text
    if 'transcription' in data:
        for seg in data['transcription']:
            if 'text' in seg:
                seg['text'] = convert_text(seg['text'])

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

if __name__ == '__main__':
    main()
