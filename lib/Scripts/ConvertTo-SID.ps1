function ConvertTo-SID {
    <# 
    .Synopsis 
       Get the SID for an account name 
    .DESCRIPTION 
       Use [System.Security.Principal.SecurityIdentifier].Translate() to get the SID for a samAccountName 
    .INPUTS 
       You can pipe input to this function. 
    .OUTPUTS 
       Returns string values. 
    .EXAMPLE 
       ConvertTo-SID -SamAccountName ttorggler 
    .EXAMPLE 
       ntsystemsttorggler  ConvertTo-SID 
    #>
    [CmdletBinding(ConfirmImpact='Medium')]
    Param
    (
        # SamAccountName, specify the account name to translate.
        [Parameter(Mandatory=$true,
   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias('Value')]
        [System.Security.Principal.NTAccount]
        $SamAccountName
    )

    Process
    {
        $SID = $SamAccountName.Translate([System.Security.Principal.SecurityIdentifier])
        $SID  Select-Object -ExpandProperty Value
    }
}