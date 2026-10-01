@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "EXTINSTALLER_SELF=%~f0"
set "EXTINSTALLER_PS1=%TEMP%\ExtensionInstaller_%RANDOM%_%RANDOM%.ps1"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$self=$env:EXTINSTALLER_SELF; $out=$env:EXTINSTALLER_PS1; try { Unblock-File -LiteralPath $self -ErrorAction Stop } catch { }; $text=[System.IO.File]::ReadAllText($self,[System.Text.Encoding]::UTF8); $marker='### POWERSHELL_'+'PAYLOAD ###'; $i=$text.IndexOf($marker); if($i -lt 0){exit 11}; $payload=$text.Substring($i+$marker.Length); [System.IO.File]::WriteAllText($out,$payload,(New-Object System.Text.UTF8Encoding($true)))" >nul 2>nul

if errorlevel 1 (
    powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -Command "Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show('Не удалось запустить Установщик расширений. Встроенная PowerShell-часть повреждена или недоступна.','Установщик расширений',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)"
    exit /b 11
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%EXTINSTALLER_PS1%"
set "EXTINSTALLER_RC=%ERRORLEVEL%"

del /f /q "%EXTINSTALLER_PS1%" >nul 2>nul

if "%EXTINSTALLER_RC%"=="100" exit /b 0
if not "%EXTINSTALLER_RC%"=="0" powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -Command "Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show('Установщик расширений завершился с ошибкой. Код: %EXTINSTALLER_RC%.','Установщик расширений',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)"
exit /b %EXTINSTALLER_RC%

### POWERSHELL_PAYLOAD ###
$ErrorActionPreference = "Stop"
$YandexBaseKey = "HKCU:\Software\Yandex\YandexBrowser\Extensions"
$LegacyBaseRoot = Join-Path $env:LOCALAPPDATA "UniversalExtensionBuilder"
$AppRoot = Join-Path $env:LOCALAPPDATA "ExtensionInstaller"
$ProjectsRoot = Join-Path $LegacyBaseRoot "projects"
$SettingsPath = Join-Path $AppRoot "settings.json"
$LogRoot = Join-Path $AppRoot "logs"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
try { [Console]::OutputEncoding = $Utf8NoBom; $OutputEncoding = $Utf8NoBom } catch { }

if (-not (Test-Path -LiteralPath $AppRoot)) { New-Item -ItemType Directory -Path $AppRoot -Force | Out-Null }
if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null }
if (-not (Test-Path -LiteralPath $ProjectsRoot)) { New-Item -ItemType Directory -Path $ProjectsRoot -Force | Out-Null }

$script:SessionStarted = Get-Date
$script:SessionLogPath = Join-Path $LogRoot ("installer-" + $script:SessionStarted.ToString("yyyyMMdd-HHmmss") + ".txt")
$script:CurrentRoot = ""
$script:CurrentExtensionFolder = ""
$script:CurrentPackage = $null
$script:EnablePanelVisible = $false
$script:ExtensionFolderMap = @{}
$script:BuilderPath = [string]$env:EXTINSTALLER_SELF
if ([string]::IsNullOrWhiteSpace($script:BuilderPath) -or -not (Test-Path -LiteralPath $script:BuilderPath -PathType Leaf)) {
    $script:BuilderDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
}
else {
    $script:BuilderDirectory = Split-Path -Parent $script:BuilderPath
}

function Write-Log([string]$Level, [string]$Message) {
    $line = "{0} [{1}] {2}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"), $Level.ToUpperInvariant(), $Message
    try { [System.IO.File]::AppendAllText($script:SessionLogPath, $line + "`r`n", $Utf8NoBom) } catch { }
}

function Write-LogException([string]$Context, $ErrorRecord) {
    Write-Log "ERROR" ($Context + ": " + $ErrorRecord.Exception.Message)
    try { Write-Log "ERROR" ($ErrorRecord.Exception.ToString()) } catch { }
    try { if ($ErrorRecord.ScriptStackTrace) { Write-Log "ERROR" ("Stack: " + $ErrorRecord.ScriptStackTrace) } } catch { }
}

Write-Log "INFO" "Запуск Установщика расширений."
Write-Log "INFO" ("Лог сеанса: " + $script:SessionLogPath)
Write-Log "INFO" ("Папка установщика: " + $script:BuilderDirectory)

function Get-PropertyValue($Object, [string]$Name, $DefaultValue) {
    if ($null -eq $Object) { return $DefaultValue }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $DefaultValue }
    return $property.Value
}

function Get-FileSha256([string]$PathValue) {
    return (Get-FileHash -LiteralPath $PathValue -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Is-ValidExtensionId([string]$Id) {
    return (-not [string]::IsNullOrWhiteSpace($Id) -and $Id -match '^[a-p]{32}$')
}

function Path-Is-InRoot([string]$PathValue, [string]$RootValue) {
    if ([string]::IsNullOrWhiteSpace($PathValue) -or [string]::IsNullOrWhiteSpace($RootValue)) { return $false }
    try {
        $full = [System.IO.Path]::GetFullPath($PathValue)
        $rootFull = [System.IO.Path]::GetFullPath($RootValue)
        if (-not $rootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString())) { $rootFull += [System.IO.Path]::DirectorySeparatorChar }
        return $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)
    }
    catch { return $false }
}

function Read-State([string]$StatePath) {
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { return $null }
    try { return ([System.IO.File]::ReadAllText($StatePath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop) }
    catch { throw ("Файл состояния поврежден: " + $_.Exception.Message) }
}

function Write-State([string]$StatePath, $StateObject) {
    $json = $StateObject | ConvertTo-Json -Depth 10
    $temp = $StatePath + ".tmp"
    [System.IO.File]::WriteAllText($temp, $json + "`r`n", $Utf8NoBom)
    Move-Item -LiteralPath $temp -Destination $StatePath -Force
}

function Get-YandexValues([string]$ExtensionId) {
    $key = Join-Path $YandexBaseKey $ExtensionId
    if (-not (Test-Path -LiteralPath $key)) { return $null }
    $value = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
    return [pscustomobject]@{ Key = $key; Path = [string]$value.path; Version = [string]$value.version }
}

function Read-Settings {
    if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) { return $null }
    try { return ([System.IO.File]::ReadAllText($SettingsPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop) }
    catch { Write-LogException "Не удалось прочитать настройки" $_; return $null }
}

function Save-Settings([string]$RootFolder) {
    try {
        $obj = [pscustomobject]@{ ExtensionsRoot = $RootFolder }
        [System.IO.File]::WriteAllText($SettingsPath, (($obj | ConvertTo-Json -Depth 5) + "`r`n"), $Utf8NoBom)
        Write-Log "INFO" ("Сохранена папка библиотеки расширений: " + $RootFolder)
    }
    catch { Write-LogException "Не удалось сохранить настройки" $_ }
}

function Get-ExtensionFolders([string]$RootFolder) {
    if ([string]::IsNullOrWhiteSpace($RootFolder) -or -not (Test-Path -LiteralPath $RootFolder -PathType Container)) { return }
    foreach ($dir in (Get-ChildItem -LiteralPath $RootFolder -Directory -Force -ErrorAction Stop | Sort-Object -Property Name)) {
        $zip = Get-ChildItem -LiteralPath $dir.FullName -Filter "*.zip" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $zip) {
            [pscustomobject]@{
                Name = [string]$dir.Name
                Path = [string]$dir.FullName
            }
        }
    }
}

function Get-LatestZip([string]$ExtensionFolder) {
    if ([string]::IsNullOrWhiteSpace($ExtensionFolder) -or -not (Test-Path -LiteralPath $ExtensionFolder -PathType Container)) { throw "Папка расширения не найдена." }
    $zips = @(Get-ChildItem -LiteralPath $ExtensionFolder -Filter "*.zip" -File -ErrorAction Stop | Sort-Object -Property @{Expression="LastWriteTimeUtc"; Descending=$true}, @{Expression="Name"; Descending=$true})
    if ($zips.Count -eq 0) { throw "В папке расширения нет ZIP-архивов." }
    return $zips[0]
}

function Read-ManifestFromZip([string]$ZipPath) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entries = @($archive.Entries | Where-Object { $_.Name -ieq "manifest.json" })
        if ($entries.Count -eq 0) { throw "В ZIP отсутствует manifest.json." }
        if ($entries.Count -gt 1) { throw "В ZIP найдено несколько manifest.json; архив должен содержать одно расширение." }
        $stream = $entries[0].Open()
        try {
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
            try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
        }
        finally { $stream.Dispose() }
        $manifest = $text | ConvertFrom-Json -ErrorAction Stop
        $name = [string](Get-PropertyValue $manifest "name" "")
        $version = [string](Get-PropertyValue $manifest "version" "")
        $manifestVersion = [string](Get-PropertyValue $manifest "manifest_version" "")
        $publicKey = [string](Get-PropertyValue $manifest "key" "")
        if ([string]::IsNullOrWhiteSpace($name)) { throw "manifest.json не содержит name." }
        if ($version -notmatch '^\d+(\.\d+){0,3}$') { throw "manifest.json содержит некорректную version." }
        if ($manifestVersion -notin @("2","3")) { throw ("Неподдерживаемый manifest_version: " + $manifestVersion) }
        $extensionId = ""
        if (-not [string]::IsNullOrWhiteSpace($publicKey)) {
            Initialize-CrxGenerator
            $extensionId = [Crx3Generator]::ExtensionIdFromPublicKeyBase64($publicKey)
        }
        return [pscustomobject]@{
            ZipPath = $ZipPath
            ZipName = [System.IO.Path]::GetFileName($ZipPath)
            Modified = (Get-Item -LiteralPath $ZipPath).LastWriteTime
            Name = $name
            Version = $version
            ManifestVersion = $manifestVersion
            PublicKey = $publicKey
            ExtensionIdFromManifest = $extensionId
        }
    }
    finally { $archive.Dispose() }
}

function Expand-ZipSafely([string]$ZipPath, [string]$DestinationRoot) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $DestinationRoot) { Remove-Item -LiteralPath $DestinationRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
    $rootFull = [System.IO.Path]::GetFullPath($DestinationRoot)
    if (-not $rootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString())) { $rootFull += [System.IO.Path]::DirectorySeparatorChar }
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        foreach ($entry in $archive.Entries) {
            $relative = $entry.FullName.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            if ([string]::IsNullOrWhiteSpace($relative)) { continue }
            $target = [System.IO.Path]::GetFullPath((Join-Path $DestinationRoot $relative))
            if (-not $target.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { throw ("ZIP содержит небезопасный путь: " + $entry.FullName) }
            if ([string]::IsNullOrEmpty($entry.Name)) {
                if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
                continue
            }
            $parent = Split-Path -Parent $target
            if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            $input = $entry.Open()
            try {
                $output = New-Object System.IO.FileStream($target, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                try { $input.CopyTo($output) } finally { $output.Dispose() }
            }
            finally { $input.Dispose() }
        }
    }
    finally { $archive.Dispose() }
}

function Find-ExtractedExtensionRoot([string]$ExtractedRoot) {
    $manifests = @(Get-ChildItem -LiteralPath $ExtractedRoot -Filter "manifest.json" -File -Recurse -ErrorAction Stop)
    if ($manifests.Count -eq 0) { throw "После распаковки manifest.json не найден." }
    if ($manifests.Count -gt 1) { throw "После распаковки найдено несколько manifest.json; ZIP должен содержать одно расширение." }
    return $manifests[0].Directory.FullName
}

function Read-ManifestFromFolder([string]$Folder) {
    $manifestPath = Join-Path $Folder "manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "manifest.json отсутствует." }
    $manifest = ([System.IO.File]::ReadAllText($manifestPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop)
    $name = [string](Get-PropertyValue $manifest "name" "")
    $version = [string](Get-PropertyValue $manifest "version" "")
    $mv = [string](Get-PropertyValue $manifest "manifest_version" "")
    if ([string]::IsNullOrWhiteSpace($name)) { throw "manifest.json не содержит name." }
    if ($version -notmatch '^\d+(\.\d+){0,3}$') { throw "manifest.json содержит некорректную version." }
    if ($mv -notin @("2","3")) { throw ("Неподдерживаемый manifest_version: " + $mv) }
    return [pscustomobject]@{ ManifestPath = $manifestPath; Manifest = $manifest; Name = $name; Version = $version; ManifestVersion = $mv; PublicKey = [string](Get-PropertyValue $manifest "key" "") }
}

function Set-ManifestPublicKey([string]$ManifestPath, [string]$PublicKey) {
    $text = [System.IO.File]::ReadAllText($ManifestPath, [System.Text.Encoding]::UTF8)
    $manifest = $text | ConvertFrom-Json -ErrorAction Stop
    $existing = $manifest.PSObject.Properties["key"]
    if ($null -eq $existing) { $manifest | Add-Member -MemberType NoteProperty -Name "key" -Value $PublicKey }
    else { $manifest.key = $PublicKey }
    $json = $manifest | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($ManifestPath, $json + "`r`n", $Utf8NoBom)
}

function Copy-ExtensionTree([string]$SourceRoot, [string]$DestinationRoot) {
    if (Test-Path -LiteralPath $DestinationRoot) { Remove-Item -LiteralPath $DestinationRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
    $excludedDirectories = @("build", ".git", ".svn", ".hg", "node_modules")
    $excludedFiles = @("Thumbs.db", ".DS_Store", "RSA_PRIVATE_KEY.txt")
    $stack = New-Object System.Collections.Generic.Stack[object]
    $stack.Push([pscustomobject]@{ Source = $SourceRoot; Relative = "" })
    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $current.Source -Force -ErrorAction Stop)) {
            $relative = if ([string]::IsNullOrWhiteSpace($current.Relative)) { $item.Name } else { Join-Path $current.Relative $item.Name }
            if ($item.PSIsContainer) {
                if ($item.Name -in $excludedDirectories) { continue }
                $targetDir = Join-Path $DestinationRoot $relative
                if (-not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
                $stack.Push([pscustomobject]@{ Source = $item.FullName; Relative = $relative })
            }
            else {
                if ($item.Name -in $excludedFiles) { continue }
                $targetFile = Join-Path $DestinationRoot $relative
                $targetParent = Split-Path -Parent $targetFile
                if (-not (Test-Path -LiteralPath $targetParent)) { New-Item -ItemType Directory -Path $targetParent -Force | Out-Null }
                Copy-Item -LiteralPath $item.FullName -Destination $targetFile -Force
            }
        }
    }
}

function New-ExtensionZip([string]$SourceRoot, [string]$StagingRoot) {
    $payloadRoot = Join-Path $StagingRoot "payload"
    Copy-ExtensionTree $SourceRoot $payloadRoot
    if (-not (Test-Path -LiteralPath (Join-Path $payloadRoot "manifest.json") -PathType Leaf)) { throw "После подготовки проекта manifest.json отсутствует." }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipPath = Join-Path $StagingRoot "extension-payload.zip"
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($payloadRoot, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
    return $zipPath
}

function Get-KeyFilePath([string]$ExtensionFolder) {
    return (Join-Path $ExtensionFolder "RSA_PRIVATE_KEY.txt")
}

function Ensure-FolderPrivateKey([string]$ExtensionFolder, $PackageInfo) {
    Initialize-CrxGenerator
    $keyPath = Get-KeyFilePath $ExtensionFolder
    $manifestKey = [string]$PackageInfo.PublicKey

    if (Test-Path -LiteralPath $keyPath -PathType Leaf) {
        try {
            $publicKey = [Crx3Generator]::GetPublicKeyBase64($keyPath)
            $extensionId = [Crx3Generator]::GetExtensionId($keyPath)
        }
        catch { throw ("RSA_PRIVATE_KEY.txt поврежден или имеет неверный формат: " + $_.Exception.Message) }
        if (-not [string]::IsNullOrWhiteSpace($manifestKey)) {
            $manifestId = [Crx3Generator]::ExtensionIdFromPublicKeyBase64($manifestKey)
            if ($manifestId -cne $extensionId) { throw "RSA_PRIVATE_KEY.txt не соответствует полю key в manifest.json последнего ZIP." }
        }
        Write-Log "INFO" ("Используется RSA-ключ из папки расширения: " + $keyPath)
        return [pscustomobject]@{ KeyPath = $keyPath; PublicKey = $publicKey; ExtensionId = $extensionId; Created = $false; Migrated = $false }
    }

    if (-not [string]::IsNullOrWhiteSpace($manifestKey)) {
        $manifestId = [Crx3Generator]::ExtensionIdFromPublicKeyBase64($manifestKey)
        $legacyKeyPath = Join-Path (Join-Path (Join-Path $LegacyBaseRoot "projects") $manifestId) "signing-key.bin"
        if (Test-Path -LiteralPath $legacyKeyPath -PathType Leaf) {
            [Crx3Generator]::ImportLegacyBinaryKeyToText($legacyKeyPath, $keyPath, $manifestKey)
            $publicKey = [Crx3Generator]::GetPublicKeyBase64($keyPath)
            $extensionId = [Crx3Generator]::GetExtensionId($keyPath)
            Write-Log "INFO" ("Старый приватный ключ перенесен в папку расширения: " + $keyPath)
            return [pscustomobject]@{ KeyPath = $keyPath; PublicKey = $publicKey; ExtensionId = $extensionId; Created = $true; Migrated = $true }
        }
        throw ("В последнем ZIP уже закреплен Extension ID " + $manifestId + ", но приватный RSA-ключ не найден. Нельзя создать новый ключ без изменения Extension ID.")
    }

    [Crx3Generator]::EnsureKey($keyPath)
    $publicKey = [Crx3Generator]::GetPublicKeyBase64($keyPath)
    $extensionId = [Crx3Generator]::GetExtensionId($keyPath)
    Write-Log "INFO" ("Создан новый RSA-ключ: " + $keyPath)
    Write-Log "INFO" ("Extension ID: " + $extensionId)
    return [pscustomobject]@{ KeyPath = $keyPath; PublicKey = $publicKey; ExtensionId = $extensionId; Created = $true; Migrated = $false }
}

function Get-SelectionIdentity([string]$ExtensionFolder, $PackageInfo) {
    Initialize-CrxGenerator
    $keyPath = Get-KeyFilePath $ExtensionFolder
    if (Test-Path -LiteralPath $keyPath -PathType Leaf) {
        try { return [Crx3Generator]::GetExtensionId($keyPath) }
        catch { return "" }
    }
    if ($null -ne $PackageInfo -and -not [string]::IsNullOrWhiteSpace([string]$PackageInfo.PublicKey)) {
        try { return [Crx3Generator]::ExtensionIdFromPublicKeyBase64([string]$PackageInfo.PublicKey) }
        catch { return "" }
    }
    return ""
}

function Get-InstallStatus([string]$ExtensionFolder, $PackageInfo) {
    $id = Get-SelectionIdentity $ExtensionFolder $PackageInfo
    if ([string]::IsNullOrWhiteSpace($id)) {
        return [pscustomobject]@{ ExtensionId = ""; Text = "Не установлено"; Installed = $false; InstalledVersion = "" }
    }
    $y = Get-YandexValues $id
    if ($null -eq $y) {
        return [pscustomobject]@{ ExtensionId = $id; Text = "Не установлено"; Installed = $false; InstalledVersion = "" }
    }
    $exists = (-not [string]::IsNullOrWhiteSpace($y.Path) -and (Test-Path -LiteralPath $y.Path -PathType Leaf))
    if ($exists) {
        return [pscustomobject]@{ ExtensionId = $id; Text = ("Установлено, версия " + $y.Version); Installed = $true; InstalledVersion = $y.Version }
    }
    return [pscustomobject]@{ ExtensionId = $id; Text = "Запись установки есть, файл CRX отсутствует"; Installed = $false; InstalledVersion = $y.Version }
}

function Install-SelectedExtension([string]$ExtensionFolder, $PackageInfo) {
    if ($null -eq $PackageInfo) { throw "Расширение не выбрано." }
    Write-Log "INFO" ("Начало установки/обновления: " + $ExtensionFolder)
    Write-Log "INFO" ("Исходный ZIP: " + $PackageInfo.ZipPath)
    Write-Log "INFO" ("ZIP modified: " + $PackageInfo.Modified.ToString("o"))

    $identity = Ensure-FolderPrivateKey $ExtensionFolder $PackageInfo
    $extensionId = $identity.ExtensionId
    if (-not (Is-ValidExtensionId $extensionId)) { throw "Получен некорректный Extension ID." }

    $projectRoot = Join-Path $ProjectsRoot $extensionId
    $crxRoot = Join-Path $projectRoot "crx"
    $statePath = Join-Path $projectRoot "state.json"
    $stagingRoot = Join-Path $projectRoot ("staging-" + [Guid]::NewGuid().ToString("N"))
    $extractRoot = Join-Path $stagingRoot "extracted"
    if (-not (Test-Path -LiteralPath $projectRoot)) { New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null }
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

    try {
        Expand-ZipSafely $PackageInfo.ZipPath $extractRoot
        $sourceRoot = Find-ExtractedExtensionRoot $extractRoot
        $workingManifest = Read-ManifestFromFolder $sourceRoot
        Set-ManifestPublicKey $workingManifest.ManifestPath $identity.PublicKey
        $workingManifest = Read-ManifestFromFolder $sourceRoot
        if ($workingManifest.Version -cne [string]$PackageInfo.Version) { Write-Log "WARN" "Версия manifest после распаковки отличается от предварительно прочитанной версии." }
        Write-Log "INFO" ("Рабочий manifest: " + $workingManifest.ManifestPath)
        Write-Log "INFO" ("Версия: " + $workingManifest.Version + "; Manifest V" + $workingManifest.ManifestVersion)
        Write-Log "INFO" ("Extension ID: " + $extensionId)

        $payloadZip = New-ExtensionZip $sourceRoot $stagingRoot
        Initialize-CrxGenerator
        if (-not [Crx3Generator]::PrivateKeyMatchesPublicKey($identity.KeyPath, $identity.PublicKey)) { throw "Приватный RSA-ключ не соответствует рабочему manifest key." }
        $generated = [Crx3Generator]::Generate($payloadZip, $stagingRoot, $identity.KeyPath)
        if ([string]$generated.ExtensionId -cne $extensionId) { throw "CRX3 сформирован с неожиданным Extension ID." }
        $sha = ([string]$generated.Sha256).ToLowerInvariant()
        Write-Log "INFO" ("CRX SHA-256: " + $sha)

        if (-not (Test-Path -LiteralPath $crxRoot)) { New-Item -ItemType Directory -Path $crxRoot -Force | Out-Null }
        $newCrxPath = Join-Path $crxRoot ($extensionId + "-" + $workingManifest.Version + "-" + $sha.Substring(0,12) + ".crx")
        $newYandexKey = Join-Path $YandexBaseKey $extensionId
        $state = Read-State $statePath
        $oldYandex = Get-YandexValues $extensionId

        if ($null -eq $state -and $null -ne $oldYandex -and -not (Path-Is-InRoot $oldYandex.Path $crxRoot)) { throw "Этот Extension ID уже зарегистрирован в Яндекс.Браузере, но запись не принадлежит установщику." }
        if ($null -ne $state -and $null -ne $oldYandex -and $oldYandex.Path -cne [string]$state.CrxPath) { throw "Текущая запись Яндекс.Браузера отличается от сохраненного состояния; обновление остановлено." }

        if (Test-Path -LiteralPath $newCrxPath -PathType Leaf) {
            if ((Get-FileSha256 $newCrxPath) -cne $sha) { throw "Целевой CRX существует, но имеет другой SHA-256." }
        }
        else { Move-Item -LiteralPath $generated.CrxPath -Destination $newCrxPath }

        try {
            New-Item -Path $newYandexKey -Force | Out-Null
            New-ItemProperty -LiteralPath $newYandexKey -Name "path" -PropertyType String -Value $newCrxPath -Force | Out-Null
            New-ItemProperty -LiteralPath $newYandexKey -Name "version" -PropertyType String -Value $workingManifest.Version -Force | Out-Null
            $verify = Get-YandexValues $extensionId
            if ($null -eq $verify -or $verify.Path -cne $newCrxPath -or $verify.Version -cne $workingManifest.Version) { throw "Проверка записи Яндекс.Браузера не пройдена." }

            $newState = [pscustomobject]@{
                ExtensionId = $extensionId
                CrxPath = $newCrxPath
                Sha256 = $sha
                Version = $workingManifest.Version
                SourcePath = $ExtensionFolder
                SourceZip = $PackageInfo.ZipPath
                InstalledUtc = [DateTime]::UtcNow.ToString("o")
            }
            Write-State $statePath $newState

            if ($null -ne $state) {
                $previous = [string]$state.CrxPath
                if (-not [string]::IsNullOrWhiteSpace($previous) -and $previous -cne $newCrxPath -and (Test-Path -LiteralPath $previous -PathType Leaf)) { Remove-Item -LiteralPath $previous -Force -ErrorAction SilentlyContinue }
            }
            foreach ($oldFile in @(Get-ChildItem -LiteralPath $crxRoot -Filter "*.crx" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -cne $newCrxPath })) {
                Remove-Item -LiteralPath $oldFile.FullName -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            $reason = $_.Exception.Message
            Write-Log "WARN" ("Ошибка установки, выполняется rollback: " + $reason)
            if ($null -ne $oldYandex) {
                New-Item -Path $oldYandex.Key -Force | Out-Null
                New-ItemProperty -LiteralPath $oldYandex.Key -Name "path" -PropertyType String -Value $oldYandex.Path -Force | Out-Null
                New-ItemProperty -LiteralPath $oldYandex.Key -Name "version" -PropertyType String -Value $oldYandex.Version -Force | Out-Null
            }
            elseif (Test-Path -LiteralPath $newYandexKey) { Remove-Item -LiteralPath $newYandexKey -Recurse -Force -ErrorAction SilentlyContinue }
            if ((Test-Path -LiteralPath $newCrxPath -PathType Leaf) -and ($null -eq $state -or [string]$state.CrxPath -cne $newCrxPath)) { Remove-Item -LiteralPath $newCrxPath -Force -ErrorAction SilentlyContinue }
            throw ("Установка не выполнена. Rollback завершен. Причина: " + $reason)
        }

        Write-Log "INFO" ("Установка завершена. Версия " + $workingManifest.Version + ", Extension ID " + $extensionId)
        return [pscustomobject]@{ Version = $workingManifest.Version; ExtensionId = $extensionId; CrxPath = $newCrxPath; KeyCreated = $identity.Created; KeyMigrated = $identity.Migrated }
    }
    finally {
        if (Test-Path -LiteralPath $stagingRoot) { Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Uninstall-SelectedExtension([string]$ExtensionFolder, $PackageInfo) {
    if ($null -eq $PackageInfo) { throw "Расширение не выбрано." }
    $extensionId = Get-SelectionIdentity $ExtensionFolder $PackageInfo
    if ([string]::IsNullOrWhiteSpace($extensionId)) { throw "У расширения еще нет Extension ID; удалять нечего." }
    Write-Log "INFO" ("Начало удаления Extension ID " + $extensionId)
    $projectRoot = Join-Path $ProjectsRoot $extensionId
    $crxRoot = Join-Path $projectRoot "crx"
    $statePath = Join-Path $projectRoot "state.json"
    $state = Read-State $statePath
    $y = Get-YandexValues $extensionId
    if ($null -ne $y) {
        if ($null -ne $state) {
            if ($y.Path -cne [string]$state.CrxPath) { throw "Путь в реестре Яндекс.Браузера отличается от сохраненного состояния; удаление остановлено." }
        }
        elseif (-not (Path-Is-InRoot $y.Path $crxRoot)) { throw "Запись Яндекс.Браузера указывает на файл вне служебной папки этого расширения; удаление остановлено." }
        Remove-Item -LiteralPath $y.Key -Recurse -Force
    }
    if (Test-Path -LiteralPath $crxRoot) { Remove-Item -LiteralPath $crxRoot -Recurse -Force }
    if (Test-Path -LiteralPath $statePath) { Remove-Item -LiteralPath $statePath -Force }
    Write-Log "INFO" ("Удаление завершено. RSA_PRIVATE_KEY.txt сохранен в папке расширения.")
    return $extensionId
}

function Initialize-YandexWindowBridge {
    if ("UniversalExtensionBuilderWindowBridge" -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class UniversalExtensionBuilderWindowBridge
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

function Get-YandexWindowProcess {
    Initialize-YandexWindowBridge
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
        $foreground = [UniversalExtensionBuilderWindowBridge]::GetForegroundWindow()
        foreach ($item in $windows) {
            if ($item.IsYandex -and [IntPtr]$item.Process.MainWindowHandle -eq $foreground) { return $item.Process }
        }
    }
    catch { }
    $verified = @($windows | Where-Object { $_.IsYandex })
    if ($verified.Count -gt 0) { return $verified[0].Process }
    return $windows[0].Process
}

function Activate-YandexBrowser {
    try {
        Initialize-YandexWindowBridge
        $process = Get-YandexWindowProcess
        if ($null -eq $process -or $process.MainWindowHandle -eq 0) { return $false }
        $handle = [IntPtr]$process.MainWindowHandle
        if ([UniversalExtensionBuilderWindowBridge]::IsIconic($handle)) {
            [void][UniversalExtensionBuilderWindowBridge]::ShowWindowAsync($handle, 9)
            Start-Sleep -Milliseconds 120
        }
        $currentThread = [UniversalExtensionBuilderWindowBridge]::GetCurrentThreadId()
        $foreground = [UniversalExtensionBuilderWindowBridge]::GetForegroundWindow()
        [uint32]$foregroundProcessId = 0
        [uint32]$targetProcessId = 0
        [uint32]$foregroundThread = 0
        [uint32]$targetThread = [UniversalExtensionBuilderWindowBridge]::GetWindowThreadProcessId($handle, [ref]$targetProcessId)
        if ($foreground -ne [IntPtr]::Zero) { $foregroundThread = [UniversalExtensionBuilderWindowBridge]::GetWindowThreadProcessId($foreground, [ref]$foregroundProcessId) }
        $attachedForeground = $false
        $attachedTarget = $false
        try {
            if ($foregroundThread -ne 0 -and $foregroundThread -ne $currentThread) { $attachedForeground = [UniversalExtensionBuilderWindowBridge]::AttachThreadInput($currentThread, $foregroundThread, $true) }
            if ($targetThread -ne 0 -and $targetThread -ne $currentThread) { $attachedTarget = [UniversalExtensionBuilderWindowBridge]::AttachThreadInput($currentThread, $targetThread, $true) }
            [void][UniversalExtensionBuilderWindowBridge]::BringWindowToTop($handle)
            [void][UniversalExtensionBuilderWindowBridge]::SetForegroundWindow($handle)
            [void][UniversalExtensionBuilderWindowBridge]::SetActiveWindow($handle)
            [void][UniversalExtensionBuilderWindowBridge]::SetFocus($handle)
        }
        finally {
            if ($attachedTarget) { [void][UniversalExtensionBuilderWindowBridge]::AttachThreadInput($currentThread, $targetThread, $false) }
            if ($attachedForeground) { [void][UniversalExtensionBuilderWindowBridge]::AttachThreadInput($currentThread, $foregroundThread, $false) }
        }
        Start-Sleep -Milliseconds 100
        return ([UniversalExtensionBuilderWindowBridge]::GetForegroundWindow() -eq $handle)
    }
    catch { Write-LogException "Не удалось активировать Яндекс.Браузер" $_; return $false }
}

function Copy-TuneAddress {
    try {
        [System.Windows.Forms.Clipboard]::SetText("browser://tune/")
        return $true
    }
    catch {
        try { Set-Clipboard -Value "browser://tune/" -ErrorAction Stop; return $true } catch { return $false }
    }
}

function Initialize-CrxGenerator {
    if ("Crx3Generator" -as [type]) { return }
    $code = @'

using System;
using System.IO;
using System.Text;
using System.Security.Cryptography;
using System.Collections.Generic;

public sealed class Crx3BuildResult
{
    public string ExtensionId { get; set; }
    public string CrxPath { get; set; }
    public string Sha256 { get; set; }
}

public static class Crx3Generator
{
    private static byte[] Concat(params byte[][] arrays)
    {
        int total = 0;
        foreach (byte[] a in arrays)
        {
            if (a != null) total += a.Length;
        }

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

    private static byte[] Varint(ulong value)
    {
        List<byte> bytes = new List<byte>();

        do
        {
            byte b = (byte)(value & 0x7FUL);
            value >>= 7;
            if (value != 0) b |= 0x80;
            bytes.Add(b);
        }
        while (value != 0);

        return bytes.ToArray();
    }

    private static byte[] ProtoBytes(int fieldNumber, byte[] data)
    {
        ulong key = ((ulong)fieldNumber << 3) | 2UL;
        return Concat(
            Varint(key),
            Varint((ulong)data.Length),
            data
        );
    }

    private static byte[] DerLength(int length)
    {
        if (length < 128)
            return new byte[] { (byte)length };

        List<byte> bytes = new List<byte>();
        int n = length;

        while (n > 0)
        {
            bytes.Insert(0, (byte)(n & 0xFF));
            n >>= 8;
        }

        byte[] result = new byte[1 + bytes.Count];
        result[0] = (byte)(0x80 | bytes.Count);

        for (int i = 0; i < bytes.Count; i++)
            result[i + 1] = bytes[i];

        return result;
    }

    private static byte[] DerWrap(byte tag, byte[] content)
    {
        return Concat(
            new byte[] { tag },
            DerLength(content.Length),
            content
        );
    }

    private static byte[] DerInteger(byte[] unsignedBigEndian)
    {
        int start = 0;

        while (
            start < unsignedBigEndian.Length - 1 &&
            unsignedBigEndian[start] == 0x00
        )
        {
            start++;
        }

        int len = unsignedBigEndian.Length - start;
        bool prependZero = (unsignedBigEndian[start] & 0x80) != 0;

        byte[] value = new byte[len + (prependZero ? 1 : 0)];
        int dst = prependZero ? 1 : 0;

        Buffer.BlockCopy(
            unsignedBigEndian,
            start,
            value,
            dst,
            len
        );

        return DerWrap(0x02, value);
    }

    private static byte[] BuildSubjectPublicKeyInfo(RSAParameters p)
    {
        byte[] rsaPublicKey = DerWrap(
            0x30,
            Concat(
                DerInteger(p.Modulus),
                DerInteger(p.Exponent)
            )
        );

        byte[] algorithmIdentifier = new byte[]
        {
            0x30, 0x0D,
            0x06, 0x09,
            0x2A, 0x86, 0x48, 0x86, 0xF7,
            0x0D, 0x01, 0x01, 0x01,
            0x05, 0x00
        };

        byte[] subjectPublicKeyBitString = DerWrap(
            0x03,
            Concat(
                new byte[] { 0x00 },
                rsaPublicKey
            )
        );

        return DerWrap(
            0x30,
            Concat(
                algorithmIdentifier,
                subjectPublicKeyBitString
            )
        );
    }

    private static string BuildExtensionId(byte[] publicKeyDer)
    {
        byte[] hash;

        using (SHA256 sha = SHA256.Create())
        {
            hash = sha.ComputeHash(publicKeyDer);
        }

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

    private static string Sha256File(string path)
    {
        using (SHA256 sha = SHA256.Create())
        using (FileStream fs = File.OpenRead(path))
        {
            byte[] hash = sha.ComputeHash(fs);
            StringBuilder sb = new StringBuilder(hash.Length * 2);

            foreach (byte b in hash)
                sb.Append(b.ToString("x2"));

            return sb.ToString();
        }
    }

    private static RSACryptoServiceProvider LoadKey(string keyPath)
    {
        if (!File.Exists(keyPath))
            throw new FileNotFoundException("Signing key was not found.", keyPath);

        string keyText = File.ReadAllText(keyPath, Encoding.UTF8).Trim();
        byte[] keyBlob = Convert.FromBase64String(keyText);
        CspParameters csp = new CspParameters(24);
        csp.Flags = CspProviderFlags.CreateEphemeralKey;

        RSACryptoServiceProvider rsa = new RSACryptoServiceProvider(2048, csp);
        rsa.PersistKeyInCsp = false;
        rsa.ImportCspBlob(keyBlob);
        return rsa;
    }

    private static RSACryptoServiceProvider LoadOrCreateKey(string keyPath)
    {
        if (File.Exists(keyPath))
            return LoadKey(keyPath);

        string keyDirectory = Path.GetDirectoryName(keyPath);
        if (!String.IsNullOrEmpty(keyDirectory))
            Directory.CreateDirectory(keyDirectory);

        CspParameters csp = new CspParameters(24);
        csp.Flags = CspProviderFlags.CreateEphemeralKey;

        RSACryptoServiceProvider rsa = new RSACryptoServiceProvider(2048, csp);
        rsa.PersistKeyInCsp = false;

        byte[] keyBlob = rsa.ExportCspBlob(true);
        string tempPath = keyPath + ".tmp";
        File.WriteAllText(tempPath, Convert.ToBase64String(keyBlob), new UTF8Encoding(false));

        if (File.Exists(keyPath))
        {
            File.Delete(tempPath);
            rsa.Dispose();
            return LoadKey(keyPath);
        }

        File.Move(tempPath, keyPath);
        return rsa;
    }

    public static void ImportLegacyBinaryKeyToText(string legacyPath, string textPath, string expectedPublicKeyBase64)
    {
        if (!File.Exists(legacyPath))
            throw new FileNotFoundException("Legacy signing key was not found.", legacyPath);

        byte[] keyBlob = File.ReadAllBytes(legacyPath);
        CspParameters csp = new CspParameters(24);
        csp.Flags = CspProviderFlags.CreateEphemeralKey;

        using (RSACryptoServiceProvider rsa = new RSACryptoServiceProvider(2048, csp))
        {
            rsa.PersistKeyInCsp = false;
            rsa.ImportCspBlob(keyBlob);
            RSAParameters publicParameters = rsa.ExportParameters(false);
            byte[] publicKeyDer = BuildSubjectPublicKeyInfo(publicParameters);
            string actualPublicKey = Convert.ToBase64String(publicKeyDer);

            if (!String.IsNullOrWhiteSpace(expectedPublicKeyBase64))
            {
                byte[] left = Convert.FromBase64String(actualPublicKey);
                byte[] right = Convert.FromBase64String(expectedPublicKeyBase64.Trim());
                if (left.Length != right.Length)
                    throw new CryptographicException("Legacy private key does not match manifest key.");
                for (int i = 0; i < left.Length; i++)
                    if (left[i] != right[i])
                        throw new CryptographicException("Legacy private key does not match manifest key.");
            }

            string directory = Path.GetDirectoryName(textPath);
            if (!String.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
            string tempPath = textPath + ".tmp";
            File.WriteAllText(tempPath, Convert.ToBase64String(keyBlob), new UTF8Encoding(false));
            if (File.Exists(textPath)) File.Delete(textPath);
            File.Move(tempPath, textPath);
        }
    }

    public static void EnsureKey(string keyPath)
    {
        using (RSACryptoServiceProvider rsa = LoadOrCreateKey(keyPath))
        {
        }
    }

    public static string GetPublicKeyBase64(string keyPath)
    {
        using (RSACryptoServiceProvider rsa = LoadKey(keyPath))
        {
            RSAParameters publicParameters = rsa.ExportParameters(false);
            byte[] publicKeyDer = BuildSubjectPublicKeyInfo(publicParameters);
            return Convert.ToBase64String(publicKeyDer);
        }
    }

    public static string ExtensionIdFromPublicKeyBase64(string publicKeyBase64)
    {
        if (String.IsNullOrWhiteSpace(publicKeyBase64))
            throw new ArgumentException("Manifest key is empty.");

        byte[] publicKeyDer = Convert.FromBase64String(publicKeyBase64.Trim());
        return BuildExtensionId(publicKeyDer);
    }

    public static bool PrivateKeyMatchesPublicKey(string keyPath, string publicKeyBase64)
    {
        string actual = GetPublicKeyBase64(keyPath);
        byte[] left = Convert.FromBase64String(actual);
        byte[] right = Convert.FromBase64String(publicKeyBase64.Trim());
        if (left.Length != right.Length) return false;
        for (int i = 0; i < left.Length; i++)
        {
            if (left[i] != right[i]) return false;
        }
        return true;
    }

    public static string GetExtensionId(string keyPath)
    {
        using (RSACryptoServiceProvider rsa = LoadKey(keyPath))
        {
            RSAParameters publicParameters = rsa.ExportParameters(false);
            byte[] publicKeyDer = BuildSubjectPublicKeyInfo(publicParameters);
            return BuildExtensionId(publicKeyDer);
        }
    }

    public static Crx3BuildResult Generate(
        string zipPath,
        string outputDirectory,
        string keyPath
    )
    {
        byte[] zipBytes = File.ReadAllBytes(zipPath);

        if (
            zipBytes.Length < 2 ||
            zipBytes[0] != 0x50 ||
            zipBytes[1] != 0x4B
        )
        {
            throw new InvalidDataException("Payload is not a ZIP archive.");
        }

        Directory.CreateDirectory(outputDirectory);

        using (RSACryptoServiceProvider rsa = LoadOrCreateKey(keyPath))
        {
            RSAParameters publicParameters = rsa.ExportParameters(false);
            byte[] publicKeyDer = BuildSubjectPublicKeyInfo(publicParameters);
            string extensionId = BuildExtensionId(publicKeyDer);

            byte[] idHash;
            using (SHA256 sha = SHA256.Create())
            {
                idHash = sha.ComputeHash(publicKeyDer);
            }

            byte[] crxId = new byte[16];
            Buffer.BlockCopy(idHash, 0, crxId, 0, 16);

            byte[] signedHeaderData = ProtoBytes(1, crxId);

            byte[] signedBlob = Concat(
                Encoding.ASCII.GetBytes("CRX3 SignedData\0"),
                BitConverter.GetBytes((UInt32)signedHeaderData.Length),
                signedHeaderData,
                zipBytes
            );

            byte[] signature = rsa.SignData(
                signedBlob,
                CryptoConfig.MapNameToOID("SHA256")
            );

            if (!rsa.VerifyData(
                signedBlob,
                CryptoConfig.MapNameToOID("SHA256"),
                signature
            ))
            {
                throw new CryptographicException(
                    "Generated CRX signature verification failed."
                );
            }

            byte[] proof = Concat(
                ProtoBytes(1, publicKeyDer),
                ProtoBytes(2, signature)
            );

            byte[] header = Concat(
                ProtoBytes(2, proof),
                ProtoBytes(10000, signedHeaderData)
            );

            byte[] crx = Concat(
                Encoding.ASCII.GetBytes("Cr24"),
                BitConverter.GetBytes((UInt32)3),
                BitConverter.GetBytes((UInt32)header.Length),
                header,
                zipBytes
            );

            string outputPath = Path.Combine(
                outputDirectory,
                extensionId + ".crx"
            );

            File.WriteAllBytes(outputPath, crx);

            return new Crx3BuildResult
            {
                ExtensionId = extensionId,
                CrxPath = outputPath,
                Sha256 = Sha256File(outputPath)
            };
        }
    }
}

'@
    try { Add-Type -TypeDefinition $code -Language CSharp }
    catch { throw ("Не удалось инициализировать генератор CRX3: " + $_.Exception.Message) }
}


function Initialize-ModernFolderPicker {
    if ("ModernFolderPicker" -as [type]) { return }
    $code = @'
using System;
using System.Runtime.InteropServices;

public static class ModernFolderPicker
{
    [Flags]
    private enum FOS : uint
    {
        FOS_PICKFOLDERS = 0x00000020,
        FOS_FORCEFILESYSTEM = 0x00000040,
        FOS_PATHMUSTEXIST = 0x00000800,
        FOS_DONTADDTORECENT = 0x02000000
    }

    private enum SIGDN : uint
    {
        FILESYSPATH = 0x80058000
    }

    [ComImport]
    [Guid("DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7")]
    private class FileOpenDialogRCW
    {
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("42F85136-DB7E-439C-85F1-E4075D135FC8")]
    private interface IFileOpenDialog
    {
        [PreserveSig] int Show(IntPtr parent);
        void SetFileTypes(uint cFileTypes, IntPtr rgFilterSpec);
        void SetFileTypeIndex(uint iFileType);
        void GetFileTypeIndex(out uint piFileType);
        void Advise(IntPtr pfde, out uint pdwCookie);
        void Unadvise(uint dwCookie);
        void SetOptions(FOS fos);
        void GetOptions(out FOS pfos);
        void SetDefaultFolder(IShellItem psi);
        void SetFolder(IShellItem psi);
        void GetFolder(out IShellItem ppsi);
        void GetCurrentSelection(out IShellItem ppsi);
        void SetFileName([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetFileName([MarshalAs(UnmanagedType.LPWStr)] out string pszName);
        void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string pszTitle);
        void SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string pszText);
        void SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string pszLabel);
        void GetResult(out IShellItem ppsi);
        void AddPlace(IShellItem psi, int fdap);
        void SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string pszDefaultExtension);
        void Close(int hr);
        void SetClientGuid(ref Guid guid);
        void ClearClientData();
        void SetFilter(IntPtr pFilter);
        void GetResults(out IntPtr ppenum);
        void GetSelectedItems(out IntPtr ppsai);
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE")]
    private interface IShellItem
    {
        void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
        void GetParent(out IShellItem ppsi);
        void GetDisplayName(SIGDN sigdnName, out IntPtr ppszName);
        void GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
        void Compare(IShellItem psi, uint hint, out int piOrder);
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = true)]
    private static extern int SHCreateItemFromParsingName(
        [MarshalAs(UnmanagedType.LPWStr)] string pszPath,
        IntPtr pbc,
        ref Guid riid,
        out IShellItem ppv);

    public static string PickFolder(IntPtr owner, string initialFolder, string title)
    {
        IFileOpenDialog dialog = (IFileOpenDialog)new FileOpenDialogRCW();
        try
        {
            FOS options;
            dialog.GetOptions(out options);
            options |= FOS.FOS_PICKFOLDERS | FOS.FOS_FORCEFILESYSTEM | FOS.FOS_PATHMUSTEXIST | FOS.FOS_DONTADDTORECENT;
            dialog.SetOptions(options);
            if (!String.IsNullOrWhiteSpace(title))
                dialog.SetTitle(title);
            dialog.SetOkButtonLabel("Выбрать папку");

            if (!String.IsNullOrWhiteSpace(initialFolder))
            {
                Guid shellItemGuid = new Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE");
                IShellItem initialItem;
                int createHr = SHCreateItemFromParsingName(initialFolder, IntPtr.Zero, ref shellItemGuid, out initialItem);
                if (createHr >= 0 && initialItem != null)
                {
                    try { dialog.SetFolder(initialItem); }
                    finally { Marshal.ReleaseComObject(initialItem); }
                }
            }

            int hr = dialog.Show(owner);
            if (hr == unchecked((int)0x800704C7))
                return null;
            Marshal.ThrowExceptionForHR(hr);

            IShellItem result;
            dialog.GetResult(out result);
            try
            {
                IntPtr pathPtr;
                result.GetDisplayName(SIGDN.FILESYSPATH, out pathPtr);
                try { return Marshal.PtrToStringUni(pathPtr); }
                finally { Marshal.FreeCoTaskMem(pathPtr); }
            }
            finally
            {
                if (result != null) Marshal.ReleaseComObject(result);
            }
        }
        finally
        {
            if (dialog != null) Marshal.ReleaseComObject(dialog);
        }
    }
}
'@
    try { Add-Type -TypeDefinition $code -Language CSharp }
    catch { throw ("Не удалось инициализировать современный выбор папки: " + $_.Exception.Message) }
}


function Show-MainWindow {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Установщик расширений"
    $form.StartPosition = "CenterScreen"
    $form.Size = New-Object System.Drawing.Size(860, 585)
    $form.MinimumSize = New-Object System.Drawing.Size(860, 585)
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.MaximizeBox = $false

    $rootLabel = New-Object System.Windows.Forms.Label
    $rootLabel.Location = New-Object System.Drawing.Point(24, 24)
    $rootLabel.Size = New-Object System.Drawing.Size(190, 22)
    $rootLabel.Text = "Папка с расширениями"
    $form.Controls.Add($rootLabel)

    $rootBox = New-Object System.Windows.Forms.TextBox
    $rootBox.Location = New-Object System.Drawing.Point(24, 49)
    $rootBox.Size = New-Object System.Drawing.Size(680, 27)
    $rootBox.ReadOnly = $true
    $form.Controls.Add($rootBox)

    $browseButton = New-Object System.Windows.Forms.Button
    $browseButton.Location = New-Object System.Drawing.Point(716, 47)
    $browseButton.Size = New-Object System.Drawing.Size(110, 30)
    $browseButton.Text = "Выбрать..."
    $form.Controls.Add($browseButton)

    $extensionLabel = New-Object System.Windows.Forms.Label
    $extensionLabel.Location = New-Object System.Drawing.Point(24, 92)
    $extensionLabel.Size = New-Object System.Drawing.Size(150, 22)
    $extensionLabel.Text = "Расширение"
    $form.Controls.Add($extensionLabel)

    $extensionCombo = New-Object System.Windows.Forms.ComboBox
    $extensionCombo.Location = New-Object System.Drawing.Point(24, 117)
    $extensionCombo.Size = New-Object System.Drawing.Size(802, 28)
    $extensionCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $extensionCombo.Enabled = $false
    $form.Controls.Add($extensionCombo)

    $infoGroup = New-Object System.Windows.Forms.GroupBox
    $infoGroup.Location = New-Object System.Drawing.Point(24, 160)
    $infoGroup.Size = New-Object System.Drawing.Size(802, 122)
    $infoGroup.Text = "Выбранное расширение"
    $form.Controls.Add($infoGroup)

    $archiveTitle = New-Object System.Windows.Forms.Label
    $archiveTitle.Location = New-Object System.Drawing.Point(16, 27)
    $archiveTitle.Size = New-Object System.Drawing.Size(110, 20)
    $archiveTitle.Text = "Свежий ZIP:"
    $infoGroup.Controls.Add($archiveTitle)

    $archiveValue = New-Object System.Windows.Forms.Label
    $archiveValue.Location = New-Object System.Drawing.Point(130, 27)
    $archiveValue.Size = New-Object System.Drawing.Size(650, 20)
    $archiveValue.AutoEllipsis = $true
    $archiveValue.Text = "—"
    $infoGroup.Controls.Add($archiveValue)

    $versionTitle = New-Object System.Windows.Forms.Label
    $versionTitle.Location = New-Object System.Drawing.Point(16, 52)
    $versionTitle.Size = New-Object System.Drawing.Size(110, 20)
    $versionTitle.Text = "Версия:"
    $infoGroup.Controls.Add($versionTitle)

    $versionValue = New-Object System.Windows.Forms.Label
    $versionValue.Location = New-Object System.Drawing.Point(130, 52)
    $versionValue.Size = New-Object System.Drawing.Size(180, 20)
    $versionValue.Text = "—"
    $infoGroup.Controls.Add($versionValue)

    $idTitle = New-Object System.Windows.Forms.Label
    $idTitle.Location = New-Object System.Drawing.Point(330, 52)
    $idTitle.Size = New-Object System.Drawing.Size(100, 20)
    $idTitle.Text = "Extension ID:"
    $infoGroup.Controls.Add($idTitle)

    $idValue = New-Object System.Windows.Forms.Label
    $idValue.Location = New-Object System.Drawing.Point(430, 52)
    $idValue.Size = New-Object System.Drawing.Size(350, 20)
    $idValue.Text = "—"
    $infoGroup.Controls.Add($idValue)

    $statusTitle = New-Object System.Windows.Forms.Label
    $statusTitle.Location = New-Object System.Drawing.Point(16, 78)
    $statusTitle.Size = New-Object System.Drawing.Size(110, 20)
    $statusTitle.Text = "Состояние:"
    $infoGroup.Controls.Add($statusTitle)

    $statusValue = New-Object System.Windows.Forms.Label
    $statusValue.Location = New-Object System.Drawing.Point(130, 78)
    $statusValue.Size = New-Object System.Drawing.Size(650, 20)
    $statusValue.Text = "—"
    $infoGroup.Controls.Add($statusValue)

    $installButton = New-Object System.Windows.Forms.Button
    $installButton.Location = New-Object System.Drawing.Point(24, 299)
    $installButton.Size = New-Object System.Drawing.Size(175, 34)
    $installButton.Text = "Установить / обновить"
    $installButton.Enabled = $false
    $form.Controls.Add($installButton)

    $uninstallButton = New-Object System.Windows.Forms.Button
    $uninstallButton.Location = New-Object System.Drawing.Point(209, 299)
    $uninstallButton.Size = New-Object System.Drawing.Size(105, 34)
    $uninstallButton.Text = "Удалить"
    $uninstallButton.Enabled = $false
    $form.Controls.Add($uninstallButton)

    $openFolderButton = New-Object System.Windows.Forms.Button
    $openFolderButton.Location = New-Object System.Drawing.Point(324, 299)
    $openFolderButton.Size = New-Object System.Drawing.Size(175, 34)
    $openFolderButton.Text = "Открыть папку"
    $openFolderButton.Enabled = $false
    $form.Controls.Add($openFolderButton)

    $saveLogButton = New-Object System.Windows.Forms.Button
    $saveLogButton.Location = New-Object System.Drawing.Point(509, 299)
    $saveLogButton.Size = New-Object System.Drawing.Size(145, 34)
    $saveLogButton.Text = "Сохранить лог..."
    $form.Controls.Add($saveLogButton)

    $enableGroup = New-Object System.Windows.Forms.GroupBox
    $enableGroup.Location = New-Object System.Drawing.Point(24, 350)
    $enableGroup.Size = New-Object System.Drawing.Size(802, 100)
    $enableGroup.Text = "Включение в Яндекс.Браузере"
    $enableGroup.Visible = $false
    $form.Controls.Add($enableGroup)

    $enableLabel = New-Object System.Windows.Forms.Label
    $enableLabel.Location = New-Object System.Drawing.Point(16, 25)
    $enableLabel.Size = New-Object System.Drawing.Size(750, 20)
    $enableLabel.Text = "Если браузер просит подтверждение, откройте в адресной строке:"
    $enableGroup.Controls.Add($enableLabel)

    $tuneBox = New-Object System.Windows.Forms.TextBox
    $tuneBox.Location = New-Object System.Drawing.Point(16, 52)
    $tuneBox.Size = New-Object System.Drawing.Size(330, 27)
    $tuneBox.ReadOnly = $true
    $tuneBox.Text = "browser://tune/"
    $enableGroup.Controls.Add($tuneBox)

    $copyButton = New-Object System.Windows.Forms.Button
    $copyButton.Location = New-Object System.Drawing.Point(360, 50)
    $copyButton.Size = New-Object System.Drawing.Size(150, 30)
    $copyButton.Text = "Скопировать адрес"
    $enableGroup.Controls.Add($copyButton)

    $browserButton = New-Object System.Windows.Forms.Button
    $browserButton.Location = New-Object System.Drawing.Point(522, 50)
    $browserButton.Size = New-Object System.Drawing.Size(210, 30)
    $browserButton.Text = "Открыть Яндекс.Браузер"
    $enableGroup.Controls.Add($browserButton)

    $noticePanel = New-Object System.Windows.Forms.Panel
    $noticePanel.Location = New-Object System.Drawing.Point(24, 470)
    $noticePanel.Size = New-Object System.Drawing.Size(802, 52)
    $noticePanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $form.Controls.Add($noticePanel)

    $noticeLabel = New-Object System.Windows.Forms.Label
    $noticeLabel.Location = New-Object System.Drawing.Point(12, 14)
    $noticeLabel.Size = New-Object System.Drawing.Size(776, 24)
    $noticeLabel.AutoEllipsis = $true
    $noticeLabel.Text = "Выберите папку с расширениями."
    $noticePanel.Controls.Add($noticeLabel)

    $setNotice = {
        param([string]$Text, [string]$Kind)
        $noticeLabel.Text = $Text
        if ($Kind -eq "error") { $noticeLabel.ForeColor = [System.Drawing.Color]::Firebrick }
        elseif ($Kind -eq "success") { $noticeLabel.ForeColor = [System.Drawing.Color]::DarkGreen }
        elseif ($Kind -eq "warning") { $noticeLabel.ForeColor = [System.Drawing.Color]::DarkOrange }
        else { $noticeLabel.ForeColor = [System.Drawing.SystemColors]::ControlText }
    }

    $setBusy = {
        param([bool]$Busy)
        $form.UseWaitCursor = $Busy
        $browseButton.Enabled = -not $Busy
        $extensionCombo.Enabled = (-not $Busy -and $extensionCombo.Items.Count -gt 0)
        $installButton.Enabled = (-not $Busy -and $null -ne $script:CurrentPackage)
        $openFolderButton.Enabled = (-not $Busy -and -not [string]::IsNullOrWhiteSpace($script:CurrentExtensionFolder))
        if (-not $Busy -and $null -ne $script:CurrentPackage) {
            try {
                $st = Get-InstallStatus $script:CurrentExtensionFolder $script:CurrentPackage
                $uninstallButton.Enabled = $st.Installed
            }
            catch { $uninstallButton.Enabled = $false }
        }
        else { $uninstallButton.Enabled = $false }
        [System.Windows.Forms.Application]::DoEvents()
    }

    $refreshSelected = {
        $script:CurrentPackage = $null
        $script:CurrentExtensionFolder = ""
        $archiveValue.Text = "—"
        $versionValue.Text = "—"
        $idValue.Text = "—"
        $statusValue.Text = "—"
        $installButton.Enabled = $false
        $uninstallButton.Enabled = $false
        $openFolderButton.Enabled = $false
        if ($extensionCombo.SelectedIndex -lt 0) { return }
        try {
            $itemName = [string]$extensionCombo.SelectedItem
            if ([string]::IsNullOrWhiteSpace($itemName) -or -not $script:ExtensionFolderMap.ContainsKey($itemName)) { throw "Не удалось определить папку выбранного расширения." }
            $script:CurrentExtensionFolder = [string]$script:ExtensionFolderMap[$itemName]
            $zip = Get-LatestZip $script:CurrentExtensionFolder
            $package = Read-ManifestFromZip $zip.FullName
            $script:CurrentPackage = $package
            $archiveValue.Text = $zip.Name + "   (" + $zip.LastWriteTime.ToString("dd.MM.yyyy HH:mm:ss") + ")"
            $versionValue.Text = $package.Version + "   •   Manifest V" + $package.ManifestVersion
            $status = Get-InstallStatus $script:CurrentExtensionFolder $package
            $idValue.Text = if ([string]::IsNullOrWhiteSpace($status.ExtensionId)) { "будет создан при первой установке" } else { $status.ExtensionId }
            $statusValue.Text = $status.Text
            $installButton.Enabled = $true
            $uninstallButton.Enabled = $status.Installed
            $openFolderButton.Enabled = $true
            Write-Log "INFO" ("Выбрано расширение: " + $itemName + "; ZIP: " + $zip.FullName)
            & $setNotice ("Выбрано: " + $package.Name + " " + $package.Version) "info"
        }
        catch {
            Write-LogException "Не удалось прочитать выбранное расширение" $_
            & $setNotice ("Ошибка: " + $_.Exception.Message) "error"
        }
    }

    $refreshExtensionList = {
        param([bool]$PreserveSelection)
        if ([string]::IsNullOrWhiteSpace($script:CurrentRoot) -or -not (Test-Path -LiteralPath $script:CurrentRoot -PathType Container)) {
            $extensionCombo.Items.Clear()
            $script:ExtensionFolderMap = @{}
            $script:CurrentPackage = $null
            $script:CurrentExtensionFolder = ""
            $extensionCombo.Enabled = $false
            $archiveValue.Text = "—"
            $versionValue.Text = "—"
            $idValue.Text = "—"
            $statusValue.Text = "—"
            return
        }

        $selectedName = ""
        if ($PreserveSelection -and $extensionCombo.SelectedIndex -ge 0) {
            $selectedName = [string]$extensionCombo.SelectedItem
        }

        try {
            $folders = @(Get-ExtensionFolders $script:CurrentRoot)
            $extensionCombo.BeginUpdate()
            try {
                $extensionCombo.Items.Clear()
                $script:ExtensionFolderMap = @{}
                foreach ($folder in $folders) {
                    $name = [string]$folder.Name
                    $path = [string]$folder.Path
                    if (-not [string]::IsNullOrWhiteSpace($name) -and -not [string]::IsNullOrWhiteSpace($path)) {
                        $script:ExtensionFolderMap[$name] = $path
                        [void]$extensionCombo.Items.Add($name)
                    }
                }
            }
            finally { $extensionCombo.EndUpdate() }

            $extensionCombo.Enabled = ($extensionCombo.Items.Count -gt 0)
            if ($extensionCombo.Items.Count -eq 0) {
                $script:CurrentPackage = $null
                $script:CurrentExtensionFolder = ""
                $archiveValue.Text = "—"
                $versionValue.Text = "—"
                $idValue.Text = "—"
                $statusValue.Text = "—"
                $installButton.Enabled = $false
                $uninstallButton.Enabled = $false
                $openFolderButton.Enabled = $false
                & $setNotice "В выбранной папке нет подпапок с ZIP-архивами расширений." "warning"
                return
            }

            $newIndex = 0
            if (-not [string]::IsNullOrWhiteSpace($selectedName)) {
                $foundIndex = $extensionCombo.FindStringExact($selectedName)
                if ($foundIndex -ge 0) { $newIndex = $foundIndex }
            }
            $extensionCombo.SelectedIndex = $newIndex
            Write-Log "INFO" ("Список расширений обновлён. Найдено: " + $extensionCombo.Items.Count)
        }
        catch {
            Write-LogException "Ошибка обновления списка расширений" $_
            & $setNotice ("Ошибка: " + $_.Exception.Message) "error"
        }
    }

    $loadRoot = {
        param([string]$RootFolder)
        if ([string]::IsNullOrWhiteSpace($RootFolder) -or -not (Test-Path -LiteralPath $RootFolder -PathType Container)) {
            $rootBox.Text = ""
            $script:CurrentRoot = ""
            & $refreshExtensionList $false
            & $setNotice "Выберите папку с расширениями." "info"
            return
        }
        try {
            $resolved = (Resolve-Path -LiteralPath $RootFolder).Path
            $script:CurrentRoot = $resolved
            $rootBox.Text = $resolved
            Save-Settings $resolved
            & $refreshExtensionList $false
        }
        catch {
            Write-LogException "Ошибка сканирования папки расширений" $_
            & $setNotice ("Ошибка: " + $_.Exception.Message) "error"
        }
    }

    $browseButton.Add_Click({
        try {
            Initialize-ModernFolderPicker
            $selectedPath = [ModernFolderPicker]::PickFolder($form.Handle, $script:BuilderDirectory, "Выберите папку с расширениями")
            if (-not [string]::IsNullOrWhiteSpace($selectedPath)) { & $loadRoot $selectedPath }
        }
        catch {
            Write-LogException "Ошибка выбора папки" $_
            & $setNotice ("Ошибка выбора папки: " + $_.Exception.Message) "error"
        }
    })


    $extensionCombo.Add_DropDown({
        if (-not [string]::IsNullOrWhiteSpace($script:CurrentRoot)) {
            & $refreshExtensionList $true
        }
    })

    $extensionCombo.Add_SelectedIndexChanged({ & $refreshSelected })

    $installButton.Add_Click({
        if ($null -eq $script:CurrentPackage) { & $setNotice "Расширение не выбрано." "warning"; return }
        & $setBusy $true
        & $setNotice "Установка / обновление..." "info"
        try {
            $result = Install-SelectedExtension $script:CurrentExtensionFolder $script:CurrentPackage
            & $setNotice ("Готово: установлена версия " + $result.Version + ".") "success"
            $enableGroup.Visible = $true
            $script:EnablePanelVisible = $true
            & $refreshSelected
            & $setNotice ("Готово: установлена версия " + $result.Version + ".") "success"
        }
        catch {
            Write-LogException "Установка/обновление завершилось ошибкой" $_
            & $setNotice ("Ошибка установки: " + $_.Exception.Message) "error"
        }
        finally { & $setBusy $false }
    })

    $uninstallButton.Add_Click({
        if ($null -eq $script:CurrentPackage) { & $setNotice "Расширение не выбрано." "warning"; return }
        & $setBusy $true
        & $setNotice "Удаление..." "info"
        try {
            [void](Uninstall-SelectedExtension $script:CurrentExtensionFolder $script:CurrentPackage)
            $enableGroup.Visible = $false
            $script:EnablePanelVisible = $false
            & $refreshSelected
            & $setNotice "Готово: расширение удалено. RSA-ключ сохранён." "success"
        }
        catch {
            Write-LogException "Удаление завершилось ошибкой" $_
            & $setNotice ("Ошибка удаления: " + $_.Exception.Message) "error"
        }
        finally { & $setBusy $false }
    })

    $openFolderButton.Add_Click({
        if (-not [string]::IsNullOrWhiteSpace($script:CurrentExtensionFolder) -and (Test-Path -LiteralPath $script:CurrentExtensionFolder -PathType Container)) {
            try { Start-Process explorer.exe -ArgumentList ('"' + $script:CurrentExtensionFolder + '"') | Out-Null; & $setNotice "Папка расширения открыта." "success" }
            catch { Write-LogException "Не удалось открыть папку" $_; & $setNotice ("Ошибка: " + $_.Exception.Message) "error" }
        }
    })

    $saveLogButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $dialog.Title = "Сохранить лог"
        $dialog.Filter = "Текстовый файл (*.txt)|*.txt|Все файлы (*.*)|*.*"
        $dialog.FileName = "extension-installer-" + (Get-Date).ToString("yyyyMMdd-HHmmss") + ".txt"
        if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            try {
                Copy-Item -LiteralPath $script:SessionLogPath -Destination $dialog.FileName -Force
                & $setNotice ("Лог сохранён: " + $dialog.FileName) "success"
            }
            catch { Write-LogException "Не удалось сохранить лог" $_; & $setNotice ("Ошибка сохранения лога: " + $_.Exception.Message) "error" }
        }
        $dialog.Dispose()
    })

    $copyHandler = {
        if (Copy-TuneAddress) { & $setNotice "Адрес browser://tune/ скопирован." "success" }
        else { & $setNotice "Не удалось скопировать адрес." "error" }
    }
    $tuneBox.Add_Click($copyHandler)
    $copyButton.Add_Click($copyHandler)
    $browserButton.Add_Click({
        if (Activate-YandexBrowser) { & $setNotice "Активировано открытое окно Яндекс.Браузера." "success" }
        else { & $setNotice "Открытое окно Яндекс.Браузера не найдено." "warning" }
    })

    $settings = Read-Settings
    if ($null -ne $settings) {
        $savedRoot = [string](Get-PropertyValue $settings "ExtensionsRoot" "")
        if (-not [string]::IsNullOrWhiteSpace($savedRoot) -and (Test-Path -LiteralPath $savedRoot -PathType Container)) { & $loadRoot $savedRoot }
    }

    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
    $form.Dispose()
}

try {
    Show-MainWindow
    Write-Log "INFO" "Установщик закрыт пользователем."
    exit 100
}
catch {
    Write-LogException "Критическая ошибка до/вне интерфейса" $_
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show(("Не удалось запустить Установщик расширений.`r`n`r`n" + $_.Exception.Message + "`r`n`r`nЛог: " + $script:SessionLogPath), "Установщик расширений", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    catch { }
    exit 2
}