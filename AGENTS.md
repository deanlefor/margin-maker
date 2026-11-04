# Margin Maker project instructions

## Goal

Build a free, privacy-preserving macOS utility for creating generous annotation
margins around existing academic PDF readings before they are marked up in PDF
Expert. The UI should feel like a tiny single-purpose tool, not a PDF editor.

## Nonnegotiable first-version features

- Import a PDF; never modify its original file.
- Show a white 8.5 x 11-inch (US Letter) page preview containing the source page.
- Nine position buttons: top/middle/bottom crossed with left/center/right.
- One scale slider from 50% to 100%, default 75%.
- Export another PDF with one Letter-sized page per original page.
- Include a simple way to apply the current settings to every page or customize
  individual pages. Prefer all pages by default.
- Keep vector text selectable/searchable when the source PDF supports it.
- Work fully offline with no analytics, accounts, external processing, or
  subscriptions. Target Mac as the primary platform.

## Out of scope for v1

- Editing annotations, OCR, AI features, multi-document batch processing.
- Syncing, upload accounts, telemetry, licensing/payment infrastructure.
- Automatic content trimming, except as a later optional enhancement.

## Engineering expectations

- Keep a tight scope and intuitive UI. Do not add complex options unrequested.
- Preserve PDFs' original aspect ratios; never stretch content.
- For non-Letter source pages, treat 100% as maximum size that fits on Letter;
  lower percentages scale that fitted size proportionally.
- Handle cropped pages and rotated pages correctly.
- Reject password-locked/invalid PDFs with actionable error messages.
- Add automated tests for page size, all anchor positions, rotation, crop boxes,
  and extracted text in the exported PDF.
- Support local macOS testing before calling the app release-ready.
- Prefer permissive open-source dependencies. Do not introduce AGPL-only
  dependencies without explaining their licensing implications.
- This repository contains a Python prototype conversion engine. It is a
  behavioral reference, not an architectural mandate. A native SwiftUI/PDFKit
  interface is welcome if it makes a simpler Mac application.

## Acceptance tests

1. A normal US Letter PDF at 75%, positioned middle-right, yields a Letter page
   with a 2.125-inch left margin and 1.375-inch margins at top and bottom.
2. All nine anchors place content in the expected corner/edge/center.
3. Mixed page dimensions remain inside the Letter page without distortion.
4. Multi-page PDFs export in the original page order.
5. Original PDFs remain unchanged; the new PDF opens in PDF Expert and can be
   highlighted and annotated.
