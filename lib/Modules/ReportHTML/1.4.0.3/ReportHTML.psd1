#
# Module manifest for module 'PSGet_ReportHTML'
#
# Generated by: Matthew Quickenden
#
# Generated on: 12/13/2016
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'ReportHTML.psm1'

# Version number of this module.
ModuleVersion = '1.4.0.3'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '13c25942-f436-44e1-b236-66e3ae11a8a0'

# Author of this module
Author = 'Matthew Quickenden'

# Company or vendor of this module
CompanyName = 'Avanade'

# Copyright statement for this module
Copyright = '(c) 2017. All rights reserved.'

# Description of the functionality provided by this module
Description = 'A module for creating HTML reports within PowerShell.  For more details see this four part blog series.  http://www.azurefieldnotes.com/2016/08/04/powershellhtmlreportingpart1'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '2.0'

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
DotNetFrameworkVersion = '2.0'

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
CLRVersion = '2.0.50727'

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
#RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @('ReportHTMLHelp.psm1')

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport ='*'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = '*'

# Variables to export from this module
# VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('PSModule','HTML','Reporting','Charts','AzureAutomation')

        # A URL to the license for this module.
        #LicenseUri = 'http://use.it/do.it/do.it/'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/azurefieldnotes/ReportHTML/'

        # A URL to an icon representing this module.
        IconUri = 'https://azurefieldnotesblog.blob.core.windows.net/wp-content/2016/08/HTMLReport-600x239.jpg'

        # ReleaseNotes of this module
        ReleaseNotes = 'Added Change log to Help File'

        # External dependent modules of this module
        # ExternalModuleDependencies = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
HelpInfoURI = 'http://www.azurefieldnotes.com/help-reporthtml1/'

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

