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
    param([string]$ExtensionId, [string]$UserDataRoot = "")
    if (-not (Test-ReleaseExtensionId $ExtensionId)) { throw "Некорректный Extension ID." }
    if ([string]::IsNullOrWhiteSpace($UserDataRoot)) { $UserDataRoot = Get-ReleaseYandexUserDataRoot }
    if (-not (Test-Path -LiteralPath $UserDataRoot -PathType Container)) { return @() }

    $result = @()
    foreach ($profile in @(Get-ChildItem -LiteralPath $UserDataRoot -Directory -Force -ErrorAction SilentlyContinue)) {
        $root = Join-Path (Join-Path $profile.FullName "Extensions") $ExtensionId
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        foreach ($dir in @(Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue)) {
            $name = [string]$dir.Name
            if ($name -notmatch '^(\d+(?:\.\d+){0,3})(?:_\d+)?
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
    try {
        $preferenceBackups = @(Remove-ReleaseYandexExternalUninstallMarker $extensionId)
        New-Item -Path $yandexKey -Force | Out-Null
        New-ItemProperty -LiteralPath $yandexKey -Name "path" -PropertyType String -Value $installedCrxPath -Force | Out-Null
        New-ItemProperty -LiteralPath $yandexKey -Name "version" -PropertyType String -Value $version -Force | Out-Null

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
    }
}

function Uninstall-ReleaseExtension([string]$ExtensionId, [string]$InstallRoot) {
    if (-not (Test-ReleaseExtensionId $ExtensionId)) { throw "Некорректный Extension ID." }
    if ([string]::IsNullOrWhiteSpace($InstallRoot)) { throw "Не задана служебная папка установки." }

    $extensionRoot = Join-Path $InstallRoot $ExtensionId
    $crxRoot = Join-Path $extensionRoot "crx"
    $statePath = Join-Path $extensionRoot "state.json"
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
        Remove-Item -LiteralPath $y.Key -Recurse -Force
    }

    if (Test-Path -LiteralPath $extensionRoot -PathType Container) {
        Remove-Item -LiteralPath $extensionRoot -Recurse -Force
    }
    return $ExtensionId
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
) { continue }
            $result += [pscustomobject]@{ Profile = [string]$profile.Name; Version = [string]$Matches[1]; Path = [string]$dir.FullName }
        }
    }
    return @($result)
}

function Get-ReleaseYandexExternalUninstallProfiles {
    param([string]$ExtensionId, [string]$UserDataRoot = "")
    if (-not (Test-ReleaseExtensionId $ExtensionId)) { throw "Некорректный Extension ID." }
    if ([string]::IsNullOrWhiteSpace($UserDataRoot)) { $UserDataRoot = Get-ReleaseYandexUserDataRoot }
    if (-not (Test-Path -LiteralPath $UserDataRoot -PathType Container)) { return @() }

    $result = @()
    foreach ($profile in @(Get-ChildItem -LiteralPath $UserDataRoot -Directory -Force -ErrorAction SilentlyContinue)) {
        $path = Join-Path $profile.FullName "Preferences"
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        try {
            $prefs = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
            $extensions = Get-ReleaseProperty $prefs "extensions" $null
            $items = @(Get-ReleaseProperty $extensions "external_uninstalls" $null)
            if (@($items | Where-Object { [string]$_ -ceq $ExtensionId }).Count -gt 0) {
                $result += [pscustomobject]@{ Profile = [string]$profile.Name; PreferencesPath = $path }
            }
        }
        catch { }
    }
    return @($result)
}

function Test-ReleaseYandexBrowserRunning {
    foreach ($p in @(Get-Process -Name "browser" -ErrorAction SilentlyContinue)) {
        try {
            $path = [string]$p.Path
            if ([string]::IsNullOrWhiteSpace($path)) { return $true }
            if ($path.IndexOf("\Yandex\YandexBrowser\", [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
        }
        catch { return $true }
    }
    return $false
}

function Restore-ReleaseYandexPreferenceBackups($Backups) {
    foreach ($b in @($Backups)) {
        $path = [string](Get-ReleaseProperty $b "Path" "")
        $bytes = Get-ReleaseProperty $b "Bytes" $null
        if ([string]::IsNullOrWhiteSpace($path) -or $null -eq $bytes) { continue }
        [System.IO.File]::WriteAllBytes($path, [byte[]]$bytes)
    }
}

function Remove-ReleaseYandexExternalUninstallMarker {
    param([string]$ExtensionId, [string]$UserDataRoot = "")
    $profiles = @(Get-ReleaseYandexExternalUninstallProfiles $ExtensionId $UserDataRoot)
    if ($profiles.Count -eq 0) { return @() }
    if (Test-ReleaseYandexBrowserRunning) {
        throw "Расширение было удалено через Яндекс.Браузер. Полностью закройте Яндекс.Браузер и повторите установку."
    }

    $backups = @()
    try {
        foreach ($profile in $profiles) {
            $path = [string]$profile.PreferencesPath
            $bytes = [System.IO.File]::ReadAllBytes($path)
            $textValue = [System.Text.Encoding]::UTF8.GetString($bytes)
            if ($textValue.Length -gt 0 -and [int]$textValue[0] -eq 0xFEFF) { $textValue = $textValue.Substring(1) }

            $m = [regex]::Match($textValue, '"external_uninstalls"\s*:\s*\[(?<body>[^\]]*)\]')
            if (-not $m.Success) { throw ("Не найдена блокировка повторной установки в профиле " + [string]$profile.Profile + ".") }

            $oldBody = [string]$m.Groups["body"].Value
            $wanted = '"' + $ExtensionId + '"'
            $parts = @($oldBody -split ',')
            $kept = @($parts | Where-Object { $_.Trim() -cne $wanted })
            if ($kept.Count -eq $parts.Count) { throw ("Не найдена блокировка Extension ID в профиле " + [string]$profile.Profile + ".") }

            $newBody = $kept -join ','
            $left = $m.Value.Substring(0, $m.Value.IndexOf('[') + 1)
            $replacement = $left + $newBody + ']'
            $newText = $textValue.Substring(0, $m.Index) + $replacement + $textValue.Substring($m.Index + $m.Length)

            $backups += [pscustomobject]@{ Path = $path; Bytes = $bytes }
            $utf8 = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($path, $newText, $utf8)
        }
    }
    catch {
        Restore-ReleaseYandexPreferenceBackups $backups
        throw
    }
    return @($backups)
}

function Test-ReleaseLegacyYandexRegistration($YandexValues, [string]$ExtensionId) {
    if ($null -eq $YandexValues -or -not (Test-ReleaseExtensionId $ExtensionId)) { return $false }
    $legacy = Join-Path (Join-Path (Join-Path (Join-Path $env:LOCALAPPDATA "UniversalExtensionBuilder") "projects") $ExtensionId) "crx"
    return (Test-PathUnderRoot ([string]$YandexValues.Path) $legacy)
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
    if (-not (Test-Path -LiteralPath $crxRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $crxRoot -Force | Out-Null
    }

    $fileName = $extensionId + "-" + $version + "-" + $sha.Substring(0,12) + ".crx"
    $installedCrxPath = Join-Path $crxRoot $fileName
    $yandexKey = Join-Path "HKCU:\Software\Yandex\YandexBrowser\Extensions" $extensionId
    $oldState = Read-ReleaseInstallState $statePath
    $oldYandex = Get-ReleaseYandexValues $extensionId

    if ($null -eq $oldState -and $null -ne $oldYandex -and -not (Test-PathUnderRoot $oldYandex.Path $crxRoot)) {
        throw "Этот Extension ID уже зарегистрирован, но текущая запись не принадлежит release-installer."
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

    try {
        New-Item -Path $yandexKey -Force | Out-Null
        New-ItemProperty -LiteralPath $yandexKey -Name "path" -PropertyType String -Value $installedCrxPath -Force | Out-Null
        New-ItemProperty -LiteralPath $yandexKey -Name "version" -PropertyType String -Value $version -Force | Out-Null

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
    }
}

function Uninstall-ReleaseExtension([string]$ExtensionId, [string]$InstallRoot) {
    if (-not (Test-ReleaseExtensionId $ExtensionId)) { throw "Некорректный Extension ID." }
    if ([string]::IsNullOrWhiteSpace($InstallRoot)) { throw "Не задана служебная папка установки." }

    $extensionRoot = Join-Path $InstallRoot $ExtensionId
    $crxRoot = Join-Path $extensionRoot "crx"
    $statePath = Join-Path $extensionRoot "state.json"
    $state = Read-ReleaseInstallState $statePath
    $y = Get-ReleaseYandexValues $ExtensionId

    if ($null -ne $y) {
        if ($null -ne $state) {
            if ($y.Path -cne [string]$state.CrxPath) {
                throw "Путь в реестре Яндекс.Браузера отличается от сохранённого состояния; удаление остановлено."
            }
        }
        elseif (-not (Test-PathUnderRoot $y.Path $crxRoot)) {
            throw "Запись Яндекс.Браузера указывает за пределы служебной папки; удаление остановлено."
        }
        Remove-Item -LiteralPath $y.Key -Recurse -Force
    }

    if (Test-Path -LiteralPath $extensionRoot -PathType Container) {
        Remove-Item -LiteralPath $extensionRoot -Recurse -Force
    }
    return $ExtensionId
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
