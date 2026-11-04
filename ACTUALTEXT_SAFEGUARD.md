# ActualText safeguard feasibility follow-up

November 4, 2026. Starting point: clean `codex/release-0.3.0` at `0e31d56b`.
Investigation branch: `codex/actualtext-safeguard`.

**Final v0.3.0 decision:** The user accepted the documented ActualText limitation
for personal use and source publication. This report preserves the earlier
investigation; its experimental detector was never integrated. Further safeguard
or engine development is outside this release. The final decision supersedes
the investigation's earlier recommendation to hold release pending a decision.

## Decision

**A dependable safeguard has not been established within the requested narrow
scope. No detector, rejection rule, message, or application behavior was shipped.**
A native detector is possible in principle, but a small object walk plus
`CGPDFScannerScan` is not sufficient evidence of complete inspection. The
prototype exposed false-clear and ambiguous results. Connecting it to import or
export would risk presenting incomplete inspection as protection, contrary to
the task's explicit requirement. Work stopped before application integration.

This is not a claim that detection is mathematically impossible or that every
Core Graphics scan fails. It is a decision not to certify an unproven small
safeguard. A fuller resource-aware parsing/validation component, or an explicitly
restricted supported-format policy, needs a separate scope decision.

The 0.3.0 engine still loses ActualText. Prominent limitation disclosure remains
in force. No package is described as protected by a detector.

## What was investigated

The PDF standard permits ActualText in structure element dictionaries and in
marked-content property lists. The property lists may be inline or named through
resources. Structure data and resources can contain indirect/compressed objects,
arrays, cycles and nested references. Content programs occur in pages, Form
XObjects, tiling patterns and Type 3 glyph programs, not just page streams.

Primary references:

- [Adobe-hosted PDF 32000-1, sections 7.8 and 14.9.4](https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/PDF32000_2008.pdf)
- [PDF Association's approved form-resource errata](https://pdf-issues.pdfa.org/32000-2-2020/clause08.html)
- [Apple resource lookup API](https://developer.apple.com/documentation/coregraphics/cgpdfcontentstreamgetresource(_:_:_:))

An isolated native prototype used parsed Core Graphics dictionaries, arrays,
streams, and BDC/DP callbacks. It walked the live catalog graph with cycle and
complexity bounds, and scanned nested content programs. It did not raw-search
source bytes. Positive probes detected:

- Inline property dictionaries, including escaped `/Actual#54ext` names.
- Named resource properties and tagged-document structure elements/parent trees.
- Nested forms, tiling patterns and Type 3 glyph streams.
- Property dictionaries stored in compressed object streams.
- Replacement properties after other inline marked-content dictionaries.

Ordinary text, `/ActualText` inside painted literal strings or comments, and
ordinary language-tagged marked content were negative controls. These successes
show useful native capabilities; they do not establish complete coverage.

## Reliability boundaries found

### Resource context affects whether the scanner reaches later content

A synthetic, structurally valid form contains a one-pixel inline image using a
named `/CS0` colour space, followed by an inline ActualText span. The form's
Resources dictionary defines that colour space. qpdf reports no warnings and
Poppler extracts `academic text`.

When the nested stream scanner is supplied the wrong resource context, Core
Graphics calls the inline-image callback, never calls the later BDC callback,
and **returns true from `CGPDFScannerScan`**. Supplying the correct resource
dictionary makes the BDC callback run and finds the replacement.

The local mistake is correctable. It nevertheless disproves the proposed simple
flat scan as a reliable negative test: a true scanner result is not an independent
certificate that the program was fully inspected. A dependable implementation
must bind resources correctly for every content scope, distinguish an absent
resource dictionary from an explicitly present one, and handle page-tree
inheritance, legacy forms/fonts, shared content used on different pages, patterns,
and glyph programs. Arbitrarily attaching nested streams to the first page is
unsafe. Blanket scanning of object dictionaries does not replace this work,
because inline property dictionaries exist only inside content programs.

### Decoder/scanner success is not a strict validity result

For a deliberately damaged Flate content stream, Core Graphics returned a
non-nil, zero-length decoded data object and a successful scan. A valid empty
Flate stream also decodes to zero bytes and scans successfully. A malformed split
property-name probe likewise produced scanner success; independent tools flagged
its syntax. These malformed probes are **not** claimed to be valid PDFs with
preserved text; they test whether the APIs provide a trustworthy fail-closed
completion signal. They do not.

An empty-output rule can conservatively reject the damaged case, but also rejects
legitimate compressed blank content. Filter whitelists, nil checks, resource
fixes and complexity bounds improve a prototype, but do not by themselves prove
that all relevant bytes and contexts were inspected. The public interfaces used
here do not expose a consumed-byte offset or a strict decoder-completeness/error
result. Dependable negative conclusions need more parsing/validation work or
explicit exclusions, not a raw-string fallback.

### Presence is not exact semantic dependency

Even complete detection of a replacement property would be conservative. It may
be unused, equal to painted text, or attached to content not selected for output.
Proving exact dependency requires more content/resource interpretation. A future
safeguard should clearly describe conservative rejection rather than pretend to
make an exact semantic-equivalence determination.

## Alternatives

1. **A separately scoped validation component.** Evaluate a dedicated local PDF
   parser with decoded-object/stream access and usable error/completeness signals,
   then implement resource-aware inspection with a broad adversarial regression
   matrix. This need not replace rendering, but adds a substantial validation
   responsibility and possibly a native dependency requiring licensing, build,
   packaging, memory and compatibility review. No dependency was selected or added.
2. **An explicitly restricted format policy.** Reject all content constructs whose
   completeness cannot be established, with an understandable message. This can
   reduce compatibility with ordinary PDFs (including some inline images,
   inherited-resource forms or compressed blank streams). It needs approval and
   a demonstrably reliable exclusion classifier; it was not silently adopted.
3. **Object-preserving composition.** Preserve the original streams/resources
   rather than redrawing them. This remains the larger engine change already
   excluded from this task.
4. **Retain the documented limitation.** This was the final choice for v0.3.0
   personal use and source publication. It does not provide a safeguard and must
   not be described as one.

The investigation recommended against treating the small prototype as dependable
protection. Options 1 and 2 remain possible future work if rejection is required.
The accepted limitation is sufficient for the finalized v0.3.0 scope.

## Evidence and verification performed

All inputs were synthetic. The original local scratch directory contained:

- `Inspection.swift`: exploratory object/stream walker; **not production code**.
- `trace.swift`: resource-context counterexample using public Core Graphics calls.
- `fixtures`, `fixtures-more`, `fixtures-boundaries`, `split-fixtures`: generated
  positive/negative, resource-context and malformed-input probes.
- `findings.json`: qpdf result, independent extracted text, scanner trace and checksum.

Those temporary probes are not part of the repository and may no longer exist.
The resource-context and damaged-stream observations above are a historical
investigation record, not a committed reproducible detector test suite.

To reproduce the user-visible text loss from committed source, install the
development tools described in [TESTING.md](TESTING.md) and run on a Mac:

```bash
python scripts/check-pdf-compatibility.py /private/tmp/margin-maker-actualtext-repro
pdftotext /private/tmp/margin-maker-actualtext-repro/actualtext.pdf -
pdftotext /private/tmp/margin-maker-actualtext-repro/actualtext-Portrait.pdf -
```

Use a new output directory. The first command exits **2** for the accepted known
loss; inspect `report.json`. The input extracts as `academic text`; both Portrait
and Landscape exports extract as `XXXXX`. The generated fixture uses an inline
marked-content property dictionary and requires no personal PDF. This gives
future contributors a minimal semantic-preservation example without integrating
the incomplete detector. See [COMPATIBILITY.md](COMPATIBILITY.md) for the drawing
and PDFKit controls.

Commit `774f7c6` changed only investigation documentation. No safeguard QA build
was produced because no safeguard was implemented. Current release verification
is recorded separately in [TESTING.md](TESTING.md); passing those tests is not
evidence of a working ActualText safeguard.
