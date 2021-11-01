Import
Get-ADUser –Identity victor.m.jimenez -Properties uidNumber, gidNumber


$DomainLearn='DC=LEARN,DC=TALEOCLOUD,DC=PRD'
cd ..
D:

        New-PSDrive `
            –Name LEARN `
            –PSProvider ActiveDirectory `
            –Server "chcsdcx02001.learn.taleocloud.prd" `
            –Root "//RootDSE/" `
            -Scope Global
            
cd LEARN:
cd $DomainLearn

Get-ADUser –Identity sa_syprbxe02001 -Properties uidNumber, gidNumber


Write-Progress -Status -PercentComplete -SecondsRemaining



get-pnp

get-help *cluster*

$DiskAdded  = Get-ClusterResource -Cluster $CLuster_Name | ?{ ($_.ResourceType -eq "Physical Disk") -and ($_.Name -eq "Cluster Disk 3") } | Select *

$DiskAdded.ID
$DiscoNum.Name


Get-ClusterResource -Cluster $CLuster_Name | where ResourceType -eq "Physical Disk"


# Code to get the Disk partition inside of the added disk resources in the cluster

$CurrentDisks =@()
$CurrentDisks += Get-CimInstance -Namespace Root\MSCluster -ClassName MSCluster_Resource -ComputerName $CLuster_Name | ?{$_.Type -eq 'Physical Disk'}
$CurrentDisks.Name
| Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$CurrentDisks | %{Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition} 


$CurrentDisks | where VolumeLabel -eq 'CHS00991_E'

### OLD

# Code to get the Disk partition inside of the added disk resources in hte cluster
#This is to add the disk into their correspoindig FS resource based on variable instead of flat names or disk IDs that can change
$CurrenClutDisks = Get-CimInstance -Namespace Root\MSCluster -ClassName MSCluster_Resource -ComputerName $CLuster_Name | ?{$_.Type -eq 'Physical Disk'}| Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
Write-log "Below we can see the disks added to the cluster among with their Assigned lette and Label" -Type INFO
$CurrenClutDisks
$CurrenClutDisks | Out-File  -Encoding ascii -Append $AppendLog 
    
    # Filtering the cluster disks as per label/Driver letter assigned
    $Clu_Disk_E = $CurrenClutDisks | where VolumeLabel -eq 'CHS00991_E' # This is a filter to get only E:
    $Clu_Disk_F = $CurrenClutDisks | where VolumeLabel -eq 'CHS00991_F' # This is a filter to get only F:
    $Clu_Disk_G = $CurrenClutDisks | where VolumeLabel -eq 'CHS00991_G' # This is a filter to get only G:
    $Clu_Disk_H = $CurrenClutDisks | where VolumeLabel -eq 'CHS00991_H' # This is a filter to get only H:
    $Clu_Disk_I = $CurrenClutDisks | where VolumeLabel -eq 'CHS00991_I' # This is a filter to get only I:
    $Clu_Disk_J = $CurrenClutDisks | where VolumeLabel -eq 'CHS00991_J' # This is a filter to get only J:




#### NEW

# Code to get the Disk partition inside of the added disk resources in the cluster
$AllCluDisks.count
$AllCluDisks = @()
$AllCluDisks += Get-CimInstance -Namespace Root\MSCluster -ClassName MSCluster_Resource -ComputerName $CLuster_Name | ?{$_.Type -eq 'Physical Disk'}
$DiskLetter1 = $AllCluDisks[1] | Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$DiskLetter2 = $AllCluDisks[2] | Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$DiskLetter3 = $AllCluDisks[3] | Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$DiskLetter4 = $AllCluDisks[4] | Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$DiskLetter5 = $AllCluDisks[5] | Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$DiskLetter6 = $AllCluDisks[6] | Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$DiskLetter1.Path


# From Above code Create a Hash Table to map the Drive letter with the Disk cluster Name 
$HashCluDisks  =[ordered] @{
                $DiskLetter1.Path.Substring(0,1) = $AllCluDisks[1].Name
                $DiskLetter2.Path.Substring(0,1) = $AllCluDisks[2].Name 
                $DiskLetter3.Path.Substring(0,1) = $AllCluDisks[3].Name 
                $DiskLetter4.Path.Substring(0,1) = $AllCluDisks[4].Name 
                $DiskLetter5.Path.Substring(0,1) = $AllCluDisks[5].Name 
                $DiskLetter6.Path.Substring(0,1) = $AllCluDisks[6].Name 
                }

Write-log "Found below Disk Partitions" -Type INFO
$HashCluDisks.Keys


                $HashCluDisks.E




