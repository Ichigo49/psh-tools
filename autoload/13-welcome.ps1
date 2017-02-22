# Welcome message

Function Get-ProfileBanner {
    <#
    .SYNOPSIS
        Get-ProfileBanner
    .SYNOPSIS
        Displays system information to a host.
    .DESCRIPTION
        The Get-ProfileBanner cmdlet is a system information tool written in PowerShell. 
    .EXAMPLE
    #>

    $WMI_OS = Get-WmiObject -Class Win32_OperatingSystem
    $LastBootTime = ([WMI]'').ConvertToDateTime($WMI_OS.LastBootUpTime)
    $UpTime = New-TimeSpan -Start $LastBootTime -End (Get-Date)
    [string]$Up = [string]$UpTime.days + "days, " + [string]$UpTime.Hours + "h" + [string]$UpTime.Minutes + "m" + [string]$UpTime.Seconds + "s"
    $TimeZone = ([TimeZoneInfo]::Local).displayname
    $CsPhyicallyInstalledMemory = (get-wmiobject -class "win32_physicalmemory" -namespace "root\CIMV2").Capacity


    Write-Host -Object ("##########################") -ForegroundColor Cyan
    Write-Host -Object ("#ppppp   \ppppppppppppppp#") -NoNewline -ForegroundColor Cyan
    Write-Host -Object ("    $(Get-Date)") -ForegroundColor Green
    Write-Host -Object ("#ooooo.    oooooooooooooo#") -ForegroundColor Cyan
    Write-Host -Object ("#wwwwwww-   wwwwwwwwwwwww#") -NoNewline -ForegroundColor Cyan
    Write-Host -Object ("    User: ") -NoNewline
    if (Test-IsElevatedUser) {
	Write-Host -Object ("$($env:USERNAME)") -ForegroundColor red
	} else {
		Write-Host -Object ("$($env:USERNAME)") -ForegroundColor darkgray	
	}
    Write-Host -Object ("#eeeeeeee\   .eeeeeeeeeee#") -NoNewline -ForegroundColor Cyan
    Write-Host -Object ("    Hostname: ") -NoNewline
    Write-Host -Object ("$($env:COMPUTERNAME)") -ForegroundColor Yellow
    Write-Host -Object ("#rrrrrrrrr.    ;rrrrrrrrr#") -NoNewline -ForegroundColor Cyan
    Write-Host -Object ("    Logon Domain: ") -NoNewline
    Write-Host -Object ("$($env:USERDOMAIN)") -ForegroundColor Yellow
    Write-Host -Object ("#sssssssssss    sssssssss#") -NoNewline -ForegroundColor Cyan
    Write-Host -Object ("    Boot Time: ") -NoNewline
    Write-Host -Object ("$($LastBootTime.ToString()) ($Up)") -ForegroundColor Yellow
    Write-Host -Object ("#hhhhhhhhh/    /hhhhhhhhh#") -NoNewline -ForegroundColor Cyan
    Write-Host -Object ("    OS: ") -NoNewline
    Write-Host -Object ("$($WMI_OS.Caption)") -ForegroundColor Yellow
    Write-Host -Object ("#eeeeeee;    eeeeeeeeeeee#") -NoNewline -ForegroundColor Cyan
    Write-Host -Object ("    TimeZone: ") -NoNewline
    Write-Host -Object ("$TimeZone") -ForegroundColor Yellow
    Write-Host -Object ("#lllll.    ;lllllllllllll#") -NoNewline -ForegroundColor Cyan
    Write-Host -Object ("    Shell: ") -NoNewline
    Write-Host -Object ("Powershell $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)") -ForegroundColor Yellow
    Write-Host -Object ("#lllll   .lll       lllll#") -NoNewline -ForegroundColor Cyan
    Write-Host -Object ("    Memory: ") -NoNewline
    Write-Host -Object ("$([math]::round($WMI_OS.FreePhysicalMemory / 1MB, 2))GB / $($CsPhyicallyInstalledMemory / 1GB)GB") -ForegroundColor Yellow
    Write-Host -Object ("##########################") -ForegroundColor Cyan
    Write-Host -Object ("")
}

Get-ProfileBanner