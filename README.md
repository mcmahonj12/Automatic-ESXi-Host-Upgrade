# Automatic-ESXi-Host-Upgrade
Host upgrade uses performs configuration backups of hosts and uses VUM to upgrade hosts which are backed up and "NonCompliant" serially. Clusters can be upgraded one at a time and the script accepts pipeline in the ClusterName paramater to upgrade multiple clusters if desired.

The script first gets the cluster objects which were specified. Mutiple clusters can be specified if desired. It then gets all hosts in
the cluster to be upgraded and attempts to disconnect any ISOs which may be connected to VMs. These ISOs may prevent the host from 
entering maintenance mode.

A backup of all host configurations is then taken and stored in the "ConfigBackupLocation" which was specified. In the event a host experiences 
and issue following the upgrade, the host configuration can quickly be restored. The upgrade baseline is then applied and each host is 
checked for compliance. There are 3 types:
  - Compliant: We'll do nothing
  - NonCompliant: We'll upgrade
  - Incompatible: The host either requires a reboot or a 3rd party driver is not compatible with the version. Review the VUM log for details.

Hosts which are not compliant are placed into a variable and compared to the hosts which backed up their configuration successfully. Only hosts 
with a successful backup and are noncompliant are upgraded.

Finally, the baseline is applied to each host serially and the upgrade begins. The following occurs:
1. Host is placed into maintenance mode. All VMs are migrated to other hosts in the cluster.
2. The installer is downloaded to the host.
3. The upgrade is performed.
4. Host will wait 4-5 minutes following the successful upgrade while logs are sent to VUM.
5. Host reboots.
6. Once the host re-connects to the vCenter Server, the host is removed from maintenance mode and the process begins again.

Steps to prepare and run the script:
1. Download an ESXi ISO image from the VMware respository.
2. Add any required 3rd party VIBs as desired to the image. Use ImageBuilder to perform this task and export the new image as an ISO.
3. Add the new ISO (downloaded or modified) to the VUM image repository.
4. Create an upgrade baseline with the upgrade ISO file as the source image.
5. Create a file share or local repository to store host backups.
6. Run the script specifying the
  - ClusterName
  - Baseline: The name of the upgrade baseline just created. Use Get-Baseline to see a list of baselines if unsure.
  - ConfigBackupDestination: This is the destination for host configuration backups. This can be a UNC path.
  
