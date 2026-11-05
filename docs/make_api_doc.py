"""Builds docs/API.docx and docs/API.pdf from docs/API.md (the generated API reference).

Run:  python docs/make_api_doc.py   (needs pip install pypandoc_binary python-docx, and LibreOffice for the PDF)
Regenerate docs/API.md first with `flask --app run api-docs` if the API changed.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import pypandoc

DOCS = Path(__file__).resolve().parent
sys.path.insert(0, str(DOCS / "requirements"))
from make_docx import polish  # noqa: E402

md = (DOCS / "API.md").read_text(encoding="utf-8")
# Drop the "generated, do not edit" note (for the repo, not the reader) and the H1 (the title is set below)
md = "\n".join(l for l in md.splitlines() if not l.startswith(("> Generated", "# ")))

out = DOCS / "API.docx"
with tempfile.TemporaryDirectory() as tmp:
    src = Path(tmp) / "API.md"
    src.write_text(md, encoding="utf-8")
    pypandoc.convert_file(str(src), "docx", outputfile=str(out),
                          extra_args=["--from=gfm", "--metadata=title:Anime World Shop - API Documentation"])
polish(out)
print("wrote", out.name)

soffice = shutil.which("soffice") or r"C:\Program Files\LibreOffice\program\soffice.exe"
subprocess.run([soffice, "--headless", "--convert-to", "pdf", "--outdir", str(DOCS), str(out)], check=True)
print("wrote API.pdf")
