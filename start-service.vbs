Option Explicit

Dim sh, fso, base, nodePath, programFiles, programFilesX86, command
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

base = fso.GetParentFolderName(WScript.ScriptFullName)
sh.CurrentDirectory = base

programFiles = sh.ExpandEnvironmentStrings("%ProgramFiles%")
programFilesX86 = sh.ExpandEnvironmentStrings("%ProgramFiles(x86)%")

nodePath = programFiles & "\nodejs\node.exe"

If Not fso.FileExists(nodePath) Then
    nodePath = programFilesX86 & "\nodejs\node.exe"
End If

If Not fso.FileExists(nodePath) Then
    MsgBox "Node.js não foi encontrado. Reinstale o SEZ Print Service ou verifique a instalação do Node.js.", vbCritical, "SEZ Print Service"
    WScript.Quit 1
End If

command = Chr(34) & nodePath & Chr(34) & " " & Chr(34) & base & "\server.js" & Chr(34)
sh.Run command, 0, False

Set fso = Nothing
Set sh = Nothing
