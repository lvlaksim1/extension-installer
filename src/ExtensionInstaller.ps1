# ExtensionInstaller clean GUI.
# Windows PowerShell 5.1 compatible.
# The application consumes only signed extension releases from the catalog.

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppRoot = $PSScriptRoot
$script:CatalogPath = Join-Path $script:AppRoot "catalog\extensions.json"
$script:ReleaseEnginePath = Join-Path $script:AppRoot "ReleaseInstaller.ps1"
$script:DataRoot = Join-Path $env:LOCALAPPDATA "ExtensionInstaller"
$script:InstallRoot = Join-Path $script:DataRoot "extensions"
$script:LogRoot = Join-Path $script:DataRoot "logs"
$script:DownloadRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ExtensionInstaller\downloads"
$script:CurrentLogPath = Join-Path $script:LogRoot ("ExtensionInstaller-" + (Get-Date -Format "yyyyMMdd") + ".log")
$script:CatalogEntries = @()
$script:ResolvedRelease = $null
$script:LogBox = $null

foreach ($path in @($script:DataRoot, $script:InstallRoot, $script:LogRoot, $script:DownloadRoot)) {
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

if (-not (Test-Path -LiteralPath $script:ReleaseEnginePath -PathType Leaf)) {
    [System.Windows.Forms.MessageBox]::Show(
        ("ReleaseInstaller.ps1 не найден:" + [Environment]::NewLine + $script:ReleaseEnginePath),
        "ExtensionInstaller",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 2
}

. $script:ReleaseEnginePath

function Write-AppLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    try {
        Add-Content -LiteralPath $script:CurrentLogPath -Value $line -Encoding UTF8
    }
    catch { }

    if ($null -ne $script:LogBox -and -not $script:LogBox.IsDisposed) {
        $script:LogBox.AppendText($line + [Environment]::NewLine)
        $script:LogBox.SelectionStart = $script:LogBox.TextLength
        $script:LogBox.ScrollToCaret()
    }
}

function Remove-ResolvedWorkingRoot {
    if ($null -eq $script:ResolvedRelease) { return }
    $root = [string](Get-ReleaseProperty $script:ResolvedRelease "WorkingRoot" "")
    if (-not [string]::IsNullOrWhiteSpace($root) -and (Test-PathUnderRoot $root $script:DownloadRoot)) {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
    $script:ResolvedRelease = $null
}

function Get-SelectedCatalogEntry {
    if ($script:ExtensionCombo.SelectedIndex -lt 0) { return $null }
    if ($script:ExtensionCombo.SelectedIndex -ge $script:CatalogEntries.Count) { return $null }
    return $script:CatalogEntries[$script:ExtensionCombo.SelectedIndex]
}

function Get-InstallSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        $Entry
    )

    $extensionId = [string](Get-ReleaseProperty $Entry "extension_id" "")
    $extensionRoot = Join-Path $script:InstallRoot $extensionId
    $crxRoot = Join-Path $extensionRoot "crx"
    $statePath = Join-Path $extensionRoot "state.json"
    $ownershipPath = Join-Path $extensionRoot "ownership.json"

    $state = Read-ReleaseInstallState $statePath
    $ownership = Read-ReleaseOwnershipMarker $ownershipPath
    $yandex = Get-ReleaseYandexValues $extensionId
    $browserProfileEntries = @(Get-ReleaseYandexProfileInstallations $extensionId)
    $browserInstallations = @($browserProfileEntries | Where-Object { -not [bool]$_.IsExternalUninstalled })
    $externalUninstallProfiles = @(Get-ReleaseYandexExternalUninstallProfiles $extensionId)

    # Persisted state=2 (EXTERNAL_EXTENSION_UNINSTALLED) or external_uninstalls means
    # "do not reinstall", not an installed extension. Never present it as Installed.
    $removedByUser = ($externalUninstallProfiles.Count -gt 0)
    $browserInstalled = ($browserInstallations.Count -gt 0 -and -not $removedByUser)
    $legacy = ($null -ne $yandex -and (Test-ReleaseLegacyYandexRegistration $yandex $extensionId))
    $foreign = $false
    $managed = $false
    $browserOnly = $false
    $removedByInstaller = $false
    $installedVersion = ""

    if ($browserInstalled) {
        $best = @($browserInstallations | Sort-Object -Property @{ Expression = {
            try { [version]$_.Version } catch { [version]"0.0" }
        }; Descending = $true } | Select-Object -First 1)
        if ($best.Count -eq 1) { $installedVersion = [string]$best[0].Version }
    }

    if ($null -ne $yandex) {
        if ($null -ne $state) {
            $managed = (
                [string]$yandex.Path -ceq [string](Get-ReleaseProperty $state "CrxPath" "") -and
                (Test-PathUnderRoot ([string]$yandex.Path) $crxRoot)
            )
            if (-not $managed) { $foreign = $true }
        }
        elseif (Test-PathUnderRoot ([string]$yandex.Path) $crxRoot) { $managed = $true }
        elseif ($legacy) { $managed = $false }
        else { $foreign = $true }
    }
    elseif ($null -ne $state) { $managed = $true }

    # A browser-profile entry with the trusted catalog Extension ID but no external
    # registry/state is not a "foreign registration". It can be a residual entry after
    # our own live uninstall or a browser-managed installation of the same signed ID.
    if ($browserInstalled -and $null -eq $yandex -and $null -eq $state) {
        $browserOnly = $true
    }

    if ($null -ne $ownership -and $null -eq $state) {
        $markerId = [string](Get-ReleaseProperty $ownership "ExtensionId" "")
        $markerVersion = [string](Get-ReleaseProperty $ownership "LastVersion" "")
        if ($markerId -ceq $extensionId) {
            if (-not $browserInstalled -or [string]::IsNullOrWhiteSpace($markerVersion) -or $installedVersion -ceq $markerVersion) {
                $removedByInstaller = $true
                $foreign = $false
            }
        }
    }

    return [pscustomobject]@{
        ExtensionId = $extensionId
        ExtensionRoot = $extensionRoot
        CrxRoot = $crxRoot
        State = $state
        Ownership = $ownership
        Yandex = $yandex
        BrowserProfileEntries = $browserProfileEntries
        BrowserInstallations = $browserInstallations
        BrowserInstalled = $browserInstalled
        BrowserProfileCount = @($browserInstallations | Select-Object -ExpandProperty Profile -Unique).Count
        RemovedByUser = $removedByUser
        RemovedByInstaller = $removedByInstaller
        BrowserOnly = $browserOnly
        ExternalUninstallProfileCount = $externalUninstallProfiles.Count
        Managed = $managed
        Legacy = $legacy
        Foreign = $foreign
        InstalledVersion = $installedVersion
        HasState = ($null -ne $state)
        HasOwnership = ($null -ne $ownership)
        HasRegistry = ($null -ne $yandex)
    }
}

function Activate-ExtensionInstallerWindow {
    try {
        if ($null -eq $script:Form -or $script:Form.IsDisposed) { return $false }
        if ($script:Form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
            $script:Form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        }
        $script:Form.Show()
        $script:Form.BringToFront()
        $script:Form.Activate()
        [System.Windows.Forms.Application]::DoEvents()
        return (Activate-ReleaseWindowHandle -Handle $script:Form.Handle)
    }
    catch { return $false }
}

function Show-ExtensionInstallerMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [string]$Caption,
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )

    [void](Activate-ExtensionInstallerWindow)
    return [System.Windows.Forms.MessageBox]::Show($script:Form, $Text, $Caption, $Buttons, $Icon)
}

function Set-Busy {
    param([bool]$Busy)

    $script:Form.UseWaitCursor = $Busy
    $script:ExtensionCombo.Enabled = -not $Busy
    $script:RefreshButton.Enabled = -not $Busy
    if ($Busy) {
        $script:InstallButton.Enabled = $false
        $script:UninstallButton.Enabled = $false
    }
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-StatusText {
    param(
        [string]$Text,
        [ValidateSet("Normal","Good","Error","Warn")]
        [string]$Kind = "Normal"
    )

    $script:StateValue.Text = $Text
    switch ($Kind) {
        "Good"  { $script:StateValue.ForeColor = [System.Drawing.Color]::DarkGreen }
        "Error" { $script:StateValue.ForeColor = [System.Drawing.Color]::Firebrick }
        "Warn"  { $script:StateValue.ForeColor = [System.Drawing.Color]::DarkOrange }
        default { $script:StateValue.ForeColor = [System.Drawing.SystemColors]::ControlText }
    }
}

function Update-UiFromState {
    param(
        [Parameter(Mandatory = $true)]
        $Entry
    )

    $snapshot = Get-InstallSnapshot $Entry
    $script:InstalledVersionValue.Text = if ($snapshot.RemovedByInstaller -or [string]::IsNullOrWhiteSpace($snapshot.InstalledVersion)) { "—" } else { $snapshot.InstalledVersion }

    $availableVersion = ""
    if ($null -ne $script:ResolvedRelease) { $availableVersion = [string](Get-ReleaseProperty $script:ResolvedRelease "Version" "") }

    if ($snapshot.Foreign) {
        Set-StatusText "Обнаружена сторонняя установка/регистрация с этим Extension ID" "Warn"
        $script:InstallButton.Text = "Установить"
        $script:InstallButton.Enabled = $false
        $script:UninstallButton.Enabled = $false
        return
    }

    if ($snapshot.RemovedByInstaller) {
        Set-StatusText "Удалено через ExtensionInstaller; можно установить снова без перезапуска браузера" "Warn"
        $script:InstallButton.Text = "Установить снова"
        $script:InstallButton.Enabled = ($null -ne $script:ResolvedRelease)
        $script:UninstallButton.Enabled = $false
        return
    }

    if ($snapshot.BrowserOnly) {
        Set-StatusText "Расширение есть в профиле Яндекс.Браузера без регистрации ExtensionInstaller" "Warn"
        $script:InstallButton.Text = "Подключить / переустановить"
        $script:InstallButton.Enabled = ($null -ne $script:ResolvedRelease)
        $script:UninstallButton.Enabled = $false
        return
    }

    if ($snapshot.BrowserInstalled -and $snapshot.Legacy) {
        Set-StatusText "Установлено предыдущей версией ExtensionInstaller" "Warn"
        if (-not [string]::IsNullOrWhiteSpace($availableVersion) -and $snapshot.InstalledVersion -cne $availableVersion) {
            $script:InstallButton.Text = "Обновить"
        }
        else { $script:InstallButton.Text = "Перенести" }
        $script:InstallButton.Enabled = ($null -ne $script:ResolvedRelease)
        $script:UninstallButton.Enabled = $true
        return
    }

    if ($snapshot.BrowserInstalled -and $snapshot.Managed) {
        if (-not [string]::IsNullOrWhiteSpace($availableVersion) -and $snapshot.InstalledVersion -cne $availableVersion) {
            Set-StatusText "Доступно обновление" "Warn"
            $script:InstallButton.Text = "Обновить"
        }
        else {
            Set-StatusText "Установлено" "Good"
            $script:InstallButton.Text = "Переустановить"
        }
        $script:InstallButton.Enabled = ($null -ne $script:ResolvedRelease)
        $script:UninstallButton.Enabled = $true
        return
    }

    if ($snapshot.RemovedByUser) {
        Set-StatusText "Удалено через Яндекс.Браузер; можно установить снова без перезапуска браузера" "Warn"
        $script:InstallButton.Text = "Установить снова"
        $script:InstallButton.Enabled = ($null -ne $script:ResolvedRelease)
        $script:UninstallButton.Enabled = ($snapshot.HasRegistry -or $snapshot.HasState -or $snapshot.Legacy)
        return
    }

    if (-not $snapshot.BrowserInstalled -and $snapshot.Legacy) {
        Set-StatusText "Не установлено; осталась регистрация предыдущей версии ExtensionInstaller" "Warn"
        $script:InstallButton.Text = "Установить"
        $script:InstallButton.Enabled = ($null -ne $script:ResolvedRelease)
        $script:UninstallButton.Enabled = $true
        return
    }

    if (-not $snapshot.BrowserInstalled -and $snapshot.Managed -and $snapshot.HasRegistry) {
        if (Test-ReleaseYandexBrowserRunning) {
            Set-StatusText "Зарегистрировано; можно применить в открытом Яндекс.Браузере без перезапуска" "Warn"
            $script:InstallButton.Text = "Применить в браузере"
        }
        else {
            Set-StatusText "Зарегистрировано; будет применено при следующем запуске Яндекс.Браузера" "Warn"
            $script:InstallButton.Text = "Переустановить"
        }
        $script:InstallButton.Enabled = ($null -ne $script:ResolvedRelease)
        $script:UninstallButton.Enabled = $true
        return
    }

    if (-not $snapshot.BrowserInstalled -and $snapshot.Managed -and -not $snapshot.HasRegistry) {
        Set-StatusText "Состояние ExtensionInstaller найдено, запись браузера отсутствует" "Warn"
        $script:InstallButton.Text = "Восстановить"
        $script:InstallButton.Enabled = ($null -ne $script:ResolvedRelease)
        $script:UninstallButton.Enabled = $true
        return
    }

    if (-not $snapshot.BrowserInstalled -and -not $snapshot.HasRegistry -and -not $snapshot.HasState) {
        Set-StatusText "Не установлено" "Normal"
        $script:InstallButton.Text = "Установить"
        $script:InstallButton.Enabled = ($null -ne $script:ResolvedRelease)
        $script:UninstallButton.Enabled = $false
        return
    }

    Set-StatusText "Неизвестное состояние" "Warn"
    $script:InstallButton.Enabled = $false
    $script:UninstallButton.Enabled = $false
}

function Refresh-SelectedExtension {
    $entry = Get-SelectedCatalogEntry
    if ($null -eq $entry) { return }

    Set-Busy $true
    try {
        Remove-ResolvedWorkingRoot

        $script:AvailableVersionValue.Text = "Проверяется…"
        $script:ExtensionIdValue.Text = [string](Get-ReleaseProperty $entry "extension_id" "")
        Set-StatusText "Проверка GitHub Release…" "Normal"
        [System.Windows.Forms.Application]::DoEvents()

        Write-AppLog ("Проверка релиза: " + [string](Get-ReleaseProperty $entry "name" ""))
        $resolved = Resolve-LatestSignedExtensionRelease $entry $script:DownloadRoot
        $script:ResolvedRelease = $resolved

        $script:AvailableVersionValue.Text = [string]$resolved.Version
        $script:ReleaseValue.Text = [string]$resolved.ReleaseTag
        Write-AppLog ("Релиз проверен: version=" + $resolved.Version + "; id=" + $resolved.ExtensionId + "; sha256=" + $resolved.Sha256)

        Update-UiFromState $entry
    }
    catch {
        $script:ResolvedRelease = $null
        $script:AvailableVersionValue.Text = "—"
        $script:ReleaseValue.Text = "—"
        Update-UiFromState $entry
        Set-StatusText ("Ошибка проверки: " + $_.Exception.Message) "Error"
        Write-AppLog $_.Exception.Message "ERROR"
    }
    finally {
        Set-Busy $false
    }
}

function Install-SelectedExtension {
    $entry = Get-SelectedCatalogEntry
    if ($null -eq $entry) { return }

    Set-Busy $true
    try {
        if ($null -eq $script:ResolvedRelease) {
            Write-AppLog "Перед установкой выполняется повторная проверка релиза."
            $script:ResolvedRelease = Resolve-LatestSignedExtensionRelease $entry $script:DownloadRoot
        }

        $before = Get-InstallSnapshot $entry
        $name = [string](Get-ReleaseProperty $entry "name" "")
        $beforeBrowserInstalled = [bool](Get-ReleaseProperty $before "BrowserInstalled" $false)
        $beforeVersion = [string](Get-ReleaseProperty $before "InstalledVersion" "")
        $targetVersion = [string]$script:ResolvedRelease.Version
        $isVersionUpdate = (
            $beforeBrowserInstalled -and
            -not [string]::IsNullOrWhiteSpace($beforeVersion) -and
            $beforeVersion -cne $targetVersion
        )

        Write-AppLog ("Установка: " + $name + " " + $targetVersion)
        $installWatch = [System.Diagnostics.Stopwatch]::StartNew()
        $result = Install-ValidatedSignedRelease $script:ResolvedRelease $script:InstallRoot
        $installWatch.Stop()

        $browserRunning = [bool](Get-ReleaseProperty $result "BrowserWasRunning" $false)
        $browserConfirmationRequired = [bool](Get-ReleaseProperty $result "BrowserConfirmationRequired" $false)
        $browserObservedInstalled = [bool](Get-ReleaseProperty $result "BrowserObservedInstalled" $false)
        $liveResetPerformed = [bool](Get-ReleaseProperty $result "LiveResetPerformed" $false)
        $liveResetCleared = [bool](Get-ReleaseProperty $result "LiveResetCleared" $false)
        $registrationValuesChanged = [bool](Get-ReleaseProperty $result "RegistrationValuesChanged" $false)
        Write-AppLog ("Установка подготовлена: id=" + $result.ExtensionId + "; version=" + $result.Version + "; install_ms=" + [int]$installWatch.ElapsedMilliseconds + "; browser_running=" + $browserRunning + "; live_reset=" + $liveResetPerformed + "; live_reset_cleared=" + $liveResetCleared + "; live_reset_ms=" + [int](Get-ReleaseProperty $result "LiveResetElapsedMilliseconds" 0) + "; registry_in_place=" + [bool](Get-ReleaseProperty $result "RegistrationInPlace" $false) + "; registry_values_changed=" + $registrationValuesChanged + "; browser_confirmation_required=" + $browserConfirmationRequired + "; browser_observed_installed=" + $browserObservedInstalled + "; browser_observe_ms=" + [int](Get-ReleaseProperty $result "BrowserObserveElapsedMilliseconds" 0))

        $message = ""
        if ($browserRunning) {
            if ($browserConfirmationRequired -and -not $browserObservedInstalled) {
                $message = (
                    "Регистрация " + $name + " " + $result.Version + " восстановлена, но Яндекс.Браузер пока не подтвердил повторную загрузку расширения." +
                    [Environment]::NewLine + [Environment]::NewLine +
                    "ExtensionInstaller не открывал новое окно браузера. Если расширение не появится в течение нескольких секунд, проверьте его состояние в уже открытом Яндекс.Браузере."
                )
            }
            elseif ($isVersionUpdate) {
                $message = (
                    $name + " обновлён до версии " + $result.Version + "." +
                    [Environment]::NewLine + [Environment]::NewLine +
                    "Перезапуск Яндекс.Браузера не требуется."
                )
            }
            elseif ($beforeBrowserInstalled) {
                $message = (
                    $name + " " + $result.Version + " переустановлен." +
                    [Environment]::NewLine + [Environment]::NewLine +
                    "Перезапуск Яндекс.Браузера не требуется."
                )
            }
            else {
                $message = (
                    $name + " " + $result.Version + " зарегистрирован." +
                    [Environment]::NewLine + [Environment]::NewLine +
                    "Перезапуск Яндекс.Браузера не требуется; браузер подхватит расширение автоматически."
                )
            }
        }
        else {
            $message = (
                $name + " " + $result.Version + " зарегистрирован." +
                [Environment]::NewLine + [Environment]::NewLine +
                "Яндекс.Браузер сейчас не запущен; при следующем обычном запуске он подхватит расширение автоматически."
            )
        }

        Show-ExtensionInstallerMessage -Text $message -Caption "ExtensionInstaller" -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) -Icon ([System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    }
    catch {
        Write-AppLog $_.Exception.Message "ERROR"
        Show-ExtensionInstallerMessage -Text $_.Exception.Message -Caption "Ошибка установки" -Buttons ([System.Windows.Forms.MessageBoxButtons]::OK) -Icon ([System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
    finally {
        Set-Busy $false
        Update-UiFromState $entry
    }
}
function Uninstall-SelectedExtension {
    $entry = Get-SelectedCatalogEntry
    if ($null -eq $entry) { return }

    $name = [string](Get-ReleaseProperty $entry "name" "")
    $answer = [System.Windows.Forms.MessageBox]::Show(
        ("Удалить расширение «" + $name + "» из Яндекс.Браузера?"),
        "ExtensionInstaller",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    Set-Busy $true
    try {
        $extensionId = [string](Get-ReleaseProperty $entry "extension_id" "")
        $result = Uninstall-ReleaseExtension $extensionId $script:InstallRoot
        Write-AppLog ("Расширение удалено: " + $name + "; id=" + $extensionId + "; browser_running=" + [bool](Get-ReleaseProperty $result "BrowserWasRunning" $false) + "; ownership_marker=" + [string](Get-ReleaseProperty $result "OwnershipPath" ""))
    }
    catch {
        Write-AppLog $_.Exception.Message "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            "Ошибка удаления",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    finally {
        Set-Busy $false
        Update-UiFromState $entry
    }
}

function Save-CurrentLog {
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Title = "Сохранить лог ExtensionInstaller"
    $dialog.Filter = "Текстовый файл (*.txt)|*.txt|Все файлы (*.*)|*.*"
    $dialog.FileName = "ExtensionInstaller-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".txt"
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    try {
        [System.IO.File]::WriteAllText(
            $dialog.FileName,
            $script:LogBox.Text,
            (New-Object System.Text.UTF8Encoding($true))
        )
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            "Ошибка сохранения",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

$script:Form = New-Object System.Windows.Forms.Form
$script:Form.Text = "ExtensionInstaller"
$script:Form.StartPosition = "CenterScreen"
$script:Form.Size = New-Object System.Drawing.Size(760, 575)
$script:Form.MinimumSize = New-Object System.Drawing.Size(720, 540)
$script:Form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$script:Form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi

$title = New-Object System.Windows.Forms.Label
$title.Text = "Расширения"
$title.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 15)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(24, 20)
$script:Form.Controls.Add($title)

$description = New-Object System.Windows.Forms.Label
$description.Text = "Установка и обновление из проверенных GitHub Releases"
$description.AutoSize = $true
$description.ForeColor = [System.Drawing.SystemColors]::GrayText
$description.Location = New-Object System.Drawing.Point(27, 52)
$script:Form.Controls.Add($description)

$comboLabel = New-Object System.Windows.Forms.Label
$comboLabel.Text = "Расширение"
$comboLabel.AutoSize = $true
$comboLabel.Location = New-Object System.Drawing.Point(27, 91)
$script:Form.Controls.Add($comboLabel)

$script:ExtensionCombo = New-Object System.Windows.Forms.ComboBox
$script:ExtensionCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$script:ExtensionCombo.Location = New-Object System.Drawing.Point(30, 112)
$script:ExtensionCombo.Size = New-Object System.Drawing.Size(545, 28)
$script:ExtensionCombo.Anchor = "Top,Left,Right"
$script:Form.Controls.Add($script:ExtensionCombo)

$script:RefreshButton = New-Object System.Windows.Forms.Button
$script:RefreshButton.Text = "Проверить"
$script:RefreshButton.Location = New-Object System.Drawing.Point(590, 110)
$script:RefreshButton.Size = New-Object System.Drawing.Size(125, 30)
$script:RefreshButton.Anchor = "Top,Right"
$script:Form.Controls.Add($script:RefreshButton)

$group = New-Object System.Windows.Forms.GroupBox
$group.Text = "Состояние"
$group.Location = New-Object System.Drawing.Point(30, 158)
$group.Size = New-Object System.Drawing.Size(685, 168)
$group.Anchor = "Top,Left,Right"
$script:Form.Controls.Add($group)

function Add-ValueRow {
    param(
        [System.Windows.Forms.Control]$Parent,
        [string]$Caption,
        [int]$Y,
        [int]$ValueX = 190
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Caption
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(18, $Y)
    $Parent.Controls.Add($label)

    $value = New-Object System.Windows.Forms.Label
    $value.Text = "—"
    $value.AutoEllipsis = $true
    $value.Location = New-Object System.Drawing.Point($ValueX, $Y)
    $value.Size = New-Object System.Drawing.Size(470, 20)
    $value.Anchor = "Top,Left,Right"
    $Parent.Controls.Add($value)
    return $value
}

$script:AvailableVersionValue = Add-ValueRow $group "Доступная версия:" 30
$script:InstalledVersionValue = Add-ValueRow $group "Установленная версия:" 58
$script:ExtensionIdValue = Add-ValueRow $group "Extension ID:" 86
$script:ReleaseValue = Add-ValueRow $group "GitHub Release:" 114
$script:StateValue = Add-ValueRow $group "Состояние:" 142

$script:InstallButton = New-Object System.Windows.Forms.Button
$script:InstallButton.Text = "Установить"
$script:InstallButton.Location = New-Object System.Drawing.Point(30, 344)
$script:InstallButton.Size = New-Object System.Drawing.Size(170, 36)
$script:InstallButton.Enabled = $false
$script:Form.Controls.Add($script:InstallButton)

$script:UninstallButton = New-Object System.Windows.Forms.Button
$script:UninstallButton.Text = "Удалить"
$script:UninstallButton.Location = New-Object System.Drawing.Point(215, 344)
$script:UninstallButton.Size = New-Object System.Drawing.Size(130, 36)
$script:UninstallButton.Enabled = $false
$script:Form.Controls.Add($script:UninstallButton)

$saveLogButton = New-Object System.Windows.Forms.Button
$saveLogButton.Text = "Сохранить лог…"
$saveLogButton.Location = New-Object System.Drawing.Point(575, 344)
$saveLogButton.Size = New-Object System.Drawing.Size(140, 36)
$saveLogButton.Anchor = "Top,Right"
$script:Form.Controls.Add($saveLogButton)

$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Text = "Журнал"
$logLabel.AutoSize = $true
$logLabel.Location = New-Object System.Drawing.Point(27, 399)
$script:Form.Controls.Add($logLabel)

$script:LogBox = New-Object System.Windows.Forms.TextBox
$script:LogBox.Multiline = $true
$script:LogBox.ReadOnly = $true
$script:LogBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$script:LogBox.Location = New-Object System.Drawing.Point(30, 421)
$script:LogBox.Size = New-Object System.Drawing.Size(685, 100)
$script:LogBox.Anchor = "Top,Bottom,Left,Right"
$script:LogBox.BackColor = [System.Drawing.SystemColors]::Window
$script:Form.Controls.Add($script:LogBox)

$script:RefreshButton.Add_Click({ Refresh-SelectedExtension })
$script:InstallButton.Add_Click({ Install-SelectedExtension })
$script:UninstallButton.Add_Click({ Uninstall-SelectedExtension })
$saveLogButton.Add_Click({ Save-CurrentLog })

$script:ExtensionCombo.Add_SelectedIndexChanged({
    $entry = Get-SelectedCatalogEntry
    if ($null -eq $entry) { return }

    Remove-ResolvedWorkingRoot
    $script:AvailableVersionValue.Text = "—"
    $script:ReleaseValue.Text = "—"
    $script:ExtensionIdValue.Text = [string](Get-ReleaseProperty $entry "extension_id" "")
    Update-UiFromState $entry
})

$script:Form.Add_FormClosed({
    Remove-ResolvedWorkingRoot
})

try {
    $catalog = Read-ExtensionCatalog $script:CatalogPath
    $script:CatalogEntries = @($catalog.extensions)
    if ($script:CatalogEntries.Count -eq 0) {
        throw "Каталог расширений пуст."
    }

    foreach ($entry in $script:CatalogEntries) {
        [void]$script:ExtensionCombo.Items.Add([string](Get-ReleaseProperty $entry "name" ""))
    }

    $script:ExtensionCombo.SelectedIndex = 0
    Write-AppLog ("ExtensionInstaller запущен. Расширений в каталоге: " + $script:CatalogEntries.Count)

    $script:Form.Add_Shown({
        $script:Form.Activate()
        Refresh-SelectedExtension
    })

    [void][System.Windows.Forms.Application]::Run($script:Form)
}
catch {
    Write-AppLog $_.Exception.Message "ERROR"
    [System.Windows.Forms.MessageBox]::Show(
        $_.Exception.Message,
        "ExtensionInstaller",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}
