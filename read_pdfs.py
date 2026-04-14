
# -*- coding: utf-8 -*-
import os, sys, io
from pdfminer.high_level import extract_text

# Force UTF-8 output
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

base = r'C:\Users\ASUS\Desktop\data-mini'

# List files to find exact names
files = os.listdir(base)
pdf_files = [f for f in files if f.lower().endswith('.pdf')]

for pdf in pdf_files:
    full_path = os.path.join(base, pdf)
    print("="*60)
    print(f"FILE: {pdf}")
    print("="*60)
    try:
        text = extract_text(full_path)
        print(text)
    except Exception as e:
        print(f"ERROR: {e}")
