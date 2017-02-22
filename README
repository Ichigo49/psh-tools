# directory where my scripts are stored
$fullPathIncFileName = $MyInvocation.MyCommand.Definition
$rootdir = (Get-Item $fullPathIncFileName).Directory
$psdir = $rootdir
$pslib = Join-Path $psdir "lib"
# load all 'autoload' scripts
get-childitem "${psdir}\autoload\*.ps1" | sort | %{.$_}
