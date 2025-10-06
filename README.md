# FLEx XML Viewer

Client‑side viewer for exploring FieldWorks (FLEx) XML exports in a clean, readable format (which you can also copy and paste). Runs entirely in the browser (no server) and also ships as a Windows desktop app via Electron.
  
This project is part of the Field Linguistics Extension Tools (FLET) project: [https://github.com/rulingAnts/flet](https://github.com/rulingAnts/flet)

- Web app: [https://rulingants.github.io/flexml_display](https://rulingants.github.io/flexml_display)
- Latest Windows release: [https://github.com/rulingAnts/flexml_display/releases/latest](https://github.com/rulingAnts/flexml_display/releases/latest)

## What it does

FLEx XML Viewer renders common FLEx export types:

- Lists — hierarchical `<list>` structures as collapsible trees
- Translated Lists — multilingual AUni-based lists with language ordering/visibility controls
- Phonology — natural classes, phoneme inventories, cross-references, and codes
- Wordforms — lexical items and analyses, with Card and Table views and filtering
- Generic XML — fallback recursive tree for any well‑formed XML

Not in scope: LIFT, FLExText (open those in FLEx), XLingPaper (open in XLingPaper), Word XML (open in Word), Discourse XML and Dekereke (see FLET project).

## Try it online (no install)

1. Open the web app: https://rulingants.github.io/flexml_display
2. Paste XML into the textbox or choose a .xml file.
3. Click Transform.
4. Optional:
   - Toggle “Show element names”
   - Open in new window
   - Save as HTML (exports a standalone snapshot of the current view)

All processing is local in your browser; your files are not uploaded.

## Download for Windows

1. Go to the latest release: [https://github.com/rulingAnts/flexml_display/releases/latest](https://github.com/rulingAnts/flexml_display/releases/latest)
2. Download the installer (.exe). You may also see a “portable” .exe.
3. Run the installer. If Windows SmartScreen warns (unsigned binary), choose “More info” → “Run anyway.”

The desktop app bundles the same viewer for offline use.

## Usage tips

- Lists and Translated Lists: click triangles to expand/collapse; reorder and show/hide languages.
- Phonology: click a phoneme “pill” to highlight it; click a table row to highlight related natural classes.
- Wordforms: use the Filter box; switch Card/Table view; choose which gloss languages appear in Table view.
- “Open in new window” creates a self‑contained view for sharing or printing; “Save as HTML” saves a static snapshot.

## Privacy

- 100% client‑side. Files never leave your machine.
- Preferences (e.g., language ordering, wordform view mode) are stored locally in your browser’s LocalStorage.

## Developer setup

Requirements
- Windows 10/11 x64
- Node.js (use nvm-windows to match project version)

Install and run (VS Code PowerShell)
```powershell
# Use the project’s Node version
nvm use 22.20.0

# Install dependencies (use npm.cmd if PowerShell blocks npm.ps1)
npm.cmd ci

# Start Electron
npm.cmd start
```

Build Windows installer locally
```powershell
# Optional: avoid symlink errors by enabling Developer Mode or using an elevated shell
# Win+R → ms-settings:developers → Developer Mode ON
# or run VS Code/PowerShell "As Administrator"

# Build
npm.cmd run dist:win
# Artifacts appear in dist\ (NSIS installer .exe, blockmap, .yml)
```

Troubleshooting (Windows PowerShell)
- “npm.ps1 is not digitally signed” → use npm.cmd:
  ```powershell
  npm.cmd install
  npm.cmd run dist:win
  ```
  Or set once:
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
  ```
- Symlink privilege error during electron-builder cache extraction:
  - Turn on Windows Developer Mode, or
  - Run an elevated PowerShell for the build, then:
    ```powershell
    Remove-Item "$env:LOCALAPPDATA\electron-builder\Cache\winCodeSign" -Recurse -Force -EA SilentlyContinue
    npm.cmd run dist:win
    ```

## Continuous delivery (optional)

- GitHub Pages (docs/): updates on push to main (via .github/workflows/pages.yml).
- GitHub Releases: tag vX.Y.Z to build and upload Windows installers as Release assets (via .github/workflows/release.yml).

## License and attribution

- License: AGPL-3.0 — see https://www.gnu.org/licenses/agpl-3.0.html
- Copyright © 2025 Seth Johnston
- Portions of this code were generated collaboratively with ChatGPT (GPT-5) by OpenAI, under the author’s direction and guidance.

## Contributing

Issues and pull requests are welcome:
- Report bugs or request features: https://github.com/rulingAnts/flexml_display/issues
- Please avoid attaching real project data; share minimal sample XMLs that reproduce problems.

## Roadmap ideas

- Code signing for Windows builds
- Keyboard shortcuts and accessibility improvements
- Sample datasets and screenshots in docs/
- Export to CSV/Excel for selected views
- Additional FLEx export types if feasible
- Filtering, Sorting, Searching features
- Export to other formats (Word, Excel, LaTeX, PDF)
