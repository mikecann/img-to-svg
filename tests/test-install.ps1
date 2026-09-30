# No Pester dependency: syntax, helper outputs and lightweight dependency setup.
$ErrorActionPreference = "Stop"
$Repo = Split-Path $PSScriptRoot -Parent
function Assert($condition, $message) {
    if (-not $condition) { throw $message }
}
Get-ChildItem $Repo -Recurse -Filter *.ps1 | ForEach-Object {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
    Assert ($errors.Count -eq 0) "Parse errors in $($_.FullName): $errors"
    Write-Host "Parsed $($_.Name)"
}
. (Join-Path $Repo "install-lib.ps1")
$temp = Join-Path ([IO.Path]::GetTempPath()) ("img-to-svg-tests-" + [guid]::NewGuid())
New-Item -ItemType Directory $temp | Out-Null
try {
    Write-BatStub "img-to-svg" "@echo off`ncall `"C:\clone with spaces\img-to-svg.bat`" %*" -ToolsDir $temp
    $stub = Join-Path $temp "img-to-svg.bat"
    $bytes = [IO.File]::ReadAllBytes($stub)
    Assert (@($bytes | Where-Object { $_ -gt 127 }).Count -eq 0) "Bat forwarder must be ASCII"
    Assert ((Get-Content $stub -Raw).Contains('call "C:\clone with spaces\img-to-svg.bat" %*')) "Clone path must be quoted"
    Assert ((Get-Content (Join-Path $temp "img-to-svg") -Raw).Contains('exec "$SCRIPT_DIR/img-to-svg.bat" "$@"')) "Bash forwarder must preserve arguments"
    $ico = Join-Path $temp "img-to-svg.ico"
    $png = Join-Path $Repo "icons/img-to-svg.png"
    ConvertTo-Ico $png $ico
    $icoBytes = [IO.File]::ReadAllBytes($ico)
    $pngBytes = [IO.File]::ReadAllBytes($png)
    Assert ($icoBytes.Length -eq $pngBytes.Length + 22) "ICO length must include exactly the PNG and header"
    Assert ([BitConverter]::ToUInt16($icoBytes, 2) -eq 1) "ICO header must identify an icon"
    Assert ([BitConverter]::ToUInt32($icoBytes, 18) -eq 22) "PNG offset must be 22"
    Assert ([Convert]::ToBase64String($icoBytes[22..($icoBytes.Length - 1)]) -eq [Convert]::ToBase64String($pngBytes)) "PNG alpha data must remain intact"

    # Exercise deps.ps1 without installing packages or cloning the GPU engine.
    $global:ImgToSvgTestCalls = [Collections.Generic.List[string]]::new()
    $global:ImgToSvgTestMissing = $true
    $global:ImgToSvgTestFailInstall = $false
    function python {
        $global:ImgToSvgTestCalls.Add(($args -join ' '))
        if ($args[0] -eq '-c') {
            if ($global:ImgToSvgTestMissing) { $global:LASTEXITCODE = 1 } else { $global:LASTEXITCODE = 0 }
        } elseif ($args[0] -eq '-m' -and $args[1] -eq 'pip') {
            if ($global:ImgToSvgTestFailInstall) { $global:LASTEXITCODE = 1 } else { $global:LASTEXITCODE = 0 }
        } else { throw "Unexpected Python invocation: $args" }
    }
    & (Join-Path $Repo "deps.ps1")
    Assert ($global:ImgToSvgTestCalls.Contains('-m pip install vtracer')) "Missing vtracer should be installed"
    Assert ($global:ImgToSvgTestCalls.Contains('-m pip install Pillow')) "Missing Pillow should be installed"
    Assert ($global:ImgToSvgTestCalls.Count -eq 4) "Default setup must only check/install the two default packages"
    $global:ImgToSvgTestCalls.Clear()
    $global:ImgToSvgTestMissing = $false
    & (Join-Path $Repo "deps.ps1")
    Assert ($global:ImgToSvgTestCalls.Count -eq 2) "Installed packages should only be checked"
    $global:ImgToSvgTestMissing = $true
    $global:ImgToSvgTestFailInstall = $true
    $failed = $false
    try { & (Join-Path $Repo "deps.ps1") } catch { $failed = $true }
    Assert $failed "Dependency install failure must stop setup"
    Remove-Item Function:python
    # The mocked failure above leaves $LASTEXITCODE non-zero. GitHub Actions runs
    # this script by dot-sourcing it, so a stray non-zero $LASTEXITCODE at the
    # end would fail the step even though every assertion passed.
    $global:LASTEXITCODE = 0

    if ($env:OS -eq 'Windows_NT') {
        # Use an isolated registry fixture, never touch Explorer's real associations.
        $registry = "HKCU:\Software\img-to-svg-tests-$([guid]::NewGuid())"
        try {
            Set-MikesToolsRoot $registry 'shared.ico'
            Add-MikesVerb $registry 'OtherTool' 'Another tool' 'other.ico' 'other command'
            Set-MikesToolsRoot $registry 'replacement.ico'
            Add-MikesVerb $registry 'ImgToSvg' 'Convert to SVG' $ico 'img-to-svg command'
            Assert ((Get-ItemProperty $registry).Icon -eq 'shared.ico') "Existing shared menu settings must survive"
            Assert ((Get-Item "$registry\shell\OtherTool\command").GetValue('') -eq 'other command') "Other tools must survive registration"
            Assert ((Get-Item "$registry\shell\ImgToSvg\command").GetValue('') -eq 'img-to-svg command') "Own verb must be registered"
        } finally {
            if (Test-Path $registry) { Remove-Item $registry -Recurse -Force }
        }
    } else {
        Write-Host 'Windows registry helper checks skipped on this platform.'
    }
    Write-Host 'PowerShell installer checks passed.'
} finally {
    if (Test-Path Function:python) { Remove-Item Function:python }
    Remove-Item $temp -Recurse -Force
}
