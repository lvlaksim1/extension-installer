# Release-driven extension acquisition for ExtensionInstaller.
# Windows PowerShell 5.1 compatible. This module intentionally contains no private-key handling.

$ErrorActionPreference = "Stop"

function Test-ReleaseExtensionId([string]$Id) {
    return (-not [string]::IsNullOrWhiteSpace($Id) -and $Id -match '^[a-p]{32}$')
}

function Get-ReleaseFileSha256([string]$PathValue) {
    if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) { throw "Файл не найден: $PathValue" }
    return (Get-FileHash -LiteralPath $PathValue -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-ReleaseProperty($Object, [string]$Name, $DefaultValue) {
    if ($null -eq $Object) { return $DefaultValue }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $DefaultValue }
    return $p.Value
}

function Read-ExtensionCatalog([string]$CatalogPath) {
    if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) { throw "Каталог расширений не найден: $CatalogPath" }
    $catalog = [System.IO.File]::ReadAllText($CatalogPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop

    if ([string](Get-ReleaseProperty $catalog "schema" "") -cne "extension-installer-catalog") {
        throw "Неподдерживаемая схема каталога расширений."
    }
    if ([int](Get-ReleaseProperty $catalog "schema_version" 0) -ne 1) {
        throw "Неподдерживаемая версия схемы каталога расширений."
    }

    $seenSlug = @{}
    $seenId = @{}
    foreach ($entry in @($catalog.extensions)) {
        $slug = [string](Get-ReleaseProperty $entry "slug" "")
        $name = [string](Get-ReleaseProperty $entry "name" "")
        $repository = [string](Get-ReleaseProperty $entry "repository" "")
        $extensionId = [string](Get-ReleaseProperty $entry "extension_id" "")
        $channel = [string](Get-ReleaseProperty $entry "channel" "")

        if ($slug -notmatch '^[a-z0-9][a-z0-9._-]*$') { throw "Некорректный slug в каталоге: $slug" }
        if ([string]::IsNullOrWhiteSpace($name)) { throw "У записи $slug отсутствует name." }
        if ($repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw "Некорректный GitHub repository у $slug." }
        if (-not (Test-ReleaseExtensionId $extensionId)) { throw "Некорректный extension_id у $slug." }
        if ($channel -cne "stable" -and $channel -cne "prerelease") { throw "Неподдерживаемый channel у ${slug}: $channel" }
        if ($seenSlug.ContainsKey($slug)) { throw "Дублирующийся slug в каталоге: $slug" }
        if ($seenId.ContainsKey($extensionId)) { throw "Дублирующийся extension_id в каталоге: $extensionId" }

        $seenSlug[$slug] = $true
        $seenId[$extensionId] = $true
    }

    return $catalog
}

function Invoke-GitHubReleaseJson([string]$Uri) {
    try {
        if ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12) { }
        else { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 }
    }
    catch { }

    $headers = @{
        "Accept" = "application/vnd.github+json"
        "User-Agent" = "ExtensionInstaller"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    $optionalToken = [string]$env:EXTENSION_INSTALLER_GITHUB_TOKEN
    if (-not [string]::IsNullOrWhiteSpace($optionalToken)) {
        $headers["Authorization"] = "Bearer " + $optionalToken.Trim()
    }

    return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers -UseBasicParsing -ErrorAction Stop
}

function Save-ReleaseAsset([string]$Uri, [string]$DestinationPath) {
    $parent = Split-Path -Parent $DestinationPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $tempPath = $DestinationPath + ".partial-" + [Guid]::NewGuid().ToString("N")
    try {
        $headers = @{ "User-Agent" = "ExtensionInstaller" }
        Invoke-WebRequest -Method Get -Uri $Uri -Headers $headers -UseBasicParsing -OutFile $tempPath -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $tempPath -PathType Leaf)) { throw "Загрузка не создала файл." }
        Move-Item -LiteralPath $tempPath -Destination $DestinationPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $tempPath -PathType Leaf) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-ReleaseAsset($Release, [string]$AssetName) {
    $matches = @($Release.assets | Where-Object { [string]$_.name -ceq $AssetName })
    if ($matches.Count -eq 0) { throw "В GitHub Release отсутствует asset: $AssetName" }
    if ($matches.Count -gt 1) { throw "В GitHub Release найдено несколько assets с именем: $AssetName" }
    return $matches[0]
}

function Read-ExtensionReleaseDescriptor([string]$PathValue) {
    if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) { throw "Release descriptor не найден." }
    $d = [System.IO.File]::ReadAllText($PathValue, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop

    if ([string](Get-ReleaseProperty $d "schema" "") -cne "extension-installer-release") {
        throw "Неподдерживаемая схема release descriptor."
    }
    if ([int](Get-ReleaseProperty $d "schema_version" 0) -ne 1) {
        throw "Неподдерживаемая версия release descriptor."
    }

    $slug = [string](Get-ReleaseProperty $d "slug" "")
    $version = [string](Get-ReleaseProperty $d "version" "")
    $extensionId = [string](Get-ReleaseProperty $d "extension_id" "")
    $crxAsset = [string](Get-ReleaseProperty $d "crx_asset" "")
    $sha = ([string](Get-ReleaseProperty $d "crx_sha256" "")).ToLowerInvariant()

    if ($slug -notmatch '^[a-z0-9][a-z0-9._-]*$') { throw "Release descriptor содержит некорректный slug." }
    if ($version -notmatch '^\d+(\.\d+){0,3}$') { throw "Release descriptor содержит некорректную version." }
    if (-not (Test-ReleaseExtensionId $extensionId)) { throw "Release descriptor содержит некорректный extension_id." }
    if ([string]::IsNullOrWhiteSpace($crxAsset) -or [System.IO.Path]::GetFileName($crxAsset) -cne $crxAsset -or -not $crxAsset.EndsWith(".crx", [StringComparison]::OrdinalIgnoreCase)) {
        throw "Release descriptor содержит некорректный crx_asset."
    }
    if ($sha -notmatch '^[0-9a-f]{64}$') { throw "Release descriptor содержит некорректный crx_sha256." }

    return $d
}

function Resolve-LatestSignedExtensionRelease($CatalogEntry, [string]$WorkingRoot) {
    $slug = [string](Get-ReleaseProperty $CatalogEntry "slug" "")
    $repo = [string](Get-ReleaseProperty $CatalogEntry "repository" "")
    $pinnedId = [string](Get-ReleaseProperty $CatalogEntry "extension_id" "")

    if (-not (Test-ReleaseExtensionId $pinnedId)) { throw "Каталог содержит некорректный Extension ID: $slug" }

    $channel = [string](Get-ReleaseProperty $CatalogEntry "channel" "stable")
    if ($channel -ceq "stable") {
        $release = Invoke-GitHubReleaseJson ("https://api.github.com/repos/" + $repo + "/releases/latest")
        if ([bool](Get-ReleaseProperty $release "draft" $true)) { throw "Latest release неожиданно является draft." }
        if ([bool](Get-ReleaseProperty $release "prerelease" $true)) { throw "Stable channel получил prerelease." }
    }
    elseif ($channel -ceq "prerelease") {
        $releases = @(Invoke-GitHubReleaseJson ("https://api.github.com/repos/" + $repo + "/releases?per_page=20"))
        $release = @($releases | Where-Object {
            $_.draft -eq $false -and $_.prerelease -eq $true
        } | Select-Object -First 1)
        if ($release.Count -ne 1) { throw "Для prerelease channel не найден опубликованный prerelease." }
        $release = $release[0]
    }
    else {
        throw "Неподдерживаемый release channel: $channel"
    }

    $descriptorAsset = Get-ReleaseAsset $release "extension-release.json"
    $releaseRoot = Join-Path $WorkingRoot ($slug + "-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $releaseRoot -Force | Out-Null
    $descriptorPath = Join-Path $releaseRoot "extension-release.json"

    Save-ReleaseAsset ([string]$descriptorAsset.browser_download_url) $descriptorPath
    $descriptor = Read-ExtensionReleaseDescriptor $descriptorPath

    if ([string]$descriptor.slug -cne $slug) { throw "Release slug не совпадает с каталогом." }
    if ([string]$descriptor.extension_id -cne $pinnedId) { throw "Release пытается изменить закреплённый Extension ID." }

    $crxAsset = Get-ReleaseAsset $release ([string]$descriptor.crx_asset)
    $crxPath = Join-Path $releaseRoot ([string]$descriptor.crx_asset)
    Save-ReleaseAsset ([string]$crxAsset.browser_download_url) $crxPath

    $actualSha = Get-ReleaseFileSha256 $crxPath
    if ($actualSha -cne ([string]$descriptor.crx_sha256).ToLowerInvariant()) {
        throw "SHA-256 скачанного CRX не совпадает с release descriptor."
    }

    Initialize-Crx3PackageInspector
    $inspection = [Crx3PackageInspector]::Inspect($crxPath)
    if (-not $inspection.SignatureValid) { throw "CRX3 signature verification failed." }
    if ([string]$inspection.ExtensionId -cne $pinnedId) {
        throw ("Extension ID внутри CRX не совпадает с каталогом. Ожидался " + $pinnedId + ", получен " + $inspection.ExtensionId)
    }

    return [pscustomobject]@{
        Slug = $slug
        Name = [string](Get-ReleaseProperty $CatalogEntry "name" $slug)
        Repository = $repo
        Version = [string]$descriptor.version
        ExtensionId = $pinnedId
        CrxPath = $crxPath
        Sha256 = $actualSha
        ReleaseTag = [string](Get-ReleaseProperty $release "tag_name" "")
        ReleaseUrl = [string](Get-ReleaseProperty $release "html_url" "")
        WorkingRoot = $releaseRoot
    }
}


function Get-ReleaseYandexValues([string]$ExtensionId) {
    $baseKey = "HKCU:\Software\Yandex\YandexBrowser\Extensions"
    $key = Join-Path $baseKey $ExtensionId
    if (-not (Test-Path -LiteralPath $key)) { return $null }
    $value = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
    return [pscustomobject]@{
        Key = $key
        Path = [string]$value.path
        Version = [string]$value.version
    }
}


function Get-ReleaseYandexUserDataRoot {
    return (Join-Path $env:LOCALAPPDATA "Yandex\YandexBrowser\User Data")
}

function Get-ReleaseYandexProfileInstallations {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionId,
        [string]$UserDataRoot = ""
    )

    if (-not (Test-ReleaseExtensionId $ExtensionId)) { throw "Некорректный Extension ID." }
    if ([string]::IsNullOrWhiteSpace($UserDataRoot)) { $UserDataRoot = Get-ReleaseYandexUserDataRoot }
    if (-not (Test-Path -LiteralPath $UserDataRoot -PathType Container)) { return @() }

    $result = @()
    foreach ($profile in @(Get-ChildItem -LiteralPath $UserDataRoot -Directory -Force -ErrorAction SilentlyContinue)) {
        $settingsEntry = $null
        $settingsSource = ""

        foreach ($preferencesName in @("Secure Preferences", "Preferences")) {
            $preferencesPath = Join-Path $profile.FullName $preferencesName
            if (-not (Test-Path -LiteralPath $preferencesPath -PathType Leaf)) { continue }

            try {
                $preferences = [System.IO.File]::ReadAllText($preferencesPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
                $extensions = Get-ReleaseProperty $preferences "extensions" $null
                $settings = Get-ReleaseProperty $extensions "settings" $null
                $candidate = Get-ReleaseProperty $settings $ExtensionId $null
                if ($null -ne $candidate) {
                    $settingsEntry = $candidate
                    $settingsSource = $preferencesPath
                    break
                }
            }
            catch {
                # A transient/unreadable profile must not break normal status probing.
            }
        }

        if ($null -eq $settingsEntry) { continue }

        $version = ""
        $manifest = Get-ReleaseProperty $settingsEntry "manifest" $null
        if ($null -ne $manifest) {
            $version = [string](Get-ReleaseProperty $manifest "version" "")
        }

        $extensionRoot = Join-Path (Join-Path $profile.FullName "Extensions") $ExtensionId
        $path = ""
        if (Test-Path -LiteralPath $extensionRoot -PathType Container) {
            $versionDirs = @(Get-ChildItem -LiteralPath $extensionRoot -Directory -Force -ErrorAction SilentlyContinue)
            if ([string]::IsNullOrWhiteSpace($version)) {
                $best = @($versionDirs | Where-Object { $_.Name -match '^(\d+(?:\.\d+){0,3})(?:_\d+)?$' } | Sort-Object Name -Descending | Select-Object -First 1)
                if ($best.Count -eq 1 -and [string]$best[0].Name -match '^(\d+(?:\.\d+){0,3})(?:_\d+)?$') {
                    $version = [string]$Matches[1]
                    $path = [string]$best[0].FullName
                }
            }
            else {
                $matching = @($versionDirs | Where-Object { $_.Name -match ('^' + [regex]::Escape($version) + '(?:_\d+)?$') } | Select-Object -First 1)
                if ($matching.Count -eq 1) { $path = [string]$matching[0].FullName }
            }
        }

        $result += [pscustomobject]@{
            Profile = [string]$profile.Name
            Version = $version
            Path = $path
            PreferencesPath = $settingsSource
        }
    }
    return @($result)
}

function Get-ReleaseYandexExternalUninstallProfiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionId,
        [string]$UserDataRoot = ""
    )

    if (-not (Test-ReleaseExtensionId $ExtensionId)) { throw "Некорректный Extension ID." }
    if ([string]::IsNullOrWhiteSpace($UserDataRoot)) { $UserDataRoot = Get-ReleaseYandexUserDataRoot }
    if (-not (Test-Path -LiteralPath $UserDataRoot -PathType Container)) { return @() }

    $result = @()
    foreach ($profile in @(Get-ChildItem -LiteralPath $UserDataRoot -Directory -Force -ErrorAction SilentlyContinue)) {
        foreach ($preferencesName in @("Secure Preferences", "Preferences")) {
            $preferencesPath = Join-Path $profile.FullName $preferencesName
            if (-not (Test-Path -LiteralPath $preferencesPath -PathType Leaf)) { continue }

            try {
                $preferences = [System.IO.File]::ReadAllText($preferencesPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
                $extensions = Get-ReleaseProperty $preferences "extensions" $null
                $externalUninstalls = @(Get-ReleaseProperty $extensions "external_uninstalls" $null)
                if (@($externalUninstalls | Where-Object { [string]$_ -ceq $ExtensionId }).Count -gt 0) {
                    $result += [pscustomobject]@{
                        Profile = [string]$profile.Name
                        PreferencesPath = [string]$preferencesPath
                    }
                    break
                }
            }
            catch {
                # A transient/unreadable profile must not break normal status probing.
            }
        }
    }
    return @($result)
}

function Test-ReleaseYandexBrowserRunning {
    foreach ($process in @(Get-Process -Name "browser" -ErrorAction SilentlyContinue)) {
        try {
            $path = [string]$process.Path
            if ([string]::IsNullOrWhiteSpace($path)) { return $true }
            if ($path.IndexOf("\Yandex\YandexBrowser\", [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
        }
        catch { return $true }
    }
    return $false
}



function Initialize-ReleaseYandexWindowBridge {
    if ("ExtensionInstallerYandexWindowBridge" -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ExtensionInstallerYandexWindowBridge
{
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] public static extern IntPtr SetActiveWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr hWnd);
}
'@
}

function Get-ReleaseYandexWindowProcess {
    Initialize-ReleaseYandexWindowBridge
    $windows = New-Object System.Collections.Generic.List[object]
    foreach ($process in @(Get-Process -Name "browser" -ErrorAction SilentlyContinue)) {
        try {
            $process.Refresh()
            if ($process.MainWindowHandle -eq 0) { continue }
            $isYandex = $false
            try { if ([string]$process.Path -match '(?i)\\Yandex\\') { $isYandex = $true } } catch { }
            try { if ([string]$process.MainModule.FileVersionInfo.ProductName -match '(?i)Yandex|Яндекс') { $isYandex = $true } } catch { }
            [void]$windows.Add([pscustomobject]@{ Process = $process; IsYandex = $isYandex })
        }
        catch { }
    }

    if ($windows.Count -eq 0) { return $null }
    try {
        $foreground = [ExtensionInstallerYandexWindowBridge]::GetForegroundWindow()
        foreach ($item in $windows) {
            if ($item.IsYandex -and [IntPtr]$item.Process.MainWindowHandle -eq $foreground) { return $item.Process }
        }
    }
    catch { }

    $verified = @($windows | Where-Object { $_.IsYandex })
    if ($verified.Count -gt 0) { return $verified[0].Process }
    return $windows[0].Process
}

function Activate-ReleaseYandexBrowser {
    try {
        Initialize-ReleaseYandexWindowBridge
        $process = Get-ReleaseYandexWindowProcess
        if ($null -eq $process -or $process.MainWindowHandle -eq 0) { return $false }

        $handle = [IntPtr]$process.MainWindowHandle
        if ([ExtensionInstallerYandexWindowBridge]::IsIconic($handle)) {
            [void][ExtensionInstallerYandexWindowBridge]::ShowWindowAsync($handle, 9)
            Start-Sleep -Milliseconds 120
        }

        $currentThread = [ExtensionInstallerYandexWindowBridge]::GetCurrentThreadId()
        $foreground = [ExtensionInstallerYandexWindowBridge]::GetForegroundWindow()
        [uint32]$foregroundProcessId = 0
        [uint32]$targetProcessId = 0
        [uint32]$foregroundThread = 0
        [uint32]$targetThread = [ExtensionInstallerYandexWindowBridge]::GetWindowThreadProcessId($handle, [ref]$targetProcessId)
        if ($foreground -ne [IntPtr]::Zero) {
            $foregroundThread = [ExtensionInstallerYandexWindowBridge]::GetWindowThreadProcessId($foreground, [ref]$foregroundProcessId)
        }

        $attachedForeground = $false
        $attachedTarget = $false
        try {
            if ($foregroundThread -ne 0 -and $foregroundThread -ne $currentThread) {
                $attachedForeground = [ExtensionInstallerYandexWindowBridge]::AttachThreadInput($currentThread, $foregroundThread, $true)
            }
            if ($targetThread -ne 0 -and $targetThread -ne $currentThread) {
                $attachedTarget = [ExtensionInstallerYandexWindowBridge]::AttachThreadInput($currentThread, $targetThread, $true)
            }
            [void][ExtensionInstallerYandexWindowBridge]::BringWindowToTop($handle)
            [void][ExtensionInstallerYandexWindowBridge]::SetForegroundWindow($handle)
            [void][ExtensionInstallerYandexWindowBridge]::SetActiveWindow($handle)
            [void][ExtensionInstallerYandexWindowBridge]::SetFocus($handle)
        }
        finally {
            if ($attachedTarget) {
                [void][ExtensionInstallerYandexWindowBridge]::AttachThreadInput($currentThread, $targetThread, $false)
            }
            if ($attachedForeground) {
                [void][ExtensionInstallerYandexWindowBridge]::AttachThreadInput($currentThread, $foregroundThread, $false)
            }
        }

        Start-Sleep -Milliseconds 100
        return ([ExtensionInstallerYandexWindowBridge]::GetForegroundWindow() -eq $handle)
    }
    catch { return $false }
}

function Get-ReleaseYandexBrowserExecutablePath {
    foreach ($process in @(Get-Process -Name "browser" -ErrorAction SilentlyContinue)) {
        try {
            $path = [string]$process.Path
            if (-not [string]::IsNullOrWhiteSpace($path) -and
                $path.IndexOf("\Yandex\YandexBrowser\", [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
                (Test-Path -LiteralPath $path -PathType Leaf)) {
                return $path
            }
        }
        catch { }
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Yandex\YandexBrowser\Application\browser.exe"),
        $(if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) { Join-Path $env:ProgramFiles "Yandex\YandexBrowser\Application\browser.exe" } else { "" }),
        $(if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) { Join-Path ${env:ProgramFiles(x86)} "Yandex\YandexBrowser\Application\browser.exe" } else { "" })
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace([string]$candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return [string]$candidate
        }
    }
    return ""
}

function Open-ReleaseYandexTunePage {
    $browserPath = Get-ReleaseYandexBrowserExecutablePath
    if ([string]::IsNullOrWhiteSpace($browserPath)) { return $false }

    try {
        Start-Process -FilePath $browserPath -ArgumentList "browser://tune/" -ErrorAction Stop | Out-Null
        return $true
    }
    catch { return $false }
}

function Show-ReleaseCrxInExplorer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CrxPath
    )

    if (-not (Test-Path -LiteralPath $CrxPath -PathType Leaf)) { return $false }
    try {
        Start-Process -FilePath "explorer.exe" -ArgumentList ('/select,"' + $CrxPath + '"') -ErrorAction Stop | Out-Null
        return $true
    }
    catch { return $false }
}

function Restore-ReleaseYandexPreferenceBackups($Backups) {
    foreach ($backup in @($Backups)) {
        $path = [string](Get-ReleaseProperty $backup "Path" "")
        $bytes = Get-ReleaseProperty $backup "Bytes" $null
        if ([string]::IsNullOrWhiteSpace($path) -or $null -eq $bytes) { continue }

        $temp = $path + ".extensioninstaller-restore-" + [Guid]::NewGuid().ToString("N")
        try {
            [System.IO.File]::WriteAllBytes($temp, [byte[]]$bytes)
            Move-Item -LiteralPath $temp -Destination $path -Force
        }
        finally {
            if (Test-Path -LiteralPath $temp -PathType Leaf) {
                Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Remove-ReleaseYandexExternalUninstallMarker {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionId,
        [string]$UserDataRoot = ""
    )

    $profiles = @(Get-ReleaseYandexExternalUninstallProfiles $ExtensionId $UserDataRoot)
    if ($profiles.Count -eq 0) { return @() }

    if (Test-ReleaseYandexBrowserRunning) {
        throw "Расширение было удалено через Яндекс.Браузер. Полностью закройте Яндекс.Браузер и повторите установку."
    }

    $backups = @()
    try {
        foreach ($profile in $profiles) {
            $preferencesPath = [string]$profile.PreferencesPath
            $originalBytes = [System.IO.File]::ReadAllBytes($preferencesPath)
            $hasBom = (
                $originalBytes.Length -ge 3 -and
                $originalBytes[0] -eq 0xEF -and
                $originalBytes[1] -eq 0xBB -and
                $originalBytes[2] -eq 0xBF
            )
            $text = [System.Text.Encoding]::UTF8.GetString($originalBytes)
            if ($text.Length -gt 0 -and [int]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }

            $arrayPattern = '("external_uninstalls"\s*:\s*)\[(?<body>[^\]]*)\]'
            $matches = [regex]::Matches($text, $arrayPattern)
            $newText = $text
            $changed = $false
            $idPattern = [regex]::Escape($ExtensionId)

            for ($i = $matches.Count - 1; $i -ge 0; $i--) {
                $match = $matches[$i]
                $bodyGroup = $match.Groups["body"]
                $body = [string]$bodyGroup.Value
                if ($body -notmatch ('"' + $idPattern + '"')) { continue }

                $items = @([regex]::Matches($body, '"(?<id>[a-p]{32})"') | ForEach-Object { [string]$_.Groups["id"].Value })
                $filtered = @($items | Where-Object { $_ -cne $ExtensionId })
                if ($filtered.Count -eq $items.Count) { continue }

                $newBody = (($filtered | ForEach-Object { '"' + $_ + '"' }) -join ',')
                $newText = $newText.Substring(0, $bodyGroup.Index) + $newBody + $newText.Substring($bodyGroup.Index + $bodyGroup.Length)
                $changed = $true
            }

            if (-not $changed) {
                throw ("Не удалось снять блокировку повторной установки в профиле " + [string]$profile.Profile + ".")
            }

            $backups += [pscustomobject]@{ Path = $preferencesPath; Bytes = $originalBytes }

            $temp = $preferencesPath + ".extensioninstaller-" + [Guid]::NewGuid().ToString("N")
            try {
                $encoding = New-Object System.Text.UTF8Encoding($hasBom)
                [System.IO.File]::WriteAllText($temp, $newText, $encoding)
                Move-Item -LiteralPath $temp -Destination $preferencesPath -Force
            }
            finally {
                if (Test-Path -LiteralPath $temp -PathType Leaf) {
                    Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    catch {
        Restore-ReleaseYandexPreferenceBackups $backups
        throw
    }

    return @($backups)
}

function Set-ReleaseYandexRegistration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionId,
        [Parameter(Mandatory = $true)]
        [string]$CrxPath,
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [string]$BaseKey = "HKCU:\Software\Yandex\YandexBrowser\Extensions",
        [Nullable[bool]]$BrowserRunningOverride = $null
    )

    if (-not (Test-ReleaseExtensionId $ExtensionId)) { throw "Некорректный Extension ID." }
    if (-not (Test-Path -LiteralPath $CrxPath -PathType Leaf)) { throw "CRX для регистрации не найден." }
    if ($Version -notmatch '^\d+(\.\d+){0,3}$') { throw "Некорректная версия для регистрации." }

    if (-not (Test-Path -LiteralPath $BaseKey)) {
        New-Item -Path $BaseKey -Force | Out-Null
    }

    $key = Join-Path $BaseKey $ExtensionId
    $hadRegistration = Test-Path -LiteralPath $key
    $oldPath = ""
    $oldVersion = ""
    if ($hadRegistration) {
        try {
            $old = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
            $oldPath = [string]$old.path
            $oldVersion = [string]$old.version
        }
        catch { }
    }

    $browserRunning = if ($null -ne $BrowserRunningOverride) {
        [bool]$BrowserRunningOverride
    }
    else {
        Test-ReleaseYandexBrowserRunning
    }

    # Exact ExtensionInstaller v3.0.2 semantics: never delete an existing
    # external-extension registry key during install/update. Update path/version
    # in place so a running Chromium/Yandex instance never observes an uninstall.
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -LiteralPath $key -Name "path" -PropertyType String -Value $CrxPath -Force | Out-Null
    New-ItemProperty -LiteralPath $key -Name "version" -PropertyType String -Value $Version -Force | Out-Null

    $value = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
    if ([string]$value.path -cne $CrxPath -or [string]$value.version -cne $Version) {
        throw "Проверка записи Яндекс.Браузера после регистрации не пройдена."
    }

    return [pscustomobject]@{
        Key = $key
        HadRegistration = [bool]$hadRegistration
        BrowserRunning = [bool]$browserRunning
        InPlace = $true
        ValuesChanged = [bool]((-not $hadRegistration) -or $oldPath -cne $CrxPath -or $oldVersion -cne $Version)
    }
}

function Test-ReleaseLegacyYandexRegistration {
    param(
        $YandexValues,
        [Parameter(Mandatory = $true)]
        [string]$ExtensionId
    )

    if ($null -eq $YandexValues -or -not (Test-ReleaseExtensionId $ExtensionId)) { return $false }
    $legacyRoot = Join-Path (Join-Path (Join-Path $env:LOCALAPPDATA "UniversalExtensionBuilder") "projects") $ExtensionId
    $legacyCrxRoot = Join-Path $legacyRoot "crx"
    return (Test-PathUnderRoot ([string]$YandexValues.Path) $legacyCrxRoot)
}

function Read-ReleaseInstallState([string]$StatePath) {
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { return $null }
    try {
        return ([System.IO.File]::ReadAllText($StatePath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop)
    }
    catch { throw ("Файл состояния установки повреждён: " + $_.Exception.Message) }
}

function Write-ReleaseInstallState([string]$StatePath, $StateObject) {
    $parent = Split-Path -Parent $StatePath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $json = $StateObject | ConvertTo-Json -Depth 10
    $temp = $StatePath + ".tmp-" + [Guid]::NewGuid().ToString("N")
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($temp, $json + [Environment]::NewLine, $utf8NoBom)
        Move-Item -LiteralPath $temp -Destination $StatePath -Force
    }
    finally {
        if (Test-Path -LiteralPath $temp -PathType Leaf) {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
    }
}


function Read-ReleaseOwnershipMarker([string]$OwnershipPath) {
    if (-not (Test-Path -LiteralPath $OwnershipPath -PathType Leaf)) { return $null }
    try {
        $marker = [System.IO.File]::ReadAllText($OwnershipPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
        if ([string](Get-ReleaseProperty $marker "Schema" "") -cne "extension-installer-ownership") { return $null }
        if ([int](Get-ReleaseProperty $marker "SchemaVersion" 0) -ne 1) { return $null }
        $id = [string](Get-ReleaseProperty $marker "ExtensionId" "")
        if (-not (Test-ReleaseExtensionId $id)) { return $null }
        return $marker
    }
    catch { return $null }
}

function Write-ReleaseOwnershipMarker([string]$OwnershipPath, [string]$ExtensionId, $State, $YandexValues) {
    if (-not (Test-ReleaseExtensionId $ExtensionId)) { throw "Некорректный Extension ID для ownership marker." }

    $lastVersion = ""
    $lastCrxPath = ""
    $sourceRepository = ""

    if ($null -ne $State) {
        $lastVersion = [string](Get-ReleaseProperty $State "Version" "")
        $lastCrxPath = [string](Get-ReleaseProperty $State "CrxPath" "")
        $sourceRepository = [string](Get-ReleaseProperty $State "SourceRepository" "")
    }
    elseif ($null -ne $YandexValues) {
        $lastVersion = [string](Get-ReleaseProperty $YandexValues "Version" "")
        $lastCrxPath = [string](Get-ReleaseProperty $YandexValues "Path" "")
    }

    $marker = [pscustomobject]@{
        Schema = "extension-installer-ownership"
        SchemaVersion = 1
        ExtensionId = $ExtensionId
        LastVersion = $lastVersion
        LastCrxPath = $lastCrxPath
        SourceRepository = $sourceRepository
        RemovedUtc = [DateTime]::UtcNow.ToString("o")
    }
    Write-ReleaseInstallState $OwnershipPath $marker
    return $marker
}

function Test-PathUnderRoot([string]$PathValue, [string]$RootValue) {
    if ([string]::IsNullOrWhiteSpace($PathValue) -or [string]::IsNullOrWhiteSpace($RootValue)) { return $false }
    try {
        $full = [System.IO.Path]::GetFullPath($PathValue)
        $root = [System.IO.Path]::GetFullPath($RootValue)
        if (-not $root.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString())) {
            $root += [System.IO.Path]::DirectorySeparatorChar
        }
        return $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)
    }
    catch { return $false }
}

function Install-ValidatedSignedRelease($ResolvedRelease, [string]$InstallRoot) {
    if ($null -eq $ResolvedRelease) { throw "Release не разрешён." }
    if ([string]::IsNullOrWhiteSpace($InstallRoot)) { throw "Не задана служебная папка установки." }

    $extensionId = [string](Get-ReleaseProperty $ResolvedRelease "ExtensionId" "")
    $version = [string](Get-ReleaseProperty $ResolvedRelease "Version" "")
    $crxPath = [string](Get-ReleaseProperty $ResolvedRelease "CrxPath" "")
    $sha = ([string](Get-ReleaseProperty $ResolvedRelease "Sha256" "")).ToLowerInvariant()
    $repository = [string](Get-ReleaseProperty $ResolvedRelease "Repository" "")
    $releaseTag = [string](Get-ReleaseProperty $ResolvedRelease "ReleaseTag" "")
    $releaseUrl = [string](Get-ReleaseProperty $ResolvedRelease "ReleaseUrl" "")

    if (-not (Test-ReleaseExtensionId $extensionId)) { throw "Resolved release содержит некорректный Extension ID." }
    if ($version -notmatch '^\d+(\.\d+){0,3}$') { throw "Resolved release содержит некорректную версию." }
    if (-not (Test-Path -LiteralPath $crxPath -PathType Leaf)) { throw "Проверенный CRX не найден." }
    if ($sha -notmatch '^[0-9a-f]{64}$') { throw "Resolved release содержит некорректный SHA-256." }
    if ((Get-ReleaseFileSha256 $crxPath) -cne $sha) { throw "CRX изменился после проверки release." }

    Initialize-Crx3PackageInspector
    $inspection = [Crx3PackageInspector]::Inspect($crxPath)
    if (-not $inspection.SignatureValid) { throw "CRX3 signature verification failed перед установкой." }
    if ([string]$inspection.ExtensionId -cne $extensionId) { throw "Extension ID внутри CRX изменился перед установкой." }

    $extensionRoot = Join-Path $InstallRoot $extensionId
    $crxRoot = Join-Path $extensionRoot "crx"
    $statePath = Join-Path $extensionRoot "state.json"
    $ownershipPath = Join-Path $extensionRoot "ownership.json"
    if (-not (Test-Path -LiteralPath $crxRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $crxRoot -Force | Out-Null
    }

    $fileName = $extensionId + "-" + $version + "-" + $sha.Substring(0,12) + ".crx"
    $installedCrxPath = Join-Path $crxRoot $fileName
    $yandexKey = Join-Path "HKCU:\Software\Yandex\YandexBrowser\Extensions" $extensionId
    $oldState = Read-ReleaseInstallState $statePath
    $oldYandex = Get-ReleaseYandexValues $extensionId
    $legacyRegistration = ($null -ne $oldYandex -and (Test-ReleaseLegacyYandexRegistration $oldYandex $extensionId))

    if ($null -eq $oldState -and $null -ne $oldYandex -and -not (Test-PathUnderRoot $oldYandex.Path $crxRoot) -and -not $legacyRegistration) {
        throw "Этот Extension ID уже зарегистрирован, но текущая запись не принадлежит ExtensionInstaller."
    }
    if ($null -ne $oldState -and $null -ne $oldYandex -and $oldYandex.Path -cne [string]$oldState.CrxPath) {
        throw "Текущая запись Яндекс.Браузера расходится с сохранённым состоянием; установка остановлена."
    }

    if (Test-Path -LiteralPath $installedCrxPath -PathType Leaf) {
        if ((Get-ReleaseFileSha256 $installedCrxPath) -cne $sha) {
            throw "Целевой CRX уже существует, но имеет другой SHA-256."
        }
    }
    else {
        Copy-Item -LiteralPath $crxPath -Destination $installedCrxPath -Force
    }

    $preferenceBackups = @()
    $browserRunning = Test-ReleaseYandexBrowserRunning
    try {
        # When Yandex is closed we can safely clear a persisted user-uninstall marker
        # before the next browser start. When it is running, never edit Preferences
        # behind its back. Registration itself follows the proven v3.0.2 behavior:
        # update the owned external-extension key in place; never delete it as part of install/update.
        if (-not $browserRunning) {
            $preferenceBackups = @(Remove-ReleaseYandexExternalUninstallMarker $extensionId)
        }

        $registration = Set-ReleaseYandexRegistration -ExtensionId $extensionId -CrxPath $installedCrxPath -Version $version -BrowserRunningOverride $browserRunning

        $verify = Get-ReleaseYandexValues $extensionId
        if ($null -eq $verify -or $verify.Path -cne $installedCrxPath -or $verify.Version -cne $version) {
            throw "Проверка записи Яндекс.Браузера после установки не пройдена."
        }

        $newState = [pscustomobject]@{
            Schema = "extension-installer-state"
            SchemaVersion = 1
            ExtensionId = $extensionId
            Version = $version
            CrxPath = $installedCrxPath
            Sha256 = $sha
            SourceRepository = $repository
            ReleaseTag = $releaseTag
            ReleaseUrl = $releaseUrl
            InstalledUtc = [DateTime]::UtcNow.ToString("o")
        }
        Write-ReleaseInstallState $statePath $newState
        if (Test-Path -LiteralPath $ownershipPath -PathType Leaf) {
            Remove-Item -LiteralPath $ownershipPath -Force -ErrorAction SilentlyContinue
        }

        if ($null -ne $oldState) {
            $previous = [string]$oldState.CrxPath
            if (-not [string]::IsNullOrWhiteSpace($previous) -and $previous -cne $installedCrxPath -and (Test-Path -LiteralPath $previous -PathType Leaf)) {
                Remove-Item -LiteralPath $previous -Force -ErrorAction SilentlyContinue
            }
        }

        foreach ($oldFile in @(Get-ChildItem -LiteralPath $crxRoot -Filter "*.crx" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -cne $installedCrxPath })) {
            Remove-Item -LiteralPath $oldFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        $reason = $_.Exception.Message
        if ($preferenceBackups.Count -gt 0) {
            try { Restore-ReleaseYandexPreferenceBackups $preferenceBackups } catch { }
        }

        if ($null -ne $oldYandex) {
            New-Item -Path $oldYandex.Key -Force | Out-Null
            New-ItemProperty -LiteralPath $oldYandex.Key -Name "path" -PropertyType String -Value $oldYandex.Path -Force | Out-Null
            New-ItemProperty -LiteralPath $oldYandex.Key -Name "version" -PropertyType String -Value $oldYandex.Version -Force | Out-Null
        }
        elseif (Test-Path -LiteralPath $yandexKey) {
            Remove-Item -LiteralPath $yandexKey -Recurse -Force -ErrorAction SilentlyContinue
        }

        if ((Test-Path -LiteralPath $installedCrxPath -PathType Leaf) -and ($null -eq $oldState -or [string]$oldState.CrxPath -cne $installedCrxPath)) {
            Remove-Item -LiteralPath $installedCrxPath -Force -ErrorAction SilentlyContinue
        }
        throw ("Установка release CRX не выполнена. Rollback завершён. Причина: " + $reason)
    }

    return [pscustomobject]@{
        Version = $version
        ExtensionId = $extensionId
        CrxPath = $installedCrxPath
        Sha256 = $sha
        MigratedLegacyRegistration = $legacyRegistration
        BrowserWasRunning = [bool]$browserRunning
        RegistrationInPlace = [bool](Get-ReleaseProperty $registration "InPlace" $false)
        RegistrationValuesChanged = [bool](Get-ReleaseProperty $registration "ValuesChanged" $false)
    }
}

function Uninstall-ReleaseExtension([string]$ExtensionId, [string]$InstallRoot) {
    if (-not (Test-ReleaseExtensionId $ExtensionId)) { throw "Некорректный Extension ID." }
    if ([string]::IsNullOrWhiteSpace($InstallRoot)) { throw "Не задана служебная папка установки." }

    $extensionRoot = Join-Path $InstallRoot $ExtensionId
    $crxRoot = Join-Path $extensionRoot "crx"
    $statePath = Join-Path $extensionRoot "state.json"
    $ownershipPath = Join-Path $extensionRoot "ownership.json"
    $state = Read-ReleaseInstallState $statePath
    $y = Get-ReleaseYandexValues $ExtensionId
    $legacyRegistration = ($null -ne $y -and (Test-ReleaseLegacyYandexRegistration $y $ExtensionId))

    if ($null -ne $y) {
        if ($null -ne $state) {
            if ($y.Path -cne [string]$state.CrxPath) {
                throw "Путь в реестре Яндекс.Браузера отличается от сохранённого состояния; удаление остановлено."
            }
        }
        elseif (-not (Test-PathUnderRoot $y.Path $crxRoot) -and -not $legacyRegistration) {
            throw "Запись Яндекс.Браузера не принадлежит ExtensionInstaller; удаление остановлено."
        }
    }

    # Persist durable ownership evidence before deleting the active registration/state.
    # A running Chromium/Yandex process can retain its profile entry for a while after
    # the external registry key disappears. Without this marker the next refresh could
    # misclassify our own just-removed extension as foreign.
    if ($null -ne $state -or $null -ne $y) {
        if (-not (Test-Path -LiteralPath $extensionRoot -PathType Container)) {
            New-Item -ItemType Directory -Path $extensionRoot -Force | Out-Null
        }
        Write-ReleaseOwnershipMarker $ownershipPath $ExtensionId $state $y | Out-Null
    }

    if ($null -ne $y) {
        Remove-Item -LiteralPath $y.Key -Recurse -Force
    }

    if (Test-Path -LiteralPath $crxRoot -PathType Container) {
        Remove-Item -LiteralPath $crxRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        Remove-Item -LiteralPath $statePath -Force
    }

    return [pscustomobject]@{
        ExtensionId = $ExtensionId
        OwnershipPath = $ownershipPath
        BrowserWasRunning = [bool](Test-ReleaseYandexBrowserRunning)
    }
}

function Initialize-Crx3PackageInspector {
    if ("Crx3PackageInspector" -as [type]) { return }

    $code = @'
using System;
using System.IO;
using System.Text;
using System.Security.Cryptography;
using System.Collections.Generic;

public sealed class Crx3InspectionResult
{
    public string ExtensionId { get; set; }
    public string Sha256 { get; set; }
    public bool SignatureValid { get; set; }
    public int ZipOffset { get; set; }
}

public static class Crx3PackageInspector
{
    private static ulong ReadVarint(byte[] data, ref int pos)
    {
        ulong value = 0;
        int shift = 0;
        while (true)
        {
            if (pos >= data.Length || shift > 63) throw new InvalidDataException("Invalid protobuf varint.");
            byte b = data[pos++];
            value |= ((ulong)(b & 0x7F)) << shift;
            if ((b & 0x80) == 0) return value;
            shift += 7;
        }
    }

    private static byte[] ReadLengthDelimited(byte[] data, ref int pos)
    {
        ulong n = ReadVarint(data, ref pos);
        if (n > Int32.MaxValue || pos + (int)n > data.Length) throw new InvalidDataException("Invalid protobuf length.");
        byte[] result = new byte[(int)n];
        Buffer.BlockCopy(data, pos, result, 0, (int)n);
        pos += (int)n;
        return result;
    }

    private static void SkipField(byte[] data, ref int pos, int wire)
    {
        switch (wire)
        {
            case 0: ReadVarint(data, ref pos); return;
            case 1: pos += 8; break;
            case 2:
                ulong n = ReadVarint(data, ref pos);
                if (n > Int32.MaxValue) throw new InvalidDataException("Invalid protobuf length.");
                pos += (int)n;
                break;
            case 5: pos += 4; break;
            default: throw new InvalidDataException("Unsupported protobuf wire type.");
        }
        if (pos < 0 || pos > data.Length) throw new InvalidDataException("Protobuf field exceeds message.");
    }

    private static Dictionary<int, List<byte[]>> ReadLengthFields(byte[] data)
    {
        Dictionary<int, List<byte[]>> fields = new Dictionary<int, List<byte[]>>();
        int pos = 0;
        while (pos < data.Length)
        {
            ulong key = ReadVarint(data, ref pos);
            int field = (int)(key >> 3);
            int wire = (int)(key & 7);
            if (wire == 2)
            {
                byte[] value = ReadLengthDelimited(data, ref pos);
                if (!fields.ContainsKey(field)) fields[field] = new List<byte[]>();
                fields[field].Add(value);
            }
            else
            {
                SkipField(data, ref pos, wire);
            }
        }
        return fields;
    }

    private static int ReadDerLength(byte[] data, ref int pos)
    {
        if (pos >= data.Length) throw new InvalidDataException("Invalid DER length.");
        int first = data[pos++];
        if ((first & 0x80) == 0) return first;
        int count = first & 0x7F;
        if (count == 0 || count > 4 || pos + count > data.Length) throw new InvalidDataException("Invalid DER length.");
        int length = 0;
        for (int i = 0; i < count; i++) length = (length << 8) | data[pos++];
        return length;
    }

    private static byte[] ReadDerValue(byte[] data, ref int pos, byte expectedTag)
    {
        if (pos >= data.Length || data[pos++] != expectedTag) throw new InvalidDataException("Unexpected DER tag.");
        int length = ReadDerLength(data, ref pos);
        if (length < 0 || pos + length > data.Length) throw new InvalidDataException("DER value exceeds input.");
        byte[] value = new byte[length];
        Buffer.BlockCopy(data, pos, value, 0, length);
        pos += length;
        return value;
    }

    private static byte[] TrimInteger(byte[] value)
    {
        int start = 0;
        while (start < value.Length - 1 && value[start] == 0) start++;
        byte[] result = new byte[value.Length - start];
        Buffer.BlockCopy(value, start, result, 0, result.Length);
        return result;
    }

    private static RSAParameters ParseSubjectPublicKeyInfo(byte[] spki)
    {
        int p = 0;
        byte[] outer = ReadDerValue(spki, ref p, 0x30);
        if (p != spki.Length) throw new InvalidDataException("Trailing data after public key.");

        p = 0;
        ReadDerValue(outer, ref p, 0x30); // algorithm identifier
        byte[] bitString = ReadDerValue(outer, ref p, 0x03);
        if (bitString.Length < 2 || bitString[0] != 0) throw new InvalidDataException("Invalid RSA public-key bit string.");

        byte[] rsaDer = new byte[bitString.Length - 1];
        Buffer.BlockCopy(bitString, 1, rsaDer, 0, rsaDer.Length);
        int r = 0;
        byte[] rsaSeq = ReadDerValue(rsaDer, ref r, 0x30);
        if (r != rsaDer.Length) throw new InvalidDataException("Trailing RSA public-key data.");

        r = 0;
        byte[] modulus = TrimInteger(ReadDerValue(rsaSeq, ref r, 0x02));
        byte[] exponent = TrimInteger(ReadDerValue(rsaSeq, ref r, 0x02));
        if (r != rsaSeq.Length) throw new InvalidDataException("Unexpected RSA public-key fields.");

        return new RSAParameters { Modulus = modulus, Exponent = exponent };
    }

    private static string BuildExtensionId(byte[] publicKeyDer)
    {
        byte[] hash;
        using (SHA256 sha = SHA256.Create()) hash = sha.ComputeHash(publicKeyDer);
        const string alphabet = "abcdefghijklmnop";
        StringBuilder sb = new StringBuilder(32);
        for (int i = 0; i < 16; i++)
        {
            byte b = hash[i];
            sb.Append(alphabet[(b >> 4) & 0x0F]);
            sb.Append(alphabet[b & 0x0F]);
        }
        return sb.ToString();
    }

    private static string Sha256Bytes(byte[] data)
    {
        byte[] hash;
        using (SHA256 sha = SHA256.Create()) hash = sha.ComputeHash(data);
        StringBuilder sb = new StringBuilder(64);
        foreach (byte b in hash) sb.Append(b.ToString("x2"));
        return sb.ToString();
    }

    private static byte[] Concat(params byte[][] arrays)
    {
        int total = 0;
        foreach (byte[] a in arrays) if (a != null) total += a.Length;
        byte[] result = new byte[total];
        int offset = 0;
        foreach (byte[] a in arrays)
        {
            if (a == null) continue;
            Buffer.BlockCopy(a, 0, result, offset, a.Length);
            offset += a.Length;
        }
        return result;
    }

    public static Crx3InspectionResult Inspect(string path)
    {
        byte[] all = File.ReadAllBytes(path);
        if (all.Length < 16) throw new InvalidDataException("CRX file is too short.");
        if (all[0] != (byte)'C' || all[1] != (byte)'r' || all[2] != (byte)'2' || all[3] != (byte)'4')
            throw new InvalidDataException("CRX magic is invalid.");

        UInt32 version = BitConverter.ToUInt32(all, 4);
        if (version != 3) throw new InvalidDataException("Only CRX3 is supported.");

        UInt32 headerLength = BitConverter.ToUInt32(all, 8);
        long zipOffsetLong = 12L + headerLength;
        if (headerLength == 0 || zipOffsetLong > all.Length || zipOffsetLong > Int32.MaxValue)
            throw new InvalidDataException("CRX3 header length is invalid.");

        int zipOffset = (int)zipOffsetLong;
        if (zipOffset + 2 > all.Length || all[zipOffset] != 0x50 || all[zipOffset + 1] != 0x4B)
            throw new InvalidDataException("CRX3 payload is not a ZIP archive.");

        byte[] header = new byte[(int)headerLength];
        Buffer.BlockCopy(all, 12, header, 0, header.Length);
        Dictionary<int, List<byte[]>> headerFields = ReadLengthFields(header);

        if (!headerFields.ContainsKey(2) || headerFields[2].Count < 1)
            throw new InvalidDataException("CRX3 RSA proof is missing.");
        if (!headerFields.ContainsKey(10000) || headerFields[10000].Count != 1)
            throw new InvalidDataException("CRX3 signed header data is missing or ambiguous.");

        byte[] proof = headerFields[2][0];
        Dictionary<int, List<byte[]>> proofFields = ReadLengthFields(proof);
        if (!proofFields.ContainsKey(1) || proofFields[1].Count != 1)
            throw new InvalidDataException("CRX3 public key is missing or ambiguous.");
        if (!proofFields.ContainsKey(2) || proofFields[2].Count != 1)
            throw new InvalidDataException("CRX3 signature is missing or ambiguous.");

        byte[] publicKeyDer = proofFields[1][0];
        byte[] signature = proofFields[2][0];
        byte[] signedHeaderData = headerFields[10000][0];

        Dictionary<int, List<byte[]>> signedFields = ReadLengthFields(signedHeaderData);
        if (!signedFields.ContainsKey(1) || signedFields[1].Count != 1 || signedFields[1][0].Length != 16)
            throw new InvalidDataException("CRX3 crx_id is missing or invalid.");

        byte[] keyHash;
        using (SHA256 sha = SHA256.Create()) keyHash = sha.ComputeHash(publicKeyDer);
        for (int i = 0; i < 16; i++)
            if (signedFields[1][0][i] != keyHash[i])
                throw new InvalidDataException("CRX3 crx_id does not match the public key.");

        byte[] zipBytes = new byte[all.Length - zipOffset];
        Buffer.BlockCopy(all, zipOffset, zipBytes, 0, zipBytes.Length);

        byte[] lengthLittleEndian = BitConverter.GetBytes((UInt32)signedHeaderData.Length);
        byte[] signedBlob = Concat(
            Encoding.ASCII.GetBytes("CRX3 SignedData\0"),
            lengthLittleEndian,
            signedHeaderData,
            zipBytes
        );

        bool valid;
        RSAParameters parameters = ParseSubjectPublicKeyInfo(publicKeyDer);
        CspParameters csp = new CspParameters(24);
        csp.Flags = CspProviderFlags.CreateEphemeralKey;
        using (RSACryptoServiceProvider rsa = new RSACryptoServiceProvider(csp))
        {
            rsa.PersistKeyInCsp = false;
            rsa.ImportParameters(parameters);
            valid = rsa.VerifyData(signedBlob, CryptoConfig.MapNameToOID("SHA256"), signature);
        }

        return new Crx3InspectionResult
        {
            ExtensionId = BuildExtensionId(publicKeyDer),
            Sha256 = Sha256Bytes(all),
            SignatureValid = valid,
            ZipOffset = zipOffset
        };
    }
}
'@

    try { Add-Type -TypeDefinition $code -Language CSharp }
    catch { throw ("Не удалось инициализировать CRX3 inspector: " + $_.Exception.Message) }
}
) { throw "Некорректная версия для регистрации." }

    if (-not (Test-Path -LiteralPath $BaseKey)) {
        New-Item -Path $BaseKey -Force | Out-Null
    }

    $key = Join-Path $BaseKey $ExtensionId
    $hadRegistration = Test-Path -LiteralPath $key
    $oldPath = ""
    $oldVersion = ""
    if ($hadRegistration) {
        try {
            $old = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
            $oldPath = [string]$old.path
            $oldVersion = [string]$old.version
        }
        catch { }
    }

    $browserRunning = if ($null -ne $BrowserRunningOverride) {
        [bool]$BrowserRunningOverride
    }
    else {
        Test-ReleaseYandexBrowserRunning
    }

    # Preserve the exact registration semantics of ExtensionInstaller v3.0.2:
    # never delete an existing external-extension key during install/update.
    # Deleting it is an uninstall event for a running Chromium/Yandex instance.
    # Create/update the key in place and overwrite only path/version.
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -LiteralPath $key -Name "path" -PropertyType String -Value $CrxPath -Force | Out-Null
    New-ItemProperty -LiteralPath $key -Name "version" -PropertyType String -Value $Version -Force | Out-Null

    $value = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
    if ([string]$value.path -cne $CrxPath -or [string]$value.version -cne $Version) {
        throw "Проверка записи Яндекс.Браузера после регистрации не пройдена."
    }

    return [pscustomobject]@{
        Key = $key
        HadRegistration = [bool]$hadRegistration
        BrowserRunning = [bool]$browserRunning
        InPlace = $true
        ValuesChanged = [bool]((-not $hadRegistration) -or $oldPath -cne $CrxPath -or $oldVersion -cne $Version)
    }
}

function Test-ReleaseLegacyYandexRegistration {
    param(
        $YandexValues,
        [Parameter(Mandatory = $true)]
        [string]$ExtensionId
    )

    if ($null -eq $YandexValues -or -not (Test-ReleaseExtensionId $ExtensionId)) { return $false }
    $legacyRoot = Join-Path (Join-Path (Join-Path $env:LOCALAPPDATA "UniversalExtensionBuilder") "projects") $ExtensionId
    $legacyCrxRoot = Join-Path $legacyRoot "crx"
    return (Test-PathUnderRoot ([string]$YandexValues.Path) $legacyCrxRoot)
}

function Read-ReleaseInstallState([string]$StatePath) {
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { return $null }
    try {
        return ([System.IO.File]::ReadAllText($StatePath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop)
    }
    catch { throw ("Файл состояния установки повреждён: " + $_.Exception.Message) }
}

function Write-ReleaseInstallState([string]$StatePath, $StateObject) {
    $parent = Split-Path -Parent $StatePath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $json = $StateObject | ConvertTo-Json -Depth 10
    $temp = $StatePath + ".tmp-" + [Guid]::NewGuid().ToString("N")
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($temp, $json + [Environment]::NewLine, $utf8NoBom)
        Move-Item -LiteralPath $temp -Destination $StatePath -Force
    }
    finally {
        if (Test-Path -LiteralPath $temp -PathType Leaf) {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
    }
}


function Read-ReleaseOwnershipMarker([string]$OwnershipPath) {
    if (-not (Test-Path -LiteralPath $OwnershipPath -PathType Leaf)) { return $null }
    try {
        $marker = [System.IO.File]::ReadAllText($OwnershipPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
        if ([string](Get-ReleaseProperty $marker "Schema" "") -cne "extension-installer-ownership") { return $null }
        if ([int](Get-ReleaseProperty $marker "SchemaVersion" 0) -ne 1) { return $null }
        $id = [string](Get-ReleaseProperty $marker "ExtensionId" "")
        if (-not (Test-ReleaseExtensionId $id)) { return $null }
        return $marker
    }
    catch { return $null }
}

function Write-ReleaseOwnershipMarker([string]$OwnershipPath, [string]$ExtensionId, $State, $YandexValues) {
    if (-not (Test-ReleaseExtensionId $ExtensionId)) { throw "Некорректный Extension ID для ownership marker." }

    $lastVersion = ""
    $lastCrxPath = ""
    $sourceRepository = ""

    if ($null -ne $State) {
        $lastVersion = [string](Get-ReleaseProperty $State "Version" "")
        $lastCrxPath = [string](Get-ReleaseProperty $State "CrxPath" "")
        $sourceRepository = [string](Get-ReleaseProperty $State "SourceRepository" "")
    }
    elseif ($null -ne $YandexValues) {
        $lastVersion = [string](Get-ReleaseProperty $YandexValues "Version" "")
        $lastCrxPath = [string](Get-ReleaseProperty $YandexValues "Path" "")
    }

    $marker = [pscustomobject]@{
        Schema = "extension-installer-ownership"
        SchemaVersion = 1
        ExtensionId = $ExtensionId
        LastVersion = $lastVersion
        LastCrxPath = $lastCrxPath
        SourceRepository = $sourceRepository
        RemovedUtc = [DateTime]::UtcNow.ToString("o")
    }
    Write-ReleaseInstallState $OwnershipPath $marker
    return $marker
}

function Test-PathUnderRoot([string]$PathValue, [string]$RootValue) {
    if ([string]::IsNullOrWhiteSpace($PathValue) -or [string]::IsNullOrWhiteSpace($RootValue)) { return $false }
    try {
        $full = [System.IO.Path]::GetFullPath($PathValue)
        $root = [System.IO.Path]::GetFullPath($RootValue)
        if (-not $root.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString())) {
            $root += [System.IO.Path]::DirectorySeparatorChar
        }
        return $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)
    }
    catch { return $false }
}

function Install-ValidatedSignedRelease($ResolvedRelease, [string]$InstallRoot) {
    if ($null -eq $ResolvedRelease) { throw "Release не разрешён." }
    if ([string]::IsNullOrWhiteSpace($InstallRoot)) { throw "Не задана служебная папка установки." }

    $extensionId = [string](Get-ReleaseProperty $ResolvedRelease "ExtensionId" "")
    $version = [string](Get-ReleaseProperty $ResolvedRelease "Version" "")
    $crxPath = [string](Get-ReleaseProperty $ResolvedRelease "CrxPath" "")
    $sha = ([string](Get-ReleaseProperty $ResolvedRelease "Sha256" "")).ToLowerInvariant()
    $repository = [string](Get-ReleaseProperty $ResolvedRelease "Repository" "")
    $releaseTag = [string](Get-ReleaseProperty $ResolvedRelease "ReleaseTag" "")
    $releaseUrl = [string](Get-ReleaseProperty $ResolvedRelease "ReleaseUrl" "")

    if (-not (Test-ReleaseExtensionId $extensionId)) { throw "Resolved release содержит некорректный Extension ID." }
    if ($version -notmatch '^\d+(\.\d+){0,3}$') { throw "Resolved release содержит некорректную версию." }
    if (-not (Test-Path -LiteralPath $crxPath -PathType Leaf)) { throw "Проверенный CRX не найден." }
    if ($sha -notmatch '^[0-9a-f]{64}$') { throw "Resolved release содержит некорректный SHA-256." }
    if ((Get-ReleaseFileSha256 $crxPath) -cne $sha) { throw "CRX изменился после проверки release." }

    Initialize-Crx3PackageInspector
    $inspection = [Crx3PackageInspector]::Inspect($crxPath)
    if (-not $inspection.SignatureValid) { throw "CRX3 signature verification failed перед установкой." }
    if ([string]$inspection.ExtensionId -cne $extensionId) { throw "Extension ID внутри CRX изменился перед установкой." }

    $extensionRoot = Join-Path $InstallRoot $extensionId
    $crxRoot = Join-Path $extensionRoot "crx"
    $statePath = Join-Path $extensionRoot "state.json"
    $ownershipPath = Join-Path $extensionRoot "ownership.json"
    if (-not (Test-Path -LiteralPath $crxRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $crxRoot -Force | Out-Null
    }

    $fileName = $extensionId + "-" + $version + "-" + $sha.Substring(0,12) + ".crx"
    $installedCrxPath = Join-Path $crxRoot $fileName
    $yandexKey = Join-Path "HKCU:\Software\Yandex\YandexBrowser\Extensions" $extensionId
    $oldState = Read-ReleaseInstallState $statePath
    $oldYandex = Get-ReleaseYandexValues $extensionId
    $legacyRegistration = ($null -ne $oldYandex -and (Test-ReleaseLegacyYandexRegistration $oldYandex $extensionId))

    if ($null -eq $oldState -and $null -ne $oldYandex -and -not (Test-PathUnderRoot $oldYandex.Path $crxRoot) -and -not $legacyRegistration) {
        throw "Этот Extension ID уже зарегистрирован, но текущая запись не принадлежит ExtensionInstaller."
    }
    if ($null -ne $oldState -and $null -ne $oldYandex -and $oldYandex.Path -cne [string]$oldState.CrxPath) {
        throw "Текущая запись Яндекс.Браузера расходится с сохранённым состоянием; установка остановлена."
    }

    if (Test-Path -LiteralPath $installedCrxPath -PathType Leaf) {
        if ((Get-ReleaseFileSha256 $installedCrxPath) -cne $sha) {
            throw "Целевой CRX уже существует, но имеет другой SHA-256."
        }
    }
    else {
        Copy-Item -LiteralPath $crxPath -Destination $installedCrxPath -Force
    }

    $preferenceBackups = @()
    $browserRunning = Test-ReleaseYandexBrowserRunning
    try {
        # When Yandex is closed we can safely clear a persisted user-uninstall marker
        # before the next browser start. When it is running, never edit Preferences
        # behind its back: the fresh registry registration below is delivered through
        # Chromium's live external-registry watcher and the browser owns its prefs.
        if (-not $browserRunning) {
            $preferenceBackups = @(Remove-ReleaseYandexExternalUninstallMarker $extensionId)
        }

        $registration = Set-ReleaseYandexRegistrationFresh -ExtensionId $extensionId -CrxPath $installedCrxPath -Version $version -BrowserRunningOverride $browserRunning

        $verify = Get-ReleaseYandexValues $extensionId
        if ($null -eq $verify -or $verify.Path -cne $installedCrxPath -or $verify.Version -cne $version) {
            throw "Проверка записи Яндекс.Браузера после установки не пройдена."
        }

        $newState = [pscustomobject]@{
            Schema = "extension-installer-state"
            SchemaVersion = 1
            ExtensionId = $extensionId
            Version = $version
            CrxPath = $installedCrxPath
            Sha256 = $sha
            SourceRepository = $repository
            ReleaseTag = $releaseTag
            ReleaseUrl = $releaseUrl
            InstalledUtc = [DateTime]::UtcNow.ToString("o")
        }
        Write-ReleaseInstallState $statePath $newState
        if (Test-Path -LiteralPath $ownershipPath -PathType Leaf) {
            Remove-Item -LiteralPath $ownershipPath -Force -ErrorAction SilentlyContinue
        }

        if ($null -ne $oldState) {
            $previous = [string]$oldState.CrxPath
            if (-not [string]::IsNullOrWhiteSpace($previous) -and $previous -cne $installedCrxPath -and (Test-Path -LiteralPath $previous -PathType Leaf)) {
                Remove-Item -LiteralPath $previous -Force -ErrorAction SilentlyContinue
            }
        }

        foreach ($oldFile in @(Get-ChildItem -LiteralPath $crxRoot -Filter "*.crx" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -cne $installedCrxPath })) {
            Remove-Item -LiteralPath $oldFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        $reason = $_.Exception.Message
        if ($preferenceBackups.Count -gt 0) {
            try { Restore-ReleaseYandexPreferenceBackups $preferenceBackups } catch { }
        }

        if ($null -ne $oldYandex) {
            New-Item -Path $oldYandex.Key -Force | Out-Null
            New-ItemProperty -LiteralPath $oldYandex.Key -Name "path" -PropertyType String -Value $oldYandex.Path -Force | Out-Null
            New-ItemProperty -LiteralPath $oldYandex.Key -Name "version" -PropertyType String -Value $oldYandex.Version -Force | Out-Null
        }
        elseif (Test-Path -LiteralPath $yandexKey) {
            Remove-Item -LiteralPath $yandexKey -Recurse -Force -ErrorAction SilentlyContinue
        }

        if ((Test-Path -LiteralPath $installedCrxPath -PathType Leaf) -and ($null -eq $oldState -or [string]$oldState.CrxPath -cne $installedCrxPath)) {
            Remove-Item -LiteralPath $installedCrxPath -Force -ErrorAction SilentlyContinue
        }
        throw ("Установка release CRX не выполнена. Rollback завершён. Причина: " + $reason)
    }

    return [pscustomobject]@{
        Version = $version
        ExtensionId = $extensionId
        CrxPath = $installedCrxPath
        Sha256 = $sha
        MigratedLegacyRegistration = $legacyRegistration
        BrowserWasRunning = [bool]$browserRunning
        RegistrationPulsed = [bool](Get-ReleaseProperty $registration "Pulsed" $false)
    }
}

function Uninstall-ReleaseExtension([string]$ExtensionId, [string]$InstallRoot) {
    if (-not (Test-ReleaseExtensionId $ExtensionId)) { throw "Некорректный Extension ID." }
    if ([string]::IsNullOrWhiteSpace($InstallRoot)) { throw "Не задана служебная папка установки." }

    $extensionRoot = Join-Path $InstallRoot $ExtensionId
    $crxRoot = Join-Path $extensionRoot "crx"
    $statePath = Join-Path $extensionRoot "state.json"
    $ownershipPath = Join-Path $extensionRoot "ownership.json"
    $state = Read-ReleaseInstallState $statePath
    $y = Get-ReleaseYandexValues $ExtensionId
    $legacyRegistration = ($null -ne $y -and (Test-ReleaseLegacyYandexRegistration $y $ExtensionId))

    if ($null -ne $y) {
        if ($null -ne $state) {
            if ($y.Path -cne [string]$state.CrxPath) {
                throw "Путь в реестре Яндекс.Браузера отличается от сохранённого состояния; удаление остановлено."
            }
        }
        elseif (-not (Test-PathUnderRoot $y.Path $crxRoot) -and -not $legacyRegistration) {
            throw "Запись Яндекс.Браузера не принадлежит ExtensionInstaller; удаление остановлено."
        }
    }

    # Persist durable ownership evidence before deleting the active registration/state.
    # A running Chromium/Yandex process can retain its profile entry for a while after
    # the external registry key disappears. Without this marker the next refresh could
    # misclassify our own just-removed extension as foreign.
    if ($null -ne $state -or $null -ne $y) {
        if (-not (Test-Path -LiteralPath $extensionRoot -PathType Container)) {
            New-Item -ItemType Directory -Path $extensionRoot -Force | Out-Null
        }
        Write-ReleaseOwnershipMarker $ownershipPath $ExtensionId $state $y | Out-Null
    }

    if ($null -ne $y) {
        Remove-Item -LiteralPath $y.Key -Recurse -Force
    }

    if (Test-Path -LiteralPath $crxRoot -PathType Container) {
        Remove-Item -LiteralPath $crxRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        Remove-Item -LiteralPath $statePath -Force
    }

    return [pscustomobject]@{
        ExtensionId = $ExtensionId
        OwnershipPath = $ownershipPath
        BrowserWasRunning = [bool](Test-ReleaseYandexBrowserRunning)
    }
}

function Initialize-Crx3PackageInspector {
    if ("Crx3PackageInspector" -as [type]) { return }

    $code = @'
using System;
using System.IO;
using System.Text;
using System.Security.Cryptography;
using System.Collections.Generic;

public sealed class Crx3InspectionResult
{
    public string ExtensionId { get; set; }
    public string Sha256 { get; set; }
    public bool SignatureValid { get; set; }
    public int ZipOffset { get; set; }
}

public static class Crx3PackageInspector
{
    private static ulong ReadVarint(byte[] data, ref int pos)
    {
        ulong value = 0;
        int shift = 0;
        while (true)
        {
            if (pos >= data.Length || shift > 63) throw new InvalidDataException("Invalid protobuf varint.");
            byte b = data[pos++];
            value |= ((ulong)(b & 0x7F)) << shift;
            if ((b & 0x80) == 0) return value;
            shift += 7;
        }
    }

    private static byte[] ReadLengthDelimited(byte[] data, ref int pos)
    {
        ulong n = ReadVarint(data, ref pos);
        if (n > Int32.MaxValue || pos + (int)n > data.Length) throw new InvalidDataException("Invalid protobuf length.");
        byte[] result = new byte[(int)n];
        Buffer.BlockCopy(data, pos, result, 0, (int)n);
        pos += (int)n;
        return result;
    }

    private static void SkipField(byte[] data, ref int pos, int wire)
    {
        switch (wire)
        {
            case 0: ReadVarint(data, ref pos); return;
            case 1: pos += 8; break;
            case 2:
                ulong n = ReadVarint(data, ref pos);
                if (n > Int32.MaxValue) throw new InvalidDataException("Invalid protobuf length.");
                pos += (int)n;
                break;
            case 5: pos += 4; break;
            default: throw new InvalidDataException("Unsupported protobuf wire type.");
        }
        if (pos < 0 || pos > data.Length) throw new InvalidDataException("Protobuf field exceeds message.");
    }

    private static Dictionary<int, List<byte[]>> ReadLengthFields(byte[] data)
    {
        Dictionary<int, List<byte[]>> fields = new Dictionary<int, List<byte[]>>();
        int pos = 0;
        while (pos < data.Length)
        {
            ulong key = ReadVarint(data, ref pos);
            int field = (int)(key >> 3);
            int wire = (int)(key & 7);
            if (wire == 2)
            {
                byte[] value = ReadLengthDelimited(data, ref pos);
                if (!fields.ContainsKey(field)) fields[field] = new List<byte[]>();
                fields[field].Add(value);
            }
            else
            {
                SkipField(data, ref pos, wire);
            }
        }
        return fields;
    }

    private static int ReadDerLength(byte[] data, ref int pos)
    {
        if (pos >= data.Length) throw new InvalidDataException("Invalid DER length.");
        int first = data[pos++];
        if ((first & 0x80) == 0) return first;
        int count = first & 0x7F;
        if (count == 0 || count > 4 || pos + count > data.Length) throw new InvalidDataException("Invalid DER length.");
        int length = 0;
        for (int i = 0; i < count; i++) length = (length << 8) | data[pos++];
        return length;
    }

    private static byte[] ReadDerValue(byte[] data, ref int pos, byte expectedTag)
    {
        if (pos >= data.Length || data[pos++] != expectedTag) throw new InvalidDataException("Unexpected DER tag.");
        int length = ReadDerLength(data, ref pos);
        if (length < 0 || pos + length > data.Length) throw new InvalidDataException("DER value exceeds input.");
        byte[] value = new byte[length];
        Buffer.BlockCopy(data, pos, value, 0, length);
        pos += length;
        return value;
    }

    private static byte[] TrimInteger(byte[] value)
    {
        int start = 0;
        while (start < value.Length - 1 && value[start] == 0) start++;
        byte[] result = new byte[value.Length - start];
        Buffer.BlockCopy(value, start, result, 0, result.Length);
        return result;
    }

    private static RSAParameters ParseSubjectPublicKeyInfo(byte[] spki)
    {
        int p = 0;
        byte[] outer = ReadDerValue(spki, ref p, 0x30);
        if (p != spki.Length) throw new InvalidDataException("Trailing data after public key.");

        p = 0;
        ReadDerValue(outer, ref p, 0x30); // algorithm identifier
        byte[] bitString = ReadDerValue(outer, ref p, 0x03);
        if (bitString.Length < 2 || bitString[0] != 0) throw new InvalidDataException("Invalid RSA public-key bit string.");

        byte[] rsaDer = new byte[bitString.Length - 1];
        Buffer.BlockCopy(bitString, 1, rsaDer, 0, rsaDer.Length);
        int r = 0;
        byte[] rsaSeq = ReadDerValue(rsaDer, ref r, 0x30);
        if (r != rsaDer.Length) throw new InvalidDataException("Trailing RSA public-key data.");

        r = 0;
        byte[] modulus = TrimInteger(ReadDerValue(rsaSeq, ref r, 0x02));
        byte[] exponent = TrimInteger(ReadDerValue(rsaSeq, ref r, 0x02));
        if (r != rsaSeq.Length) throw new InvalidDataException("Unexpected RSA public-key fields.");

        return new RSAParameters { Modulus = modulus, Exponent = exponent };
    }

    private static string BuildExtensionId(byte[] publicKeyDer)
    {
        byte[] hash;
        using (SHA256 sha = SHA256.Create()) hash = sha.ComputeHash(publicKeyDer);
        const string alphabet = "abcdefghijklmnop";
        StringBuilder sb = new StringBuilder(32);
        for (int i = 0; i < 16; i++)
        {
            byte b = hash[i];
            sb.Append(alphabet[(b >> 4) & 0x0F]);
            sb.Append(alphabet[b & 0x0F]);
        }
        return sb.ToString();
    }

    private static string Sha256Bytes(byte[] data)
    {
        byte[] hash;
        using (SHA256 sha = SHA256.Create()) hash = sha.ComputeHash(data);
        StringBuilder sb = new StringBuilder(64);
        foreach (byte b in hash) sb.Append(b.ToString("x2"));
        return sb.ToString();
    }

    private static byte[] Concat(params byte[][] arrays)
    {
        int total = 0;
        foreach (byte[] a in arrays) if (a != null) total += a.Length;
        byte[] result = new byte[total];
        int offset = 0;
        foreach (byte[] a in arrays)
        {
            if (a == null) continue;
            Buffer.BlockCopy(a, 0, result, offset, a.Length);
            offset += a.Length;
        }
        return result;
    }

    public static Crx3InspectionResult Inspect(string path)
    {
        byte[] all = File.ReadAllBytes(path);
        if (all.Length < 16) throw new InvalidDataException("CRX file is too short.");
        if (all[0] != (byte)'C' || all[1] != (byte)'r' || all[2] != (byte)'2' || all[3] != (byte)'4')
            throw new InvalidDataException("CRX magic is invalid.");

        UInt32 version = BitConverter.ToUInt32(all, 4);
        if (version != 3) throw new InvalidDataException("Only CRX3 is supported.");

        UInt32 headerLength = BitConverter.ToUInt32(all, 8);
        long zipOffsetLong = 12L + headerLength;
        if (headerLength == 0 || zipOffsetLong > all.Length || zipOffsetLong > Int32.MaxValue)
            throw new InvalidDataException("CRX3 header length is invalid.");

        int zipOffset = (int)zipOffsetLong;
        if (zipOffset + 2 > all.Length || all[zipOffset] != 0x50 || all[zipOffset + 1] != 0x4B)
            throw new InvalidDataException("CRX3 payload is not a ZIP archive.");

        byte[] header = new byte[(int)headerLength];
        Buffer.BlockCopy(all, 12, header, 0, header.Length);
        Dictionary<int, List<byte[]>> headerFields = ReadLengthFields(header);

        if (!headerFields.ContainsKey(2) || headerFields[2].Count < 1)
            throw new InvalidDataException("CRX3 RSA proof is missing.");
        if (!headerFields.ContainsKey(10000) || headerFields[10000].Count != 1)
            throw new InvalidDataException("CRX3 signed header data is missing or ambiguous.");

        byte[] proof = headerFields[2][0];
        Dictionary<int, List<byte[]>> proofFields = ReadLengthFields(proof);
        if (!proofFields.ContainsKey(1) || proofFields[1].Count != 1)
            throw new InvalidDataException("CRX3 public key is missing or ambiguous.");
        if (!proofFields.ContainsKey(2) || proofFields[2].Count != 1)
            throw new InvalidDataException("CRX3 signature is missing or ambiguous.");

        byte[] publicKeyDer = proofFields[1][0];
        byte[] signature = proofFields[2][0];
        byte[] signedHeaderData = headerFields[10000][0];

        Dictionary<int, List<byte[]>> signedFields = ReadLengthFields(signedHeaderData);
        if (!signedFields.ContainsKey(1) || signedFields[1].Count != 1 || signedFields[1][0].Length != 16)
            throw new InvalidDataException("CRX3 crx_id is missing or invalid.");

        byte[] keyHash;
        using (SHA256 sha = SHA256.Create()) keyHash = sha.ComputeHash(publicKeyDer);
        for (int i = 0; i < 16; i++)
            if (signedFields[1][0][i] != keyHash[i])
                throw new InvalidDataException("CRX3 crx_id does not match the public key.");

        byte[] zipBytes = new byte[all.Length - zipOffset];
        Buffer.BlockCopy(all, zipOffset, zipBytes, 0, zipBytes.Length);

        byte[] lengthLittleEndian = BitConverter.GetBytes((UInt32)signedHeaderData.Length);
        byte[] signedBlob = Concat(
            Encoding.ASCII.GetBytes("CRX3 SignedData\0"),
            lengthLittleEndian,
            signedHeaderData,
            zipBytes
        );

        bool valid;
        RSAParameters parameters = ParseSubjectPublicKeyInfo(publicKeyDer);
        CspParameters csp = new CspParameters(24);
        csp.Flags = CspProviderFlags.CreateEphemeralKey;
        using (RSACryptoServiceProvider rsa = new RSACryptoServiceProvider(csp))
        {
            rsa.PersistKeyInCsp = false;
            rsa.ImportParameters(parameters);
            valid = rsa.VerifyData(signedBlob, CryptoConfig.MapNameToOID("SHA256"), signature);
        }

        return new Crx3InspectionResult
        {
            ExtensionId = BuildExtensionId(publicKeyDer),
            Sha256 = Sha256Bytes(all),
            SignatureValid = valid,
            ZipOffset = zipOffset
        };
    }
}
'@

    try { Add-Type -TypeDefinition $code -Language CSharp }
    catch { throw ("Не удалось инициализировать CRX3 inspector: " + $_.Exception.Message) }
}
