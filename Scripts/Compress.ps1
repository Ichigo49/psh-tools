[CmdletBinding()] 
param($Path)

#$listDir = Get-ChildItem -LiteralPath $Path | Where-Object {$_.PsIsontainer} 
$list = Get-ChildItem -LiteralPath $Path
foreach ($Item in $list) {
    if ($Item.GetType().Name -eq 'DirectoryInfo') {
        Write-verbose "Compressing $($Item.Name) to $($Item.Name).7z"
        Get-Item -LiteralPath $Item.fullname | Compress-7zip -ArchiveFileName "$($Item.Name).7z"
    } 
}
$PathName = (Get-Item -LiteralPath $Path).Name
Write-verbose "Compressing $PathName to $PathName.7z"
Get-Item -LiteralPath $Path | Compress-7zip -ArchiveFileName "$PathName.7z"