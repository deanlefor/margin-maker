"""Independent development checks; no component of this script ships in the app.

Requires requirements-dev.txt, macOS Swift tools, qpdf, and Poppler. Exit 2 reports
the known ActualText loss; exit 1 means an unexpected compatibility check failed.
Use only a new disposable output directory. No personal PDFs are read.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import unicodedata

from pypdf import PdfReader, PdfWriter
from pypdf.generic import DecodedStreamObject, NameObject
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, capture_output=True, text=True)


def normalized(text: str) -> str:
    return " ".join(unicodedata.normalize("NFC", text).split())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="new disposable directory (must not exist)")
    parser.add_argument("--font", type=Path,
                        default=Path("/System/Library/Fonts/Supplemental/Arial Unicode.ttf"))
    args = parser.parse_args()
    for tool in ("swiftc", "qpdf", "pdftotext", "pdftoppm"):
        if shutil.which(tool) is None:
            parser.error(f"Install the development tool {tool} before running this check.")
    if not args.font.is_file():
        parser.error("Supply --font with a TrueType font covering Greek, Cyrillic, and CJK.")
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=False)
    repo = Path(__file__).resolve().parent.parent

    c = canvas.Canvas(str(root / "placeholder.pdf"), pagesize=(612, 792))
    c.drawString(72, 720, "placeholder"); c.save()
    writer = PdfWriter()
    page = writer.add_page(PdfReader(root / "placeholder.pdf").pages[0])
    stream = DecodedStreamObject()
    stream.set_data(b"BT /F1 16 Tf 72 720 Td /Span << /ActualText "
                    b"<FEFF00610063006100640065006D0069006300200074006500780074> "
                    b">> BDC (XXXXX) Tj EMC ET")
    page[NameObject("/Contents")] = writer._add_object(stream)
    writer.write(root / "actualtext.pdf")

    pdfmetrics.registerFont(TTFont("CompatibilityUnicode", str(args.font)))
    c = canvas.Canvas(str(root / "unicode.pdf"), pagesize=(612, 792))
    c.setFont("CompatibilityUnicode", 16)
    for index, text in enumerate(["office fi fl ﬁ ﬂ ffi ﬃ", "café naïve résumé Straße Δ α β ∑ ∫",
                                  "Пример текста Ελληνικά 中文 日本語"]):
        c.drawString(50, 740 - index * 35, text)
    c.save()

    c = canvas.Canvas(str(root / "ocr-visible.pdf"), pagesize=(612, 792))
    c.setFont("Helvetica", 16); c.drawString(72, 720, "OCR academic reading 123"); c.save()
    run("pdftoppm", "-f", "1", "-singlefile", "-scale-to", "792", "-png",
        str(root / "ocr-visible.pdf"), str(root / "ocr-scan"))
    c = canvas.Canvas(str(root / "ocr.pdf"), pagesize=(612, 792))
    c.drawImage(str(root / "ocr-scan.png"), 0, 0, width=612, height=792)
    text = c.beginText(72, 720)
    text.setFont("Helvetica", 16); text.setTextRenderMode(3)
    text.textLine("OCR academic reading 123"); c.drawText(text); c.save()

    run("swiftc", "-parse-as-library", "-module-cache-path", str(root / "swift-cache"),
        *map(str, sorted((repo / "Sources/MarginMakerCore").glob("*.swift"))),
        str(repo / "scripts/pdf-compatibility.swift"), "-o", str(root / "probe"))
    run(str(root / "probe"), str(root))
    results = []
    actual_text_preserved = True
    for name in ("actualtext", "unicode", "ocr"):
        source = root / f"{name}.pdf"
        source_text = normalized(run("pdftotext", str(source), "-").stdout)
        assert run("qpdf", "--check", str(source), check=False).returncode == 0
        assert name != "actualtext" or source_text == "academic text"
        python_text = normalized(PdfReader(source).pages[0].extract_text())
        for orientation, dimensions in (("Portrait", (612, 792)), ("Landscape", (792, 612))):
            output = root / f"{name}-{orientation}.pdf"
            check = run("qpdf", "--check", str(output), check=False)
            extracted = normalized(run("pdftotext", str(output), "-").stdout)
            reader = PdfReader(output)
            assert len(reader.pages) == 1
            assert tuple(reader.pages[0].mediabox.upper_right) == dimensions
            assert reader.pages[0].rotation == 0
            assert check.returncode == 0, check.stderr
            if name == "actualtext":
                actual_text_preserved &= extracted == source_text
            else:
                assert extracted == source_text, (name, extracted, source_text)
                assert normalized(reader.pages[0].extract_text()) == python_text
            results.append(dict(source=name, orientation=orientation, qpdf_status=check.returncode,
                                source_poppler_text=source_text, exported_poppler_text=extracted))
    controls = {}
    for name in ("actualtext", "unicode"):
        file = root / f"{name}-bare-quartz.pdf"
        controls[name] = dict(text=normalized(run("pdftotext", str(file), "-").stdout),
                              qpdf=run("qpdf", "--check", str(file), check=False).stderr.strip())
    report = dict(actual_text_preserved=actual_text_preserved, exports=results, bare_quartz=controls,
                  pdfkit_resave_text=normalized(run("pdftotext", str(root / "actualtext-pdfkit-resave.pdf"), "-").stdout),
                  qpdf_version=run("qpdf", "--version").stdout.strip(),
                  poppler_version=run("pdftotext", "-v").stderr.strip())
    (root / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if actual_text_preserved else 2


if __name__ == "__main__":
    raise SystemExit(main())
