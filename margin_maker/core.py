"""Lossless-in-principle PDF page placement, independent of the GUI.

The original PDF content is embedded into a new Letter-sized PDF page using
PDF graphics operations, not converted into a screenshot. Existing annotations
and links are intentionally not migrated (this is a pre-annotation workflow).
"""

from __future__ import annotations

from dataclasses import dataclass
from io import BytesIO
from typing import Callable, Sequence

from pypdf import PdfReader, PdfWriter, Transformation


LETTER_WIDTH = 612.0  # 8.5 inches at 72 PDF points per inch
LETTER_HEIGHT = 792.0  # 11 inches
HORIZONTAL = ("left", "center", "right")
VERTICAL = ("top", "middle", "bottom")


@dataclass(frozen=True)
class Layout:
    """Layout choices for one source page."""

    scale_percent: int = 75
    horizontal: str = "center"
    vertical: str = "middle"

    def __post_init__(self) -> None:
        if not 50 <= self.scale_percent <= 100:
            raise ValueError("Scale must be between 50% and 100%.")
        if self.horizontal not in HORIZONTAL:
            raise ValueError(f"Invalid horizontal position: {self.horizontal}")
        if self.vertical not in VERTICAL:
            raise ValueError(f"Invalid vertical position: {self.vertical}")


def read_page_count(pdf_bytes: bytes) -> int:
    """Validate a PDF and return its page count."""

    reader = _open_reader(pdf_bytes)
    count = len(reader.pages)
    if count == 0:
        raise ValueError("This PDF has no pages.")
    return count


def _open_reader(pdf_bytes: bytes) -> PdfReader:
    if not pdf_bytes:
        raise ValueError("The selected file is empty.")
    try:
        reader = PdfReader(BytesIO(pdf_bytes), strict=False)
        if reader.is_encrypted and not reader.decrypt(""):
            raise ValueError(
                "This PDF is password-protected. Open it in your PDF editor "
                "and export an unlocked copy first."
            )
        return reader
    except ValueError:
        raise
    except Exception as exc:
        raise ValueError("This file could not be read as a PDF.") from exc


def placement_for_page(page, layout: Layout) -> tuple[Transformation, tuple[float, float, float, float]]:
    """Return PDF transformation and output bounding rectangle.

    At 100%, the source page is fitted within a US Letter page without
    distortion; other percentages refer to that fitted size. This avoids
    clipping unusual source sizes, including A4 and larger pages.
    """

    box = page.cropbox
    left = float(box.left)
    bottom = float(box.bottom)
    width = float(box.width)
    height = float(box.height)
    if width <= 0 or height <= 0:
        raise ValueError("A source page has an invalid crop box.")

    fit_factor = min(LETTER_WIDTH / width, LETTER_HEIGHT / height)
    factor = fit_factor * layout.scale_percent / 100.0
    placed_width = width * factor
    placed_height = height * factor

    if layout.horizontal == "left":
        x = 0.0
    elif layout.horizontal == "center":
        x = (LETTER_WIDTH - placed_width) / 2.0
    else:
        x = LETTER_WIDTH - placed_width

    # PDF origin is at the bottom left, whereas users choose top/middle/bottom.
    if layout.vertical == "bottom":
        y = 0.0
    elif layout.vertical == "middle":
        y = (LETTER_HEIGHT - placed_height) / 2.0
    else:
        y = LETTER_HEIGHT - placed_height

    transform = (
        Transformation()
        .translate(-left, -bottom)
        .scale(factor)
        .translate(x, y)
    )
    return transform, (x, y, x + placed_width, y + placed_height)


def convert_pdf(
    pdf_bytes: bytes,
    layouts: Sequence[Layout],
    *,
    page_indices: Sequence[int] | None = None,
    progress: Callable[[int, int], None] | None = None,
) -> bytes:
    """Export a document on white US Letter pages, preserving source PDF text.

    Page-specific settings are supplied in `layouts`, indexed by source page.
    `page_indices` permits generating a single page for an exact GUI preview.
    """

    reader = _open_reader(pdf_bytes)
    page_count = len(reader.pages)
    if len(layouts) != page_count:
        raise ValueError("There must be exactly one layout per source page.")

    indices = list(range(page_count)) if page_indices is None else list(page_indices)
    if not indices:
        raise ValueError("No pages selected for export.")
    if any(index < 0 or index >= page_count for index in indices):
        raise ValueError("A requested page is outside this PDF.")

    writer = PdfWriter()
    for completed, index in enumerate(indices, start=1):
        source_page = reader.pages[index]
        # Merge operations don't automatically honor the PDF /Rotate flag.
        # Move the rotation into the actual page content before placement.
        if int(source_page.get("/Rotate", 0) or 0) % 360:
            # transfer_rotation_to_content modifies the source page. Attach a
            # copy to a writer first, as required by pypdf 7 onward.
            rotated_page_writer = PdfWriter()
            source_page = rotated_page_writer.add_page(source_page)
            source_page.transfer_rotation_to_content()

        transform, _ = placement_for_page(source_page, layouts[index])
        output_page = writer.add_blank_page(width=LETTER_WIDTH, height=LETTER_HEIGHT)
        output_page.merge_transformed_page(source_page, transform, over=True)
        if progress is not None:
            progress(completed, len(indices))

    output = BytesIO()
    writer.write(output)
    return output.getvalue()
