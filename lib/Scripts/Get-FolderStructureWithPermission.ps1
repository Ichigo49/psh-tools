function Get-FolderStructureWithPermission
{
  param
  (
    [String]
    [Parameter(Mandatory)]
    $Path
  )
  
  if ((Test-Path -Path $Path -PathType Container) -eq $false) 
  {
    throw "$Path does not exist or is no directory!"
  }

  Get-ChildItem -Path $Path -Recurse -Directory |
  ForEach-Object {
    $sd = Get-Acl -Path $_.FullName
    $sddl = $sd.GetSecurityDescriptorSddlForm('all')
  
  
    [PSCustomObject]@{
      Path = $_.FullName.Substring($Path.Length)
      SDDL = $sddl
    }
  
  }
}