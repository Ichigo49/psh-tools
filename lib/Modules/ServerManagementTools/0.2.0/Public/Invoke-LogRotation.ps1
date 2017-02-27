function Invoke-LogRotation {
    <#
    .SYNOPSIS
        Compresses log files by month.
    .DESCRIPTION
        The Invoke-LogRotation cmdlet retrieves a list of log file in the specified locations and compressed them into a ZIP archive by month.  Once the contents of the archive are verified the original log files are deleted.
    .PARAMETER Path
        Specifies a path to one or more locations.  Invoke-LogRotation processes the log files in the specified locations.
    .PARAMETER CompressDays
        Specifies the number of days to keep uncompressed log files.  If you do not specify this parameter, the cmdlet will retain 5 days.
    .EXAMPLE
        Invoke-LogRotation -Path C:\Inetpub\Logs\LogFiles\W3SVC1
        Archives the log files for the IIS 'Default Website' using the default 5 day retention
    .EXAMPLE
        Invoke-LogRotation -Path C:\Inetpub\Logs\LogFiles\W3SVC1 -CompressDays 10
        Archives the log files for the IIS 'Default Website' using the specified 10 day retention
    .LINK
        https://github.com/twillin912/ServerManagementTools
    .NOTES
        Author: Trent Willingham
        Check out my other projects on GitHub https://github.com/twillin912
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param (
        [Parameter(Mandatory=$true, Position=1)]
        [string[]] $Path,

        [Parameter(Position=2)]
        [int] $CompressDays = 5
    )

    Begin {
        $DateDisplayFormat = 'MM/dd/yyyy'
        $DateFileFormat = 'yyyy-MM'
        $CurrentDate = Get-Date -Hour 0 -Minute 0 -Second 0

        if ($CompressDays) {
            $CompressBefore = (Get-Date -Date $CurrentDate).AddDays(-$CompressDays)
        }

        $null = [Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" )

    }

    Process {
        foreach ( $LogPath in $Path ) {
            if ( ! ( Test-Path -Path $LogPath ) ) {
                Write-Error -Message "Cannot find path '$LogPath' because it does not exist."
                break
            }

            $LogFolder = Split-Path -Path $($LogPath) -Leaf

        if ( $CompressDays ) {
            $LogsToCompress = Get-ChildItem -Path $LogPath -Include '*.log' -Recurse |
            Where-Object { $PSItem.PSIsContainer -eq $false -and $PSItem.LastWriteTime -lt $CompressBefore }
            Write-Verbose -Message "Compressing $($LogsToCompress.Count) older than $($CompressBefore.ToString($DateDisplayFormat))"

            $LogHashTable = @{}
            foreach ( $File in $LogsToCompress ) {
                $LogHashTable.Add($File.FullName,$File.LastWriteTime.ToString($DateFileFormat))
            }
            $LogHashTable = $LogHashTable.GetEnumerator() | Sort-Object -Property Value,Name
            $MonthsToProcess = @( $LogHashTable | Group-Object -Property Value | Select-Object -Property Name )

            foreach ( $Month in $MonthsToProcess ) {
                $ZipFileName = "$($env:ComputerName)-$($LogFolder)-$($Month.Name).zip"
                $ZipFullName = Join-Path -Path $LogPath -ChildPath $ZipFileName
                $CurrentMonthLogs = $LogHashTable | Where-Object { $PSItem.Value -eq "$($Month.Name)" }

                foreach ( $LogFile in $CurrentMonthLogs ) {
                    $LogName = Split-Path -Path $LogFile.Name -Leaf

                    if ( $PSCmdlet.ShouldProcess($ZipFullName,"Create/Update Archive") ) {
                        $ZipFile = [System.IO.Compression.ZipFile]::Open($ZipFullName, "Update")
                    }

                    if ( $PSCmdlet.ShouldProcess($LogFile.Name,"Get Content") ) {
                        $LogContent = Get-Content -Path $LogFile.Name -Raw
                    }

                    if ( ! ( $ZipFile.GetEntry($LogName) ) ) {
                        if ( $PSCmdlet.ShouldProcess($LogFile.Name,"Add to Archive") ) {
                            $ZipFileEntry = $ZipFile.CreateEntry($LogName)
                            $StreamWriter = [System.IO.StreamWriter] $ZipFileEntry.Open()
                            $StreamWriter.Write($LogContent)
                            $StreamWriter.Dispose()
                            $ZipFileEntry.LastWriteTime = (Get-Item -Path "$($LogFile.Name)").LastWriteTime
                        }
                    }

                    if ( $PSCmdlet.ShouldProcess($ZipFullName,"Save Archive") ) {
                        $ZipFile.Dispose()
                    }

                    if ( $PSCmdlet.ShouldProcess($LogFile.Name,"Compare to Archive") ) {
                        $ZipFile = [System.IO.Compression.ZipFile]::Open($ZipFullName, "Read")
                        $ZipFileEntry = [System.IO.StreamReader] $ZipFile.GetEntry($LogName).Open()
                        $ZipContent = $ZipFileEntry.ReadToEnd()
                        $ZipFile.Dispose()

                        if ( $ZipContent -eq $LogContent ) {
                            Remove-Item -Path $LogFile.Name
                        }
                    }
                    [System.GC]::Collect()
                }
            }
        }
    }
}

End {

}
}
