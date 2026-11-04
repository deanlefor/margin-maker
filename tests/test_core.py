"""Regression tests for the reusable, headless PDF placement engine."""

from __future__ import annotations

import unittest
from io import BytesIO

from pypdf import PdfReader, PdfWriter
from reportlab.lib.pagesizes import A4, letter
from reportlab.pdfgen.canvas import Canvas

from margin_maker.core import (
    LETTER_HEIGHT,
    LETTER_WIDTH,
    Layout,
    convert_pdf,
    placement_for_page,
    read_page_count,
)


def sample_pdf() -> bytes:
    data = BytesIO()
    canvas = Canvas(data, pagesize=letter)
    canvas.drawString(72, 720, "FIRST PAGE: selectable text")
    canvas.showPage()
    canvas.setPageSize(A4)
    canvas.drawString(75, 710, "SECOND PAGE: also selectable")
    canvas.showPage()
    canvas.save()
    return data.getvalue()


class MarginMakerCoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.source = sample_pdf()

    def test_reader_page_count(self) -> None:
        self.assertEqual(read_page_count(self.source), 2)

    def test_right_middle_75_percent_letter_layout(self) -> None:
        page = PdfReader(BytesIO(self.source)).pages[0]
        _, rect = placement_for_page(page, Layout(75, "right", "middle"))
        self.assertEqual(tuple(round(x, 4) for x in rect), (153.0, 99.0, 612.0, 693.0))

    def test_nine_anchors_touch_expected_edges(self) -> None:
        page = PdfReader(BytesIO(self.source)).pages[0]
        for h in ("left", "center", "right"):
            for v in ("top", "middle", "bottom"):
                with self.subTest(h=h, v=v):
                    _, (x0, y0, x1, y1) = placement_for_page(page, Layout(50, h, v))
                    self.assertGreaterEqual(x0, -1e-9)
                    self.assertGreaterEqual(y0, -1e-9)
                    self.assertLessEqual(x1, LETTER_WIDTH + 1e-9)
                    self.assertLessEqual(y1, LETTER_HEIGHT + 1e-9)
                    if h == "left":
                        self.assertAlmostEqual(x0, 0)
                    elif h == "center":
                        self.assertAlmostEqual(x0, LETTER_WIDTH - x1)
                    else:
                        self.assertAlmostEqual(x1, LETTER_WIDTH)
                    if v == "bottom":
                        self.assertAlmostEqual(y0, 0)
                    elif v == "middle":
                        self.assertAlmostEqual(y0, LETTER_HEIGHT - y1)
                    else:
                        self.assertAlmostEqual(y1, LETTER_HEIGHT)

    def test_export_letter_pages_and_preserve_text_and_order(self) -> None:
        original = self.source
        output = convert_pdf(
            self.source,
            [Layout(75, "right", "middle"), Layout(65, "center", "top")],
        )
        reader = PdfReader(BytesIO(output))
        self.assertEqual(len(reader.pages), 2)
        for page in reader.pages:
            self.assertAlmostEqual(float(page.mediabox.width), LETTER_WIDTH)
            self.assertAlmostEqual(float(page.mediabox.height), LETTER_HEIGHT)
        self.assertIn("FIRST PAGE", reader.pages[0].extract_text())
        self.assertIn("SECOND PAGE", reader.pages[1].extract_text())
        self.assertEqual(self.source, original)

    def test_single_page_preview_export(self) -> None:
        output = convert_pdf(
            self.source, [Layout(), Layout()], page_indices=[1]
        )
        reader = PdfReader(BytesIO(output))
        self.assertEqual(len(reader.pages), 1)
        self.assertIn("SECOND PAGE", reader.pages[0].extract_text())

    def test_rotated_page_export(self) -> None:
        writer = PdfWriter()
        writer.add_page(PdfReader(BytesIO(self.source)).pages[0]).rotate(90)
        data = BytesIO()
        writer.write(data)
        output = convert_pdf(data.getvalue(), [Layout()])
        page = PdfReader(BytesIO(output)).pages[0]
        self.assertEqual(int(page.get("/Rotate", 0) or 0), 0)
        self.assertIn("FIRST PAGE", page.extract_text())

    def test_offset_crop_box_does_not_leak_outside_page(self) -> None:
        writer = PdfWriter()
        page = writer.add_page(PdfReader(BytesIO(self.source)).pages[0])
        page.cropbox.lower_left = (24, 36)
        page.cropbox.upper_right = (588, 756)
        out = BytesIO()
        writer.write(out)
        exported = convert_pdf(out.getvalue(), [Layout(100, "center", "middle")])
        result = PdfReader(BytesIO(exported)).pages[0]
        self.assertAlmostEqual(float(result.mediabox.width), LETTER_WIDTH)
        self.assertIn("FIRST PAGE", result.extract_text())

    def test_rejects_invalid_input_and_layout_count(self) -> None:
        with self.assertRaises(ValueError):
            read_page_count(b"not a pdf")
        with self.assertRaises(ValueError):
            convert_pdf(self.source, [Layout()])
        with self.assertRaises(ValueError):
            Layout(20, "left", "middle")


if __name__ == "__main__":
    unittest.main()
