##############################################################################
# Populate_HPE_Synergy.ps1
#
# - Example script for configuring the HPE Synergy Appliance
#
#   VERSION 1.0
#
#   AUTHORS
#   Dave Olker - HPE Global Solutions Engineering (BEST)
#
# (C) Copyright 2017 Hewlett Packard Enterprise Development LP 
##############################################################################
<#
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>


function Add_Remote_Enclosures
{
    Write-Output "Adding Remote Enclosures" | Timestamp
    Send-HPOVRequest -uri "/rest/enclosures" -method POST -body @{'hostname' = 'fe80::2:0:9:7%eth2'} | Wait-HPOVTaskComplete
    Write-Output "Remote Enclosures Added" | Timestamp
}


function Configure_SAN_Managers
{
    Write-Output "Configuring SAN Managers" | Timestamp
    Add-HPOVSanManager -Hostname 172.18.20.1 -SnmpUserName dcs-SHA-AES128 -SnmpAuthLevel AuthAndPriv -SnmpAuthPassword hpinvent! -SnmpAuthProtocol sha -SnmpPrivPassword hpinvent! -SnmpPrivProtocol aes-128 -Type Cisco -Port 161 | Wait-HPOVTaskComplete
    Add-HPOVSanManager -Hostname 172.18.20.2 -SnmpUserName dcs-SHA-AES128 -SnmpAuthLevel AuthAndPriv -SnmpAuthPassword hpinvent! -SnmpAuthProtocol sha -SnmpPrivPassword hpinvent! -SnmpPrivProtocol aes-128 -Type Cisco -Port 161 | Wait-HPOVTaskComplete
    Write-Output "SAN Manager Configuration Complete" | Timestamp
}


function Configure_Networks
{
    ##########################################################################
    #
    # Process variables in the Populate_HPE_Synergy-Params.txt file.
    #
    ##########################################################################
    New-Variable -Name config_file -Value .\Populate_HPE_Synergy-Params.txt

    if (Test-Path $config_file) {    
        Get-Content $config_file | Where-Object { !$_.StartsWith("#") } | Foreach-Object {
            $var = $_.Split('=')
            New-Variable -Name $var[0] -Value $var[1]
        }
    } else { 
        Write-Output "Configuration file '$config_file' not found.  Exiting." | Timestamp
        Exit
    }
    
    Write-Output "Adding IPv4 Subnets" | Timestamp
    New-HPOVAddressPoolSubnet -Domain "mgmt.lan" -Gateway $prod_gateway -NetworkId $prod_subnet -SubnetMask $prod_mask
    New-HPOVAddressPoolSubnet -Domain "deployment.lan" -Gateway $deploy_gateway -NetworkId $deploy_subnet -SubnetMask $deploy_mask
    
    Write-Output "Adding IPv4 Address Pool Ranges" | Timestamp
    Get-HPOVAddressPoolSubnet -NetworkId $prod_subnet | New-HPOVAddressPoolRange -Name Mgmt -Start $prod_pool_start -End $prod_pool_end
    Get-HPOVAddressPoolSubnet -NetworkId $deploy_subnet | New-HPOVAddressPoolRange -Name Deployment -Start $deploy_pool_start -End $deploy_pool_end
    
    Write-Output "Adding Networks" | Timestamp
    New-HPOVNetwork -Name "ESX Mgmt" -MaximumBandwidth 20000 -Purpose Management -Type Ethernet -TypicalBandwidth 2500 -VlanId 1131 -VLANType Tagged
    New-HPOVNetwork -Name "ESX vMotion" -MaximumBandwidth 20000 -Purpose VMMigration -Type Ethernet -TypicalBandwidth 2500 -VlanId 1132 -VLANType Tagged
    New-HPOVNetwork -Name Prod_1101 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1101 -VLANType Tagged
    New-HPOVNetwork -Name Prod_1102 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1102 -VLANType Tagged
    New-HPOVNetwork -Name Prod_1103 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1103 -VLANType Tagged
    New-HPOVNetwork -Name Prod_1104 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1104 -VLANType Tagged
    New-HPOVNetwork -Name Deployment -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1500 -VLANType Tagged
    Set-HPOVNetwork -InputObject Deployment -IPv4Subnet $deploy_subnet
    New-HPOVNetwork -Name Mgmt -MaximumBandwidth 20000 -Purpose Management -Type Ethernet -TypicalBandwidth 2500 -VlanId 100 -VLANType Tagged
    Set-HPOVNetwork -InputObject Mgmt -IPv4Subnet $prod_subnet
    New-HPOVNetwork -Name "SAN A FC" -Type "Fibre Channel" -FabricType FabricAttach -LinkStabilityTime 30 -ManagedSan VSAN20 -MaximumBandwidth 20000 -TypicalBandwidth 8000
    New-HPOVNetwork -Name "SAN B FC" -Type "Fibre Channel" -FabricType FabricAttach -LinkStabilityTime 30 -ManagedSan VSAN21 -MaximumBandwidth 20000 -TypicalBandwidth 8000
    New-HPOVNetwork -Name "SAN A FCoE" -VlanId 10 -ManagedSan VSAN10 -MaximumBandwidth 20000 -Type FCoE -TypicalBandwidth 8000
    New-HPOVNetwork -Name "SAN B FCoE" -VlanId 11 -ManagedSan VSAN11 -MaximumBandwidth 20000 -Type FCoE -TypicalBandwidth 8000
    
    Write-Output "Adding Network Sets" | Timestamp
    New-HPOVNetworkSet -Name Prod -Networks Prod_1101, Prod_1102, Prod_1103, Prod_1104 -MaximumBandwidth 20000 -TypicalBandwidth 2500
    
    Write-Output "Networking Configuration Complete" | Timestamp
}


function Add_Storage
{
    Write-Output "Adding Storage Systems" | Timestamp
    Add-HPOVStorageSystem -Hostname 172.18.11.11 -Password dcs -Username dcs -Domain TestDomain | Wait-HPOVTaskComplete
    Add-HPOVStorageSystem -Hostname 172.18.11.12 -Password dcs -Username dcs -Domain TestDomain | Wait-HPOVTaskComplete

    Write-Output "Adding Storage Pools" | Timestamp
    $StoragePools = "CPG-SSD", "CPG-SSD-AO", "CPG_FC-AO", "FST_CPG1", "FST_CPG2"
    Add-HPOVStoragePool -StorageSystem "ThreePAR7200-6710" $StoragePools | Wait-HPOVTaskComplete
    Add-HPOVStoragePool -StorageSystem "ThreePAR7200-6955" $StoragePools | Wait-HPOVTaskComplete

    Write-Output "Adding Storage Volume Templates" | Timestamp
    New-HPOVStorageVolumeTemplate -capacity 100 -Name SVT-Demo-Shared -StoragePool CPG-SSD -Shared -SnapshotStoragePool CPG-SSD -StorageSystem ThreePAR7200-6710
    Write-Output "Adding Storage Volumes" | Timestamp
    New-HPOVStorageVolume -Capacity 200 -Name Demo-Volume-1 -StoragePool FST_CPG1 -SnapshotStoragePool FST_CPG1 -StorageSystem ThreePAR7200-6710 | Wait-HPOVTaskComplete
    New-HPOVStorageVolume -Capacity 200 -Name Shared-Volume-1 -StoragePool FST_CPG1 -SnapshotStoragePool FST_CPG1 -Shared -StorageSystem ThreePAR7200-6955 | Wait-HPOVTaskComplete
    New-HPOVStorageVolume -Capacity 200 -Name Shared-Volume-2 -StoragePool FST_CPG1 -SnapshotStoragePool FST_CPG1 -Shared -StorageSystem ThreePAR7200-6955 | Wait-HPOVTaskComplete

    Write-Output "Storage Configuration Complete" | Timestamp
}


function Rename_Enclosures
{
    Write-Output "Renaming Enclosures" | Timestamp
    Get-HPOVEnclosure -Name 0000A66101 -ErrorAction SilentlyContinue | Set-HPOVEnclosure -Name Synergy-Encl-1 | Wait-HPOVTaskComplete
    Get-HPOVEnclosure -Name 0000A66102 -ErrorAction SilentlyContinue | Set-HPOVEnclosure -Name Synergy-Encl-2 | Wait-HPOVTaskComplete
    Get-HPOVEnclosure -Name 0000A66103 -ErrorAction SilentlyContinue | Set-HPOVEnclosure -Name Synergy-Encl-3 | Wait-HPOVTaskComplete
    Get-HPOVEnclosure -Name 0000A66104 -ErrorAction SilentlyContinue | Set-HPOVEnclosure -Name Synergy-Encl-4 | Wait-HPOVTaskComplete
    Get-HPOVEnclosure -Name 0000A66105 -ErrorAction SilentlyContinue | Set-HPOVEnclosure -Name Synergy-Encl-5 | Wait-HPOVTaskComplete
    #
    # Sleep for 60 seconds to allow Enclosure renaming to complete
    #
    Start-Sleep -Seconds 60
    Write-Output "All Enclosures Renamed" | Timestamp
}


function Create_Uplink_Sets
{
    Write-Output "Adding Fibre Channel Uplink Sets" | Timestamp
    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-SAN-A-FC" -Type FibreChannel -Networks "SAN A FC" -UplinkPorts "Enclosure1:BAY3:Q2.1"
    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-SAN-B-FC" -Type FibreChannel -Networks "SAN B FC" -UplinkPorts "Enclosure2:BAY6:Q2.1"
    
    Write-Output "Adding FCoE Uplink Sets" | Timestamp
    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-SAN-A-FCoE" -Type Ethernet -Networks "SAN A FCoE" -UplinkPorts "Enclosure1:BAY3:Q1.1" -LacpTimer Short
    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-SAN-B-FCoE" -Type Ethernet -Networks "SAN B FCoE" -UplinkPorts "Enclosure2:BAY6:Q1.1" -LacpTimer Short

    Write-Output "Adding FlexFabric Uplink Sets" | Timestamp
    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-ESX-Mgmt" -Type Ethernet -Networks "ESX Mgmt" -UplinkPorts "Enclosure1:Bay3:Q1.2","Enclosure2:Bay6:Q1.2"
    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-ESX-vMotion" -Type Ethernet -Networks "ESX vMotion" -UplinkPorts "Enclosure1:Bay3:Q1.3","Enclosure2:Bay6:Q1.3"
    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-Prod" -Type Ethernet -Networks "Prod_1101","Prod_1102","Prod_1103","Prod_1104" -UplinkPorts "Enclosure1:Bay3:Q1.4","Enclosure2:Bay6:Q1.4"
    
    Write-Output "Adding ImageStreamer Uplink Sets" | Timestamp
    $ImageStreamerDeploymentNetworkObject = Get-HPOVNetwork -Name "Deployment" -ErrorAction Stop
    Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric" -ErrorAction Stop | New-HPOVUplinkSet -Name "US-Image Streamer" -Type ImageStreamer -Networks $ImageStreamerDeploymentNetworkObject -UplinkPorts "Enclosure1:Bay3:Q5.1","Enclosure1:Bay3:Q6.1","Enclosure2:Bay6:Q5.1","Enclosure2:Bay6:Q6.1"
    
    Write-Output "All Uplink Sets Configured" | Timestamp
}


function Create_Enclosure_Group
{
    ##########################################################################
    #
    # Process variables in the Populate_HPE_Synergy-Params.txt file.
    #
    ##########################################################################
    Write-Output "Creating Enclosure Group" | Timestamp
    New-Variable -Name config_file -Value .\Populate_HPE_Synergy-Params.txt
    if (Test-Path $config_file) {    
        Get-Content $config_file | Where-Object { !$_.StartsWith("#") } | Foreach-Object {
            $var = $_.Split('=')
            New-Variable -Name $var[0] -Value $var[1]
        }
    } else { 
        Write-Output "Configuration file '$config_file' not found.  Exiting."
        Exit
    }
    
    $AddressPool = Get-HPOVAddressPoolSubnet -NetworkId $deploy_subnet -ErrorAction Stop | Get-HPOVAddressPoolRange
    $3FrameVCLIG = Get-HPOVLogicalInterconnectGroup -Name LIG-FlexFabric
    $SasLIG = Get-HPOVLogicalInterconnectGroup -Name LIG-SAS
    $FcLIG = Get-HPOVLogicalInterconnectGroup -Name LIG-FC
    New-HPOVEnclosureGroup -name "EG-Synergy-Local" -LogicalInterconnectGroupMapping @{Frame1 = $3FrameVCLIG,$SasLIG,$FcLIG; Frame2 = $3FrameVCLIG,$SasLIG,$FcLIG; Frame3 = $3FrameVCLIG,$SasLIG,$FcLIG} -EnclosureCount 3 -IPv4AddressType External -DeploymentNetworkType Internal

    Write-Output "Enclosure Group Created" | Timestamp
}


function Create_Logical_Enclosure
{
    Write-Output "Creating Logical Enclosure" | Timestamp
    $EG = Get-HPOVEnclosureGroup -Name EG-Synergy-Local
    $Encl = Get-HPOVEnclosure -Name Synergy-Encl-1
    New-HPOVLogicalEnclosure -EnclosureGroup $EG -Name LE-Synergy-Local -Enclosure $Encl
    Write-Output "Logical Enclosure Created" | Timestamp
}


function Create_Logical_Interconnect_Groups
{
    Write-Output "Creating Logical Interconnect Groups" | Timestamp
    New-HPOVLogicalInterconnectGroup -Name "LIG-SAS" -FrameCount 1 -InterconnectBaySet 1 -FabricModuleType "SAS" -Bays @{Frame1 = @{Bay1 = "SE12SAS" ; Bay4 = "SE12SAS"}}
    New-HPOVLogicalInterconnectGroup -Name "LIG-FC" -FrameCount 1 -InterconnectBaySet 2 -FabricModuleType "SEVCFC" -Bays @{Frame1 = @{Bay2 = "SEVC16GbFC" ; Bay5 = "SEVC16GbFC"}}
    New-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric" -FrameCount 3 -InterconnectBaySet 3 -FabricModuleType "SEVC40F8" -Bays @{Frame1 = @{Bay3 = "SEVC40f8" ; Bay6 = "SE20ILM"};Frame2 = @{Bay3 = "SE20ILM"; Bay6 = "SEVC40f8" };Frame3 = @{Bay3 = "SE20ILM"; Bay6 = "SE20ILM"}} -FabricRedundancy "HighlyAvailable"
    Write-Output "Logical Interconnect Groups Created" | Timestamp
}


function Add_Licenses
{
    Write-Output "Adding Two OneView Advanced Licenses" | Timestamp
    $ov_license_1 = Read-Host "Optional: Enter First OneView Advanced 16-Server License"
    if ($ov_license_1) {
        New-HPOVLicense -LicenseKey $ov_license_1
    }
    
    $ov_license_2 = Read-Host "Optional: Enter Second OneView Advanced 16-Server License"
    if ($ov_license_2) {
        New-HPOVLicense -LicenseKey $ov_license_2
    }
    
    Write-Output "Adding Two Synergy 8GB FC Licenses" | Timestamp
    $fc_license_1 = Read-Host "Optional: Enter First Synergy 8GB FC License"
    if ($fc_license_1) {
        New-HPOVLicense -LicenseKey $fc_license_1
    }
    
    $fc_license_2 = Read-Host "Optional: Enter Second Synergy 8GB FC License"
    if ($fc_license_2) {
        New-HPOVLicense -LicenseKey $fc_license_2
    }
    
    Write-Output "All Licenses Added" | Timestamp
}


function Add_Firmware_Bundle
{
    Write-Output "Adding Firmware Bundles" | Timestamp
    $firmware_bundle = Read-Host "Optional: Specify location of Service Pack for ProLiant ISO file"
    if ($firmware_bundle) {
        if (Test-Path $firmware_bundle) {   
            Add-HPOVBaseline -File $firmware_bundle | Wait-HPOVTaskComplete
        }
        else { 
            Write-Output "Service Pack for ProLiant file '$firmware_bundle' not found.  Skipping firmware upload."
        }
    }

    Write-Output "Firmware Bundle Added" | Timestamp
}


function Create_OS_Deployment_Server
{
    Write-Output "Configuring OS Deployment Servers" | Timestamp
    $ManagementNetwork = Get-HPOVNetwork -Type Ethernet -Name "Mgmt"
    Get-HPOVImageStreamerAppliance | Select-Object -First 1 | New-HPOVOSDeploymentServer -Name "LE1 Image Streamer" -ManagementNetwork $ManagementNetwork -Description "Image Streamer for Logical Enclosure 1" | Wait-HPOVTaskComplete
    Write-Output "OS Deployment Server Configured" | Timestamp
}


function Create_Server_Profile_Template_Local_Storage
{
    Write-Output "Creating Local Storage Server Profile Template" | Timestamp
    
    $SHT = Get-HPOVServerHardwareTypes -Name "SY 480 Gen9 1"
    $EnclGroup = Get-HPOVEnclosureGroup "EG-Synergy-Local"
    $Eth1 = Get-HPOVNetwork "Prod_1101" | New-HPOVServerProfileConnection -ConnectionID 1 -ConnectionType Ethernet -Name Prod-1101
    $Eth2 = Get-HPOVNetwork "Prod_1102" | New-HPOVServerProfileConnection -ConnectionID 2 -ConnectionType Ethernet -Name Prod-1102
    $LogicalDisk = New-HPOVServerProfileLogicalDisk -Name "SAS RAID1 SSD" -RAID RAID1 -NumberofDrives 2 -DriveType SASSSD -Bootable $True
    $Controller = New-HPOVServerProfileLogicalDiskController -Initialize -Mode RAID -LogicalDisk $LogicalDisk
    
    $params = @{
        Affinity                 = "Bay";
        BootMode                 = "UEFI";
        Connections              = $Eth1, $Eth2;
        Description              = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module with Local Storage";
        EnclosureGroup           = $EnclGroup;
        HideUnusedFlexNics       = $True;
        LocalStorage             = $True;
        ManageBoot               = $True;
        Name                     = "HPE Synergy 480 Gen9 Profile Template";
        ServerHardwareType       = $SHT;
        ServerProfileDescription = "Server Profile for HPE Synergy 480 Gen9 Compute Module";
        StorageController        = $Controller
    }

    New-HPOVServerProfileTemplate @params | Wait-HPOVTaskComplete
    
    Write-Output "Local Storage Server Profile Template Created" | Timestamp
}


function Create_Server_Profile_Local_Storage
{
    Write-Output "Creating Local Storage Server Profile" | Timestamp
    $SPT = Get-HPOVServerProfileTemplate -Name "HPE Synergy 480 Gen9 Profile Template"
    Get-HPOVServer -Name "Synergy-Encl-1, Bay 5" | New-HPOVServerProfile -Name "Syn-480-Gen9-01" -Description "HPE Synergy 480 Gen9 Server" -AssignmentType "Bay" -ServerProfileTemplate $SPT | Wait-HPOVTaskComplete
    Write-Output "Local Storage Server Profile Created" | Timestamp
}


function Create_Server_Profile_Template_SAN_Storage
{
    Write-Output "Creating SAN Storage Server Profile Template" | Timestamp
    
    $SHT = Get-HPOVServerHardwareTypes -Name "SY 660 Gen9 1"
    $EnclGroup = Get-HPOVEnclosureGroup "EG-Synergy-Local"
    $Eth1 = Get-HPOVNetwork "Prod_1101" | New-HPOVServerProfileConnection -ConnectionID 1 -ConnectionType Ethernet -Name Prod-1101 -Priority NotBootable
    $Eth2 = Get-HPOVNetwork "Prod_1102" | New-HPOVServerProfileConnection -ConnectionID 2 -ConnectionType Ethernet -Name Prod-1102 -Priority NotBootable
    $FC1 = Get-HPOVNetwork "SAN A FC" | New-HPOVServerProfileConnection -ConnectionID 3 -ConnectionType FibreChannel -Name "SAN-A"
    $FC2 = Get-HPOVNetwork "SAN B FC" | New-HPOVServerProfileConnection -ConnectionID 4 -ConnectionType FibreChannel -Name "SAN-B"
    $SANVol = Get-HPOVStorageVolume -Name "Shared-Volume-2" | New-HPOVProfileAttachVolume -LunIdType Manual -LunID 0
    $LogicalDisk = New-HPOVServerProfileLogicalDisk -Name "SAS RAID5 SSD" -RAID RAID5 -NumberofDrives 3 -DriveType SASSSD -Bootable $True
    $Controller = New-HPOVServerProfileLogicalDiskController -Initialize -Mode RAID -LogicalDisk $LogicalDisk

    $params = @{
        Affinity                 = "Bay";
        BootMode                 = "UEFI";
        Connections              = $Eth1, $Eth2, $FC1, $FC2;
        Description              = "Server Profile Template for HPE Synergy 660 Gen9 Compute Module with Local and SAN Storage";
        EnclosureGroup           = $EnclGroup;
        HideUnusedFlexNics       = $True;
        LocalStorage             = $True;
        HostOStype               = "Win2k12";
        ManageBoot               = $True;
        Name                     = "HPE Synergy 660 Gen9 Profile Template";
        SANStorage               = $True;
        ServerHardwareType       = $SHT;
        ServerProfileDescription = "Server Profile for HPE Synergy 660 Gen9 Compute Module";
        StorageController        = $Controller;
        StorageVolume            = $SANVol        
    }

    New-HPOVServerProfileTemplate @params | Wait-HPOVTaskComplete
    
    Write-Output "SAN Boot Server Profile Template Created" | Timestamp
}


function Create_Server_Profile_SAN_Storage
{
    Write-Output "Creating SAN Storage Server Profile" | Timestamp
    $SPT = Get-HPOVServerProfileTemplate -Name "HPE Synergy 660 Gen9 Profile Template"
    Get-HPOVServer -Name "Synergy-Encl-1, Bay 3" | New-HPOVServerProfile -Name "Syn-660-Gen9-01" -Description "HPE Synergy 660 Gen9 Server" -AssignmentType Bay -ServerProfileTemplate $SPT | Wait-HPOVTaskComplete
    Write-Output "SAN Storage Server Profile Created" | Timestamp
}


function PowerOff_All_Servers
{
    Write-Output "Powering Off All Servers" | Timestamp

    $Servers = Get-HPOVServer
    
    $Servers | ForEach-Object {
        if ($_.PowerState -ne "Off") {
            Write-Host "Server $($_.Name) is $($_.PowerState).  Powering off..." | Timestamp
            Stop-HPOVServer -Server $_ -Force -Confirm:$false | Wait-HPOVTaskComplete
        }
    }
    
    Write-Output "All Servers Powered Off" | Timestamp
}


function Add_Users
{
    Write-Output "Adding New Users" | Timestamp

    New-HPOVUser -UserName BackupAdmin -FullName "Backup Administrator" -Password BackupPasswd -Roles "Backup Administrator" -EmailAddress "backup@hpe.com" -OfficePhone "(111) 111-1111" -MobilePhone "(999) 999-9999"
    New-HPOVUser -UserName NetworkAdmin -FullName "Network Administrator" -Password NetworkPasswd -Roles "Network Administrator" -EmailAddress "network@hpe.com" -OfficePhone "(222) 222-2222" -MobilePhone "(888) 888-8888"
    New-HPOVUser -UserName ServerAdmin -FullName "Server Administrator" -Password ServerPasswd -Roles "Server Administrator" -EmailAddress "server@hpe.com" -OfficePhone "(333) 333-3333" -MobilePhone "(777) 777-7777"
    New-HPOVUser -UserName StorageAdmin -FullName "Storage Administrator" -Password StoragePasswd -Roles "Storage Administrator" -EmailAddress "storage@hpe.com" -OfficePhone "(444) 444-4444" -MobilePhone "(666) 666-6666"
    New-HPOVUser -UserName SoftwareAdmin -FullName "Software Administrator" -Password SoftwarePasswd -Roles "Software Administrator" -EmailAddress "software@hpe.com" -OfficePhone "(555) 555-5555" -MobilePhone "(123) 234-3456"

    Write-Output "All New Users Added" | Timestamp
}


function Add_Scopes
{
    Write-Output "Adding New Scopes" | Timestamp

    New-HPOVScope -Name FinanceScope -Description "Finance Scope of Resources"
    $Resources += Get-HPOVNetwork -Name Prod*
    $Resources += Get-HPOVEnclosure -Name Synergy-Encl-1
    Get-HPOVScope -Name FinanceScope | Add-HPOVResourceToScope -InputObject $Resources

    Write-Output "All New Scopes Added" | Timestamp
}


##############################################################################
#
# Main Program
#
##############################################################################

if (-not (get-module HPOneview.300)) 
{
    Import-Module HPOneView.300
}

if (-not $ConnectedSessions) 
{
	$Appliance = Read-Host 'ApplianceName'
	$Username  = Read-Host 'Username'
	$Password  = Read-Host 'Password' -AsSecureString

    $ApplianceConnection = Connect-HPOVMgmt -Hostname $Appliance -Username $Username -Password $Password

    if (-not $ConnectedSessions)
    {
        Write-Output "Login to Synergy Appliance failed.  Exiting."
        Exit
    } 
    else {
        Import-HPOVSslCertificate
    }
}

filter Timestamp {"$(Get-Date -Format G): $_"}

Write-Output "Configuring HPE Synergy Appliance" | Timestamp

Add_Firmware_Bundle
Add_Licenses
Add_Remote_Enclosures
Rename_Enclosures
PowerOff_All_Servers
Configure_SAN_Managers
Configure_Networks
Add_Storage
Add_Users
Create_OS_Deployment_Server
Create_Logical_Interconnect_Groups
Create_Uplink_Sets
Create_Enclosure_Group
Create_Logical_Enclosure
Create_Server_Profile_Template_Local_Storage
Create_Server_Profile_Template_SAN_Storage
Create_Server_Profile_Local_Storage
Create_Server_Profile_SAN_Storage
Add_Scopes

Write-Output "HPE Synergy Appliance Configuration Complete" | Timestamp
