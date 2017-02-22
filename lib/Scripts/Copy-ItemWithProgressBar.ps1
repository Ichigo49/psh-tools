function Copy-ItemWithProgressBar
{
	<#
	.Notes
	AUTHOR:   Arnaud Petitjean
	VERSION:  1.0
	CREATED:  11/26/2012
	LASTEDIT: 

	.Synopsis
	Copie un répertoire ainsi que ses objets enfants d'un emplacement à un autre en affichant une barre de progression.

	.Description
	La copie des objets s'effectue de façon récursive. Si le répertoire de destination n'existe pas, il sera créé automatiquement.

	.Parameter Source
	Spécifie le chemin d'accès de l'objet à copier. Il s'agit généralement d'un répertoire.

	.Parameter Destination
	Spécifie le chemin d'accès de l'emplacement où les éléments doivent être copiés.

	.Example
	PS > Copy-ItemWithProgressBar -Source C:\temp\monDossier -Destination D:\

	Copie le répertoire C:\temp\monDossier ainsi que son contenu vers D:\ en affichant une barre de progression.

		.Example
	PS > Copy-ItemWithProgressBar -Source .\monDossier -Destination D:\temp

	Copie le répertoire "monDossier" à partir du chemin courant ainsi que son contenu vers D:\temp en affichant une barre de progression.
	#>
	[cmdletBinding()]
	Param (
	[parameter(Mandatory=$true, ValueFromPipeline=$true)]$Source,
	[parameter(Mandatory=$true, ValueFromPipeline=$false)]$Destination
	)

	begin
	{
		$numberofitems = @(Get-ChildItem $Source).count
		$cpt = 0
		$Source = Get-Item -Path $Source
	}

	process
	{
		if ($Source.PSIsContainer) {
			foreach ($item in (Get-ChildItem $Source)) {
				if (!(Test-Path $Destination)) {
					New-Item -Path $Destination -ItemType Directory | Out-Null
				}
				if ($item.PSIsContainer) {
					Copy-ItemWithProgressBar -Source $item.FullName -Destination (Join-Path $Destination $item.Name)
				}
				else {
					$cpt++
					Copy-Item -Path $item.Fullname -Destination $Destination
					Write-Progress -Id 1 -Activity ("Copie du répertoire {0}" -f $Source) -PercentComplete ($cpt / $numberofitems * 100) -Status ("Copie du fichier {0} - {1} sur {2}" -f $item.Name, $cpt, $numberofitems)
				}
			}
		} 
	}
}