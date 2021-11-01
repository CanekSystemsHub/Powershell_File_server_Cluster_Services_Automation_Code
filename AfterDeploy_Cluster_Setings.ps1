Get-ClusterQuorum -Cluster chsmfso02111 | select *
$FQDN = "learn.taleocloud.prd"


# Cluster Resource settings 

Get-ClusterResource -Cluster CHSMCNO02101 | Select Name, restartperiod, RetryPeriodOnFailure


            $CLuster_Name = "CHSMCNO02101"
            $ResourceValuesQ = @()
            $ResourceValuesQ = Get-ClusterResource -Cluster $CLuster_Name | Select Name, restartperiod, RetryPeriodOnFailure
            $ResourceValuesQ
            $ResourceValuesQ | Out-File  -Encoding ascii -Append $AppendLog 

            Foreach ($value in $ResourceValuesQ)
            {
                Get-ClusterResource -Cluster $CLuster_Name -Name $value.Name | % {$_.restartperiod = "120000"}
                Get-ClusterResource -Cluster $CLuster_Name -Name $value.Name | % {$_.RetryPeriodOnFailure = "120000"}
            }


            Write-log "values have been set as the standard" -Type INFO
            $NewResourceValuesQ = @()
            $NewResourceValuesQ = Get-ClusterResource -Cluster $CLuster_Name | Select Name, restartperiod, RetryPeriodOnFailure
            $NewResourceValuesQ
            $NewResourceValuesQ | Out-File  -Encoding ascii -Append $AppendLog 




            $FSGroupValues = @()
            $FSGroupValues = Get-ClusterGroup -Cluster $CLuster_Name | where State -eq "Online" | Select Name, FailoverThreshold, FailoverPeriod
            $FSGroupValues
            $FSGroupValues | Out-File  -Encoding ascii -Append $AppendLog 
            
            Foreach ($FSvalue in $FSGroupValues)
            {
                 Get-ClusterGroup -Cluster $CLuster_Name -Name $FSvalue.Name | % {$_.FailoverThreshold = "3"}
                 Get-ClusterGroup -Cluster $CLuster_Name -Name $FSvalue.Name | % {$_.FailoverPeriod = "2"}
            }
            Write-log "FS group values have been set as the standard" -Type INFO
            $NewFSGroupValues = @()
            $NewFSGroupValues = Get-ClusterGroup -Cluster $CLuster_Name | where State -eq "Online" | Select Name, FailoverThreshold, FailoverPeriod
            $NewFSGroupValues
            $NewFSGroupValues | Out-File  -Encoding ascii -Append $AppendLog 

            Write-log "So far all the standard configurations have been set. Since this is to migrate a new cluster. `r From now on the migration should be coordinated with the teams. `r Script completed." -Type INFO
            Start-Sleep 60

# Set the $FS_X_Final Computer Names corresponding of the Shares to avoid Accidental deletion in AD
Write-log "Time to set the Computer Names corresponding of the Shares to avoid Accidental deletion in AD" -Type INFO

    $FS_1_Final = "CHO0201-FS"
    $FS_2_Final = "CHO0202-FS"
    $FS_3_Final = "CHO0203-FS"
    $FS_4_Final = "CHO0204-FS"
    $FS_Shares = @()
    $FS_Shares = $FS_1_Final,$FS_2_Final,$FS_3_Final,$FS_4_Final
    
    Foreach ($Share in $FS_Shares)
    {
        get-ADObject -server $FQDN -filter 'name -like $share' | set-adobject -ProtectedFromAccidentalDeletion:$true
        $Protect_Sh1 = get-ADObject -server $FQDN -filter 'name -like $Share' -Properties protectedfromaccidentaldeletion
        If ($Protect_Sh1.ProtectedFromAccidentalDeletion)
        {
            Write-log "$Share was set successfully to *Protected From Accidental Deletion*" -Type INFO
        }
        Else
        {
            Write-log "$Share was NOT set successfully to *Protected From Accidental Deletion* check you have proper permission in AD to do so or request assitence " -Type Error
        }
    }

  


# Shares creation:


# Get content from AddDataFolders.txt file since the folder name is the smae as the Share to be created.
$Validate_groups = Get-Content .\AddADGroups.txt
$Share_ADGroups = @()
        foreach($Line in $Validate_groups)
        {
            $Share_ADGroups += $FQDN + "\" + $Line.Substring(21)
   
        }

    #Clear-Variable -Name ScriptBlockSMB 
    $ScriptBlockSMB =
    {
        Param([Array]$Share_ADGroups)
        $FQDN = "learn.taleocloud.prd"
        $ShareNames = @()
        $ShareNames = Get-Content C:\Windows\Temp\AddDataFolders.txt
        $ShareBXBF_E = $ShareNames[0].Substring(5) + "$"
        $ShareINBF_F = $ShareNames[1].Substring(5) + "$"
        $ShareINBF_G = $ShareNames[2].Substring(5) + "$"
        $ShareRPBF_H = $ShareNames[3].Substring(5) + "$"
        $ShareLGBE_I = $ShareNames[4].Substring(5) + "$"
        $ShareLGFE_I = $ShareNames[5].Substring(5) + "$"
        $ShareUTBF_J = $ShareNames[6].Substring(5) + "$"

        $PathBXBF_E = "E:\Data\" + $ShareNames[0].Substring(2)
        $PathBXBF_F = "F:\Data\" + $ShareNames[1].Substring(2)
        $PathBXBF_G = "G:\Data\" + $ShareNames[2].Substring(2)
        $PathBXBF_H = "H:\Data\" + $ShareNames[3].Substring(2)
        $PathBXBE_I = "I:\Data\" + $ShareNames[4].Substring(2)
        $PathBXFE_I = "I:\Data\" + $ShareNames[5].Substring(2)
        $PathBXBF_J = "J:\Data\" + $ShareNames[6].Substring(2)

        $Group1 = $FQDN + "\" + $Validate_groups[0].Substring(21)

        New-SmbShare -Name $ShareBXBF_E -path $PathBXBF_E -FolderEnumerationMode AccessBased -FullAccess "Administrators","$FQDN\G_Ops_Admins" -ChangeAccess $Share_ADGroups[0]        
        New-SmbShare -Name $ShareINBF_F -path $PathBXBF_F -FolderEnumerationMode AccessBased -FullAccess "Administrators","$FQDN\G_Ops_Admins" -ChangeAccess $Share_ADGroups[1]        
        New-SmbShare -Name $ShareINBF_G -path $PathBXBF_G -FolderEnumerationMode AccessBased -FullAccess "Administrators","$FQDN\G_Ops_Admins" -ChangeAccess $Share_ADGroups[2]        
        New-SmbShare -Name $ShareRPBF_H -path $PathBXBF_H -FolderEnumerationMode AccessBased -FullAccess "Administrators","$FQDN\G_Ops_Admins" -ChangeAccess $Share_ADGroups[3]        
        New-SmbShare -Name $ShareLGBE_I -path $PathBXBE_I -FolderEnumerationMode AccessBased -FullAccess "Administrators","$FQDN\G_Ops_Admins" -ChangeAccess $Share_ADGroups[4]        
        New-SmbShare -Name $ShareLGFE_I -path $PathBXFE_I -FolderEnumerationMode AccessBased -FullAccess "Administrators","$FQDN\G_Ops_Admins" -ChangeAccess $Share_ADGroups[5]        
        New-SmbShare -Name $ShareUTBF_J -path $PathBXBF_J -FolderEnumerationMode AccessBased -FullAccess "Administrators","$FQDN\G_Ops_Admins" -ChangeAccess $Share_ADGroups[6]

        Get-SmbShareAccess -Name $ShareBXBF_E
        Get-SmbShareAccess -Name $ShareINBF_F
        Get-SmbShareAccess -Name $ShareINBF_G
        Get-SmbShareAccess -Name $ShareRPBF_H
        Get-SmbShareAccess -Name $ShareRPBF_H
        Get-SmbShareAccess -name $ShareLGFE_I
        Get-SmbShareAccess -Name $ShareUTBF_J
    }


    $SMBResult = Invoke-Command -ComputerName chsmfso02111.learn.taleocloud.prd -ScriptBlock $ScriptBlockSMB -ArgumentList (,$Share_ADGroups)

    write-log "Below shares have been created successfully and the granted access is listed as well" -Type INFO
    $SMBResult
    $SMBResult | Out-File  -Encoding ascii -Append $AppendLog

    #Get-SmbShare -CimSession $Node_1


