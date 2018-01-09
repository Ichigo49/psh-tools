Function Import-WindowsUpdateLog {
<#
    .SYNOPSIS
        Read the content of the Windows Update log and import it as an object
    .DESCRIPTION
        Read the content of the Windows Update log and import it as an object.
        It will read each line and create an object with the following properties:
        Date,Hour,PID,TID,Component,Message
    .PARAMETER FilePath
        The path of the windows update log file.
    .EXAMPLE
        Import-WindowsUpdateLog -FilePath ~\Desktop\WindowsUpdate.log
    
    .EXAMPLE
        "~\Desktop\WindowsUpdate.log" | Import-WindowsUpdateLog | Out-GridView
    .EXAMPLE
        Get-Item ~\Desktop\WindowsUpdate.log | Import-WindowsUpdateLog | Out-GridView
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [Alias('Path','PSPath')]
    [ValidateScript({
        Test-Path -Path $_ -PathType Leaf
    })]
    [string]$FilePath

)
Begin {}
Process {
    try {
        Get-Content -Path $FilePath -ReadCount 1 -ErrorAction Stop | 
        ForEach-Object {
            $Date,$Hour,$WUPID,$WUTID,$Component,$Message = (
            [regex]'^(?<Date>2\d{3}/\d{2}/\d{2})\s+(?<Hour>\d{2}:\d{2}:\d{2}\.\d{1,23})\s+(?<PID>\d{1,6})\s+(?<TID>\d{1,6})\s+(?<Component>[a-zA-Z]+)\s+(?<Message>.+)'
            ).Match($_).Groups | Select-Object -Last 6 -ExpandProperty Value
            [PsCustomObject]@{ 
                Date = $Date
                Hour = $Hour
                PID = $WUPID 
                TID = $WUTID
                Component = $Component
                Message = $Message 
            }
        }
    } catch {
        Throw "Failed because $($_.Exception.Message)"
    }
}
End {}
}