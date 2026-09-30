# <img src="icons/img-to-svg.png" width="24" height="24" alt=""> img-to-svg

Turn a PNG, JPEG or WebP into an SVG

Windows · macOS

<!-- media: hero -->
<!-- ![img-to-svg](docs/hero.png) -->
<!-- /media: hero -->

![img-to-svg header](docs/header.webp)

## What it is

This converts raster images into SVGs. By default it uses vtracer, which is fast, runs locally and works on pretty much any image, with presets for logos and flat colour, photos, or black and white line art.

If you've got an NVIDIA GPU you can also try the StarVector AI models instead, which are best for icons, logos and diagrams.

## Get it

Paste this into your AI coding agent (Claude Code, Codex, Cursor...):

> Clone https://github.com/mikecann/img-to-svg and make it my own. It's one of Mike
> Cann's personal tools, so read the README first, change anything specific to his
> setup to suit mine, then help me get it running.

### Or set it up by hand

You'll need Git and Python 3 with pip. The default engine needs no API keys, `.env` file or GPU.

```sh
git clone https://github.com/mikecann/img-to-svg.git
cd img-to-svg
```

On Windows, make sure `python` is on PATH, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

This installs vtracer and Pillow into the `python` environment on PATH, writes CLI forwarders into `C:\dev\tools`, and adds **Mike's Tools > Convert to SVG** to Explorer's image right-click menu. It offers to add the tools directory to your User PATH. Open a new terminal afterwards. On Windows 11 you may need **Show more options** to see the menu.

On macOS, make sure `python3` is on PATH, then run:

```sh
bash install.sh
```

This installs vtracer and Pillow into `.venv` in this clone and links the launcher into `~/.local/bin`. Follow the printed PATH instruction if needed. You can choose a different location with `bash install.sh /path/to/bin`.

The clone holds the code, so keep it in place. After moving it, run the installer again. To skip dependency setup, use `install.ps1 -SkipDeps` on Windows or `bash install.sh --skip-deps` on macOS.

## Using it

```sh
img-to-svg logo.png
img-to-svg photo.webp --preset photo
img-to-svg sketch.png --preset bw
img-to-svg "input image.png" "output image.svg"
```

By default the SVG is saved beside the input with the same name and an `.svg` extension. An existing output file is overwritten. Windows users can also right-click an image and choose **Mike's Tools > Convert to SVG**, which uses the default `poster` preset.

## Options

| Flag | Default | Description |
|---|---|---|
| `--engine` | `vtracer` | `vtracer`, `starvector-1b`, or `starvector-8b` |
| `--preset` | `poster` | `poster` for logos, icons and flat colour, `photo` for photos and gradients, `bw` for black and white line art |
| `--max-length` | `4000` | Maximum SVG token length, StarVector only |

PNG and JPEG go straight to vtracer. Other formats, including WebP, BMP and TIFF, are converted to a temporary PNG with Pillow first.

## Optional StarVector setup

The optional Windows setup needs an NVIDIA GPU and CUDA-enabled PyTorch. The 1B model needs roughly 3 GB VRAM, and the 8B model roughly 16 GB. This path is best for icons, logos and diagrams. The macOS installer sets up vtracer only.

Install a CUDA-enabled PyTorch build appropriate for your GPU from the [PyTorch installer](https://pytorch.org/get-started/locally/), using the same `python` environment as the tool, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deps.ps1 -WithStarVector
```

Or pass `-WithStarVector` to `install.ps1`. The setup script clones [star-vector](https://github.com/joanrod/star-vector) into `C:\dev\tools\star-vector`, installs its inference dependencies and applies the existing patch for optional evaluation imports. Model weights download from Hugging Face on first use, so allow plenty of disk space and download time.

```sh
img-to-svg icon.png --engine starvector-8b
img-to-svg icon.png out.svg --engine starvector-1b --max-length 2000
```

## Troubleshooting

If the command isn't found, check that the install directory is on PATH and open a new terminal. On macOS the launcher uses this clone's `.venv` when present, otherwise `python3` on PATH.

If vtracer or Pillow is missing, rerun the installer. On Windows you can also run `deps.ps1` directly. Keep Python installs consistent: `python -m pip` installs packages for the interpreter the Windows launcher uses.

Windows bat forwarders require an ASCII clone path. Spaces are fine.

## Uninstalling

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

On macOS:

```sh
bash uninstall.sh
# If you used a custom install directory:
bash uninstall.sh /path/to/bin
```

These remove this clone's launcher registration. On Windows, other tools' Explorer verbs and the shared Mike's Tools submenu remain. Shared PATH entries and Python packages are kept, as is the optional StarVector checkout. Delete this clone separately if you want to remove its source and macOS `.venv`.

## Development

```sh
python3 -m venv .venv
.venv/bin/python3 -m pip install -r requirements.txt
.venv/bin/python3 -m unittest discover -s tests -v
```

On Windows, use `python -m pip install -r requirements.txt` and `python -m unittest discover -s tests -v`. Run `pwsh -NoProfile -File tests/test-install.ps1` for PowerShell syntax and installer checks. CI runs conversion tests on macOS and Windows, with no GPU, model downloads or secrets.

## More tools

My other tools live at [mikerosoft.app](https://mikerosoft.app).

MIT licensed.
