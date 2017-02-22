Function Expand-7Zip {
    <#
    .SYNOPSIS
    Extract contents of a compressed archive file
    .DESCRIPTION
    Use Expand-7Zip to extract the contents of an archive.
    .EXAMPLE
    Expand-7Zip archive.zip
    
    Extract contents of archive.zip in the current working folder
	
    .EXAMPLE
    Expand-7Zip "c:\folder\files.gz"
    
    Extract contents of c:\folder\files.gz into current working folder
	
    .PARAMETER FullName
    The full path of the compressed archive file.
    .PARAMETER Remove
    If $True this will remove the compressed version of the file only leaving the uncompressed contents.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=1,ValueFromPipelineByPropertyName=$True)]
        [ValidateScript({Test-Path $_})]
        [string]$FullName,
		
        [Parameter(Mandatory=$false,Position=2)]
        [string]$Destination = $((Get-Item $FullName).Directory),
		
        [bool]$Remove
    )
    Process {
		
        Write-Verbose "Extracting contents of compressed archive file"
		Write-Verbose "$Destination"
        $outputOption = "-o$Destination"
		& "$7zaBinary" x "$FullName" $outputOption
        If($PSBoundParameters.ContainsKey('Remove')) {
            If ($Remove -eq $True) {
                Write-Verbose "Removing compressed archive file"
                Remove-Item $FullName -Force
            }
        }
    }
}