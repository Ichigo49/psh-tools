@{

# Script module or binary module file associated with this manifest.
RootModule = '.\PSParallel.dll'

# Version number of this module.
ModuleVersion = '2.2.2'

# ID used to uniquely identify this module
GUID = '79e69e01-f25c-4745-9a57-846bfe194855'

# Author of this module
Author = 'PowerCode'

# Copyright statement for this module
Copyright = '(c) 2015 PowerCode. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Provides Invoke-Parallel <scriptblock> that runs the scriptblock in parallel in separate runspaces' 

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '4.0'

# Minimum version of Microsoft .NET Framework required by this module
DotNetFrameworkVersion = '4.5'

# Cmdlets to export from this module
CmdletsToExport = 'Invoke-Parallel'

# Aliases to export from this module
AliasesToExport = 'ipa'

# List of all files packaged with this module
FileList = @('.\PSParallel.psd1', '.\PSParallel.dll', '.\en-US\about_PSParallel.Help.txt', '.\en-US\about_PSParallel.Help.txt')

PrivateData = @{
    PSData = @{        
        Tags = @('Parallel','Runspace','Invoke','Foreach')        
        LicenseUri = 'https://github.com/powercode/PSParallel/blob/master/LICENSE'
        ProjectUri = 'https://github.com/powercode/PSParallel'
        IconUri = 'https://github.com/powercode/PSParallel/blob/master/images/PSParallel_icon.png'                
        ReleaseNotes = @'
2.2.1
Fixing issue with -NoProgress resulting in null reference
2.2.0
Fixing issues with reuse of runspaces
Grouped progress
Variables PSParallelIndex and PSParallelProgressId available in the parallel runspaces
Simplified interface by removing parameters to import things from invoking runspace. Use
InitialSessionState instead.     
'@
    } # End of PSData hashtable

} # End of PrivateData hashtable
}

