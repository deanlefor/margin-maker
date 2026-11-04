# Contributing

Margin Maker is a small, offline macOS tool for preparing PDFs before annotation.
Bug reports, focused fixes, and compatibility results are welcome. There is no
promised response time or release schedule.

- Describe what happened, what you expected, and your macOS version, architecture,
  and Swift version. Include a minimal synthetic PDF or generator when useful;
  do not upload private or copyrighted readings or credentials.
- Build and run the relevant checks in [TESTING.md](TESTING.md). For PDF changes,
  check geometry, crops, rotations, source protection, and independently extracted
  text. A visually correct page alone does not establish text preservation.
- Keep changes small, offline, and appropriate for a single-purpose tool. Discuss
  substantial engine changes or dependencies before investing in them.
- The known `/ActualText` loss is documented in [COMPATIBILITY.md](COMPATIBILITY.md).
  [ACTUALTEXT_SAFEGUARD.md](ACTUALTEXT_SAFEGUARD.md) records the investigation and
  why the experimental detector was not integrated. Its reproduction command is
  a useful starting point; no additional engine work is planned for v0.3.0.

Code and documentation are provided under the [MIT license](LICENSE).
