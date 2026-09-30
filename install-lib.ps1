function Write-BatStub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ToolName,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Content,

        [Parameter(Mandatory = $false)]
        [string]$ToolsDir
    )

    if (-not $PSBoundParameters.ContainsKey("ToolsDir")) {
        $ToolsDir = Get-Variable -Name ToolsDir -Scope 1 -ValueOnly
    }

    $batDest = Join-Path $ToolsDir "$ToolName.bat"
    Set-Content -Path $batDest -Value $Content -Encoding ASCII
    Write-Host "  [bat]  $batDest" -ForegroundColor Green

    $bashDest = Join-Path $ToolsDir $ToolName
    $bashContent = @'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/__TOOL_NAME__.bat" "$@"
'@.Replace("__TOOL_NAME__", $ToolName)
    Set-Content -Path $bashDest -Value $bashContent -Encoding ASCII
    Write-Host "  [bash] $bashDest" -ForegroundColor Green
}

function ConvertTo-Ico($pngPath, $icoPath) {
    $pngBytes = [System.IO.File]::ReadAllBytes($pngPath)
    $stream   = [System.IO.FileStream]::new($icoPath, [System.IO.FileMode]::Create)
    $w        = [System.IO.BinaryWriter]::new($stream)
    $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]1)   # ICONDIR
    $w.Write([byte]16);  $w.Write([byte]16);  $w.Write([byte]0)     # ICONDIRENTRY width/height/colorcount
    $w.Write([byte]0);   $w.Write([uint16]1); $w.Write([uint16]32)  # reserved/planes/bitcount
    $w.Write([uint32]$pngBytes.Length); $w.Write([uint32]22)        # data size / offset
    $w.Write($pngBytes)
    $w.Close(); $stream.Close()
}

# Helper: ensure a "Mike's Tools" submenu root exists at $rootKey with $icon.
function Set-MikesToolsRoot($rootKey, $icon) {
    # Other standalone tools share this root. Keep their root settings intact.
    if (Test-Path $rootKey) { return }
    New-Item -Path $rootKey -Force | Out-Null
    Set-ItemProperty -Path $rootKey -Name "MUIVerb"     -Value "Mike's Tools"
    Set-ItemProperty -Path $rootKey -Name "SubCommands" -Value ""
    Set-ItemProperty -Path $rootKey -Name "Icon"        -Value $icon
}

# Helper: add a verb entry + command under an existing Mike's Tools root.
function Add-MikesVerb($rootKey, $verbName, $label, $icon, $command) {
    $verbKey = "$rootKey\shell\$verbName"
    $cmdKey  = "$verbKey\command"
    New-Item -Path $verbKey -Force | Out-Null
    New-Item -Path $cmdKey  -Force | Out-Null
    Set-ItemProperty -Path $verbKey -Name "MUIVerb" -Value $label
    Set-ItemProperty -Path $verbKey -Name "Icon"    -Value $icon
    Set-ItemProperty -Path $cmdKey  -Name "(Default)" -Value $command
}

