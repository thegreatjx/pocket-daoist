' Double-click launcher for the game.
' Flow: locate godot.exe -> rebuild import cache (hidden) -> launch game window.
'
' Why rebuild cache silently:
'   GDScript class_name globals need .godot\global_script_class_cache.cfg.
'   Without it, scripts fail to parse and the game window closes instantly.
'
' NOTE: keep this file ASCII-only. WScript reads .vbs as ANSI (GBK on zh-CN),
'   and UTF-8 Chinese bytes can swallow the closing quote of a string.

Option Explicit

Dim shell, fso, projectDir, godotExe, logPath
Set shell = CreateObject("WScript.Shell")
Set fso   = CreateObject("Scripting.FileSystemObject")

projectDir = fso.GetParentFolderName(WScript.ScriptFullName)
shell.CurrentDirectory = projectDir
logPath = projectDir & "\play_log.txt"

Sub Log(msg)
    On Error Resume Next
    Dim ts
    Set ts = fso.OpenTextFile(logPath, 8, True)
    ts.WriteLine Now & "  " & msg
    ts.Close
    Set ts = Nothing
    On Error GoTo 0
End Sub

Function ResolveGodot()
    Dim candidates, c, exec, line
    candidates = Array( _
        shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Microsoft\WinGet\Links\godot.exe", _
        "C:\Program Files\Godot\godot.exe", _
        "C:\Godot\godot.exe" _
    )
    For Each c In candidates
        If fso.FileExists(c) Then
            ResolveGodot = c
            Exit Function
        End If
    Next
    ' Fallback: search PATH via where.exe
    On Error Resume Next
    Set exec = shell.Exec("cmd /c where godot 2>nul")
    If Err.Number = 0 And Not (exec Is Nothing) Then
        Do While Not exec.StdOut.AtEndOfStream
            line = Trim(exec.StdOut.ReadLine())
            If LCase(Right(line, 10)) = "godot.exe" Then
                ResolveGodot = line
                Exit Function
            End If
        Loop
    End If
    Err.Clear
    On Error GoTo 0
    ResolveGodot = ""
End Function

godotExe = ResolveGodot()
If godotExe = "" Then
    Log "FATAL: godot.exe not found"
    MsgBox "Godot 4 engine not found." & vbCrLf & vbCrLf & _
           "Make sure 'godot --version' works in a terminal," & vbCrLf & _
           "or see play_log.txt next to this file.", vbCritical, "Launch failed"
    WScript.Quit 1
End If

Log "godot=" & godotExe

' Step 1: rebuild asset + global class cache (0 = hidden window, True = wait)
Log "import_start"
shell.Run """" & godotExe & """ --headless --path """ & projectDir & """ --import", 0, True
Log "import_done"

' Step 2: launch the game (1 = normal window, False = do not wait)
Log "launch_game"
shell.Run """" & godotExe & """ --path """ & projectDir & """", 1, False
Log "launch_returned"
