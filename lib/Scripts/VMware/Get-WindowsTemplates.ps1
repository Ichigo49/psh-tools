function Get-WindowsTemplates{
    $wintpl = Get-Template | Get-View | where {$_.Guest.GuestFamily -eq 'windowsGuest'} | Get-VIObjectByVIView
    return $wintpl
}