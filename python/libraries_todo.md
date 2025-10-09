# Libraries & Licensing To‑Do

This checklist guides replacing placeholder/stub vendor libraries with full, authentic distributions and adding correct licensing & attribution (AGPL + MIT third‑party libs) across the project.

---
## 1. Current Situation (Baseline)
- `docs/vendor/exceljs.min.js` is a **stub placeholder** (non-functional) created for offline structure.
- `docs/vendor/file-saver.min.js` is a **trimmed placeholder** version (simplified) – not the official minified build.
- `docs/index.html` already loads the local vendor copies instead of CDN.
- Project license: **AGPL-3.0**.
- Third-party libraries to formalize:
  - ExcelJS (MIT) — https://github.com/exceljs/exceljs
  - FileSaver.js (MIT) — https://github.com/eligrey/FileSaver.js

---
## 2. Replace Placeholder Vendor Files
### Tasks
1. Create a temporary working install (or use existing project root):
   - `npm init -y` (if no package.json in root; you already have one so skip this if present).
   - `npm install exceljs@4.3.0 file-saver@2.0.5 --save-dev` (dev or regular; we only need artifacts for copying).
2. Copy authentic production builds:
   - ExcelJS: `cp node_modules/exceljs/dist/exceljs.min.js docs/vendor/exceljs.min.js`
   - FileSaver: `cp node_modules/file-saver/dist/FileSaver.min.js docs/vendor/file-saver.min.js`
3. (Optional) Keep a non-minified copy for debugging (e.g., `exceljs.js`) in a `debug/` folder or skip to reduce repo size.
4. Verify file integrity (optional but recommended):
   - Generate SHA256: `shasum -a 256 docs/vendor/exceljs.min.js` and store in this file under Appendix A.
5. Remove any stub-only comments that mislead (but **retain original upstream license headers** at the top of each file).
6. Commit with message: `chore: replace ExcelJS & FileSaver placeholders with full builds (MIT licenses retained)`.

### Acceptance Criteria
- Excel export produces meaningful `.xlsx` with merged headers and cell content.
- No console warning from stub.
- License headers present at top of both vendor files.

---
## 3. Version Pinning & Update Policy
### Tasks
1. Record exact versions in `README.md` under a new section: **Third-Party Libraries**.
2. Decide update cadence (e.g., quarterly or on security advisories).
3. Add an npm script (optional) to refresh vendor libs:
   ```json
   "scripts": {
     "vendor:update": "npm install exceljs@4.3.0 file-saver@2.0.5 && cp node_modules/exceljs/dist/exceljs.min.js docs/vendor/ && cp node_modules/file-saver/dist/FileSaver.min.js docs/vendor/"
   }
   ```
4. (Optional) Add a GitHub Action job to diff SHA256 on PRs touching vendor files.

---
## 4. Introduce a Third-Party License Summary File
### Tasks
1. Create `THIRD-PARTY-LICENSES.md` at repo root.
2. Content outline:
   - Intro sentence referencing AGPL project using permissive components.
   - Table listing: Library | Version | License | Upstream URL | Local Path.
   - Full MIT license texts (verbatim) for ExcelJS & FileSaver.js appended below table.
3. Link to this file from `README.md` and from `docs/index.html` (footer link: “Third-Party Licenses”).

---
## 5. Update README.md
### Tasks
Add a section similar to:
```
## Third-Party Libraries
This project bundles the following permissively licensed libraries:
| Library       | Version | License | Upstream | Local Path |
|---------------|---------|---------|----------|------------|
| ExcelJS       | 4.3.0   | MIT     | https://github.com/exceljs/exceljs | docs/vendor/exceljs.min.js |
| FileSaver.js  | 2.0.5   | MIT     | https://github.com/eligrey/FileSaver.js | docs/vendor/file-saver.min.js |
Their original license texts are included in THIRD-PARTY-LICENSES.md. Redistribution is under the AGPL-3.0 for project code; the above components remain under their respective MIT licenses.
```
Also add:
```
### Updating Vendor Builds
Run: `npm run vendor:update`
Then verify Excel export still works and commit the new hashes.
```

---
## 6. Attribution & License Notice in Web UI
### Tasks
1. In `docs/index.html` footer (or an About modal) add a short mention:
   - “Includes ExcelJS and FileSaver.js (MIT licensed).” linking to upstream repos or local license summary.
2. (Optional) Add an “About / Licenses” collapsible panel listing the libraries with versions and license names.
3. Ensure AGPL notice remains intact (already there) and clarify that third-party components have separate MIT licenses.

Suggested snippet (HTML):
```
<div class="small-muted">Includes <a href="https://github.com/exceljs/exceljs" target="_blank">ExcelJS</a> and <a href="https://github.com/eligrey/FileSaver.js" target="_blank">FileSaver.js</a> (MIT). See <a href="THIRD-PARTY-LICENSES.md" target="_blank">Third-Party Licenses</a>.</div>
```

---
## 7. AGPL Compliance Checklist
### Tasks
1. Ensure full, corresponding source is published (including vendor JS files and build instructions if derived artifacts).
2. Keep your own modifications clearly segregated (no removal of upstream license text).
3. If distributing compiled Electron binaries, include:
   - LICENSE (AGPL)
   - THIRD-PARTY-LICENSES.md
   - README with build instructions (already present / update as needed)
4. For any networked deployment (if later hosted), provide a “Source Code” link pointing to repository.

---
## 8. Optional Enhancements
| Enhancement | Benefit |
|-------------|---------|
| CDN fallback logic (try local, fallback to CDN if checksum mismatches) | Resilience & integrity | 
| SRI hashes for CDN tags (if reintroducing CDN) | Tamper detection |
| Automated license header audit script | Prevent accidental header removal |
| About dialog with license texts loaded on demand | UX clarity |
| Hash verification script (`scripts/verify-vendor-hashes.js`) | Supply-chain safety |

---
## 9. Testing After Replacement
### Tasks
1. Load a sample Text Chart XML, verify table renders.
2. Export to Excel — open in Excel / LibreOffice, confirm:
   - Merged header cells
   - Analysis columns present
   - Column widths applied
3. Toggle analysis type and export again.
4. Confirm no console errors referencing stub workbook.

---
## 10. Maintenance Procedure (Repeatable)
1. Create a branch: `chore/vendor-update-YYYYMMDD`.
2. Bump versions intentionally (review changelogs for ExcelJS & FileSaver).
3. Re-run vendor update script.
4. Recalculate hashes; update in THIRD-PARTY-LICENSES.md Appendix.
5. Run manual Excel export smoke test.
6. Open PR referencing dependency changelog links.

---
## 11. Risk & Mitigation
| Risk | Mitigation |
|------|------------|
| Accidentally commit a maliciously altered vendor file | Compare SHA256 with upstream release; use fresh npm install |
| License header stripped by minifier workflow | Always copy official distributed minified file (already includes header) |
| Future ExcelJS API change breaks export | Pin version; add minimal unit test for export workflow (integration test generating workbook & checking merged cells) |
| Bundle size concerns | Consider dynamic import or only loading ExcelJS when Text Chart detected |

---
## 12. Actionable Task List (Condensed)
- [ ] Install exact versions: `exceljs@4.3.0`, `file-saver@2.0.5`.
- [ ] Copy authentic minified builds into `docs/vendor/` (overwrite placeholders).
- [ ] Preserve upstream MIT license headers.
- [ ] Add `THIRD-PARTY-LICENSES.md` with table + full MIT texts.
- [ ] Update `README.md` (Third-Party Libraries section + update instructions).
- [ ] Add footer attribution snippet in `docs/index.html`.
- [ ] (Optional) Add npm script `vendor:update`.
- [ ] Compute and store SHA256 hashes in THIRD-PARTY-LICENSES.md.
- [ ] Manual Excel export smoke test (two analysis modes).
- [ ] Commit & push.
- [ ] (Optional) Add GitHub Action to lint vendor license presence.

---
## Appendix A: (Placeholder for Hashes After Replacement)
Add after real files are copied:
```
exceljs.min.js  SHA256: <pending>
file-saver.min.js  SHA256: <pending>
```

## Appendix B: MIT License Template Reference
Include complete, verbatim MIT license texts from each upstream project in THIRD-PARTY-LICENSES.md.

---
## 13. Future Considerations
- If adding more libraries (e.g., SheetJS, Papaparse), follow same flow.
- Consider switching to an automated bundler (Rollup/ESBuild) to tree-shake future additions, but keep raw vendor copies for license clarity.

---
## 14. Deferred / Parking Lot (Do Later)
These are items you explicitly deferred or that were suggested but not yet scheduled. Copy any you want into the main checklist when you resume work.

### Library Integration & Code Improvements
- [ ] Replace placeholder `exceljs.min.js` and `file-saver.min.js` with authentic upstream builds (run: `npm run vendor:update`).
- [ ] After replacement, remove any placeholder/stub warning comments you added (retain upstream license headers!).
- [ ] Add runtime guard: if `ExcelJS.Workbook().addWorksheet` shape looks like stub (e.g., missing `xlsx.writeBuffer` real behavior), display a banner: “Development stub of ExcelJS detected – export output may be incomplete.”
- [ ] Lazy-load ExcelJS & FileSaver only when a Text Chart is detected (optional performance optimization).

### UI / Attribution
- [ ] Insert footer attribution snippet linking to THIRD-PARTY-LICENSES:
   `<div class="small-muted">Includes ExcelJS and FileSaver.js (MIT). See Third-Party Licenses.</div>`
- [ ] Convert that snippet into links (ExcelJS repo, FileSaver repo, local THIRD-PARTY-LICENSES.md).
- [ ] Add an "About / Licenses" modal (trigger button in header or footer) with: project version, AGPL notice, table of third-party libs, link to source repo.
- [ ] Add dynamic export filename for Text Chart Excel: `StoryTitle_text_chart_<YYYYMMDD>.xlsx` (sanitize: non-alphanumerics -> `_`).
- [ ] Add a tooltip or inline help near the analysis dropdown describing each preset.
- [ ] Provide a small inline note that analysis columns are user-editable after export in Excel.

### Licensing & Compliance
- [ ] Update `README.md` (if not yet done) with Third-Party Libraries table & update procedure (may partially exist—verify).
- [ ] Ensure `THIRD-PARTY-LICENSES.md` is packaged in Electron build (electron-builder includes it by default only if listed or matched by glob—verify `build.files`).
- [ ] Add copy of `THIRD-PARTY-LICENSES.md` to `dist` output root after build (postbuild script if necessary).
- [ ] Add explicit menu item (Help > Licenses) in Electron that opens the local `THIRD-PARTY-LICENSES.md` in a browser window.
- [ ] Consider adding SPDX license identifiers as comments at the top of custom source files (optional clarity).

### Integrity / Automation
- [ ] Add script `scripts/verify-vendor-hashes.mjs` that:
   1. Reads expected SHA256 entries from `THIRD-PARTY-LICENSES.md`.
   2. Computes current hashes of vendor files.
   3. Exits non-zero if mismatch.
- [ ] Add GitHub Action job `verify-vendor-hashes` triggered on PRs touching `docs/vendor/**` or `THIRD-PARTY-LICENSES.md`.
- [ ] Add security note in README on procedure for updating vendor libs & verifying integrity (supply chain transparency).
- [ ] Optionally integrate `license-checker` or `oss-review-toolkit` if future dependencies expand (currently overkill).

### Testing Enhancements
- [ ] Add minimal headless Jest (or Vitest) test that loads a synthetic Text Chart XML string, invokes `renderTextChartView`, and asserts table structure (number of header rows, column count).
- [ ] Add an integration test to simulate Excel export (in a jsdom-limited way or by abstracting workbook creation behind a testable wrapper) verifying model assembly logic.
- [ ] Snapshot test for the generated HTML of a small sample chart.

### Performance / UX
- [ ] Defer loading ExcelJS until user clicks Export OR until a chart is detected (dynamic import with fallback if unsupported in some environments).
- [ ] Add a small spinner / disabled state to Export button while workbook is being generated for large charts.
- [ ] Add column freeze suggestion or implement optional “Freeze Row Headers” toggle (ExcelJS can set `views`).

### Documentation
- [ ] Add section to README: “Text Chart Export” with screenshot + workflow steps.
- [ ] Provide example XML snippet (sanitized) for users to experiment.
- [ ] Clarify that analysis columns are intentionally blank for manual annotation and not auto-filled.

### Nice-to-Have Security / Supply Chain
- [ ] Record initial hashes now, then re-verify quarterly.
- [ ] Add date stamp in `THIRD-PARTY-LICENSES.md` for when versions last audited.
- [ ] Evaluate adding Subresource Integrity (SRI) if you reintroduce optional CDN fallback.

### Electron Packaging
- [ ] Confirm `THIRD-PARTY-LICENSES.md` is included (add to `build.files` if absent: e.g., "THIRD-PARTY-LICENSES.md").
- [ ] Add an NSIS installer custom page (optional) linking to license summary (for thorough compliance optics).

---
## 15. Quick Start When You Return
1. Run `npm run vendor:update`.
2. Compute & paste SHA256 hashes into BOTH: `THIRD-PARTY-LICENSES.md` + Appendix A here.
3. Add footer attribution snippet.
4. Implement dynamic filename export.
5. Smoke test Excel export (two analysis modes).
6. Commit with message: `feat: finalize vendor libs & licensing attribution`.

---
End of file.
