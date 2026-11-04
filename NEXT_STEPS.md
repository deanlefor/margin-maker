# Publishing the source when ready

The v0.3.0 implementation is feature-complete. The `/ActualText` limitation is
accepted and documented; no additional PDF-engine development is planned.
Local verification and the publication audit are recorded in
[RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) and
[PUBLICATION_AUDIT.md](PUBLICATION_AUDIT.md).

When you decide to publish:

1. Create an empty GitHub repository (without an initial README or license).
2. Add its URL as `origin` in this checkout.
3. Push `main` and the `v0.2.0` and `v0.3.0` tags:

   ```bash
   git remote add origin YOUR_GITHUB_REPOSITORY_URL
   git push -u origin main
   git push origin v0.2.0 v0.3.0
   ```

Use a private repository first if you want a final hosted review, then change
its visibility yourself. Push only the named branch and tags; generated apps,
archives, caches, and PDFs do not belong in source control. Existing Git author
attribution is part of the history that will be published.

No push, repository creation, visibility change, or public release is automated
by this project. A binary release, installer, or notarization is unnecessary for
source publication.
