function Get-LinuxTemplates{
    $lnxtpl = Get-Template | Get-View | where {$_.Guest.GuestFamily -eq 'linuxGuest'} | Get-VIObjectByVIView
    return $lnxtpl
}