Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
base = fso.GetParentFolderName(WScript.ScriptFullName)
sh.CurrentDirectory = base
sh.Run """" & sh.ExpandEnvironmentStrings("%ProgramFiles%") & "\\nodejs\\node.exe"" """" & base & "\\server.js""""", 0, False
