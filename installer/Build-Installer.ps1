param(
    [Parameter(Mandatory = $false)]
    [string]$Version = "3.0.2-preview",

    [Parameter(Mandatory = $false)]
    [string]$IsccPath = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$iss = Join-Path $PSScriptRoot "ExtensionInstaller.iss"
$dist = Join-Path $repoRoot "dist"

if ([string]::IsNullOrWhiteSpace($IsccPath)) {
    $candidates = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe"
    )
    $IsccPath = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}

if ([string]::IsNullOrWhiteSpace($IsccPath) -or -not (Test-Path -LiteralPath $IsccPath -PathType Leaf)) {
    throw "ISCC.exe (Inno Setup 6) не найден."
}

if (Test-Path -LiteralPath $dist) {
    Remove-Item -LiteralPath $dist -Recurse -Force
}
New-Item -ItemType Directory -Path $dist -Force | Out-Null

& $IsccPath "/DMyAppVersion=$Version" $iss
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup завершился с кодом $LASTEXITCODE."
}

$setup = Get-ChildItem -LiteralPath $dist -Filter "ExtensionInstaller_Setup_*.exe" -File | Select-Object -Single
$sha = (Get-FileHash -LiteralPath $setup.FullName -Algorithm SHA256).Hash.ToLowerInvariant()

[pscustomobject]@{
    Version = $Version
    Path = $setup.FullName
    Sha256 = $sha
    Size = $setup.Length
}
