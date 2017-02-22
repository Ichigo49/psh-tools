Function Get-7Zip {
    <#
    .SYNOPSIS
    List contents of a compressed archive file
    .DESCRIPTION
    Use Get-7Zip to list the contents of an archive.
    .EXAMPLE
    Get-7Zip archive.zip
    
    List contents of archive.zip in the current working folder
	
    .EXAMPLE
    Get-7Zip "c:\folder\files.gz"
    
    List contents of c:\folder\files.gz
    
    .PARAMETER FullName
    The full path of the compressed archive file.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=1,ValueFromPipelineByPropertyName=$True)]
        [ValidateScript({Test-Path $_})]
        [string]$FullName
    )
    Process {
        Write-Verbose "Getting contents of archive file"
        & "$7zaBinary" l "$FullName"
    }
}