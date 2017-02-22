#handle PS2
if(-not $PSScriptRoot)
{
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

#Verbose output if this isn't master, or we are testing locally
$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master" -or -not $env:APPVEYOR_REPO_BRANCH)
{
    $Verbose.add("Verbose",$False)
}

$PSVersion = $PSVersionTable.PSVersion.Major
Import-Module $PSScriptRoot\..\PS7Zip -Verbose -Force -ErrorAction SilentlyContinue

Describe "PS7Zip Module PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should load all functions' {
            $Commands = @( Get-Command -CommandType Function -Module PS7Zip | Select -ExpandProperty Name)
            $Commands.count | Should be 3
            $Commands -contains "Compress-7Zip" | Should be $True
            $Commands -contains "Expand-7Zip"   | Should be $True
            $Commands -contains "Get-7Zip"      | Should be $True
        }
    }
}
 
Describe "Compress-7Zip Function PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should create archive.zip in the current working folder' {
            New-Item archive -ItemType Directory
            Compress-7Zip .\archive
            Test-Path .\archive.zip | Should Be $True
            Remove-Item archive*
        }
        It 'should create a gzip archive of a single file and delete the uncompressed file' {
            New-Item archive.csv -ItemType File
            New-Item folder -ItemType Directory
            Compress-7Zip "archive.csv" -OutputFile ".\folder\files.gz" -ArchiveType GZIP -Remove $True
            Test-Path .\folder\files.gz | Should Be $True
            Test-Path .\archive.csv | Should Be $False
        }
        It 'should create an archive based on pipeline input' {
            New-Item archive.txt -ItemType File
            Get-ChildItem archive.txt | Compress-7Zip
            Test-Path .\archive.zip | Should Be $True
            Remove-Item archive.txt
        }
    }
}

Describe "Expand-7Zip Function PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should extract contents of archive.zip in the current working folder' {
            Expand-7Zip archive.zip
            Test-Path .\archive.txt | Should Be $True
            Remove-Item archive.txt
        }
        It 'should extract contents of .\folder\files.gz into current working folder' {
            Expand-7Zip ".\folder\files.gz"
            Test-Path .\archive.csv | Should Be $True
            Remove-Item archive.csv
        }
    }
}

Describe "Get-7Zip Function PS$PSVersion" {
    Context 'Strict mode' {
        Set-StrictMode -Version latest
        It 'should list contents of archive.zip in the current working folder' {
            $get7ziptest1 = Get-7Zip archive.zip
            Test-Path Variable:get7ziptest1 | Should Be $True
            Remove-Item archive*
        }
        It 'should list contents of .\folder\files.gz' {
            $get7ziptest2 = Get-7Zip ".\folder\files.gz"
            Test-Path Variable:get7ziptest2 | Should Be $True
            Remove-Item folder -Recurse
        }
    }
}