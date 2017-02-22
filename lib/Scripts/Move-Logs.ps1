Function Move-Logs {
    <#    
 
    Public Domain License
 
    .SYNOPSIS
    Clean up and rotate files
 
    .DESCRIPTION
    This script rotates files and keeps them in three directories
    \daily
    \weekly
    \monthly
 
    New files are expected to be written to $LogDir and Move-Logs moves them into subdirectories
 
    .EXAMPLE
    Move-Logs -LogDir "c:\MyLogDirectory"
 
    .LINKS
    http://www.getsurreal.com/powershell/powershell-file-rotation
    #>
 
	Param (
		[Parameter(Mandatory=$True,ValueFromPipeline=$false)]
		[string]$LogDir, # Directory log files are written to
		[Parameter(ValueFromPipeline=$false)]
		[int]$DayOfWeek = 2, # The day of the week to store for weekly files (1 to 7 where 1 is Sunday)
		[Parameter(ValueFromPipeline=$false)]
		[int]$DayOfMonth = 1, # The day of the month to store for monthly files (Max = 28 since varying last day of month not currently handled)
		[Parameter(ValueFromPipeline=$false)]
		[int]$RotationDaily = 7, # The number of daily files to keep
		[Parameter(ValueFromPipeline=$false)]
		[int]$RotationWeekly = 6, # The number of weekly files to keep
		[Parameter(ValueFromPipeline=$false)]
		[int]$RotationMonthly = 5 # The number of monthly files to keep
	)
 
	Process {
		if (-not $LogDir) {
			Write-Host "Error:  -LogDir not set"
			Exit
        }
 
        $date = Get-Date
 
        $verify_log_dir = Test-Path $LogDir
        if ($verify_log_dir) {
            $verify_daily_dir = Test-Path "$LogDir\daily"
            $verify_weekly_dir = Test-Path "$LogDir\weekly"
            $verify_monthly_dir = Test-Path "$LogDir\monthly"
 
            # If the daily directory does not exist try to create it
            if (!$verify_daily_dir) {
                $md_daily = New-Item -Name "daily" -Path $LogDir -ItemType Directory | Out-Null
                if (!$md_daily){
                    Write-Host "Error setting up log directories. Check Permissions."
                    exit
                }
            }
            # If the weekly directory does not exist try to create it
            if (!$verify_weekly_dir) {
                $md_weekly = New-Item -Name "weekly" -Path $LogDir -ItemType Directory | Out-Null
                if (!$md_weekly){
                    Write-Host "Error setting up log directories. Check Permissions."
                    exit
                }
            }
            # If the monthly directory does not exist try to create it
            if (!$verify_monthly_dir) {
                $md_monthly = New-Item -Name "monthly" -Path $LogDir -ItemType Directory | Out-Null
                if (!$md_monthly){
                    Write-Host "Error setting up log directories. Check Permissions."
                    exit
                }
            }
        }
        else {
            Write-Host "Error:  Log directory $LogDir does not exist."
            exit
        }
 
        $logs_root = Get-ChildItem $LogDir | Where-Object {$_.Attributes -ne "Directory"}
 
        if ($logs_root) {
            foreach ($file in $logs_root) {
                $file_date = get-date $file.LastWriteTime
                if ($file_date -ge $date.AddDays(-$RotationDaily)) {
                    #Write-Host "$($file.Name) - $($file_date)"
                    Copy-Item "$LogDir\$file" "$LogDir\daily"
                }
                if ($file_date -ge $date.AddDays(-$RotationWeekly*7) -and [int]$file_date.DayOfWeek -eq $DayOfWeek) {
                    #Write-Host "Weekly $($file.Name) - $($file_date)"
                    Copy-Item "$LogDir\$file" "$LogDir\weekly"
                }
                if ($file_date -ge $date.AddDays(-$RotationMonthly*30) -and [int]$file_date.Day -eq $DayOfMonth) {
                    #Write-Host "Monthly $($file.Name) - $($file_date) $([int]$file_date.DayOfWeek)"
                    Copy-Item "$LogDir\$file" "$LogDir\monthly"
                }
                Remove-Item "$LogDir\$file"
            }
 
            $logs_daily = Get-ChildItem "$LogDir\daily" | Where-Object {$_.Attributes -ne "Directory"} | Sort-Object LastWriteTime -Descending
            $logs_weekly = Get-ChildItem "$LogDir\weekly" | Where-Object {$_.Attributes -ne "Directory"}
            $logs_monthly = Get-ChildItem "$LogDir\monthly" | Where-Object {$_.Attributes -ne "Directory"}
 
            if ($logs_daily) {
                foreach ($file in $logs_daily) {
                    $file_date = get-date $file.LastWriteTime
                    if ($file_date -le $date.AddDays(-$RotationDaily)) {
                        #Write-Host "$file.Name"
                        Remove-Item "$LogDir\daily\$file"                    
                    }
                }
            }
 
            if ($logs_weekly) {
                foreach ($file in $logs_weekly) {
                    $file_date = get-date $file.LastWriteTime
                    if ($file_date -le $date.AddDays(-$RotationWeekly*7)) {
                        #Write-Host "$file.Name"
                        Remove-Item "$LogDir\weekly\$file"
                    }
                }
            }
 
            if ($logs_monthly) {
                foreach ($file in $logs_monthly) {
                    $file_date = get-date $file.LastWriteTime
                    if ($file_date -le $date.AddDays(-$RotationMonthly*30)) {
                        #Write-Host "$file.Name"
                        Remove-Item "$LogDir\monthly\$file"
                    }
                }
            }
        }
    }
}
