<# 	Name: Upgrade-VMHost.ps1
	Author: Jim McMahon II
	Date: 6/8/2017
	Synopsis: Automate a rolling upgrade of vSphere Hosts using Update Manager. 
	Description: This script automates the upgrade of vSphere Hosts using Update Manager. This script upgrades hosts one at a time to 
	prevent an outage. This script is designed for environments where change control will typically only allow limited cluster upgrades at 
	any one time.
	
	Below example applys the baseline ESXi-55-U3 to testcluster and creates host backups on a file server. Each host will have its own folder.
	Example: .\Upgrade-VMHost.ps1 -ClusterName "testcluster" -Baseline "ESXi-55-U3" -ConfigBackupDestination "\\fileserver\backup\config"

	Below example applys the baseline ESXi-55-U3 to all clusters and creates host backups on a file server. Each host will have its own folder.
	Example: .\Upgrade-VMHost.ps1 -ClusterName (Get-Datacenter Site-B | Get-Cluster) -Baseline "ESXi-55-U3" -ConfigBackupDestination "\\fileserver\backup\config"
	#>

[CmdletBinding()]
Param(
	[parameter(valuefrompipeline = $true, mandatory = $true,
		HelpMessage = "Enter the name of the cluster to upgrade.")]
		[PSObject]$ClusterName,
	[parameter(mandatory = $true,
		HelpMessage = "Enter the name of the Host Upgrade Baseline to apply.")]
		[String]$Baseline,
	[parameter(mandatory = $true,
		HelpMessage = "Enter the path where host backups should be stored. Use \\server\backup\config or C:\backup\config.")]
		[string]$ConfigBackupDestination
	)


<#********************************************************************************
	Begin Script
  ********************************************************************************#>	
#$cluster = Get-Cluster $ClusterName
$clusterName | Foreach-Object {
$cluster = Get-Cluster $_
<#Disable HA if it is enabled.
$enableHA = ""
if ($cluster.HAEnabled -eq "True"){
		Set-Cluster $cluster -HAEnabled:$false -Confirm:$false
		$enableHA = $true
	}#>
	
#Disconnect all ISOs that may be attached to VMs and set the CD Drive state to "disconnected"
$cluster | Get-VM | Get-CDDrive | where {
	($_.IsoPath -ne $null) -or ($_.ConnectionState.Connected -eq "true")} | 
	Set-CDDrive -NoMedia -Connected:$false -Confirm:$false
	
#Create backup location for each host
$cfgBakDst = $ConfigBackupDestination.TrimEnd("\")
$cluster | Get-VMHost | Foreach-Object {
	New-Item -ItemType Directory -Force -Path $cfgBakDst\$_}

#Backup host configuration to the host folder that was created
$success = $cluster | Get-VMHost | Foreach-Object {
	Get-VMHostFirmware $_ -BackupConfiguration -DestinationPath $cfgBakDst\$_}

#Apply baseline to cluster
Add-EntityBaseline -Entity $cluster -Baseline (Get-Baseline $baseline)

#Test baseline compliance on the cluster
Test-Compliance -Entity $cluster

#Check for host compliance to the applied baseline.
$hostNotComp = $success | Foreach-Object {
	Get-Compliance (Get-VMHost $_.host.name) | Where-Object {$_.Status -eq "NotCompliant"}}
	
#Compare cluster vs success; Add difference to new Object with backup failure for now upgrade
$tmpSuccess = @()
$tmpNotComp = @()

foreach ($y in $success) {$tmpSuccess += $y.host.name}
foreach ($x in $hostNotComp) {$tmpNotComp += $x.entity.name}

$hostUpgrade = $tmpSuccess | Where {$tmpNotComp -Contains $_}

$base = Get-Baseline $baseline

#Update hosts limiting the number of parallel installs
Write-Host "*******************************************************`nBeginning baseline installation `n*******************************************************`n" -ForegroundColor Magenta
$hostUpgrade | Foreach-Object {
	Write-Host "Installing baseline $base.Name on host $_" -ForegroundColor  Green
	Update-Entity -Entity $_ -Baseline $base -ClusterDisableHighAvailability:$true -ClusterEnableParallelRemediation:$true -Confirm:$False -WhatIf
	}

<#Enable HA if it was previously enabled
if ($enableHA){
		Set-Cluster $cluster -HAEnabled:$true -Confirm:$false
	}#>
}

$ClusterName | Foreach-Object {
	Write-Host "Review host compliance on cluster $_ below:" -ForegroundColor  Magenta
	Test-Compliance -Entity $cluster
	}
	
<#********************************************************************************
	End Script
  ********************************************************************************#>