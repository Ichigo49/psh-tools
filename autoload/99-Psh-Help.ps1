#Help Center psh-tools

<# lister les fonctions
Random-Password
Get-Clipboard,get content of clipboard
Set-Clipboard,set content to clipboard
ccd,cd to the path in the clipboard
Pause, pause in script, wait for keypress
setdate, set multiple date variables
rotation,make a rotation of lo files
Test-IsElevatedUser, test if user is admin or not
Get-ScriptDirectory, get the script parent directory
Start-Countdown, start-sleep with a count
Get-DiskFree, get partition size info
CheckPendingReboot, check if there is a pending reboot
UpTime, get uptime of computer
clx, clear screen with history
p, ping one time
Get-LoggedIn, get logged in user
Reload-Profile, reload powershell profile
New-Console, launch new console
ll, list with colorized file type
la, list -force
edit, use notepad++ to edit files
RPC-Ping, test rpc connection
Ping-Host, ping replacement
Get-ScheduledTasks, get schedule tasks
Start-SystemProcess, start-process
importad, import activedirectory module
addvmware, import VMware snappin
PowerEdit, enable advanced edit for powershell
now, get current datetime
ts, ToString
LaunchConsole, relaunch powershell console
Get-Time, get hours,minutes,second
prompt, 
listps, list all psh-tools script/module
editps, edit one of the psh-tools script
exploreps, open psh-tools in explorer
loadps, load all psh-tools scripts
tmpedit, set content to C:\temp\tmp.txt and edit it
explore, launch explorer in current directory
FixCRLF, fix the EOL in files
Get-Service2, advanced Get-Service command
Set-GoogleTools, Set function and aliases to open google with a search
Google-Search, make a google search
Google-Image, make a google image search
Google-Video, make a google video search
Google-News, make a google news search
Google-PowerShell, make a google powerShell search
Google-MSDN, make a google MSDN search
h, get history with count (for powershell 1 & 2)
hg, get history item (for powershell 1 & 2)
hist, get history command line only (for powershell 1 & 2)
#>

<# lister les variables
$psdir, path to psh-tools directory
$ShortDay, day of the week on 4 digits
$Month, current month on 4 digits
$Year, current year, format yyyy
$Day, current day in the month
$pshtVersion, version of psh-tools
$BASEEXPLOIT, psh-tools's parent directory
$BASETMP, psh-tools's temp directory
$BASEUTIL, psh-tools's utils directory
$BASEBIN, psh-tools's bin directory
$BASEFIC, psh-tools's fic directory
$BASELOG, psh-tools's log directory
$journal, psh-tools's journal log
$exploit, variable set to 1 when psh-tools environement is loaded
$OSlang, OS language, format 1033/1036 (EN/FR)
$OSver, OS version
$OSName, OS friendly Name
$OSArchi, OS architecture 32/64
$PSver, PowerShell version
$systemdrive, PAth to system Drive
$computername, Computer's Name
#>

<# lister les filter & autres trucs !
ConvertTo-KMG, convert number to size in KB / MB or GB
match, match
exclude, exclude

#>

<# lister les ALIAS
gcmd, Get-Command
null, Out-Null
ad, function importad
vim, function addvmware
sz, 7za.exe
ex, function explorer
exps, function exploreps
newc, function New-Console
Open-Url, function Start-SystemProcess
sysinfo, run script SYS_INFO.ps1
rdp, shortcut to mstsc
rld, function Reload-Profile
i, Invoke-History
original_h, old h alias
gsv2, get-service2
google, Google-Search
ggit, Google-Search (mean go google it)
gimg, Google-Image
gnews, Google-News
gvid, Google-Video
gpsh, Google-PowerShell
gmsdn, Google-MSDN
#>

<# Lister PSdrive
script, Drive Script: for psh-tools directory


#>