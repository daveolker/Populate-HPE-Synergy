##############################################################################
# Populate_HPE_Synergy.ps1
#
# - Example script for configuring the HPE Synergy Appliance
#
#   VERSION 3.1
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
    Add-HPOVSanManager -Hostname 172.18.20.1 -SnmpUserName dcs-SHA-AES128 -SnmpAuthLevel AuthAndPriv -SnmpAuthPassword dcsdcsdcs -SnmpAuthProtocol sha -SnmpPrivPassword dcsdcsdcs -SnmpPrivProtocol aes-128 -Type Cisco -Port 161 | Wait-HPOVTaskComplete
    Add-HPOVSanManager -Hostname 172.18.20.2 -SnmpUserName dcs-SHA-AES128 -SnmpAuthLevel AuthAndPriv -SnmpAuthPassword dcsdcsdcs -SnmpAuthProtocol sha -SnmpPrivPassword dcsdcsdcs -SnmpPrivProtocol aes-128 -Type Cisco -Port 161 | Wait-HPOVTaskComplete
    Write-Output "SAN Manager Configuration Complete" | Timestamp
}


function Configure_Networks
{
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
    New-HPOVNetwork -Name Mgmt -MaximumBandwidth 20000 -Purpose Management -Type Ethernet -TypicalBandwidth 2500 -VlanId 100 -VLANType Tagged
    New-HPOVNetwork -Name SVCluster-1 -MaximumBandwidth 20000 -Purpose ISCSI -Type Ethernet -TypicalBandwidth 2500 -VlanId 301 -VLANType Tagged
    New-HPOVNetwork -Name SVCluster-2 -MaximumBandwidth 20000 -Purpose ISCSI -Type Ethernet -TypicalBandwidth 2500 -VlanId 302 -VLANType Tagged
    New-HPOVNetwork -Name SVCluster-3 -MaximumBandwidth 20000 -Purpose ISCSI -Type Ethernet -TypicalBandwidth 2500 -VlanId 303 -VLANType Tagged
    
    $Deploy_AddrPool = Get-HPOVAddressPoolSubnet -NetworkId $deploy_subnet
    Get-HPOVNetwork -Name Deployment | Set-HPOVNetwork -IPv4Subnet $Deploy_AddrPool
    $Prod_AddrPool = Get-HPOVAddressPoolSubnet -NetworkId $prod_subnet
    Get-HPOVNetwork -Name Mgmt | Set-HPOVNetwork -IPv4Subnet $Prod_AddrPool
    
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
    Write-Output "Adding 3PAR Storage Systems" | Timestamp
    Add-HPOVStorageSystem -Hostname 172.18.11.11 -Password dcs -Username dcs -Domain TestDomain | Wait-HPOVTaskComplete
    Add-HPOVStorageSystem -Hostname 172.18.11.12 -Password dcs -Username dcs -Domain TestDomain | Wait-HPOVTaskComplete

    Write-Output "Adding 3PAR Storage Pools" | Timestamp
    $StoragePools = "CPG-SSD", "CPG-SSD-AO", "CPG_FC-AO", "FST_CPG1", "FST_CPG2"
    Add-HPOVStoragePool -StorageSystem ThreePAR-1 $StoragePools | Wait-HPOVTaskComplete
    Add-HPOVStoragePool -StorageSystem ThreePAR-2 $StoragePools | Wait-HPOVTaskComplete

    Write-Output "Adding 3PAR Storage Volume Templates" | Timestamp
    New-HPOVStorageVolumeTemplate -Capacity 100 -Name SVT-3PAR-Shared-1 -ProvisionType Thin -StoragePool CPG-SSD -Shared -SnapshotStoragePool CPG-SSD -StorageSystem ThreePAR-1
    New-HPOVStorageVolumeTemplate -Capacity 100 -Name SVT-3PAR-Shared-2 -ProvisionType Thin -StoragePool CPG-SSD -Shared -SnapshotStoragePool CPG-SSD -StorageSystem ThreePAR-2
    
    Write-Output "Adding 3PAR Storage Volumes" | Timestamp
    New-HPOVStorageVolume -Capacity 200 -Name Demo-Volume-1 -StoragePool FST_CPG1 -SnapshotStoragePool FST_CPG1 -StorageSystem ThreePAR-1 | Wait-HPOVTaskComplete
    New-HPOVStorageVolume -Capacity 200 -Name Shared-Volume-1 -StoragePool FST_CPG1 -SnapshotStoragePool FST_CPG1 -Shared -StorageSystem ThreePAR-2 | Wait-HPOVTaskComplete
    New-HPOVStorageVolume -Capacity 200 -Name Shared-Volume-2 -StoragePool FST_CPG1 -SnapshotStoragePool FST_CPG1 -Shared -StorageSystem ThreePAR-2 | Wait-HPOVTaskComplete

    Write-Output "Adding StoreVirtual Storage Systems" | Timestamp
    $SVNet1 = Get-HPOVNetwork -Name SVCluster-1 -ErrorAction Stop
    Add-HPOVStorageSystem -Hostname 172.18.30.1 -Family StoreVirtual -Password dcs -Username dcs -VIPS @{ "172.18.30.1" = $SVNet1 } | Wait-HPOVTaskComplete
    $SVNet2 = Get-HPOVNetwork -Name SVCluster-2 -ErrorAction Stop
    Add-HPOVStorageSystem -Hostname 172.18.30.2 -Family StoreVirtual -Password dcs -Username dcs -VIPS @{ "172.18.30.2" = $SVNet2 } | Wait-HPOVTaskComplete
    $SVNet3 = Get-HPOVNetwork -Name SVCluster-3 -ErrorAction Stop
    Add-HPOVStorageSystem -Hostname 172.18.30.3 -Family StoreVirtual -Password dcs -Username dcs -VIPS @{ "172.18.30.3" = $SVNet3 } | Wait-HPOVTaskComplete

    Write-Output "Adding StoreVirtual Storage Volume Templates" | Timestamp
    New-HPOVStorageVolumeTemplate -Capacity 100 -Name SVT-StoreVirt-1 -ProvisionType Thin -StoragePool Cluster-1 -Shared -StorageSystem Cluster-1
    New-HPOVStorageVolumeTemplate -Capacity 100 -Name SVT-StoreVirt-2 -ProvisionType Thin -StoragePool Cluster-2 -Shared -StorageSystem Cluster-2
    New-HPOVStorageVolumeTemplate -Capacity 100 -Name SVT-StoreVirt-3 -ProvisionType Thin -StoragePool Cluster-3 -Shared -StorageSystem Cluster-3

    Write-Output "Storage Configuration Complete" | Timestamp
}


function Rename_Enclosures
{
    Write-Output "Renaming Enclosures" | Timestamp
    $Enc = Get-HPOVEnclosure -Name 0000A66101 -ErrorAction SilentlyContinue
    Set-HPOVEnclosure -Name Synergy-Encl-1 -Enclosure $Enc | Wait-HPOVTaskComplete

    $Enc = Get-HPOVEnclosure -Name 0000A66102 -ErrorAction SilentlyContinue
    Set-HPOVEnclosure -Name Synergy-Encl-2 -Enclosure $Enc | Wait-HPOVTaskComplete
    
    $Enc = Get-HPOVEnclosure -Name 0000A66103 -ErrorAction SilentlyContinue
    Set-HPOVEnclosure -Name Synergy-Encl-3 -Enclosure $Enc | Wait-HPOVTaskComplete
    
    $Enc = Get-HPOVEnclosure -Name 0000A66104 -ErrorAction SilentlyContinue
    Set-HPOVEnclosure -Name Synergy-Encl-4 -Enclosure $Enc | Wait-HPOVTaskComplete
    
    $Enc = Get-HPOVEnclosure -Name 0000A66105 -ErrorAction SilentlyContinue
    Set-HPOVEnclosure -Name Synergy-Encl-5 -Enclosure $Enc | Wait-HPOVTaskComplete
    
    Write-Output "All Enclosures Renamed" | Timestamp
}


function Create_Uplink_Sets
{
    Write-Output "Adding Fibre Channel and FCoE Uplink Sets" | Timestamp
    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    $SAN_A_FC = Get-HPOVNetwork -Name "SAN A FC"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-SAN-A-FC" -Type FibreChannel -Networks $SAN_A_FC -UplinkPorts "Enclosure1:BAY3:Q2.1" | Wait-HPOVTaskComplete

    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    $SAN_B_FC = Get-HPOVNetwork -Name "SAN B FC"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-SAN-B-FC" -Type FibreChannel -Networks $SAN_B_FC -UplinkPorts "Enclosure2:BAY6:Q2.1" | Wait-HPOVTaskComplete
    
    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    $SAN_A_FCoE = Get-HPOVNetwork -Name "SAN A FCoE"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-SAN-A-FCoE" -Type Ethernet -Networks $SAN_A_FCoE -UplinkPorts "Enclosure1:BAY3:Q1.1" -LacpTimer Short | Wait-HPOVTaskComplete
    
    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    $SAN_B_FCoE = Get-HPOVNetwork -Name "SAN B FCoE"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-SAN-B-FCoE" -Type Ethernet -Networks $SAN_B_FCoE -UplinkPorts "Enclosure2:BAY6:Q1.1" -LacpTimer Short | Wait-HPOVTaskComplete

    Write-Output "Adding FlexFabric Uplink Sets" | Timestamp
    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    $ESX_Mgmt = Get-HPOVNetwork -Name "ESX Mgmt"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-ESX-Mgmt" -Type Ethernet -Networks $ESX_Mgmt -UplinkPorts "Enclosure1:Bay3:Q1.2","Enclosure2:Bay6:Q1.2" | Wait-HPOVTaskComplete
    
    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    $ESX_vMotion = Get-HPOVNetwork -Name "ESX vMotion"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-ESX-vMotion" -Type Ethernet -Networks $ESX_vMotion -UplinkPorts "Enclosure1:Bay3:Q1.3","Enclosure2:Bay6:Q1.3" | Wait-HPOVTaskComplete
    
    $LIGFlex = Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric"
    $Prod_Nets = Get-HPOVNetwork -Name "Prod*"
    New-HPOVUplinkSet -Resource $LIGFlex -Name "US-Prod" -Type Ethernet -Networks $Prod_Nets -UplinkPorts "Enclosure1:Bay3:Q1.4","Enclosure2:Bay6:Q1.4" | Wait-HPOVTaskComplete
    
    Write-Output "Adding ImageStreamer Uplink Sets" | Timestamp
    $ImageStreamerDeploymentNetworkObject = Get-HPOVNetwork -Name "Deployment" -ErrorAction Stop
    Get-HPOVLogicalInterconnectGroup -Name "LIG-FlexFabric" -ErrorAction Stop | New-HPOVUplinkSet -Name "US-Image Streamer" -Type ImageStreamer -Networks $ImageStreamerDeploymentNetworkObject -UplinkPorts "Enclosure1:Bay3:Q5.1","Enclosure1:Bay3:Q6.1","Enclosure2:Bay6:Q5.1","Enclosure2:Bay6:Q6.1" | Wait-HPOVTaskComplete
    
    Write-Output "All Uplink Sets Configured" | Timestamp
}


function Create_Enclosure_Group
{
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
    New-HPOVLogicalEnclosure -EnclosureGroup $EG -Name LE-Synergy-Local -Enclosure $Encl | Wait-HPOVTaskComplete
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
    Write-Output "Adding OneView and Synergy FC Licenses" | Timestamp
    
    $License_File = Read-Host -Prompt "Optional: Enter Filename Containing OneView and Synergy FC Licenses"
    if ($License_File) {
        New-HPOVLicense -File $License_File
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


function Create_Server_Profile_Template_SY480_RHEL_Local_Storage
{
    Write-Output "Creating Local Storage Server Profile Template" | Timestamp
    
    $SY480Gen9SHT      = Get-HPOVServerHardwareTypes -name "SY 480 Gen9 1" -ErrorAction Stop
    $EnclGroup         = Get-HPOVEnclosureGroup -Name "EG-Synergy-Local" -ErrorAction Stop
    $FWBaseline        = Get-HPOVBaseline
    $Eth1              = Get-HPOVNetwork -Name "Prod_1101" | New-HPOVServerProfileConnection -ConnectionID 1 -Name 'Prod-1101' -PortId "Mezz 3:1-c" -ErrorAction Stop
    $Eth2              = Get-HPOVNetwork -Name "Prod_1102" | New-HPOVServerProfileConnection -ConnectionID 2 -Name 'Prod-1102' -PortId "Mezz 3:2-c" -ErrorAction Stop
    $Deploy1           = Get-HPOVNetwork -Name "Deployment" | New-HPOVServerProfileConnection -ConnectionID 3 -Name 'Deployment Network A' -PortId "Mezz 3:1-a" -Bootable -Priority Primary -ErrorAction Stop
    $Deploy2           = Get-HPOVNetwork -Name "Deployment" | New-HPOVServerProfileConnection -ConnectionID 4 -Name 'Deployment Network B' -PortId "Mezz 3:2-a" -Bootable -Priority Secondary -ErrorAction Stop
    $LogicalDisk       = New-HPOVServerProfileLogicalDisk -Name "SAS RAID1 SSD" -RAID RAID1 -NumberofDrives 2 -DriveType SASSSD -ErrorAction Stop
    $StorageController = New-HPOVServerProfileLogicalDiskController -ControllerID Embedded -Mode RAID -Initialize -LogicalDisk $LogicalDisk -ErrorAction Stop
    
    $params = @{
        Affinity                 = "Bay";
        Baseline                 = $FWBaseline;
        BootMode                 = "UEFI";
        BootOrder                = "HardDisk";
        Connections              = $Eth1, $Eth2, $Deploy1, $Deploy2;
        Description              = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module with Local Storage";
        EnclosureGroup           = $EnclGroup;
        Firmware                 = $False;
        FirmwareMode             = "FirmwareOffline";
        HideUnusedFlexNics       = $True;
        LocalStorage             = $True;
        HostOStype               = "RHEL";
        ManageBoot               = $True;
        Name                     = "HPE Synergy 480 Gen9 RHEL with Local Storage Template";
        SANStorage               = $False;
        ServerHardwareType       = $SY480Gen9SHT;
        ServerProfileDescription = "Server Profile for HPE Synergy 480 Gen9 Compute Module with Local Storage";
        StorageController        = $StorageController;
        StorageVolume            = $LogicalDisk
    }

    New-HPOVServerProfileTemplate @params | Wait-HPOVTaskComplete
    
    Write-Output "Local Storage Server Profile Template Created" | Timestamp
}


function Create_Server_Profile_SY480_RHEL_Local_Storage
{
    Write-Output "Creating Local Storage Server Profile" | Timestamp
    
    $SY480Gen9SHT   = Get-HPOVServerHardwareTypes -name "SY 480 Gen9 1" -ErrorAction Stop
    $Template       = Get-HPOVServerProfileTemplate -Name "HPE Synergy 480 Gen9 RHEL with Local Storage Template" -ErrorAction Stop
    $DeploymentPlan = Get-HPOVOSDeploymentPlan -Name "Basic Deployment Plan" -ErrorAction Stop
    $Server         = Get-HPOVServer -ServerHardwareType $SY480Gen9SHT -NoProfile -ErrorAction Stop | Select-Object -First 1 
    
    $params = @{
        AssignmentType        = "Bay";
        Description           = "HPE Synergy 480 Gen9 Server";
        Name                  = "SP - SY480-RHEL-Local-Storage";
        OSDeploymentPlan      = $DeploymentPlan;
        Server                = $Server;
        ServerProfileTemplate = $Template
    }

    New-HPOVServerProfile @params | Wait-HPOVTaskComplete
    Get-HPOVServerProfile | Update-HPOVServerProfile -Confirm:$false

    Write-Output "SY480 Local Storage Server Profile Created" | Timestamp
}


function Create_Server_Profile_Template_SY660_Windows_SAN_Storage
{
    Write-Output "Creating SAN Storage Server Profile Template" | Timestamp

    $SY660Gen9SHT      = Get-HPOVServerHardwareTypes -name "SY 660 Gen9 1" -ErrorAction Stop
    $EnclGroup         = Get-HPOVEnclosureGroup -Name "EG-Synergy-Local" -ErrorAction Stop
    $FWBaseline        = Get-HPOVBaseline
    $Eth1              = Get-HPOVNetwork -Name "Prod_1101" | New-HPOVServerProfileConnection -ConnectionID 1 -Name 'Prod-1101' -PortId "Mezz 3:1-c" -ErrorAction Stop
    $Eth2              = Get-HPOVNetwork -Name "Prod_1102" | New-HPOVServerProfileConnection -ConnectionID 2 -Name 'Prod-1102' -PortId "Mezz 3:2-c" -ErrorAction Stop
    $FC1               = Get-HPOVNetwork -Name 'SAN A FC' | New-HPOVServerProfileConnection -connectionId 3 -ErrorAction Stop
    $FC2               = Get-HPOVNetwork -Name 'SAN B FC' | New-HPOVServerProfileConnection -connectionId 4 -ErrorAction Stop
    $LogicalDisk       = New-HPOVServerProfileLogicalDisk -Name "SAS RAID5 SSD" -RAID RAID5 -NumberofDrives 3 -DriveType SASSSD -ErrorAction Stop
    $SANVol            = Get-HPOVStorageVolume -Name "Shared-Volume-2" | New-HPOVProfileAttachVolume -LunIdType Manual -LunID 0 -ErrorAction Stop
    $StorageController = New-HPOVServerProfileLogicalDiskController -ControllerID Embedded -Mode RAID -Initialize -LogicalDisk $LogicalDisk -ErrorAction Stop

    $params = @{
        Affinity                 = "Bay";
        Baseline                 = $FWBaseline;
        BootMode                 = "UEFI";
        BootOrder                = "HardDisk";
        Connections              = $Eth1, $Eth2, $FC1, $FC2;
        Description              = "Server Profile Template for HPE Synergy 660 Gen9 Compute Module with Local and SAN Storage";
        EnclosureGroup           = $EnclGroup;
        Firmware                 = $False;
        FirmwareMode             = "FirmwareOffline";
        HideUnusedFlexNics       = $True;
        LocalStorage             = $True;
        HostOStype               = "Win2k12";
        ManageBoot               = $True;
        Name                     = "HPE Synergy 660 Gen9 Windows with SAN Storage Template";
        SANStorage               = $True;
        ServerHardwareType       = $SY660Gen9SHT;
        ServerProfileDescription = "Server Profile for HPE Synergy 660 Gen9 Compute Module with SAN Storage";
        StorageController        = $StorageController;
        StorageVolume            = $SANVol
    }

    New-HPOVServerProfileTemplate @params | Wait-HPOVTaskComplete
}


function Create_Server_Profile_SY660_Windows_SAN_Storage
{
    Write-Output "Creating SAN Storage Server Profile" | Timestamp

    $SY660Gen9SHT   = Get-HPOVServerHardwareTypes -name "SY 660 Gen9 1" -ErrorAction Stop
    $Template       = Get-HPOVServerProfileTemplate -Name "HPE Synergy 660 Gen9 Windows with SAN Storage Template" -ErrorAction Stop
    $Server         = Get-HPOVServer -ServerHardwareType $SY660Gen9SHT -NoProfile -ErrorAction Stop | Select-Object -First 1
        
    $params = @{
        AssignmentType        = "Bay";
        Description           = "HPE Synergy 660 Gen9 Server";
        Name                  = "SP - SY660-Windows-SAN-Storage";
        Server                = $Server;
        ServerProfileTemplate = $Template
    }

    New-HPOVServerProfile @params | Wait-HPOVTaskComplete
    Get-HPOVServerProfile | Update-HPOVServerProfile -Confirm:$false

    Write-Output "SY660 SAN Storage Server Profile Created" | Timestamp
}


function Create_Server_Profile_Template_SY480_ESX_SAN_Storage
{
    Write-Output "Creating SAN Storage Server Profile Template" | Timestamp

    $SY660Gen9SHT      = Get-HPOVServerHardwareTypes -name "SY 480 Gen9 2" -ErrorAction Stop
    $EnclGroup         = Get-HPOVEnclosureGroup -Name "EG-Synergy-Local" -ErrorAction Stop
    $FWBaseline        = Get-HPOVBaseline -SppName "Service Pack for ProLiant" -Version "2017.07.1" -ErrorAction Stop
    $Eth1              = Get-HPOVNetwork -Name "Prod_1101" | New-HPOVServerProfileConnection -ConnectionID 1 -Name 'Prod-1101' -PortId "Mezz 3:1-c" -ErrorAction Stop
    $Eth2              = Get-HPOVNetwork -Name "Prod_1102" | New-HPOVServerProfileConnection -ConnectionID 2 -Name 'Prod-1102' -PortId "Mezz 3:2-c" -ErrorAction Stop
    $FC1               = Get-HPOVNetwork -Name 'SAN A FC' | New-HPOVServerProfileConnection -connectionId 3 -ErrorAction Stop
    $FC2               = Get-HPOVNetwork -Name 'SAN B FC' | New-HPOVServerProfileConnection -connectionId 4 -ErrorAction Stop
    $Deploy1           = Get-HPOVNetwork -Name "Deployment" | New-HPOVServerProfileConnection -ConnectionID 5 -Name 'Deployment Network A' -PortId "Mezz 3:1-a" -Bootable -Priority Primary -ErrorAction Stop
    $Deploy2           = Get-HPOVNetwork -Name "Deployment" | New-HPOVServerProfileConnection -ConnectionID 6 -Name 'Deployment Network B' -PortId "Mezz 3:2-a" -Bootable -Priority Secondary -ErrorAction Stop
    $LogicalDisk       = New-HPOVServerProfileLogicalDisk -Name "SAS RAID5 SSD" -RAID RAID5 -NumberofDrives 3 -DriveType SASSSD -ErrorAction Stop
    $SANVol            = Get-HPOVStorageVolume -Name "Shared-Volume-1" | New-HPOVProfileAttachVolume -LunIdType Manual -LunID 0 -ErrorAction Stop
    $StorageController = New-HPOVServerProfileLogicalDiskController -ControllerID Embedded -Mode RAID -Initialize -LogicalDisk $LogicalDisk -ErrorAction Stop

    $params = @{
        Affinity                 = "Bay";
        Baseline                 = $FWBaseline;
        BootMode                 = "UEFI";
        BootOrder                = "HardDisk";
        Connections              = $Eth1, $Eth2, $FC1, $FC2, $Deploy1, $Deploy2;
        Description              = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module with Local and SAN Storage";
        EnclosureGroup           = $EnclGroup;
        Firmware                 = $False;
        FirmwareMode             = "FirmwareOffline";
        HideUnusedFlexNics       = $True;
        LocalStorage             = $True;
        HostOStype               = "VMware";
        ManageBoot               = $True;
        Name                     = "HPE Synergy 480 Gen9 ESX with SAN Storage Template";
        SANStorage               = $True;
        ServerHardwareType       = $SY660Gen9SHT;
        ServerProfileDescription = "Server Profile for HPE Synergy 480 Gen9 Compute Module with SAN Storage";
        StorageController        = $StorageController;
        StorageVolume            = $SANVol
    }

    New-HPOVServerProfileTemplate @params | Wait-HPOVTaskComplete
}


function Create_Server_Profile_SY480_ESX_SAN_Storage
{
    Write-Output "Creating SAN Storage Server Profile" | Timestamp

    $SY480Gen9SHT   = Get-HPOVServerHardwareTypes -name "SY 480 Gen9 2" -ErrorAction Stop
    $Template       = Get-HPOVServerProfileTemplate -Name "HPE Synergy 480 Gen9 ESX with SAN Storage Template" -ErrorAction Stop
    $DeploymentPlan = Get-HPOVOSDeploymentPlan -Name "HPE-Esxi-6.2-U2 Deployment Test" -ErrorAction Stop
    $Server         = Get-HPOVServer -ServerHardwareType $SY480Gen9SHT -NoProfile -ErrorAction Stop | Select-Object -First 1
        
    $params = @{
        AssignmentType        = "Bay";
        Description           = "HPE Synergy 480 Gen9 Server";
        Name                  = "SP - SY480-ESX-SAN-Storage";
        OSDeploymentPlan      = $DeploymentPlan;
        Server                = $Server;
        ServerProfileTemplate = $Template
    }

    New-HPOVServerProfile @params | Wait-HPOVTaskComplete
    Get-HPOVServerProfile | Update-HPOVServerProfile -Confirm:$false

    Write-Output "SY480 SAN Storage Server Profile Created" | Timestamp
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

if (-not (get-module HPOneview.310)) 
{
    Import-Module HPOneView.310
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


##########################################################################
#
# Process variables in the Populate_HPE_Synergy-Params.txt file.
#
##########################################################################
New-Variable -Name config_file -Value .\Populate_HPE_Synergy-Params.txt -Scope Global -Force

if (Test-Path $config_file) {
    Get-Content $config_file | Where-Object { !$_.StartsWith("#") } | Foreach-Object {
        $var = $_.Split('=')
        New-Variable -Name $var[0] -Value $var[1] -Scope Global -Force
    }
} else { 
    Write-Output "Configuration file '$config_file' not found.  Exiting." | Timestamp
    Exit
}


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
Add_Scopes
Create_Server_Profile_Template_SY480_RHEL_Local_Storage
Create_Server_Profile_Template_SY660_Windows_SAN_Storage
Create_Server_Profile_Template_SY480_ESX_SAN_Storage
Create_Server_Profile_SY480_RHEL_Local_Storage
Create_Server_Profile_SY660_Windows_SAN_Storage
Create_Server_Profile_SY480_ESX_SAN_Storage

Write-Output "HPE Synergy Appliance Configuration Complete" | Timestamp
