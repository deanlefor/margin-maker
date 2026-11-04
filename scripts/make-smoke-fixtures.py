"""Optional UI fixtures; requires requirements-dev.txt. Never uses user PDFs."""
from io import BytesIO
from pathlib import Path
import textwrap

from pypdf import PdfReader, PdfWriter
from reportlab.pdfgen import canvas

destination = Path(__file__).resolve().parents[1] / "tmp" / "smoke"
destination.mkdir(parents=True, exist_ok=True)
buffer = BytesIO()
pdf = canvas.Canvas(buffer)
pdf.setTitle("A reading with room for thought")
paragraph = (
    "Reading is an active conversation with a text. A generous margin gives "
    "questions, connections, and small discoveries a place to live. These "
    "sample pages exercise Letter, A4, landscape rotation, and offset crops."
)
for number, size in enumerate([(612, 792), (595.28, 841.89), (612, 792), (612, 792)], 1):
    pdf.setPageSize(size)
    width, height = size
    pdf.setFillColorRGB(0.10, 0.38, 0.37)
    pdf.setFont("Helvetica-Bold", 10)
    pdf.drawString(60, height - 65, "MARGIN MAKER  /  SAMPLE READING")
    pdf.setFillColorRGB(0.10, 0.13, 0.16)
    pdf.setFont("Times-Bold", 27)
    pdf.drawString(60, height - 110, "A reading with room for thought")
    pdf.setFont("Times-Italic", 12)
    pdf.drawString(60, height - 137, f"Page {number} - selectable vector text")
    pdf.setStrokeColorRGB(0.1, 0.5, 0.45)
    pdf.line(60, height - 155, width - 60, height - 155)
    for column in range(2):
        x = 60 + column * (width - 100) / 2
        text = pdf.beginText(x, height - 185)
        text.setFont("Times-Roman", 11)
        text.setLeading(15)
        for repeat in range(4):
            for line in textwrap.wrap(paragraph, 43):
                text.textLine(line)
            text.textLine("")
        pdf.drawText(text)
    pdf.setFont("Helvetica", 9)
    pdf.drawCentredString(width / 2, 42, f"SAMPLE PAGE {number}")
    pdf.showPage()
pdf.save()
reader = PdfReader(BytesIO(buffer.getvalue()))
writer = PdfWriter()
for page in reader.pages:
    writer.add_page(page)
writer.pages[2].rotate(90)
writer.pages[3].cropbox.lower_left = (48, 30)
writer.pages[3].cropbox.upper_right = (570, 760)
with (destination / "Sample Reading.pdf").open("wb") as output:
    writer.write(output)
locked = PdfWriter()
locked.add_page(reader.pages[0])
locked.encrypt("margin-maker-test-password")
with (destination / "Locked.pdf").open("wb") as output:
    locked.write(output)
(destination / "Invalid.pdf").write_text("This is not a PDF.\n")
(destination / "Empty.pdf").write_bytes(b"")
print(destination)
