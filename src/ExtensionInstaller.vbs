Option Explicit

Dim shell, fso, appDir, cmdPath
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

appDir = fso.GetParentFolderName(WScript.ScriptFullName)
cmdPath = fso.BuildPath(appDir, "ExtensionInstaller.cmd")

If Not fso.FileExists(cmdPath) Then
    MsgBox "ExtensionInstaller.cmd не найден: " & cmdPath, vbCritical, "ExtensionInstaller"
    WScript.Quit 2
End If

shell.CurrentDirectory = appDir
shell.Run """" & cmdPath & """", 0, False
