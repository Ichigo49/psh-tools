function Get-ServiceAutoStarted {
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline=$True)]
        [String[]]$ComputerName = $env:ComputerName
    )
    foreach ($Computer in $ComputerName) {
        # get Auto that not Running:
        Get-WmiObject Win32_Service -ComputerName $Computer |
        Where-Object { $_.StartMode -eq 'Auto' -and $_.State -ne 'Running' } | ForEach-Object {
            $SvcInfos = $_
            # process them; in this example we just show them:
            [pscustomobject][ordered]@{
                        'Server' = $Computer
                        'Name' = $SvcInfos.Name
                        'DisplayName' = $SvcInfos.DisplayName
                        'State' = $SvcInfos.State
                        'StartMode' = $SvcInfos.StartMode
                        #'StartName' = $SvcInfos.StartName
            }
        }
    }
}