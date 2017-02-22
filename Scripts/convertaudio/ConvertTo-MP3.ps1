#requires -version 2
<#
    .SYNOPSIS
        <Overview of script>
        
    .DESCRIPTION
        <Brief description of script>
    
    .PARAMETER <Parameter_Name>
        <Brief description of parameter input required. Repeat this attribute if required>
        
    .INPUTS
        <Inputs if any, otherwise state None>
        
    .OUTPUTS
        <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
        
    .NOTES
        Version: 1.0
        Author: <Name>
        Creation Date: <Date>
        Purpose/Change: Initial script development

    .EXAMPLE
        <Example goes here. Repeat this attribute for more than one example>
#>

#---------------------------------------------------------[Parameters]--------------------------------------------------------
[CmdletBinding()] 
param (
    [string]$Source,
    [string]$Destination
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
#$ErrorActionPreference = "SilentlyContinue"

#Get Script Directory/Name
$fullPathIncFileName = $MyInvocation.MyCommand.Definition
$ScriptName = (Get-Item $fullPathIncFileName).BaseName
$ScriptDir = (Get-Item $fullPathIncFileName).Directory

#Dot Source required Function Libraries
Import-Module $ScriptDir\..\..\lib\Modules\PSLogging
. $ScriptDir\..\..\lib\Scripts\Remove-StringSpecialCharacter.ps1

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "1.0"

#Log File Info
$DateDuLog = Get-Date -f "yyyyMMdd_HHmmss"
$sLogPath = Join-Path $ScriptDir\..\.. "log"
$sLogName = "${ScriptName}_$DateDuLog.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

$flac = Join-Path -Path $ScriptDir -ChildPath "bin\flac.exe"
$lame = Join-Path -Path $ScriptDir -ChildPath "bin\lame.exe"
$shntool = Join-Path -Path $ScriptDir -ChildPath "bin\shntool.exe"
$TAGlib = Join-Path -Path $ScriptDir -ChildPath "bin\taglib-sharp.dll"
$tmp = "flac2mp3temp.wav"

#-----------------------------------------------------------[Functions]------------------------------------------------------------


#-----------------------------------------------------------[Execution]------------------------------------------------------------

#Start-Log -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

#Script Execution goes here
#Write-LogInfo -LogPath $sLogFile -Message "" -TimeStamp -ToScreen

# Load the assembly. I used a relative path so I could off using the Resolve-Path cmdlet 
[Reflection.Assembly]::LoadFrom($TAGlib)

$AllInfos = (Get-Item $Source).name
$AllInfos -match '(^.*)-' | Out-Null
$Artist = $Matches[1]
$AllInfos -match ".?\((.*?)\).*" | Out-Null
$Year = $Matches[1]
$AllInfos -match ".?\(.*?\).(.*)" | Out-Null
$Album = $Matches[1]

$FilesList = Get-ChildItem -Path $Source
$IsCueFile = $FilesList | Where-Object{ $_.extension -contains ".cue"}
if ((Test-Path -Path $Destination) -eq $false) {
    New-Item -Path $Destination -ItemType directory | Out-Null
}

if ($IsCueFile) {
    #Gestion du cue file
    #on en fait une copie
    $CUEFile = $IsCueFile.FullName
    Copy-Item -Path $CUEFile -Destination 'C:\temp\Backup.cue'
    #on remove les caractères sépciaux
    $CUEContent = Get-Content -Path $CUEFile
    $CUEContent = $CUEContent | Remove-StringSpecialCharacter -Keep '" :().-'
    Set-Content -Path $CUEFile -Value $CUEContent
    #on enregistre le nouveau cue
    $Option_o = $Source + "\*.flac"
    & $shntool split -f $($CUEFile) -t "%n - %t" -o flac $Option_o -d $Destination
    $FilesList = Get-ChildItem -Path $Destination
}

foreach ($FlacFile in $FilesList | Where-Object{ $_.extension -contains ".flac"}) {
    $fn = $FlacFile.baseName
    $fn -match '(\d*).*' | Out-Null
    $TrackNumber = $Matches[1]
    $fn -match '\d*.-.(.*)' | Out-Null
    $TrackTitle = $Matches[1]

    & $flac -d "$($FlacFile.FullName)" -o $tmp -s
    & $lame -b 320 -h -m s --quiet $tmp "$Destination\$fn.mp3"
    $media = [TagLib.File]::Create((resolve-path "$Destination\$fn.mp3"))
    $media.Tag.Album = $Album
    $media.Tag.Year = $Year
    $media.Tag.Title = $TrackTitle
    $media.Tag.Track =  $TrackNumber
    $media.Tag.AlbumArtists = $Artist
    $media.Save() 

    Remove-Item -Path $tmp
    if ($IsCueFile) {
        Remove-Item $FlacFile.FullName
    }
}

<#
# Load up the MP3 file. Again, I used a relative path, but an absolute path works too 
$media = [TagLib.File]::Create((resolve-path ".\Netcast 185 - Growing Old with Todd.mp3"))

# set the tags 
$media.Tag.Album = "Todd Klindt's SharePoint Netcast" 
$media.Tag.Year = "2014" 
$media.Tag.Title = "Netcast 185 - Growing Old with Todd" 
$media.Tag.Track = "185" 
$media.Tag.AlbumArtists = "Todd Klindt" 

# Load up the picture and set it 
$pic = [taglib.picture]::createfrompath("c:\Dropbox\Netcasts\Todd Netcast 1 - 480.jpg") 
$media.Tag.Pictures = $pic

# Save the file back 
$media.Save() 
#>
#Stop-Log -LogPath $sLogFile