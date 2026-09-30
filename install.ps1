# Install the CLI stubs and the Explorer verb for this clone.
param(
    [switch]$SkipDeps,
    [switch]$WithStarVector,
    [string]$ToolsDir = "C:\dev\tools"
)
$ErrorActionPreference = "Stop"
if ($env:OS -ne "Windows_NT") { throw "install.ps1 requires Windows. On macOS use install.sh." }
$RepoDir = $PSScriptRoot
. (Join-Path $RepoDir "install-lib.ps1")
if (-not $SkipDeps) { & (Join-Path $RepoDir "deps.ps1") -WithStarVector:$WithStarVector }
New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
# Bat launchers are ASCII. Avoid silently corrupting a non-ASCII clone path.
if ($RepoDir -match '[^\x00-\x7F]') { throw "Clone into a path with ASCII characters for the Windows bat launcher." }
Write-BatStub "img-to-svg" @"
@echo off
call "$RepoDir\img-to-svg.bat" %*
"@ -ToolsDir $ToolsDir

$iconsOut = Join-Path $env:LOCALAPPDATA "img-to-svg\icons"
New-Item -ItemType Directory -Path $iconsOut -Force | Out-Null
$icon = Join-Path $iconsOut "img-to-svg.ico"
ConvertTo-Ico (Join-Path $RepoDir "icons\img-to-svg.png") $icon
foreach ($ext in @('.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff', '.tif')) {
    $root = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\MikesTools"
    # The shared submenu icon must remain valid after this tool is uninstalled.
    Set-MikesToolsRoot $root "$env:SystemRoot\System32\shell32.dll,0"
    Add-MikesVerb $root "ImgToSvg" "Convert to SVG" $icon "cmd.exe /k `"`"$ToolsDir\img-to-svg.bat`" `"%1`"`""
}
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $userPath) { $userPath = "" }
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$onPath = ($userPath -split ';') + ($machinePath -split ';') |
    Where-Object { $_.TrimEnd('\') -ieq $ToolsDir.TrimEnd('\') }
if (-not $onPath) {
    $answer = Read-Host "Add '$ToolsDir' to User PATH? [Y/n]"
    if ($answer -eq '' -or $answer -imatch '^y') {
        $newPath = ($userPath.TrimEnd(';') + ";$ToolsDir").TrimStart(';')
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:PATH += ";$ToolsDir"
    }
}
Write-Host "Installed img-to-svg. Open a new terminal to use it." -ForegroundColor Green
