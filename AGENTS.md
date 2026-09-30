# Agent guidance for img-to-svg

This is a standalone Python raster-to-SVG CLI for Windows and macOS. Source and launchers live at the repo root.

## Code and verification

- Use test-first development for non-trivial changes. Write or update a test before changing behaviour. Extract a clean test seam if needed.
- When behaviour changes, update affected expectations and rerun the relevant tests. Test before committing, then run the actual tool and check exit codes.
- Run `python -m unittest discover -s tests -v` with vtracer and Pillow installed. On macOS use `.venv/bin/python3` after `bash install.sh`.
- Run `pwsh -NoProfile -File tests/test-install.ps1` to parse every PowerShell script and check installer helpers. Test actual Explorer integration on Windows.
- Keep CI lightweight: no GPU, model downloads or secrets. StarVector inference needs separate NVIDIA/CUDA verification.
- Avoid unrelated behaviour changes when fixing installation or packaging.

## Installers and dependencies

- Never put source files directly in `C:\dev\tools`. All logic belongs here; the Windows installer writes thin forwarders there.
- Large external binaries and the optional StarVector checkout stay in `C:\dev\tools`, not this repo. Never commit `.exe` or `.dll` files.
- Write `.bat` files and generated forwarders in ASCII. Clone paths for Windows forwarders must also be ASCII.
- `install.ps1` runs this repo's `deps.ps1`. `-SkipDeps` skips dependency checks, `-WithStarVector` opts into the AI engine. Ordinary source edits do not require reinstalling; moving the clone does.
- Keep `deps.ps1` idempotent, self-contained and runnable directly. Check imports before installing, use `python -m pip` to target the launcher interpreter, and give clear output with `Write-Host` and colour.
- Detect system tools with `Get-Command`. For large manual-download binaries, print setup instructions rather than downloading them automatically.
- Keep other tools' verbs under the shared Mike's Tools submenu. Uninstall only this clone's forwarders and the ImgToSvg verb, never the shared menu root or PATH entry.
- The macOS installer links `img-to-svg` into `~/.local/bin` or the supplied directory and sets up the local `.venv`. Preserve symlink resolution and quoted paths so a clone with spaces works.
- Keep the existing icon and real header image. Do not add API keys or `.env` requirements; this tool doesn't use them.

## Writing

Use plain, friendly language and first person for Mike's opinions. No em dashes or en dashes. PRs begin with `## Why` explaining what prompted the change.
