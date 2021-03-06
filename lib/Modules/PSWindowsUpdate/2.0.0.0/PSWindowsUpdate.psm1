Get-ChildItem -Path $PSScriptRoot | Unblock-File

#support old function name
New-Alias Get-WUList Get-WindowsUpdate
New-Alias Get-WUInstall Get-WindowsUpdate

New-Alias Install-WindowsUpdate Get-WindowsUpdate
New-Alias Download-WindowsUpdate Get-WindowsUpdate
New-Alias Hide-WindowsUpdate Get-WindowsUpdate
New-Alias Show-WindowsUpdate Get-WindowsUpdate
New-Alias Uninstall-WindowsUpdate Remove-WindowsUpdate

Export-ModuleMember -Cmdlet * -Alias *