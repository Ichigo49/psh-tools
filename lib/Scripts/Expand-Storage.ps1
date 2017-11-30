#requires -version 2
function Expand-Storage {
<#
    .SYNOPSIS
        Agrandissement de partitions
        
    .DESCRIPTION
        Agrandit la partition donnee en parametre a sa taille maximum.
        Il faut prealablement agrandir le disque cote Hyperviseur.

    .PARAMETER DriveLetter
        Lettre de la partition a agrandir
        
    .INPUTS
        None
        
    .OUTPUTS
        None
        
    .NOTES
        Version: 1.0
        Author: ALLEGRET Mathieu
        Creation Date: 05/09/2016
        Purpose/Change: Initial script development

    .EXAMPLE
        Expand-Storage -DriveLetter S

        Agrandissement de la partition S: Ã  sa valeur maximum
        
#>
    [CmdletBinding()] 
    param (
            [string]$DriveLetter
    )

    $ErrorActionPreference = "SilentlyContinue"
    Write-Verbose "Updating Storage Cache"
    Update-HostStorageCache
    Write-Verbose "Getting new MaxSize for partition $DriveLetter"
    $MaxSize = (Get-PartitionSupportedSize -DriveLetter $DriveLetter).sizeMax
    try {
        Write-Verbose "Extending Partition..."
        Resize-Partition -DriveLetter $DriveLetter -Size $MaxSize
        Write-Verbose "Done !"
    }
    catch {
        Write-Verbose "Error While extending partition : $_.Exception.Message"
    }
}
