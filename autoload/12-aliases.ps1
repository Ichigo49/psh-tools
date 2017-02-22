New-Alias -Name gcmd -Value get-command -Force
New-Alias -Name null -Value out-null -Force
New-Alias -Name ad -Value importad -Force
New-Alias -Name vim -Value addvmware -Force
New-Alias -Name vmm -Value addvmm -Force
New-Alias -Name sz -Value "$psdir\bin\7za.exe" -Force
New-alias -Name exps -Value exploreps -Force
New-alias -Name ex -Value explore -Force
New-alias -Name newc -Value New-Console -Force
New-Alias -Name Open-Url -Value Start-SystemProcess -Force
New-Alias -Name sysinfo -Value "$pslib\Scripts\SYS_INFO.ps1" -Force
if (!(Get-Alias git -ErrorAction 0)) {New-Alias -Name git -Value "$Env:ProgramFiles\Git\bin\git.exe"}
if (!(Get-Alias rdp -ErrorAction 0)) {New-Alias -name rdp -Value mstsc -Force}
if (!(Get-Alias rld -ErrorAction 0)) {New-Alias rld Reload-Profile -Force} 
if (!(Get-PSDrive lib -ErrorAction 0)) {New-PSDrive -name lib -PSProvider FileSystem -Root $psdir | Out-Null}
Set-Location $psdir
