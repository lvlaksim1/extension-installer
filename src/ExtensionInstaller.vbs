Option Explicit

Dim shell, fso, appDir, scriptPath, powershellPath, command
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

appDir = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fso.BuildPath(appDir, "ExtensionInstaller.ps1")
powershellPath = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")

If Not fso.FileExists(scriptPath) Then
    MsgBox "ExtensionInstaller.ps1 not found: " & scriptPath, vbCritical, "ExtensionInstaller"
    WScript.Quit 2
End If

shell.CurrentDirectory = appDir
command = """" & powershellPath & """ -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptPath & """"
shell.Run command, 0, False
