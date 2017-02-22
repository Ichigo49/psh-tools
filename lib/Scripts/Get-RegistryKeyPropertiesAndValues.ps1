Function Get-RegistryKeyPropertiesAndValues
{
  <#
   .Synopsis
    This function accepts a registry path and returns all reg key properties and values

   .Description
    This function returns registry key properies and values.

   .Example
    Get-RegistryKeyPropertiesAndValues -path 'HKCU:\Volatile Environment'

    Returns all of the registry property values under the \volatile environment key

   .Parameter path
    The path to the registry key

   .Notes
    NAME:  Get-RegistryKeyPropertiesAndValues
    AUTHOR: ed wilson, msft
    LASTEDIT: 05/09/2012 15:18:41
    KEYWORDS: Operating System, Registry, Scripting Techniques, Getting Started
    HSG: 5-11-12
   .Link
     Http://www.ScriptingGuys.com/blog
 #>

    Param( [Parameter(Mandatory=$true)]
           [string]$path)

     Push-Location
     Set-Location -Path $path
     Get-Item . |
        Select-Object -ExpandProperty property |
            ForEach-Object {
                New-Object psobject -Property @{"property"=$_;
                    "Value" = (Get-ItemProperty -Path . -Name $_).$_}}
     Pop-Location

} 
