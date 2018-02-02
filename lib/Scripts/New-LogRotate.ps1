Function New-LogRotate {
    <#    
    .SYNOPSIS
		Clean up and rotate files
 
    .DESCRIPTION
		This script rotates files and keeps them in three directories
		\daily
		\weekly
		\monthly
	 
		New files are expected to be written to $LogDir and Rotate-Logs moves them into subdirectories
 
    .EXAMPLE
		Rotate-Logs -LogDir "c:\MyLogDirectory"
	
	.NOTES
		Version			: 2.0
		Author 			: M. ALLEGRET
		Date			: 25/01/2018
		Purpose/Change	: improving script
		Source 			: http://www.getsurreal.com/powershell/powershell-file-rotation
	
    #>
 
	Param (
		[Parameter(Mandatory=$True,ValueFromPipeline=$false)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({ Test-Path -Path $_})]
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
		[int]$RotationMonthly = 5, # The number of monthly files to keep
		[Parameter(ValueFromPipeline=$false)]
		[String[]]$Exclude #List d'item a exclure
	)

	Begin {
		function Get-RotateDirectory {
			param($LogPath,$RotateDirName)
			$NewPath = Join-Path -Path $LogPath -ChildPath $RotateDirName
			if (-not (Test-Path $NewPath)) {
				try {
					$null = New-Item -Path $LogPath -Name $RotateDirName -ItemType Directory
				} catch {
					
				}
			}
			$NewPath
		}
		
		function New-RotateLog {
			param($LogPath,$Rotation)
			
			$logs = Get-ChildItem -Path $LogPath -Attributes !Directory
			
			if ($logs) {
                foreach ($file in $logs) {
                    $file_date = get-date $file.LastWriteTime
                    if ($file_date -le $date.AddDays(-$Rotation)) {
                        #Write-Host "$file.Name"
                        Remove-Item "$LogPath\$file"                    
                    }
                }
            }
		
		}
		
	}
	
	Process {

        $date = Get-Date
		
		$DailyDirectory = Get-RotateDirectory -LogPath $LogDir -RotateDirName daily
		$WeeklyDirectory = Get-RotateDirectory -LogPath $LogDir -RotateDirName weekly
		$MonthlyDirectory = Get-RotateDirectory -LogPath $LogDir -RotateDirName monthly
		
		$ItemParam =@{
			Path = $LogDir
			#Attributes = "!Directory"
		}
		
		if ($Exclude) {
			$ItemParam.Add("Exclude",$Exclude)
		}
 
        $logs_root = Get-ChildItem @ItemParam | Where-Object {$_.Attributes -ne "Directory"}
 
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
 
            New-RotateLog -LogPath $DailyDirectory -Rotation $RotationDaily
            New-RotateLog -LogPath $WeeklyDirectory -Rotation $($RotationWeekly*7)
            New-RotateLog -LogPath $MonthlyDirectory -Rotation $($RotationMonthly*30)
			
        }
    }
}