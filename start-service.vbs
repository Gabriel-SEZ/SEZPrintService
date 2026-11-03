Option Explicit
Dim shell, fso, folder, launcher
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
folder = fso.GetParentFolderName(WScript.ScriptFullName)
launcher = fso.BuildPath(folder, "start-service.cmd")
If Not fso.FileExists(launcher) Then
    MsgBox "Arquivo start-service.cmd não encontrado em: " & folder, vbCritical, "SEZ Print Service"
    WScript.Quit 1
End If
shell.CurrentDirectory = folder
shell.Run Chr(34) & launcher & Chr(34), 0, False
Set fso = Nothing
Set shell = Nothing
