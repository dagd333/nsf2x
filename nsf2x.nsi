﻿!define NAME "nsf2x"
!ifndef VERSION
    !define VERSION "X.X.X"
!endif
!ifndef PUBLISHER
    !define PUBLISHER "root@localhost"
!endif
!ifndef BITNESS
    !define BITNESS "x86"
!endif
!define UNINSTKEY "${NAME}-${VERSION}-${BITNESS}"

!define DEFAULTNORMALDESTINATON "$ProgramFiles\${NAME}-${VERSION}-${BITNESS}"
!define DEFAULTPORTABLEDESTINATON "$LocalAppdata\Programs\${NAME}-${VERSION}-${BITNESS}"

; Keep NSIS v3.0 Happy
Unicode true
ManifestDPIAware true

Name "${NAME}"
Outfile "${NAME}-${VERSION}-${BITNESS}-setup.exe"
RequestExecutionlevel highest
SetCompressor LZMA

Var NormalDestDir
Var LocalDestDir
Var InstallAllUsers
Var InstallAllUsersCtrl
Var InstallShortcuts
Var InstallShortcutsCtrl

!include LogicLib.nsh
!include FileFunc.nsh
!include MUI2.nsh
!include nsDialogs.nsh
!include registry.nsh

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE"
Page Custom OptionsPageCreate OptionsPageLeave
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_SHOWREADME $INSTDIR\README.txt
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!include "nsf2x_lang.nsi"

Function .onInit
StrCpy $NormalDestDir "${DEFAULTNORMALDESTINATON}"
StrCpy $LocalDestDir "${DEFAULTPORTABLEDESTINATON}"

${GetParameters} $9

ClearErrors
${GetOptions} $9 "/?" $8
${IfNot} ${Errors}
    MessageBox MB_ICONINFORMATION|MB_SETFOREGROUND "$(COMMANDLINE_HELP)"
    Quit
${EndIf}

ClearErrors
${GetOptions} $9 "/ALL" $8
${IfNot} ${Errors}
    StrCpy $0 $NormalDestDir
    ${If} ${Silent}
        Call RequireAdmin
    ${EndIf}
    SetShellVarContext all
    StrCpy $InstallAllUsers ${BST_CHECKED}
${Else}
    SetShellVarContext current
    StrCpy $0 $LocalDestDir
    StrCpy $InstallAllUsers ${BST_UNCHECKED}
${EndIf}

${GetOptions} $9 "/SHORTCUT" $8
${IfNot} ${Errors}
    StrCpy $InstallShortCuts ${BST_CHECKED}
${Else}
    StrCpy $InstallShortCuts ${BST_UNCHECKED}
${EndIf}

${If} $InstDir == ""
    ; User did not use /D to specify a directory, 
    ; we need to set a default based on the install mode
    StrCpy $InstDir $0
${EndIf}
Call SetModeDestinationFromInstdir
FunctionEnd

Function RequireAdmin
UserInfo::GetAccountType
Pop $8
${If} $8 != "admin"
    MessageBox MB_ICONSTOP "$(ADMIN_RIGHTS)"
    SetErrorLevel 740 ;ERROR_ELEVATION_REQUIRED
    Abort
${EndIf}
FunctionEnd

Function SetModeDestinationFromInstdir
${If} $InstallAllUsers == ${BST_CHECKED}
    StrCpy $NormalDestDir $InstDir
${Else}
    StrCpy $LocalDestDir $InstDir
${EndIf}
FunctionEnd

Function OptionsPageCreate
!insertmacro MUI_HEADER_TEXT "$(INSTALL_MODE)" "$(INSTALL_CHOOSE)"

Push $0
nsDialogs::Create 1018
Pop $0
${If} $0 == error
    Abort
${EndIf} 

Call SetModeDestinationFromInstdir ; If the user clicks BACK on the directory page we will remember their mode specific directory

${NSD_CreateCheckBox} 0 0 100% 12u "$(INSTALL_ADMIN)"
Pop $InstallAllUsersCtrl

UserInfo::GetAccountType
Pop $8
${If} $8 != "admin"
    ${NSD_SetState} $InstallAllUsersCtrl ${BST_UNCHECKED}
${Else}
    ${NSD_SetState} $InstallAllUsersCtrl ${BST_CHECKED}
${EndIf}

${NSD_CreateCheckBox} 0 20 100% 12u "$(INSTALL_SHORTCUT)"
Pop $InstallShortcutsCtrl
${NSD_SetState} $InstallShortcutsCtrl ${BST_CHECKED}

nsDialogs::Show
FunctionEnd

Function OptionsPageLeave
${NSD_GetState} $InstallAllUsersCtrl $InstallAllUsers
${NSD_GetState} $InstallShortcutsCtrl $InstallShortcuts

${If} $InstallAllUsers  == ${BST_CHECKED}
    StrCpy $InstDir $NormalDestDir
    Call RequireAdmin
    SetShellVarContext all
${Else}
    StrCpy $InstDir $LocalDestDir
    SetShellVarContext current
${EndIf}

; Check to see if already installed
ReadRegStr $R0 SHCTX "Software\Microsoft\Windows\CurrentVersion\Uninstall\${UNINSTKEY}" "UninstallString"
${If} $R0 != "" 
    MessageBox MB_OKCANCEL|MB_TOPMOST "$(ALREADY_INSTALLED)" IDOK Ok IDCANCEL Cancel
    Cancel:
    Quit

    Ok:
    ; Use SilentMode for the uninstall so that we can wait on the termination
    ${If} $InstallAllUsers  == ${BST_CHECKED}
        ExecWait "$R0 /S /ALL" 
    ${Else}
        ExecWait "$R0 /S"
    ${EndIf}
${EndIf}

FunctionEnd

Section "Install"
SetOutPath "$InstDir"
File /r dist\*

WriteRegStr SHCTX "Software\Microsoft\Windows\CurrentVersion\Uninstall\${UNINSTKEY}" "DisplayName" "${NAME}"
WriteRegStr SHCTX "Software\Microsoft\Windows\CurrentVersion\Uninstall\${UNINSTKEY}" "DisplayVersion" "${VERSION}"
WriteRegStr SHCTX "Software\Microsoft\Windows\CurrentVersion\Uninstall\${UNINSTKEY}" "Publisher" "${PUBLISHER}"
${If} $InstallAllUsers  == ${BST_CHECKED}
    WriteRegStr SHCTX "Software\Microsoft\Windows\CurrentVersion\Uninstall\${UNINSTKEY}" "UninstallString" '"$InstDir\uninstall.exe" /ALL'
${Else}
    WriteRegStr SHCTX "Software\Microsoft\Windows\CurrentVersion\Uninstall\${UNINSTKEY}" "UninstallString" '"$InstDir\uninstall.exe" /USER'
${EndIf}

${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
IntFmt $0 "0x%08X" $0
WriteRegDWORD SHCTX "Software\Microsoft\Windows\CurrentVersion\Uninstall\${UNINSTKEY}" "EstimatedSize" "$0"

WriteUninstaller "$InstDir\uninstall.exe"
SectionEnd

Section "Shortcuts"
CreateDirectory "$SMPROGRAMS\${NAME}-${VERSION}"
CreateShortCut "$SMPROGRAMS\${NAME}-${VERSION}\nsf2x.lnk" "$InstDir\nsf2x.exe" "" "" 0
CreateShortCut "$SMPROGRAMS\${NAME}-${VERSION}\README.lnk" "$InstDir\README.txt" "" "" 0

${If} $InstallAllUsers  == ${BST_CHECKED}
    CreateShortCut "$SMPROGRAMS\${NAME}-${VERSION}\uninstall.lnk" "$InstDir\uninstall.exe" "/ALL" "" 0
${Else}
    CreateShortCut "$SMPROGRAMS\${NAME}-${VERSION}\uninstall.lnk" "$InstDir\uninstall.exe" "/USER" "" 0
${EndIf}

${If} $InstallShortCuts == ${BST_CHECKED}
    Delete "$DESKTOP\${NAME}.lnk"
    CreateShortCut "$DESKTOP\${NAME}.lnk" "$InstDir\nsf2x.exe" "" "" 0
${Endif}
SectionEnd

Function un.onInit
${GetParameters} $9

ClearErrors
${GetOptions} $9 "/?" $8
${IfNot} ${Errors}
    MessageBox MB_ICONINFORMATION|MB_SETFOREGROUND "$(COMMANDLINE_HELP2)"
    Quit
${EndIf}

ReadRegStr $R0 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${UNINSTKEY}" "UninstallString"
${If} $R0 != ""
    SetShellVarContext all
${Else}
    SetShellVarContext current
${EndIf}
    
ClearErrors
${GetOptions} $9 "/ALL" $8
${IfNot} ${Errors}
    SetShellVarContext all
${EndIf}

${GetOptions} $9 "/USER" $8
${IfNot} ${Errors}
    SetShellVarContext current
${EndIf}
FunctionEnd

Section "Uninstall"
DeleteRegKey SHCTX "Software\Microsoft\Windows\CurrentVersion\Uninstall\${UNINSTKEY}"

RMDir /r "$SMPROGRAMS\${NAME}-${VERSION}"
RMDir "$SMPROGRAMS\${NAME}-${VERSION}"
Delete "$InstDir\uninstall.exe"
RMDir /r "$InstDir"
RMDir "$InstDir"

Delete "$DESKTOP\${NAME}.lnk"
SectionEnd