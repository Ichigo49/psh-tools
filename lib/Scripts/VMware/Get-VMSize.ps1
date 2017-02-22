function Get-VMSize {
    param ($vm)
	#Initialize variables
    $VmDirs =@()
    $VmSize = 0

    $searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
    $searchSpec.details = New-Object VMware.Vim.FileQueryFlags
    $searchSpec.details.fileSize = $TRUE

    Get-View -VIObject $vm | % {
        #Create an array with the vm's directories
        $VmDirs += $_.Config.Files.VmPathName.split("/")[0]
        $VmDirs += $_.Config.Files.SnapshotDirectory.split("/")[0]
        $VmDirs += $_.Config.Files.SuspendDirectory.split("/")[0]
        $VmDirs += $_.Config.Files.LogDirectory.split("/")[0]
        #Add directories of the vm's virtual disk files
        foreach ($disk in $_.Layout.Disk) {
            foreach ($diskfile in $disk.diskfile){
                $VmDirs += $diskfile.split("/")[0]
            }
        }
        #Only take unique array items
        $VmDirs = $VmDirs | Sort | Get-Unique

        foreach ($dir in $VmDirs){
            $ds = Get-Datastore ($dir.split("[")[1]).split("]")[0]
            $dsb = Get-View (($ds | get-view).Browser)
            $taskMoRef  = $dsb.SearchDatastoreSubFolders_Task($dir,$searchSpec)
            $task = Get-View $taskMoRef 

            while($task.Info.State -eq "running" -or $task.Info.State -eq "queued"){$task = Get-View $taskMoRef }
            foreach ($result in $task.Info.Result){
                foreach ($file in $result.File){
                    $VmSize += $file.FileSize
                }
            }
        }
    }

    $VmSize
}