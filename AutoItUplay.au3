#cs ----------------------------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2014 Spencer Machado

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

 AutoIt Version: 3.3.13.19 (Beta)
 Author:         Spencer Machado

 Script Function:
	Provide a one-click solution for launching games with Uplay DRM.

#ce ----------------------------------------------------------------------------

#include <File.au3>
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>

Global Const $DIR_UPLAY_GAMES = @ProgramFilesDir & "\Ubisoft\Ubisoft Game Launcher\games"
Global Const $DIR_AUTOIT_UPLAY_SETTINGS = @MyDocumentsDir & "\AutoIt Uplay"
Global Const $EXE_UPLAY = "Uplay.exe"
Global Const $FILE_AUTOIT_UPLAY_INI = $DIR_AUTOIT_UPLAY_SETTINGS & "\config.ini"
Global Const $FILE_UPLAY_SETTINGS = @LocalAppDataDir & "\Ubisoft Game Launcher\settings.yml"
Global Const $SEC_UPLAY_TIMEOUT = 60
Global Const $SEC_TRAYTIP_TIMEOUT = 10
Global Const $SETTING_AUTOLOGIN = "remember"
Global Const $SETTING_CLOUDSYNC = "syncsavegames"
Global Const $SETTING_OFFLINE = "forceoffline"
Global Const $SETTING_SECTION_USER = "user:"

Global $myName
Global $gameDir
Global $gameExe
Global $launchDelay = 0
Global $waitToCloseDelay = 1000

main()

Func main()
	$myName = StringLeft(@ScriptName, StringLen(@ScriptName) - 4)
	If Not (initialize()) Then
		; Initialization failed.
		Return
	EndIf
	Local $iStartedUplay = startUplay()
	launchGame()
	If $iStartedUplay Then
		waitAndClose()
	EndIf
EndFunc

; Read Ini file and walk through first time setup if it doesn't exist
Func initialize()
	; Look for global ini file
	If FileExists($FILE_AUTOIT_UPLAY_INI) Then
		; Read delay values from it
		$launchDelay = IniRead($FILE_AUTOIT_UPLAY_INI, "Config", "LaunchDelay", 0)
		$waitToCloseDelay = IniRead($FILE_AUTOIT_UPLAY_INI, "Config", "WaitToCloseDelay", 1000)
	EndIf

	Local $iniFile = @ScriptDir & "\" & $myName & ".ini"

	; Check if file exists
	If FileExists($iniFile) Then
		; Ini already exists so read the values
		$gameDir = IniRead($iniFile, "GameInfo", "Directory", "")
		$gameExe = IniRead($iniFile, "GameInfo", "Executable", "")
	Else
		; Ini doesn't exist. Attempt 1st time setup
		Local $setupResult = firstTimeSetup($iniFile)
		If $setupResult Then
			$response = MsgBox($MB_YESNO + $MB_ICONQUESTION, "Setup Complete", _
				"Setup for " & $myName & " is complete." & _
				@CRLF & @CRLF & _
				"Would you like to test it now?")
			If $response <> $IDYES Then
				; Doesn't want to continue.
				Return False
			EndIf
		Else
			; Setup failed (user cancelled)
			Return False
		EndIf
	EndIf

	; Check that the game still exists
	If Not (FileExists($gameDir & $gameExe)) Then
		MsgBox($MB_ICONERROR, "Game Not Found", "Could not find game at:" & @CRLF & @CRLF & _
		$gameDir & $gameExe & @CRLF & @CRLF & _
		"Please check the path or delete " & $myName & ".ini and run setup again.")
		Return False
	EndIf

	Return True
EndFunc

; Prompts user to select a game, saves a new ini file, and checks Uplay settings to prevent Cloud Save Sync errors
Func firstTimeSetup($iniFile)

	If Not (FileExists($DIR_AUTOIT_UPLAY_SETTINGS)) Then
		DirCreate($DIR_AUTOIT_UPLAY_SETTINGS)
	EndIf

	If Not (FileExists($FILE_AUTOIT_UPLAY_INI)) Then
		IniWrite($FILE_AUTOIT_UPLAY_INI, "Config", "LaunchDelay", 0)
		IniWrite($FILE_AUTOIT_UPLAY_INI, "Config", "WaitToCloseDelay", 1000)
	EndIf

	Local $selectedFile = FileOpenDialog("Select Game", $DIR_UPLAY_GAMES, "Executable (*.exe)", $FD_FILEMUSTEXIST)

	If $selectedFile == "" Then
		Return False
	EndIf

	$endOfDir = StringInStr($selectedFile, "\", 1, -1)
	$gameDir = StringLeft($selectedFile, $endOfDir)
	$gameExe = StringRight($selectedFile, StringLen($selectedFile) - $endOfDir)
	IniWrite($iniFile, "GameInfo", "Directory", $gameDir)
	IniWrite($iniFile, "GameInfo", "Executable", $gameExe)

	checkUplaySettings()

	Return True
EndFunc

; Checks Uplay settings and display message if cloud sync is enabled or if autologin isn't enabled
Func checkUplaySettings()
	Local $uplaySettings = $FILE_UPLAY_SETTINGS

	If Not (FileExists($uplaySettings)) Then
		; Unable to find settings file. Show warning just in case
		showLightSyncWarning()
		Return
	EndIf

	Local $forceOffline, $autologin, $cloudSync

	FileOpen($uplaySettings, 0)

	Local $userSettingsStart = -1
	For $i = 1 to _FileCountLines($uplaySettings)
		$line = FileReadLine($uplaySettings, $i)
		If StringInStr($line, $SETTING_SECTION_USER, 1, 1, 1, 5) Then
			$userSettingsStart = $i
			ExitLoop
		EndIf
	Next

	If $userSettingsStart = -1 Then
		; Unable to find user settings. Show warning just in case
		showLightSyncWarning()
		Return
	EndIf

	For $i = $userSettingsStart + 1 to _FileCountLines($uplaySettings)
		$line = FileReadLine($uplaySettings, $i)
		If Not (StringInStr($line, "  ", 1, 1, 1, 2)) Then
			; Reached the end of the section
			ExitLoop
		ElseIf StringInStr($line, $SETTING_OFFLINE, 1) Then
			; Found force offline
			$forceOffline = readBoolean($line)
		ElseIf StringInStr($line, $SETTING_AUTOLOGIN, 1) Then
			; Found autologin
			$autologin = readBoolean($line)
		ElseIf StringInStr($line, $SETTING_CLOUDSYNC, 1) Then
			; Found cloud sync
			$cloudSync = readBoolean($line)
		EndIf
	Next

	FileClose($uplaySettings)

	; Check Cloud Sync
	If Not ($forceOffline) And $cloudSync Then
		MsgBox($MB_ICONWARNING, "Uplay Cloud Save Sync Detected", _
			"This program closes Uplay after the game finishes, which may interfere with the cloud save syncing process." & _
			@CRLF & @CRLF & _
			"According to your settings, you have ""Cloud Save Synchronization"" is enabled in Uplay. " & _
			"Please disable it in Settings under General. " & _
			"You can also force Uplay into Offline Mode under Network.")
	EndIf

	; Check autologin
	If Not ($autologin) Then
		MsgBox($MB_ICONINFORMATION, "Uplay Auto Login Disabled", "Auto Login for Uplay is disabled. " & _
			"You should consider enabling it to avoid signing in each time to launch a game." & _
			@CRLF & @CRLF & _
			"You can enable it by checking ""Remember me"" on the Uplay Login screen.")
	EndIf

EndFunc

; Displays a friendly warning to avoid using Uplay's cloud save sync with this program
Func showLightSyncWarning()
	MsgBox($MB_ICONINFORMATION, "Avoid Uplay Cloud Save Sync", _
		"This program closes Uplay after the game finishes, which may interfere with the cloud save syncing process." & _
		@CRLF & @CRLF & _
		"If ""Cloud Save Synchronization"" is enabled in Uplay, " & _
		"please disable it in Settings under General. " & _
		"You can also force Uplay into Offline Mode under Network.")
EndFunc

; Reads the boolean from the Uplay settings file
Func readBoolean($string)
	Return StringInStr($string, "true", 0, -1) <> 0
EndFunc

; Starts Uplay if needed. Returns true if started, false if it was already running
Func startUplay()
	; Check if uplay process is already running
	If ProcessExists($EXE_UPLAY) Then
		; Uplay was already running
		Return False
	Else
		Run($gameDir & $gameExe)
		; Wait for main Uplay window to appear
		$windowHandle = WinWaitActive("[TITLE:Uplay; CLASS:PlatformViewClassSession0]", "", $SEC_UPLAY_TIMEOUT)
		If $windowHandle = 0 Then
			TrayTip("AutoIt Uplay Timeout", $myName & " timed out while waiting for Uplay to start", $SEC_TRAYTIP_TIMEOUT)
			Sleep($SEC_TRAYTIP_TIMEOUT * 1000)
			Exit
		EndIf
		Return True
	EndIf
EndFunc

; Launches the game.
Func launchGame()
	Sleep($launchDelay)

	; Make sure the process wasn't closed during delay
	If ProcessExists($EXE_UPLAY) Then
		Run($gameDir & $gameExe)
	Else
		; Uplay isn't running anymore (closed during sleep?) . Just exit.
		Exit
	EndIf

EndFunc

; Waits for the game to finish and shuts down Uplay
Func waitAndClose()
	ProcessWait($gameExe)
	Sleep($waitToCloseDelay)
	ProcessWaitClose($gameExe)
	ProcessClose($EXE_UPLAY)
EndFunc
