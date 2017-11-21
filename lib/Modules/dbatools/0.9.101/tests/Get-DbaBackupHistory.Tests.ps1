﻿$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1","")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
	
	BeforeAll {
		$DestBackupDir = 'C:\Temp\backups'
		if (-Not(Test-Path $DestBackupDir)) {
			New-Item -Type Container -Path $DestBackupDir
		}
		$random = Get-Random
		$dbname = "dbatoolsci_history_$random"
		$null = Get-DbaDatabase -SqlInstance $script:instance1 -Database $dbname | Remove-DbaDatabase -Confirm:$false
		$null = Restore-DbaDatabase -SqlInstance $script:instance1 -Path $script:appeyorlabrepo\singlerestore\singlerestore.bak -DatabaseName $dbname -DestinationFilePrefix $dbname
		$db = Get-DbaDatabase -SqlInstance $script:instance1 -Database $dbname
		$db | Backup-DbaDatabase -Type Full -BackupDirectory $DestBackupDir
		$db | Backup-DbaDatabase -Type Differential -BackupDirectory $DestBackupDir
		$db | Backup-DbaDatabase -Type Log -BackupDirectory $DestBackupDir
		$db | Backup-DbaDatabase -Type Log -BackupDirectory $DestBackupDir
		$null = Get-DbaDatabase -SqlInstance $script:instance1 -Database master | Backup-DbaDatabase -Type Full
		$db | Backup-DbaDatabase -Type Full -BackupDirectory $DestBackupDir -BackupFileName CopyOnly.bak -CopyOnly
 	}
	
	AfterAll {
		$null = Get-DbaDatabase -SqlInstance $script:instance1 -Database $dbname | Remove-DbaDatabase -Confirm:$false
	}
	
	Context "Get last history for single database" {
		$results = Get-DbaBackupHistory -SqlInstance $script:instance1 -Database $dbname -Last
		It "Should be 4 backups returned" {
			$results.count | Should Be 4
		}
		It "First backup should be a Full Backup" {
			$results[0].Type | Should be "Full"
		}
		It "Last Backup Should be a log backup" {
			$results[-1].Type | Should Be "Log"
		}
	}
	
	Context "Get last history for all databases" {
		$results = Get-DbaBackupHistory -SqlInstance $script:instance1
		It "Should be more than one database" {
			($results | Where-Object Database -match "master").Count | Should BeGreaterThan 0
		}
	}

	Context "Testing IncludeCopyOnly with LastFull"{
		$results = Get-DbaBackupHistory -SqlInstance $script:instance1 -LastFull -Database $dbname
		$resultsCo = Get-DbaBackupHistory -SqlInstance $script:instance1 -LastFull -IncludeCopyOnly -Database $dbname
		It "Should return the CopyOnly Backup"{
			($resultsCo.BackupSetID -ne $Results.BackupSetID) | Should Be $True
		}
	}

	Context "Testing IncludeCopyOnly with Last"{
		$resultsCo = Get-DbaBackupHistory -SqlInstance $script:instance1 -Last -IncludeCopyOnly -Database $dbname
		It "Should return just the CopyOnly Full Backup"{
			($resultsCo | Measure-Object).count | Should Be 1
		}
	}
}