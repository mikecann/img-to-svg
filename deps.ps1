# deps.ps1
# Sets up vtracer (default engine) and optionally StarVector (AI engine).
# Idempotent - safe to re-run.

param([switch]$WithStarVector)

Write-Host "  [img-to-svg] Checking dependencies..." -ForegroundColor Cyan

$ErrorActionPreference = "Stop"
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Install Python 3 with pip and add it to PATH, then re-run deps.ps1."
}

# The default engine needs both packages. Use the same interpreter for pip.
foreach ($pkg in @(@{ Name = "vtracer"; Import = "vtracer" }, @{ Name = "Pillow"; Import = "PIL" })) {
    python -c "import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('$($pkg.Import)') else 1)"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    OK  $($pkg.Name) already installed" -ForegroundColor Green
    } else {
        python -m pip install $pkg.Name
        if ($LASTEXITCODE -ne 0) { throw "Failed to install $($pkg.Name)." }
    }
}

if (-not $WithStarVector) {
    Write-Host "    StarVector skipped. Use -WithStarVector to set up the optional AI engine." -ForegroundColor Yellow
    return
}

# CUDA-enabled PyTorch depends on the GPU and driver. Don't guess a build here.
python -c "import torch; assert torch.cuda.is_available(), 'CUDA-enabled PyTorch and an NVIDIA GPU are required'"
if ($LASTEXITCODE -ne 0) { throw "Install CUDA-enabled PyTorch before running deps.ps1 -WithStarVector." }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "StarVector setup requires Git on PATH." }

# --- StarVector (AI engine) ---
# Clone the repo to C:\dev\tools\star-vector then do a no-deps editable install.
# We intentionally skip flash_attn (not needed - code has a graceful fallback)
# and cairosvg (not needed - we extract the raw SVG string directly).

$starVectorDir = "C:\dev\tools\star-vector"
New-Item -ItemType Directory -Path (Split-Path $starVectorDir -Parent) -Force | Out-Null

if (Test-Path $starVectorDir) {
    Write-Host "    OK  star-vector repo already present at $starVectorDir" -ForegroundColor Green
} else {
    Write-Host "    Cloning star-vector repository to $starVectorDir ..." -ForegroundColor Yellow
    git clone https://github.com/joanrod/star-vector.git $starVectorDir
    if ($LASTEXITCODE -ne 0) {
        throw "git clone failed. StarVector engine will not be available."
    } else {
        Write-Host "    OK  star-vector cloned" -ForegroundColor Green
    }
}

if (Test-Path $starVectorDir) {
    # Install the package structure only (no deps - we manage them manually below)
    $svInstalled = python -c "import starvector; print('ok')" 2>$null
    if ($svInstalled -eq "ok") {
        Write-Host "    OK  starvector package already importable" -ForegroundColor Green
    } else {
        Write-Host "    Installing starvector package (no-deps)..." -ForegroundColor Yellow
        python -m pip install -e $starVectorDir --no-deps
        if ($LASTEXITCODE -ne 0) {
            throw "StarVector package install failed."
        } else {
            Write-Host "    OK  starvector package installed" -ForegroundColor Green
        }
    }

    # Minimal inference packages (skip flash_attn, cairosvg, gradio, training deps)
    $inferPkgs = @(
        "transformers>=4.49.0",
        "accelerate",
        "sentencepiece",
        "tokenizers",
        "omegaconf",
        "torchvision",
        "protobuf",
        "fairscale"   # needed by starvector's CLIP encoder
    )
    foreach ($pkg in $inferPkgs) {
        $pkgName = $pkg -replace ">=.*", ""
        $check = python -c "import $($pkgName.Replace('-','_')); print('ok')" 2>$null
        if ($check -eq "ok") {
            Write-Host "    OK  $pkgName" -ForegroundColor Green
        } else {
            Write-Host "    Installing $pkg ..." -ForegroundColor Yellow
            python -m pip install $pkg
            if ($LASTEXITCODE -ne 0) { throw "Failed to install $pkg." }
        }
    }

    # Patch data/util.py to make heavy eval-only imports (cairosvg, matplotlib,
    # bs4, svgpathtools) lazy so inference works without them on Windows.
    $utilFile = "$starVectorDir\starvector\data\util.py"
    if (Select-String -Path $utilFile -Pattern "import cairosvg" -SimpleMatch -Quiet) {
        Write-Host "    Patching starvector/data/util.py to make eval-only imports lazy..." -ForegroundColor Yellow
        $content = Get-Content $utilFile -Raw
        $oldHeader = @"
from PIL import Image
from torchvision import transforms
from torchvision.transforms.functional import InterpolationMode, pad
import numpy as np
import matplotlib.pyplot as plt
from bs4 import BeautifulSoup
import re
from svgpathtools import svgstr2paths
import numpy as np
from PIL import Image
import cairosvg
from io import BytesIO
import numpy as np
import textwrap  
import os
"@
        $newHeader = @"
from PIL import Image
from torchvision import transforms
from torchvision.transforms.functional import InterpolationMode, pad
import numpy as np
import re
from io import BytesIO
import numpy as np
import textwrap  
import os

# Eval/plotting only - lazy imports so inference works without cairosvg etc.
try:
    import matplotlib.pyplot as plt
except ImportError:
    plt = None
try:
    from bs4 import BeautifulSoup
except ImportError:
    BeautifulSoup = None
try:
    from svgpathtools import svgstr2paths
except ImportError:
    svgstr2paths = None
try:
    import cairosvg
except ImportError:
    cairosvg = None
"@
        $content = $content.Replace($oldHeader, $newHeader)
        Set-Content $utilFile $content -Encoding UTF8
        Write-Host "    OK  patch applied" -ForegroundColor Green
    } else {
        Write-Host "    OK  starvector/data/util.py already patched" -ForegroundColor Green
    }

    Write-Host "    NOTE: StarVector model weights (~17 GB) download from HuggingFace on first use." -ForegroundColor Yellow
    Write-Host "          8B model requires ~16 GB VRAM; use --engine starvector-1b for ~3 GB." -ForegroundColor Yellow
    Write-Host "          StarVector works best on icons, logos, and diagrams - not photos." -ForegroundColor Yellow
}
