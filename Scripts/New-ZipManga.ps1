[CmdletBinding()]  
param($Path) 
 
$list = Get-ChildItem -LiteralPath $Path 
$PathLoc = Get-Location
foreach ($Item in $list) { 
    if ($Item.GetType().Name -eq 'DirectoryInfo') { 
        Write-verbose "Compressing $($Item.Name) to $($Item.Name).7z" 
        Get-Item -LiteralPath $Item.fullname | Compress-7zip -ArchiveFileName "$($Item.Name).7z"
$ZipFile = Join-Path $PathLoc.Path "$($Item.Name).7z"
Move-Item -LiteralPath $ZipFile -Destination $Path
Get-ChildItem -LiteralPath $Item.fullname -recurse | Remove-Item -recurse -force
Remove-Item -LiteralPath $Item.fullname -force
    }
}

$PathItem = Get-Item -LiteralPath $Path
$PathName = $PathItem.Name
$PathDir = $PathItem.DirectoryName
Write-verbose "Compressing $PathName to $PathName.7z" 
Get-Item -LiteralPath $Path | Compress-7zip -ArchiveFileName "$PathName.7z"
$AllZipFile = Join-Path $PathLoc.Path "$PathName.7z"
Move-Item -LiteralPath $AllZipFile $PathDir
Remove-Item -LiteralPath $Path -Recurse -Force
