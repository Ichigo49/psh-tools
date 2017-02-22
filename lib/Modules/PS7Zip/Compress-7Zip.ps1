Function Compress-7Zip {
    <#
    .SYNOPSIS
    Create a compressed archive of a file or folder
    .DESCRIPTION
    Use Compress-7Zip to create a 7z, gzip, zip, bzip2 or tar archive.
    .EXAMPLE
    Compress-7Zip c:\scripts
    
    Create archive.zip in the current working folder of the folder c:\scripts
    
    .EXAMPLE
    Compress-7Zip "computer inventory.csv" -OutputFile "inventory.gz" -ArchiveType GZIP -Remove $True
    
    Create a gzip archive of a single file and delete the uncompressed file
    
    .EXAMPLE
    Get-ChildItem E:\test | Where {$_.LastWriteTime -lt (Get-Date).AddDays(-5)} | Select -First 1 | Compress-7Zip
    
    Create an archive in c:\folder based on pipeline input
    
    .PARAMETER FullName
    The full path of the file or folder you would like turn into a compressed archive.
    .PARAMETER OutputFile
    The full path of the file to be created. Defaults to archive.zip in current working directory.
    .PARAMETER ArchiveType
    The type of archive you would like. Valid types 7Z, GZIP, ZIP, BZIP2, TAR.
    .PARAMETER Remove
    If $True this will remove the uncompressed version of the file or folder only leaving the compressed archive.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=1,ValueFromPipelineByPropertyName=$True)]
        [ValidateScript({Test-Path $_})]
        [string]$FullName,
        
        [string]$OutputFile,

        [ValidateSet("7Z","GZIP","ZIP","BZIP2","TAR")]
        [string]$ArchiveType,

        [bool]$Remove
    )
    Begin {
        If($PSBoundParameters.ContainsKey('ArchiveType')) {
            If ($ArchiveType -eq "7Z") {
                $7zaArchiveType = "-t7z"
                $ArchiveExt = ".7z"
            } ElseIf ($ArchiveType -eq "GZIP") {
                $7zaArchiveType = "-tgzip"
                $ArchiveExt = ".gz"
            } ElseIf ($ArchiveType -eq "ZIP") {
                $7zaArchiveType = "-tzip"
                $ArchiveExt = ".zip"
            } ElseIf ($ArchiveType -eq "BZIP2") {
                $7zaArchiveType = "-tbzip2"
                $ArchiveExt = ".bzip2"
            } ElseIf ($ArchiveType -eq "TAR") {
                $7zaArchiveType = "-ttar"
                $ArchiveExt = ".tar"
            }
        } Else {
            $7zaArchiveType = "-tzip"
            $ArchiveExt = ".zip"
        }
        If(!($PSBoundParameters.ContainsKey('OutputFile'))) {
            $OutputFile = ".\archive" + $ArchiveExt
        }
    }
    Process {
        Write-Verbose "Creating compressed archive file"
        & "$7zaBinary" a "$7zaArchiveType" "$OutputFile" "$FullName"
        If($PSBoundParameters.ContainsKey('Remove')) {
            If ($Remove -eq $True) {
                Write-Verbose "Removing original files/folders"
                Remove-Item $FullName -Force
            }
        }
    }
}