<#
.SYNOPSIS
  Synchronises folders (and their contents) to target folders.  Uses a configuration XML file (default) or a pair of
  folders passed as parameters.
.DESCRIPTION
  Reads in the Configuration xml file (passed as a parameter or defaults to 
  Sync-FolderConfiguration.xml in the script folder.
.PARAMETER ConfigurationFile
    Holds the configuration the script uses to run.
.PARAMETER SourceFolder
    Which folder to synchronise.
.PARAMETER TargetFolder
    Where to sync the source folder to.
.PARAMETER Exceptions
    An array of file paths to skip from synchronisation.  Accepts wild-cards.
.NOTES       
    1.0
        HerringsFishBait.com
        17/11/2015
    1.1
        Fixed path check to use LiteralPath
        Added returning status object throughout
    1.2 4/Aug/2016
        Added LiteralPath to the Get-ChildItem commands   
        Added totals to report on what was done 
    1.3 6/10/2016
        Added StrictMode
        Set $Changes to an empty collection on script run to reset statistics  
        Rewrote Statistics
        Added $Filter option 
    1.4 4/11/2016
        Added Get-PropertyExists function to make sure parts of the config XML are not missing.  
    1.5 13/01/2017
        Fixed Type in Tee-Object that was preventing statistics showing correctly    
    1.6 20/01/2017
        Fixed Filters not working if not specified in config file
        Fixed Exceptions not working in some cases in Exception file     
        Added Write-Verbose on all the passed parameters to Sync-OneFolder   
        Added first pass at WhatIf
.EXAMPLE
  Sync-Folder -configurationfile:"d:\temp\Config.xml"
.EXAMPLE
  Sync-Folder -SourceFolder:c:\temp -TargetFolder:d:\temp -Exceptions:"*.jpg"
#>
[CmdletBinding(DefaultParameterSetName="XMLFile")]
param
(
    [parameter(
    ParameterSetName="XMLFile")]
    [ValidateScript({Test-Path $_ -PathType leaf})]
    [string]$ConfigurationFile=$PSScriptRoot+"\Sync-FolderConfiguration.xml",
    [parameter(
    Mandatory=$True,
    ValueFromPipelineByPropertyName=$True,
    ParameterSetName="FolderPair")]
    [string]$SourceFolder,
    [parameter(
    Mandatory=$True,
    ValueFromPipelineByPropertyName=$True,
    ParameterSetName="FolderPair")]
    [string]$TargetFolder,
    [parameter(
    ParameterSetName="FolderPair")]
    [string[]]$Exceptions=$Null,
    [parameter(
    ParameterSetName="FolderPair")]
    [string]$Filter="*",
    [switch]$Whatif=$False

)
set-strictmode -version Latest
<#
.SYNOPSIS
  Checks a file doesn't match any of a passed array of exceptions.
.PARAMETER TestPath
    The full path to the file to compare to the exceptions list.
.PARAMETER PassedExceptions
    An array of all the exceptions passed to be checked.
#>
function Check-Exceptions
{
    param
    (
        [parameter(Mandatory=$True)]
        [ValidateScript({Test-Path $_ -IsValid })]
        [string]$TestPath,
        [string[]]$PassedExceptions
    )
    $Result=$False
    $MatchingException=""
    if ($PassedExceptions -eq $Null) {Return $False}
    Write-Verbose "Checking $TestPath against exceptions"
    $PassedExceptions | ForEach-Object {if($TestPath -like $_) {$Result=$True;$MatchingException=$_}}
    If ($Result) {Write-Verbose "Matched Exception : $MatchingException, skipping."}
    $Result
}

<#
.SYNOPSIS
  Creates an object to be used to report on the success of an action
#>
function New-ReportObject
{
    New-Object -typename PSObject| Add-Member NoteProperty "Successful" $False -PassThru |
         Add-Member NoteProperty "Process" "" -PassThru |
         Add-Member NoteProperty "Message" "" -PassThru    
}

<#
.SYNOPSIS
    Returns if a property of an object exists.
.PARAMETER Queryobject
    The object to check the property on.
.PARAMETER PropertyName
    The name of the property to check the existance of.
#>
function Get-PropertyExists
{
    param
    (
        [PSObject]$Queryobject,
        [string]$PropertyName
    )
    Return (($Queryobject | Get-Member -MemberType Property | Select-Object -ExpandProperty Name) -contains $PropertyName)
}
<#
.SYNOPSIS
  Synchronises the contents of one folder to another.  It recursively calls itself
  to do the same for sub-folders.  Each file and folder is checked to make sure
  it doesn't match any of the entries in the passed exception list.  if it does, 
  the item is skipped.
.PARAMETER SourceFolder
    The full path to the folder to be synchronised.
.PARAMETER SourceFolder
    The full path to the target folder that the source should be synched to.
.PARAMETER PassedExceptions
    An array of all the exceptions passed to be checked.
.PARAMETER Filter
    Only files matching this parameter will be synced.
#>
function Sync-OneFolder
{
    param
    (
        [parameter(Mandatory=$True)]
        [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
        [string]$SourceFolder,
        [parameter(Mandatory=$True)]
        [ValidateScript({Test-Path -LiteralPath $_ -IsValid })]
        [string]$TargetFolder,
        [string[]]$PassedExceptions,
        [string]$Filter="*",
        [switch]$WhatIf=$False
 
    )
    Write-Verbose "Source Folder : $SourceFolder"
    Write-Verbose "Target Folder : $TargetFolder"
    Write-Verbose "Filter : $Filter"
    if ($PassedExceptions -ne $Null)
    {
        Write-Verbose "Exceptions:"
        $PassedExceptions | ForEach-Object{Write-Verbose $_}
    }
    if (!(Test-Path -LiteralPath $TargetFolder -PathType Container))
    {
        $Output=New-ReportObject
        Write-Verbose "Creating Folder : $($TargetFolder)" 
        $Output.Process="Create Folder"
        try
        {
            $Output.Message="Adding folder missing from Target : $TargetFolder"
            Write-Verbose $Output.Message
            New-Item $TargetFolder -ItemType "Directory" -WhatIf:$WhatIf > $null
            $Output.Successful=$True
        }
        catch
        {
            $Output.Message="Error adding folder $TargetFolder)"
            Write-Error $Output.Message
            Write-Error $_
        }
        $Output
    }
    $SourceFiles=$TargetFiles=$TargetList=@()
    $SourceFolders=$TargetFolders=@()
    $SourceList=Get-ChildItem -LiteralPath $SourceFolder
    if (Test-Path $TargetFolder)
    {
        $TargetList=Get-ChildItem -LiteralPath $TargetFolder
    }
    $SourceFiles+=$SourceList | Where-Object {$_.PSIsContainer -eq $False -and $_.FullName -like $Filter -and
         !(Check-Exceptions $_.FullName $PassedExceptions)}
    $TargetFiles+=$TargetList | Where-Object {$_.PSIsContainer -eq $False -and $_.FullName -like $Filter -and
         !(Check-Exceptions $_.FullName $PassedExceptions)}
    $SourceFolders+=$SourceList | Where-Object {$_.PSIsContainer -eq $True -and !(Check-Exceptions $_.FullName $PassedExceptions)}
    $TargetFolders+=$TargetList | Where-Object {$_.PSIsContainer -eq $True -and !(Check-Exceptions $_.FullName $PassedExceptions)}
    $MissingFiles=Compare-Object $SourceFiles $TargetFiles -Property Name
    $MissingFolders=Compare-Object $SourceFolders $TargetFolders -Property Name
    foreach ($MissingFile in $MissingFiles)
    {
        $Output=New-ReportObject
        if($MissingFile.SideIndicator -eq "<=")
        {
            $Output.Process="Copy File"
            try
            {          
                $Output.Message="Copying missing file : $($TargetFolder+"\"+$MissingFile.Name)" 
                Write-Verbose $Output.Message
                Copy-Item -LiteralPath ($SourceFolder+"\"+$MissingFile.Name) -Destination ($TargetFolder+"\"+$MissingFile.Name) -WhatIf:$WhatIf
                $Output.Successful=$True
            }
            catch
            {
                $Output.Message="Error copying missing file $($TargetFolder+"\"+$MissingFile.Name)"
                Write-Error $Output.Message
                Write-Error $_
            }
        } <#elseif ($MissingFile.SideIndicator="=>")
        {
            $Output.Process="Remove File"
            try
            {
                $Output.Message="Removing file missing from Source : $($TargetFolder+"\"+$MissingFile.Name)"
                Write-Verbose $Output.Message
                Remove-Item -LiteralPath ($TargetFolder+"\"+$MissingFile.Name) -WhatIf:$WhatIf
                $Output.Successful=$True
            }
            catch
            {
                $Output.Message="Error removing file $($TargetFolder+"\"+$MissingFile.Name)"
                Write-Error $Output.Message
                Write-Error $_
            }           
        }#>
        $Output
         
    }
    
	<#foreach ($MissingFolder in $MissingFolders)
    {        
        if ($MissingFolder.SideIndicator -eq "=>")
        {
            $Output=New-ReportObject
            $Output.Process="Remove Folder"
            try
            {
                $Output.Message="Removing folder missing from Source : $($TargetFolder+"\"+$MissingFolder.Name)"
                Write-Verbose $Output.Message
                Remove-Item -LiteralPath ($TargetFolder+"\"+$MissingFolder.Name) -Recurse -WhatIf:$WhatIf
                $Output.Successful=$True
            }
            catch
            {
                $Output.Message="Error removing folder $($TargetFolder+"\"+$MissingFolder.Name)"
                Write-Error $Output.Message
                Write-Error $_
            }
            $Output
        }   
    }#>
	
    #foreach ($SourceFile in $SourceFiles)
    ForEach ($TargetFile in $TargetFiles)
    {
        $MatchingSourceFile= $SourceFiles | Where-Object {$_.Name -eq $TargetFiles.Name}
        If ($MatchingSourceFile -ne $Null)
        {
            If ($MatchingSourceFile.LastWriteTime -gt $TargetFile.LastWriteTime)
            #if ($SourceFile.LastWriteTime -gt ((Get-ChildItem -LiteralPath ($TargetFolder+"\"+$SourceFile.Name)).LastWriteTime))
            {
                $Output=New-ReportObject
                $Output.Process="Update File"
                try
                {
                    $Output.Message="Copying updated file : $($TargetFolder+"\"+$MatchingSourceFile.Name)"
                    Write-Verbose $Output.Message
                    Copy-Item -LiteralPath ($SourceFolder+"\"+$MatchingSourceFile.Name) -Destination ($TargetFolder+"\"+$MatchingSourceFile.Name) -Force -WhatIf:$WhatIf
                    $Output.Successful=$True
                }
                catch
                {
                    $Output.Message="Error copying updated file $($TargetFolder+"\"+$MatchingSourceFile.Name)"
                    Write-Error $Output.Message
                    Write-Error $_
                }
                $Output
            }

        }      
    }
    foreach($SingleFolder in $SourceFolders)
    {
        Sync-OneFolder -SourceFolder $SingleFolder.FullName -TargetFolder ($TargetFolder+"\"+$SingleFolder.Name) -PassedExceptions $PassedExceptions -Filter $Filter -WhatIf:$WhatIf #
    }
}

$Changes=$CurrentExceptions=@()
$CurrentFilter="*"
Write-Verbose "Running Sync-Folder Script"
If ($WhatIf)
{
        Write-Host "WhatIf Switch specified;  no changes will be made."
}
if ($PSBoundParameters.ContainsKey("SourceFolder"))
{
    Write-Verbose "Syncing folder pair passed as parameters."
    Sync-OneFolder -SourceFolder $SourceFolder -TargetFolder $TargetFolder -PassedExceptions $Exceptions -Filter $Filter -WhatIf:$WhatIf | 
        Tee-Object -Variable Changes
}else
{
    Write-Verbose "Running with Configuration File : $ConfigurationFile"
    $Config=[xml](Get-Content $ConfigurationFile)
    foreach ($Pair in $Config.Configuration.SyncPair)
    {
        Write-verbose "Processing Pair $($Pair.Source) $($Pair.Target)"
        $CurrentExceptions=$Null
        If(Get-PropertyExists -Queryobject $Pair -PropertyName ExceptionList)
        {
            $CurrentExceptions=@($Pair.ExceptionList.Exception)
        }
        If(Get-PropertyExists -Queryobject $Pair -PropertyName Filter)
        {
            if (($Pair.Filter -ne $Null) -and ($Pair.Filter -ne ""))
            {
                $CurrentFilter=$Pair.Filter
            }
        }   
        Sync-OneFolder -SourceFolder $Pair.Source -TargetFolder $Pair.Target -PassedExceptions $CurrentExceptions -Filter $CurrentFilter -WhatIf:$WhatIf |
             Tee-Object -Variable Changes
            
    }
}
$FolderCreations=$FileCopies=$FileRemovals=$FolderRemovals=$FileUpdates=0
Foreach ($Change in $Changes)
{
    switch ($Change.Process)
    {
        "Create Folder"{$FolderCreations+=1}
        "Copy File"{$FileCopies+=1}
        "Remove File"{$FileRemovals+=1}
        "Remove Folder"{$FolderRemovals+=1}
        "Update File"{$FileUpdates+=1}
    }
}
Write-Host "`nStatistics`n"
Write-Host "Folder Creations: `t$FolderCreations"
Write-Host "Folder Removals: `t$FolderRemovals"
Write-Host "File Copies: `t`t$FileCopies"
Write-Host "File Removals: `t`t$FileRemovals"
Write-Host "File Updates: `t`t$FileUpdates`n"