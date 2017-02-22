cd %~dp0
cd ..\bin\Sysinternals
psexec -i -d -s pslist 2>&1
psexec -i -d -s pskill 2>&1
psexec -i -d -s psinfo 2>&1
reg.exe ADD "HKCU\Software\Sysinternals\AccessChk" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\AccessEnum" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\AdExplorer" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\AdInsight" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\AdRestore" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Autologon" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Autoruns" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\BgInfo" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\BlueScreen" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\CacheSet" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\ClockRes" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Contig" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Coreinfo" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Ctrl2cap" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\DebugView" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Desktops" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Disk Usage" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Disk2vhd" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\DiskExt" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Diskmon" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\DiskView" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\EFSDump" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Handle" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Hex2dec" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Junction" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\LDMDump" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\ListDLLs" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\LiveKd" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\LoadOrder" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\LogonSessions" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\MoveFile" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\NTFSInfo" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PageDefrag" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PendMoves" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PipeList" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PortMon" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\ProcDump" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Process Explorer" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Process Monitor" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\ProcFeatures" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PsExec" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PsFile" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PsGetSid" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PsInfo" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PsKill" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PsList" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PsLoggedOn" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PsLogList" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PsPasswd" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PsService" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PsShutdown" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PsSuspend" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\PsTools" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\RAMMap" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\RegDelNull" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\RegJump" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\RootkitRevealer" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\SDelete" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\ShareEnum" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\ShellRunas" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Sigcheck" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Streams" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Strings" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Sync" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\TCPView" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\VMMap" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\VolumeId" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\Whois" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\WinObj" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD "HKCU\Software\Sysinternals\ZoomIt" /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD HKU\.DEFAULT\Software\Sysinternals\PSexec /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD HKU\.DEFAULT\Software\Sysinternals\PsKill /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD HKU\.DEFAULT\Software\Sysinternals\PsList /v EulaAccepted /t REG_DWORD /d 1 /f
reg.exe ADD HKU\.DEFAULT\Software\Sysinternals\PsInfo /v EulaAccepted /t REG_DWORD /d 1 /f	