##############################################################################
# Populate_HPE_Synergy.ps1
#
# - Example script for configuring the HPE Synergy Appliance
#
#   VERSION 5.40
#
#   AUTHORS
#   Dave Olker - HPE Storage and Big Data
#   Vincent Berger - HPE Synergy and BladeSystem
#
# (C) Copyright 2020 Hewlett Packard Enterprise Development LP
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

# ------------------ Parameters
Param ( [String]$OVApplianceIP                  = "192.168.62.128",
        [String]$OVAdminName                    = "Administrator",
        [String]$OVAuthDomain                   = "Local",
        [String]$OneViewModule                  = "HPEOneView.540"
)


function Get-TimeStamp {    
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}


function GetSchematic($ApplianceIP)
{
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        throw "This script requires PowerShell Core Version 6 or later. You are running version " + $PSVersionTable.PSVersion
    }
    $response = Invoke-WebRequest -Uri https://$ApplianceIP/dcs-status -SkipCertificateCheck
    if ($response.Content -match '<Status>(?<status>.+)</Status>') {
        if ($Matches.status -ne "DCS is Running") {
            throw "DCS is not running"
        }
        if ($response.Content -match '<Schematic_location>(?<schematic>.+)</Schematic_location>') {
            if ($Matches.schematic -eq "/dcs/schematic/synergy_2encl_c2nitro") {
                return "100Gb"
            } elseif ($Matches.schematic -eq "/dcs/schematic/synergy_2encl_gen10demo") {
                return "100Gb"
            } elseif ($Matches.schematic -eq "/dcs/schematic/synergy_3encl_demo") {
                return "40Gb"
            } else {
                throw "DCS Schematic " + $Matches.schematic + " is not supported by this script"
            }
        }
    } else {
        throw "DCS Status not found"
    }
}

function Add_Remote_Enclosures
{
    Write-Host "$(Get-TimeStamp) Adding Remote Enclosures"
    Send-OVRequest -uri "/rest/enclosures" -method POST -body @{'hostname' = 'fe80::2:0:9:7%eth2'} | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) Remote Enclosures Added"
    #
    # Sleep for 10 seconds to allow remote enclosures to quiesce
    #
    Start-Sleep 10
}


function Configure_Address_Pools
{
    Write-Host "$(Get-TimeStamp) Configuring Address Pools for MAC, WWN, and Serial Numbers"
    New-OVAddressPoolRange -PoolType vmac -RangeType Generated
    New-OVAddressPoolRange -PoolType vwwn -RangeType Generated
    New-OVAddressPoolRange -PoolType vsn -RangeType Generated
    Write-Host "$(Get-TimeStamp) Address Pool Ranges Configuration Complete"
}


function Configure_SAN_Managers
{
    Write-Host "$(Get-TimeStamp) Configuring SAN Managers"
    Add-OVSanManager -Hostname 172.18.20.1 -SnmpUserName dcs-SHA-AES128 -SnmpAuthLevel AuthAndPriv -SnmpAuthPassword dcsdcsdcs -SnmpAuthProtocol sha -SnmpPrivPassword dcsdcsdcs -SnmpPrivProtocol aes-128 -Type Cisco -Port 161 | Wait-OVTaskComplete
    Add-OVSanManager -Hostname 172.18.20.2 -SnmpUserName dcs-SHA-AES128 -SnmpAuthLevel AuthAndPriv -SnmpAuthPassword dcsdcsdcs -SnmpAuthProtocol sha -SnmpPrivPassword dcsdcsdcs -SnmpPrivProtocol aes-128 -Type Cisco -Port 161 | Wait-OVTaskComplete
    $password = ConvertTo-SecureString 'dcs' -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential('dcs',$password)
    Add-OVSanManager -Hostname 172.18.19.1 -Type BrocadeFOS -Credential $credential -UseSsl | Wait-OVTaskComplete
    Add-OVSanManager -Hostname 172.18.19.2 -Type BrocadeFOS -Credential $credential -UseSsl | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) SAN Manager Configuration Complete"
}


function Configure_Networks($schematic)
{
    if ($schematic -eq "40Gb") {
        Write-Host "$(Get-TimeStamp) Adding IPv4 Subnets"
        New-OVAddressPoolSubnet -Domain "mgmt.lan" -Gateway $prod_gateway -NetworkId $prod_subnet -SubnetMask $prod_mask
        New-OVAddressPoolSubnet -Domain "deployment.lan" -Gateway $deploy_gateway -NetworkId $deploy_subnet -SubnetMask $deploy_mask
    
        Write-Host "$(Get-TimeStamp) Adding IPv4 Address Pool Ranges"
        Get-OVAddressPoolSubnet -NetworkId $prod_subnet | New-OVAddressPoolRange -Name Mgmt -Start $prod_pool_start -End $prod_pool_end
        Get-OVAddressPoolSubnet -NetworkId $deploy_subnet | New-OVAddressPoolRange -Name Deployment -Start $deploy_pool_start -End $deploy_pool_end
    }
    Write-Host "$(Get-TimeStamp) Adding Networks"
    New-OVNetwork -Name "ESX Mgmt" -MaximumBandwidth 20000 -Purpose Management -Type Ethernet -TypicalBandwidth 2500 -VlanId 1131 -VLANType Tagged
    New-OVNetwork -Name "ESX vMotion" -MaximumBandwidth 20000 -Purpose VMMigration -Type Ethernet -TypicalBandwidth 2500 -VlanId 1132 -VLANType Tagged
    New-OVNetwork -Name Prod_1101 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1101 -VLANType Tagged
    New-OVNetwork -Name Prod_1102 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1102 -VLANType Tagged
    New-OVNetwork -Name Prod_1103 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1103 -VLANType Tagged
    New-OVNetwork -Name Prod_1104 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1104 -VLANType Tagged
    New-OVNetwork -Name Deployment -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1500 -VLANType Tagged
    New-OVNetwork -Name Mgmt -MaximumBandwidth 20000 -Purpose Management -Type Ethernet -TypicalBandwidth 2500 -VlanId 100 -VLANType Tagged
    New-OVNetwork -Name SVCluster-1 -MaximumBandwidth 20000 -Purpose ISCSI -Type Ethernet -TypicalBandwidth 2500 -VlanId 301 -VLANType Tagged
    New-OVNetwork -Name SVCluster-2 -MaximumBandwidth 20000 -Purpose ISCSI -Type Ethernet -TypicalBandwidth 2500 -VlanId 302 -VLANType Tagged
    New-OVNetwork -Name SVCluster-3 -MaximumBandwidth 20000 -Purpose ISCSI -Type Ethernet -TypicalBandwidth 2500 -VlanId 303 -VLANType Tagged

    if ($schematic -eq "40Gb") {
        $Deploy_AddrPool = Get-OVAddressPoolSubnet -NetworkId $deploy_subnet
        Get-OVNetwork -Name Deployment | Set-OVNetwork -IPv4Subnet $Deploy_AddrPool
        $Prod_AddrPool = Get-OVAddressPoolSubnet -NetworkId $prod_subnet
        Get-OVNetwork -Name Mgmt | Set-OVNetwork -IPv4Subnet $Prod_AddrPool
    }

    if ($schematic -eq "40Gb") {
        New-OVNetwork -Name "SAN A FC" -Type "Fibre Channel" -FabricType FabricAttach -LinkStabilityTime 30 -ManagedSan VSAN20 -MaximumBandwidth 20000 -TypicalBandwidth 8000
        New-OVNetwork -Name "SAN B FC" -Type "Fibre Channel" -FabricType FabricAttach -LinkStabilityTime 30 -ManagedSan VSAN21 -MaximumBandwidth 20000 -TypicalBandwidth 8000
    } elseif ($schematic -eq "100Gb") {
        New-OVNetwork -Name "SAN A FC" -Type "Fibre Channel" -FabricType FabricAttach -LinkStabilityTime 30 -ManagedSan 29:00:7a:2b:21:e0:00:5a 
        New-OVNetwork -Name "SAN B FC" -Type "Fibre Channel" -FabricType FabricAttach -LinkStabilityTime 30 -ManagedSan 29:00:7a:2b:21:e0:00:86 
    }
    New-OVNetwork -Name "SAN A FCoE" -VlanId 10 -ManagedSan VSAN10 -MaximumBandwidth 20000 -Type FCoE -TypicalBandwidth 8000
    New-OVNetwork -Name "SAN B FCoE" -VlanId 11 -ManagedSan VSAN11 -MaximumBandwidth 20000 -Type FCoE -TypicalBandwidth 8000

    Write-Host "$(Get-TimeStamp) Adding Network Sets"
    New-OVNetworkSet -Name Prod -Networks Prod_1101, Prod_1102, Prod_1103, Prod_1104 -MaximumBandwidth 20000 -TypicalBandwidth 2500

    Write-Host "$(Get-TimeStamp) Networking Configuration Complete"
}


function Add_Storage($schematic)
{
    Write-Host "$(Get-TimeStamp) Adding 3PAR Storage Systems"
    Add-OVStorageSystem -Hostname 172.18.11.11 -Password dcs -Username dcs -Domain TestDomain | Wait-OVTaskComplete
    Add-OVStorageSystem -Hostname 172.18.11.12 -Password dcs -Username dcs -Domain TestDomain | Wait-OVTaskComplete

    Write-Host "$(Get-TimeStamp) Adding 3PAR Storage Pools"
    $SPNames = @("CPG-SSD", "CPG-SSD-AO", "CPG_FC-AO", "FST_CPG1", "FST_CPG2")
    for ($i=0; $i -lt $SPNames.Length; $i++) {
        Get-OVStoragePool -Name $SPNames[$i] -ErrorAction Stop | Set-OVStoragePool -Managed $true | Wait-OVTaskComplete
    }
    
    Write-Host "$(Get-TimeStamp) Adding 3PAR Storage Volume Templates"
    Get-OVStoragePool CPG-SSD -StorageSystem ThreePAR-1 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-3PAR-Shared-1 -ProvisionType Thin -Shared
    Get-OVStoragePool CPG-SSD -StorageSystem ThreePAR-2 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-3PAR-Shared-2 -ProvisionType Thin -Shared
    Get-OVStoragePool CPG-SSD -StorageSystem ThreePAR-1 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-Demo-Shared-TPDD-1 -ProvisionType Thin -EnableDeduplication $true -Shared
    Get-OVStoragePool CPG-SSD -StorageSystem ThreePAR-2 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-Demo-Shared-TPDD-2 -ProvisionType Thin -EnableDeduplication $true -Shared

    Write-Host "$(Get-TimeStamp) Adding 3PAR Storage Volumes"
    Get-OVStoragePool FST_CPG1 -StorageSystem ThreePAR-1 | New-OVStorageVolume -Capacity 200 -Name Demo-Volume-1 | Wait-OVTaskComplete
    Get-OVStoragePool FST_CPG1 -StorageSystem ThreePAR-1 | New-OVStorageVolume -Capacity 200 -Name Shared-Volume-1 -Shared | Wait-OVTaskComplete
    Get-OVStoragePool FST_CPG1 -StorageSystem ThreePAR-1 | New-OVStorageVolume -Capacity 200 -Name Shared-Volume-2 -Shared | Wait-OVTaskComplete

    Write-Host "$(Get-TimeStamp) Adding StoreVirtual Storage Systems"
    $SVNet1 = Get-OVNetwork -Name SVCluster-1 -ErrorAction Stop
    Add-OVStorageSystem -Hostname 172.18.30.1 -Family StoreVirtual -Password dcs -Username dcs -VIPS @{ "172.18.30.1" = $SVNet1 } | Wait-OVTaskComplete
    $SVNet2 = Get-OVNetwork -Name SVCluster-2 -ErrorAction Stop
    Add-OVStorageSystem -Hostname 172.18.30.2 -Family StoreVirtual -Password dcs -Username dcs -VIPS @{ "172.18.30.2" = $SVNet2 } | Wait-OVTaskComplete
    if ($schematic -eq '40Gb') {
        $SVNet3 = Get-OVNetwork -Name SVCluster-3 -ErrorAction Stop
        Add-OVStorageSystem -Hostname 172.18.30.3 -Family StoreVirtual -Password dcs -Username dcs -VIPS @{ "172.18.30.3" = $SVNet3 } | Wait-OVTaskComplete
    }

    Write-Host "$(Get-TimeStamp) Adding StoreVirtual Storage Volume Templates"
    Get-OVStoragePool Cluster-1 -StorageSystem Cluster-1 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-StoreVirt-1 -ProvisionType Thin -Shared
    Get-OVStoragePool Cluster-2 -StorageSystem Cluster-2 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-StoreVirt-2 -ProvisionType Thin -Shared
    if ($schematic -eq '40Gb') {
        Get-OVStoragePool Cluster-3 -StorageSystem Cluster-3 | New-OVStorageVolumeTemplate -Capacity 100 -Name SVT-StoreVirt-3 -ProvisionType Thin -Shared
    }
    Write-Host "$(Get-TimeStamp) Storage Configuration Complete"
}


function Rename_Enclosures
{
    Write-Host "$(Get-TimeStamp) Renaming Enclosures"
    $Enc = Get-OVEnclosure -Name 0000A66101 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name Synergy-Encl-1 -Enclosure $Enc | Wait-OVTaskComplete
    $Enc = Get-OVEnclosure -Name 0000A66102 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name Synergy-Encl-2 -Enclosure $Enc | Wait-OVTaskComplete
    $Enc = Get-OVEnclosure -Name 0000A66103 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name Synergy-Encl-3 -Enclosure $Enc | Wait-OVTaskComplete
    $Enc = Get-OVEnclosure -Name 0000A66104 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name Synergy-Encl-4 -Enclosure $Enc | Wait-OVTaskComplete
    $Enc = Get-OVEnclosure -Name 0000A66105 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name Synergy-Encl-5 -Enclosure $Enc | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) All Enclosures Renamed"
}

function Rename_Enclosures_2encl
{
    Write-Host "$(Get-TimeStamp) Renaming Enclosures"
    $Enc = Get-OVEnclosure -Name 0000A66101 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name Synergy-Encl-1 -Enclosure $Enc | Wait-OVTaskComplete
    $Enc = Get-OVEnclosure -Name 0000A66102 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name Synergy-Encl-2 -Enclosure $Enc | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) All Enclosures Renamed"
}

function Create_Uplink_Sets($schematic)
{
    Write-Host "$(Get-TimeStamp) Adding Fibre Channel and FCoE Uplink Sets"
    $LIGFlex = Get-OVLogicalInterconnectGroup -Name "LIG-VCEth"
    $SAN_A_FC = Get-OVNetwork -Name "SAN A FC"
    if ($schematic -eq "40Gb") {
        New-OVUplinkSet -Resource $LIGFlex -Name "US-SAN-A-FC" -Type FibreChannel -FCUplinkSpeed 8 -Networks $SAN_A_FC -UplinkPorts "Enclosure1:Bay3:Q2.1" | Wait-OVTaskComplete
    } elseif ($schematic -eq "100Gb") {
        New-OVUplinkSet -Resource $LIGFlex -Name "US-SAN-A-FC" -Type FibreChannel -FCUplinkSpeed 32 -Networks $SAN_A_FC -UplinkPorts "Enclosure1:Bay3:Q2.1" | Wait-OVTaskComplete
    }

    $LIGFlex = Get-OVLogicalInterconnectGroup -Name "LIG-VCEth"
    $SAN_B_FC = Get-OVNetwork -Name "SAN B FC"
    if ($schematic -eq "40Gb") {
        New-OVUplinkSet -Resource $LIGFlex -Name "US-SAN-B-FC" -Type FibreChannel -FCUplinkSpeed 8 -Networks $SAN_B_FC -UplinkPorts "Enclosure2:Bay6:Q2.1" | Wait-OVTaskComplete
    } elseif ($schematic -eq "100Gb") {
        New-OVUplinkSet -Resource $LIGFlex -Name "US-SAN-B-FC" -Type FibreChannel -FCUplinkSpeed 32 -Networks $SAN_B_FC -UplinkPorts "Enclosure2:Bay6:Q2.1" | Wait-OVTaskComplete        
    }
    $LIGFlex = Get-OVLogicalInterconnectGroup -Name "LIG-VCEth"
    $SAN_A_FCoE = Get-OVNetwork -Name "SAN A FCoE"
    New-OVUplinkSet -Resource $LIGFlex -Name "US-SAN-A-FCoE" -Type Ethernet -Networks $SAN_A_FCoE -UplinkPorts "Enclosure1:Bay3:Q1.1" -LacpTimer Short | Wait-OVTaskComplete

    $LIGFlex = Get-OVLogicalInterconnectGroup -Name "LIG-VCEth"
    $SAN_B_FCoE = Get-OVNetwork -Name "SAN B FCoE"
    New-OVUplinkSet -Resource $LIGFlex -Name "US-SAN-B-FCoE" -Type Ethernet -Networks $SAN_B_FCoE -UplinkPorts "Enclosure2:Bay6:Q1.1" -LacpTimer Short | Wait-OVTaskComplete

    Write-Host "$(Get-TimeStamp) Adding Ethernet Uplink Sets"
    $LIGFlex = Get-OVLogicalInterconnectGroup -Name "LIG-VCEth"
    $ESX_Mgmt = Get-OVNetwork -Name "ESX Mgmt"
    New-OVUplinkSet -Resource $LIGFlex -Name "US-ESX-Mgmt" -Type Ethernet -Networks $ESX_Mgmt -UplinkPorts "Enclosure1:Bay3:Q1.2","Enclosure2:Bay6:Q1.2" | Wait-OVTaskComplete

    $LIGFlex = Get-OVLogicalInterconnectGroup -Name "LIG-VCEth"
    $ESX_vMotion = Get-OVNetwork -Name "ESX vMotion"
    New-OVUplinkSet -Resource $LIGFlex -Name "US-ESX-vMotion" -Type Ethernet -Networks $ESX_vMotion -UplinkPorts "Enclosure1:Bay3:Q1.3","Enclosure2:Bay6:Q1.3" | Wait-OVTaskComplete

    $LIGFlex = Get-OVLogicalInterconnectGroup -Name "LIG-VCEth"
    $Prod_Nets = Get-OVNetwork -Name "Prod*"
    New-OVUplinkSet -Resource $LIGFlex -Name "US-Prod" -Type Ethernet -Networks $Prod_Nets -UplinkPorts "Enclosure1:Bay3:Q1.4","Enclosure2:Bay6:Q1.4" | Wait-OVTaskComplete

    if ($schematic -eq "40Gb") {
        Write-Host "$(Get-TimeStamp) Adding ImageStreamer Uplink Sets"
        $ImageStreamerDeploymentNetworkObject = Get-OVNetwork -Name "Deployment" -ErrorAction Stop
        Get-OVLogicalInterconnectGroup -Name "LIG-VCEth" -ErrorAction Stop | New-OVUplinkSet -Name "US-Image Streamer" -Type ImageStreamer -Networks $ImageStreamerDeploymentNetworkObject -UplinkPorts "Enclosure1:Bay3:Q5.1","Enclosure1:Bay3:Q6.1","Enclosure2:Bay6:Q5.1","Enclosure2:Bay6:Q6.1" | Wait-OVTaskComplete
    }
    Write-Host "$(Get-TimeStamp) All Uplink Sets Configured"
}


function Create_Enclosure_Group($schematic)
{
    Write-Host "$(Get-TimeStamp) Creating Local Enclosure Group"
    if ($schematic -eq "40Gb") {
        $3FrameVCLIG = Get-OVLogicalInterconnectGroup -Name LIG-VCEth
        $SasLIG = Get-OVLogicalInterconnectGroup -Name LIG-SAS
        $FcLIG = Get-OVLogicalInterconnectGroup -Name LIG-FC
        New-OVEnclosureGroup -name "EG-Synergy-Local" -LogicalInterconnectGroupMapping @{Frame1 = $3FrameVCLIG,$SasLIG,$FcLIG; Frame2 = $3FrameVCLIG,$SasLIG,$FcLIG; Frame3 = $3FrameVCLIG,$SasLIG,$FcLIG} -EnclosureCount 3 -IPv4AddressType External -DeploymentNetworkType Internal
    } elseif ($schematic -eq "100Gb") {
        $2FrameVCLIG = Get-OVLogicalInterconnectGroup -Name LIG-VCEth
        $SasLIG = Get-OVLogicalInterconnectGroup -Name LIG-SAS
        $FC16LIG = Get-OVLogicalInterconnectGroup -Name LIG-FC16
        $FC32LIG = Get-OVLogicalInterconnectGroup -Name LIG-FC32
        $FC32LIG_Single = Get-OVLogicalInterconnectGroup -Name LIG-FC32-Single
        New-OVEnclosureGroup -name "EG-Synergy-Local" -LogicalInterconnectGroupMapping @{Frame1 = $2FrameVCLIG,$FC16LIG,$FC32LIG; Frame2 = $2FrameVCLIG,$FC32LIG_Single,$SasLIG} -EnclosureCount 2 -IPv4AddressType External
    }
    Write-Host "$(Get-TimeStamp) Enclosure Group Created"
}


function Create_Enclosure_Group_Remote
{
    Write-Host "$(Get-TimeStamp) Creating Remote Enclosure Group"
    $2FrameVCLIG_1 = Get-OVLogicalInterconnectGroup -Name LIG-VCEth-Remote-1
    $2FrameVCLIG_2 = Get-OVLogicalInterconnectGroup -Name LIG-VCEth-Remote-2
    $FcLIG = Get-OVLogicalInterconnectGroup -Name LIG-FC-Remote
    New-OVEnclosureGroup -name "EG-Synergy-Remote" -LogicalInterconnectGroupMapping @{Frame1 = $FcLIG,$2FrameVCLIG_1,$2FrameVCLIG_2; Frame2 = $FcLIG,$2FrameVCLIG_1,$2FrameVCLIG_2} -EnclosureCount 2
    Write-Host "$(Get-TimeStamp) Remote Enclosure Group Created"
}


function Create_Logical_Enclosure
{
    Write-Host "$(Get-TimeStamp) Creating Local Logical Enclosure"
    $EG = Get-OVEnclosureGroup -Name EG-Synergy-Local
    $Encl = Get-OVEnclosure -Name Synergy-Encl-1
    New-OVLogicalEnclosure -EnclosureGroup $EG -Name LE-Synergy-Local -Enclosure $Encl | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) Logical Enclosure Created"
}


function Create_Logical_Enclosure_Remote
{
    Write-Host "$(Get-TimeStamp) Creating Remote Logical Enclosure"
    $EG = Get-OVEnclosureGroup -Name EG-Synergy-Remote
    $Encl = Get-OVEnclosure -Name Synergy-Encl-4
    New-OVLogicalEnclosure -EnclosureGroup $EG -Name LE-Synergy-Remote -Enclosure $Encl | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) Logical Enclosure Created"
}


function Create_Logical_Interconnect_Groups($schematic)
{
    Write-Host "$(Get-TimeStamp) Creating Local Logical Interconnect Groups"
    if ($schematic -eq "40Gb") {
        New-OVLogicalInterconnectGroup -Name "LIG-SAS" -FrameCount 1 -InterconnectBaySet 1 -FabricModuleType "SAS" -Bays @{Frame1 = @{Bay1 = "SE12SAS" ; Bay4 = "SE12SAS"}}
        New-OVLogicalInterconnectGroup -Name "LIG-FC" -FrameCount 1 -InterconnectBaySet 2 -FabricModuleType "SEVCFC" -Bays @{Frame1 = @{Bay2 = "SEVC16GbFC" ; Bay5 = "SEVC16GbFC"}}
        New-OVLogicalInterconnectGroup -Name "LIG-VCEth" -FrameCount 3 -InterconnectBaySet 3 -FabricModuleType "SEVC40F8" -Bays @{Frame1 = @{Bay3 = "SEVC40f8" ; Bay6 = "SE20ILM"};Frame2 = @{Bay3 = "SE20ILM"; Bay6 = "SEVC40f8" };Frame3 = @{Bay3 = "SE20ILM"; Bay6 = "SE20ILM"}} -FabricRedundancy "HighlyAvailable"
    } elseif ($schematic -eq "100Gb") {
        New-OVLogicalInterconnectGroup -Name "LIG-SAS" -FrameCount 1 -InterconnectBaySet 1 -FabricModuleType "SAS" -Bays @{Frame1 = @{Bay1 = "SE12SAS" ; Bay4 = "SE12SAS"}}
        New-OVLogicalInterconnectGroup -Name "LIG-FC16" -FrameCount 1 -InterconnectBaySet 1 -FabricModuleType "SEVCFC" -Bays @{Frame1 = @{Bay1 = "SEVC16GbFC" ; Bay4 = "SEVC16GbFC"}}
        New-OVLogicalInterconnectGroup -Name "LIG-FC32" -FrameCount 1 -InterconnectBaySet 2 -FabricModuleType "SEVCFC" -Bays @{Frame1 = @{Bay2 = "SEVC32GbFC" ; Bay5 = "SEVC32GbFC"}}
        New-OVLogicalInterconnectGroup -Name "LIG-FC32-Single" -FrameCount 1 -InterconnectBaySet 2 -FabricModuleType "SEVCFC" -Bays @{Frame1 = @{Bay2 = "SEVC32GbFC" }} -FabricRedundancy ASide
        New-OVLogicalInterconnectGroup -Name "LIG-VCEth" -FrameCount 2 -InterconnectBaySet 3 -FabricModuleType "SEVC100F32" -DownlinkSpeedMode 50 -Bays @{Frame1 = @{Bay3 = "SEVC100f32" ; Bay6 = "SE50ILM"};Frame2 = @{Bay3 = "SE50ILM"; Bay6 = "SEVC100f32" }} -FabricRedundancy "HighlyAvailable"
    }
    Write-Host "$(Get-TimeStamp) Logical Interconnect Groups Created"
}


function Create_Logical_Interconnect_Groups_Remote
{
    Write-Host "$(Get-TimeStamp) Creating Remote Logical Interconnect Groups"
    New-OVLogicalInterconnectGroup -Name "LIG-FC-Remote" -FrameCount 1 -InterconnectBaySet 1 -FabricModuleType "SEVCFC" -Bays @{Frame1 = @{Bay1 = "SEVC16GbFC" ; Bay4 = "SEVC16GbFC"}}
    New-OVLogicalInterconnectGroup -Name "LIG-VCEth-Remote-1" -FrameCount 2 -InterconnectBaySet 2 -FabricModuleType "SEVC40F8" -Bays @{Frame1 = @{Bay2 = "SEVC40f8" ; Bay5 = "SE20ILM"};Frame2 = @{Bay2 = "SE20ILM"; Bay5 = "SEVC40F8" }} -FabricRedundancy "HighlyAvailable"
    New-OVLogicalInterconnectGroup -Name "LIG-VCEth-Remote-2" -FrameCount 2 -InterconnectBaySet 3 -FabricModuleType "SEVC40F8" -Bays @{Frame1 = @{Bay3 = "SEVC40f8" ; Bay6 = "SE20ILM"};Frame2 = @{Bay3 = "SE20ILM"; Bay6 = "SEVC40F8" }} -FabricRedundancy "HighlyAvailable"
    Write-Host "$(Get-TimeStamp) Logical Interconnect Groups Created"
}


function Add_Licenses
{
    Write-Host "$(Get-TimeStamp) Adding OneView and Synergy FC Licenses"
    $License_File = Read-Host -Prompt "Optional: Enter Filename Containing OneView and Synergy FC Licenses"
    if ($License_File) {
        New-OVLicense -File $License_File
    }
    Write-Host "$(Get-TimeStamp) All Licenses Added"
}


function Add_Firmware_Bundle
{
    Write-Host "$(Get-TimeStamp) Adding Firmware Bundles"
    $firmware_bundle = Read-Host "Optional: Specify location of Service Pack for ProLiant ISO file"
    if ($firmware_bundle) {
        if (Test-Path $firmware_bundle) {
            Add-OVBaseline -File $firmware_bundle | Wait-OVTaskComplete
        }
        else {
            Write-Host "$(Get-TimeStamp) Service Pack for ProLiant file '$firmware_bundle' not found.  Skipping firmware upload."
        }
    }
    Write-Host "$(Get-TimeStamp) Firmware Bundle Added"
}


function Create_OS_Deployment_Server
{
    Write-Host "$(Get-TimeStamp) Configuring OS Deployment Servers"
    $ManagementNetwork = Get-OVNetwork -Type Ethernet -Name "Mgmt"
    Get-OVImageStreamerAppliance | Select-Object -First 1 | New-OVOSDeploymentServer -Name "LE1 Image Streamer" -ManagementNetwork $ManagementNetwork -Description "Image Streamer for Logical Enclosure 1" | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) OS Deployment Server Configured"
}


function Create_Server_Profile_Template_SY480_Gen9_RHEL_Local_Boot
{
    Write-Host "$(Get-TimeStamp) Creating SY480 Gen9 with Local Boot for RHEL Server Profile Template"

    $SHT               = Get-OVServerHardwareTypes -Name "SY 480 Gen9 1" -ErrorAction Stop
    $EnclGroup         = Get-OVEnclosureGroup -Name "EG-Synergy-Local" -ErrorAction Stop
    $Eth1              = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 1 -Name 'Prod-NetworkSet-1' -PortId "Mezz 3:1-c"
    $Eth2              = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 2 -Name 'Prod-NetworkSet-2' -PortId "Mezz 3:2-c"
    $Deploy1           = Get-OVNetwork -Name "Deployment" | New-OVServerProfileConnection -ConnectionID 3 -Name 'Deployment Network A' -PortId "Mezz 3:1-a" -Bootable -Priority Primary
    $Deploy2           = Get-OVNetwork -Name "Deployment" | New-OVServerProfileConnection -ConnectionID 4 -Name 'Deployment Network B' -PortId "Mezz 3:2-a" -Bootable -Priority Secondary
    $LogicalDisk       = New-OVServerProfileLogicalDisk -Name "SAS RAID1 SSD" -RAID RAID1 -NumberofDrives 2 -DriveType SASSSD -Bootable $True
    $StorageController = New-OVServerProfileLogicalDiskController -ControllerID Embedded -Mode RAID -Initialize -LogicalDisk $LogicalDisk

    $params = @{
        Affinity                 = "Bay";
        BootMode                 = "BIOS";
        BootOrder                = "HardDisk";
        Connections              = $Eth1, $Eth2, $Deploy1, $Deploy2;
        Description              = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module with Local Boot for RHEL";
        EnclosureGroup           = $EnclGroup;
        Firmware                 = $False;
        FirmwareMode             = "FirmwareOffline";
        HideUnusedFlexNics       = $True;
        LocalStorage             = $True;
        HostOStype               = "RHEL";
        ManageBoot               = $True;
        Name                     = "HPE Synergy 480 Gen9 with Local Boot for RHEL Template";
        SANStorage               = $False;
        ServerHardwareType       = $SHT;
        ServerProfileDescription = "Server Profile for HPE Synergy 480 Gen9 Compute Module with Local Boot for RHEL";
        StorageController        = $StorageController;
        StorageVolume            = $LogicalDisk
    }
    New-OVServerProfileTemplate @params | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) SY480 Gen9 with Local Boot for RHEL Server Profile Template Created"
}


function Create_Server_Profile_SY480_Gen9_RHEL_Local_Boot
{
    Write-Host "$(Get-TimeStamp) Creating SY480 Gen9 Local Boot for RHEL Server Profile"

    $SHT            = Get-OVServerHardwareTypes -Name "SY 480 Gen9 1" -ErrorAction Stop
    $Template       = Get-OVServerProfileTemplate -Name "HPE Synergy 480 Gen9 with Local Boot for RHEL Template" -ErrorAction Stop
    $Server         = Get-OVServer -ServerHardwareType $SHT -NoProfile -ErrorAction Stop | Select-Object -First 1

    $params = @{
        AssignmentType        = "Server";
        Description           = "HPE Synergy 480 Gen9 Server with Local Boot for RHEL";
        Name                  = "SY480-Gen9-RHEL-Local-Boot";
        Server                = $Server;
        ServerProfileTemplate = $Template
    }
    New-OVServerProfile @params | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) SY480 Gen9 Local Boot for RHEL Server Profile Created"
}


function Create_Server_Profile_Template_SY480_Gen10_RHEL_Local_Boot
{
    Write-Host "$(Get-TimeStamp) Creating SY480 Gen10 with Local Boot for RHEL Server Profile Template"

    $SHT               = Get-OVServerHardwareTypes -Name "SY 480 Gen10 2" -ErrorAction Stop
    $EnclGroup         = Get-OVEnclosureGroup -Name "EG-Synergy-Local" -ErrorAction Stop
    $Eth1              = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 1 -Name 'Prod-NetworkSet-1' -PortId "Mezz 3:1-c"
    $Eth2              = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 2 -Name 'Prod-NetworkSet-2' -PortId "Mezz 3:2-c"
    $LogicalDisk       = New-OVServerProfileLogicalDisk -Name "SAS RAID1" -RAID RAID1 -NumberofDrives 2 -Bootable $True
    $StorageController = New-OVServerProfileLogicalDiskController -ControllerID Embedded -Mode RAID -Initialize -LogicalDisk $LogicalDisk

    $params = @{
        Affinity                 = "Bay";
        BootMode                 = "BIOS";
        BootOrder                = "HardDisk";
        Connections              = $Eth1, $Eth2;
        Description              = "Server Profile Template for HPE Synergy 480 Gen10 Compute Module with Local Boot for RHEL";
        EnclosureGroup           = $EnclGroup;
        Firmware                 = $False;
        FirmwareMode             = "FirmwareOffline";
        HideUnusedFlexNics       = $True;
        LocalStorage             = $True;
        HostOStype               = "RHEL";
        ManageBoot               = $True;
        Name                     = "HPE Synergy 480 Gen10 with Local Boot for RHEL Template";
        SANStorage               = $False;
        ServerHardwareType       = $SHT;
        ServerProfileDescription = "Server Profile for HPE Synergy 480 Gen10 Compute Module with Local Boot for RHEL";
        StorageController        = $StorageController;
        StorageVolume            = $LogicalDisk
    }
    New-OVServerProfileTemplate @params | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) SY480 Gen10 with Local Boot for RHEL Server Profile Template Created"
}


function Create_Server_Profile_SY480_Gen10_RHEL_Local_Boot
{
    Write-Host "$(Get-TimeStamp) Creating SY480 Gen10 Local Boot for RHEL Server Profile"

    $SHT            = Get-OVServerHardwareTypes -Name "SY 480 Gen10 2" -ErrorAction Stop
    $Template       = Get-OVServerProfileTemplate -Name "HPE Synergy 480 Gen10 with Local Boot for RHEL Template" -ErrorAction Stop
    $Server         = Get-OVServer -ServerHardwareType $SHT -NoProfile -ErrorAction Stop | Select-Object -First 1

    $params = @{
        AssignmentType        = "Server";
        Description           = "HPE Synergy 480 Gen10 Server with Local Boot for RHEL";
        Name                  = "SY480-Gen10-RHEL-Local-Boot";
        Server                = $Server;
        ServerProfileTemplate = $Template
    }
    New-OVServerProfile @params | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) SY480 Gen10 Local Boot for RHEL Server Profile Created"
}

function Create_Server_Profile_Template_SY660_Gen9_Windows_SAN_Storage
{
    Write-Host "$(Get-TimeStamp) Creating SY660 Gen9 with Local Boot and SAN Storage for Windows Server Profile Template"

    $SHT               = Get-OVServerHardwareTypes -Name "SY 660 Gen9 1" -ErrorAction Stop
    $EnclGroup         = Get-OVEnclosureGroup -Name "EG-Synergy-Local" -ErrorAction Stop
    $Eth1              = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 1 -Name 'Prod-NetworkSet-1' -PortId "Mezz 3:1-c"
    $Eth2              = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 2 -Name 'Prod-NetworkSet-2' -PortId "Mezz 3:2-c"
    $FC1               = Get-OVNetwork -Name 'SAN A FC' | New-OVServerProfileConnection -connectionId 3
    $FC2               = Get-OVNetwork -Name 'SAN B FC' | New-OVServerProfileConnection -connectionId 4
    $LogicalDisk       = New-OVServerProfileLogicalDisk -Name "SAS RAID5 SSD" -RAID RAID5 -NumberofDrives 3 -DriveType SASSSD -Bootable $True
    $SANVol            = Get-OVStorageVolume -Name "Shared-Volume-2" | New-OVServerProfileAttachVolume -VolumeID 1
    $StorageController = New-OVServerProfileLogicalDiskController -ControllerID Embedded -Mode RAID -Initialize -LogicalDisk $LogicalDisk

    $params = @{
        Affinity                 = "Bay";
        BootMode                 = "BIOS";
        BootOrder                = "HardDisk";
        Connections              = $Eth1, $Eth2, $FC1, $FC2;
        Description              = "Server Profile Template for HPE Synergy 660 Gen9 Compute Module with Local Boot and SAN Storage for Windows";
        EnclosureGroup           = $EnclGroup;
        Firmware                 = $False;
        FirmwareMode             = "FirmwareOffline";
        HideUnusedFlexNics       = $True;
        LocalStorage             = $True;
        HostOStype               = "Win2k12";
        ManageBoot               = $True;
        Name                     = "HPE Synergy 660 Gen9 with Local Boot and SAN Storage for Windows Template";
        SANStorage               = $True;
        ServerHardwareType       = $SHT;
        ServerProfileDescription = "Server Profile for HPE Synergy 660 Gen9 Compute Module with Local Boot and SAN Storage for Windows";
        StorageController        = $StorageController;
        StorageVolume            = $SANVol
    }
    New-OVServerProfileTemplate @params | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) SY660 Gen9 with Local Boot and SAN Storage for Windows Server Profile Template Created"
}


function Create_Server_Profile_SY660_Gen9_Windows_SAN_Storage
{
    Write-Host "$(Get-TimeStamp) Creating SY660 Gen9 with Local Boot and SAN Storage for Windows Server Profile"

    $SHT            = Get-OVServerHardwareTypes -Name "SY 660 Gen9 1" -ErrorAction Stop
    $Template       = Get-OVServerProfileTemplate -Name "HPE Synergy 660 Gen9 with Local Boot and SAN Storage for Windows Template" -ErrorAction Stop
    $Server         = Get-OVServer -ServerHardwareType $SHT -NoProfile -ErrorAction Stop | Select-Object -First 1

    $params = @{
        AssignmentType        = "Server";
        Description           = "HPE Synergy 660 Gen9 Server with Local Boot and SAN Storage for Windows";
        Name                  = "SY660-Gen9-Windows-Local-Boot-and-SAN-Storage";
        Server                = $Server;
        ServerProfileTemplate = $Template
    }
    New-OVServerProfile @params | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) SY660 Gen9 with Local Boot and SAN Storage for Windows Server Profile Created"
}

function Create_Server_Profile_Template_SY660_Gen10_Windows_SAN_Storage
{
    Write-Host "$(Get-TimeStamp) Creating SY660 Gen10 with Local Boot and SAN Storage for Windows Server Profile Template"

    $SHT               = Get-OVServerHardwareTypes -Name "SY 660 Gen10 1" -ErrorAction Stop
    $EnclGroup         = Get-OVEnclosureGroup -Name "EG-Synergy-Local" -ErrorAction Stop
    $Eth1              = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 1 -Name 'Prod-NetworkSet-1' -PortId "Mezz 3:1-c"
    $Eth2              = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 2 -Name 'Prod-NetworkSet-2' -PortId "Mezz 3:2-c"
    $FC1               = Get-OVNetwork -Name 'SAN A FCoE' | New-OVServerProfileConnection -ConnectionID 3
    $FC2               = Get-OVNetwork -Name 'SAN B FCoE' | New-OVServerProfileConnection -ConnectionID 4
    $LogicalDisk       = New-OVServerProfileLogicalDisk -Name "SAS RAID5" -RAID RAID5 -NumberofDrives 3 -Bootable $True
    $StoragePool       = Get-OVStoragePool -Name FST_CPG1 -StorageSystem ThreePAR-1 -ErrorAction Stop
    $SANVol            = New-OVServerProfileAttachVolume -Name SANVol-Gen10 -StoragePool $StoragePool -Capacity 100 -LunIdType Auto
    $StorageController = New-OVServerProfileLogicalDiskController -ControllerID Embedded -Mode RAID -Initialize -LogicalDisk $LogicalDisk

    $params = @{
        Affinity                 = "Bay";
        BootMode                 = "BIOS";
        BootOrder                = "HardDisk";
        Connections              = $Eth1, $Eth2, $FC1, $FC2;
        Description              = "Server Profile Template for HPE Synergy 660 Gen10 Compute Module with Local Boot and SAN Storage for Windows";
        EnclosureGroup           = $EnclGroup;
        Firmware                 = $False;
        FirmwareMode             = "FirmwareOffline";
        HideUnusedFlexNics       = $True;
        LocalStorage             = $True;
        HostOStype               = "Win2k12";
        ManageBoot               = $True;
        Name                     = "HPE Synergy 660 Gen10 with Local Boot and SAN Storage for Windows Template";
        SANStorage               = $True;
        ServerHardwareType       = $SHT;
        ServerProfileDescription = "Server Profile for HPE Synergy 660 Gen10 Compute Module with Local Boot and SAN Storage for Windows";
        StorageController        = $StorageController;
        StorageVolume            = $SANVol
    }
    New-OVServerProfileTemplate @params | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) SY660 Gen10 with Local Boot and SAN Storage for Windows Server Profile Template Created"
}

function Create_Server_Profile_SY660_Gen10_Windows_SAN_Storage
{
    Write-Host "$(Get-TimeStamp) Creating SY660 Gen10 with Local Boot and SAN Storage for Windows Server Profile"

    $SHT            = Get-OVServerHardwareTypes -Name "SY 660 Gen10 1" -ErrorAction Stop
    $Template       = Get-OVServerProfileTemplate -Name "HPE Synergy 660 Gen10 with Local Boot and SAN Storage for Windows Template" -ErrorAction Stop
    $Server         = Get-OVServer -ServerHardwareType $SHT -NoProfile -ErrorAction Stop | Select-Object -First 1

    $params = @{
        AssignmentType        = "Server";
        Description           = "HPE Synergy 660 Gen10 Server with Local Boot and SAN Storage for Windows";
        Name                  = "SY660-Gen10-Windows-Local-Boot-and-SAN-Storage";
        Server                = $Server;
        ServerProfileTemplate = $Template
    }
    New-OVServerProfile @params | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) SY660 Gen10 with Local Boot and SAN Storage for Windows Server Profile Created"
}


function Create_Server_Profile_Template_SY480_Gen9_ESX_SAN_Boot
{
    Write-Host "$(Get-TimeStamp) Creating SY480 Gen9 with SAN Boot for ESX Server Profile Template"

    $SHT               = Get-OVServerHardwareTypes -Name "SY 480 Gen9 2" -ErrorAction Stop
    $EnclGroup         = Get-OVEnclosureGroup -Name "EG-Synergy-Local" -ErrorAction Stop
    $Eth1              = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 1 -Name 'Prod-NetworkSet-1' -PortId "Mezz 3:1-c"
    $Eth2              = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 2 -Name 'Prod-NetworkSet-2' -PortId "Mezz 3:2-c"
    $FC1               = Get-OVNetwork -Name 'SAN A FC' | New-OVServerProfileConnection -ConnectionID 3 -Bootable -Priority Primary -BootVolumeSource ManagedVolume -ConnectionType FibreChannel
    $FC2               = Get-OVNetwork -Name 'SAN B FC' | New-OVServerProfileConnection -ConnectionID 4 -Bootable -Priority Secondary -BootVolumeSource ManagedVolume -ConnectionType FibreChannel
    $StoragePool       = Get-OVStoragePool -Name FST_CPG1 -StorageSystem ThreePAR-1 -ErrorAction Stop
    $SANVol            = New-OVServerProfileAttachVolume -Name BootVol -StoragePool $StoragePool -BootVolume -Capacity 100 -LunIdType Auto

    $params = @{
        Affinity                 = "Bay";
        BootMode                 = "BIOS";
        BootOrder                = "HardDisk";
        Connections              = $Eth1, $Eth2, $FC1, $FC2;
        Description              = "Server Profile Template for HPE Synergy 480 Gen9 Compute Module with SAN Boot for ESX";
        EnclosureGroup           = $EnclGroup;
        Firmware                 = $False;
        FirmwareMode             = "FirmwareOffline";
        HideUnusedFlexNics       = $True;
        LocalStorage             = $True;
        HostOStype               = "VMware";
        ManageBoot               = $True;
        Name                     = "HPE Synergy 480 Gen9 with SAN Boot for ESX Template";
        SANStorage               = $True;
        ServerHardwareType       = $SHT;
        ServerProfileDescription = "Server Profile for HPE Synergy 480 Gen9 Compute Module with SAN Boot for ESX";
        StorageVolume            = $SANVol
    }
    New-OVServerProfileTemplate @params | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) SY480 Gen9 with SAN Boot for ESX Server Profile Template Created"
}


function Create_Server_Profile_SY480_Gen9_ESX_SAN_Boot
{
    Write-Host "$(Get-TimeStamp) Creating SY480 Gen9 SAN Boot for ESX Server Profile"

    $SHT            = Get-OVServerHardwareTypes -Name "SY 480 Gen9 2" -ErrorAction Stop
    $Template       = Get-OVServerProfileTemplate -Name "HPE Synergy 480 Gen9 with SAN Boot for ESX Template" -ErrorAction Stop
    $Server         = Get-OVServer -ServerHardwareType $SHT -NoProfile -ErrorAction Stop | Select-Object -First 1

    $params = @{
        AssignmentType        = "Server";
        Description           = "HPE Synergy 480 Gen9 Server with SAN Boot for ESX";
        Name                  = "SY480-Gen9-ESX-SAN-Boot";
        Server                = $Server;
        ServerProfileTemplate = $Template
    }
    New-OVServerProfile @params | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) SY480 Gen9 with SAN Boot for ESX Server Profile Created"
}


function Create_Server_Profile_Template_SY480_Gen10_ESX_SAN_Boot
{
    Write-Host "$(Get-TimeStamp) Creating SY480 Gen10 with SAN Boot for ESX Server Profile Template"

    $SHT               = Get-OVServerHardwareTypes -Name "SY 480 Gen10 1" -ErrorAction Stop
    $EnclGroup         = Get-OVEnclosureGroup -Name "EG-Synergy-Local" -ErrorAction Stop
    $Eth1              = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 1 -Name 'Prod-NetworkSet-1' -PortId "Mezz 3:1-c"
    $Eth2              = Get-OVNetworkSet -Name "Prod" | New-OVServerProfileConnection -ConnectionID 2 -Name 'Prod-NetworkSet-2' -PortId "Mezz 3:2-c"
    $FC1               = Get-OVNetwork -Name 'SAN A FCoE' | New-OVServerProfileConnection -ConnectionID 3 -Bootable -Priority Primary -BootVolumeSource ManagedVolume -ConnectionType FibreChannel
    $FC2               = Get-OVNetwork -Name 'SAN B FCoE' | New-OVServerProfileConnection -ConnectionID 4 -Bootable -Priority Secondary -BootVolumeSource ManagedVolume -ConnectionType FibreChannel
    $StoragePool       = Get-OVStoragePool -Name FST_CPG1 -StorageSystem ThreePAR-1 -ErrorAction Stop
    $SANVol            = New-OVServerProfileAttachVolume -Name BootVol-Gen10 -StoragePool $StoragePool -BootVolume -Capacity 100 -LunIdType Auto

    #
    # Check if firmware bundles are installed.  If there are, select the last one
    # and modify the firmware-related variables in the Server Profile Template
    #
    $FW = Get-OVBaseline | Measure-Object
    if ($FW.Count -ge 1) {
        $FWBaseline = Get-OVBaseline | Select-Object -Last 1
        $params = @{
            Affinity                 = "Bay";
            Baseline                 = $FWBaseline;
            BootMode                 = "BIOS";
            BootOrder                = "HardDisk";
            Connections              = $Eth1, $Eth2, $FC1, $FC2;
            Description              = "Server Profile Template for HPE Synergy 480 Gen10 Compute Module with SAN Boot for ESX";
            EnclosureGroup           = $EnclGroup;
            Firmware                 = $True;
            FirmwareMode             = "FirmwareOffline";
            HideUnusedFlexNics       = $True;
            LocalStorage             = $True;
            HostOStype               = "VMware";
            ManageBoot               = $True;
            Name                     = "HPE Synergy 480 Gen10 with SAN Boot for ESX Template";
            SANStorage               = $True;
            ServerHardwareType       = $SHT;
            ServerProfileDescription = "Server Profile for HPE Synergy 480 Gen10 Compute Module with SAN Boot for ESX";
            StorageVolume            = $SANVol
        }
    } else {
        $params = @{
            Affinity                 = "Bay";
            BootMode                 = "BIOS";
            BootOrder                = "HardDisk";
            Connections              = $Eth1, $Eth2, $FC1, $FC2;
            Description              = "Server Profile Template for HPE Synergy 480 Gen10 Compute Module with SAN Boot for ESX";
            EnclosureGroup           = $EnclGroup;
            Firmware                 = $False;
            HideUnusedFlexNics       = $True;
            LocalStorage             = $True;
            HostOStype               = "VMware";
            ManageBoot               = $True;
            Name                     = "HPE Synergy 480 Gen10 with SAN Boot for ESX Template";
            SANStorage               = $True;
            ServerHardwareType       = $SHT;
            ServerProfileDescription = "Server Profile for HPE Synergy 480 Gen10 Compute Module with SAN Boot for ESX";
            StorageVolume            = $SANVol
        }
    }
    New-OVServerProfileTemplate @params | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) SY480 Gen10 with SAN Boot for ESX Server Profile Template Created"
}


function Create_Server_Profile_SY480_Gen10_ESX_SAN_Boot
{
    Write-Host "$(Get-TimeStamp) Creating SY480 Gen10 SAN Boot for ESX Server Profile"

    $SHT            = Get-OVServerHardwareTypes -Name "SY 480 Gen10 1" -ErrorAction Stop
    $Template       = Get-OVServerProfileTemplate -Name "HPE Synergy 480 Gen10 with SAN Boot for ESX Template" -ErrorAction Stop
    $Server         = Get-OVServer -ServerHardwareType $SHT -NoProfile -ErrorAction Stop | Select-Object -First 1

    $params = @{
        AssignmentType        = "Server";
        Description           = "HPE Synergy 480 Gen10 Server with SAN Boot for ESX";
        Name                  = "SY480-Gen10-ESX-SAN-Boot";
        Server                = $Server;
        ServerProfileTemplate = $Template
    }
    New-OVServerProfile @params | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) SY480 Gen10 with SAN Boot for ESX Server Profile Created"
}


function PowerOff_All_Servers
{
    Write-Host "$(Get-TimeStamp) Powering Off All Servers"
    $Servers = Get-OVServer
    $Servers | ForEach-Object {
        if ($_.PowerState -ne "Off") {
            Write-Host "Server $($_.Name) is $($_.PowerState).  Powering off..."
            Stop-OVServer -Server $_ -Force -Confirm:$false | Wait-OVTaskComplete
        }
    }
    Write-Host "$(Get-TimeStamp) All Servers Powered Off"
}


function Add_Users
{
    Write-Host "$(Get-TimeStamp) Adding New Users"
    New-OVUser -UserName BackupAdmin -FullName "Backup Administrator" -Password BackupPasswd -Roles "Backup Administrator" -EmailAddress "backup@hpe.com" -OfficePhone "(111) 111-1111" -MobilePhone "(999) 999-9999"
    New-OVUser -UserName NetworkAdmin -FullName "Network Administrator" -Password NetworkPasswd -Roles "Network Administrator" -EmailAddress "network@hpe.com" -OfficePhone "(222) 222-2222" -MobilePhone "(888) 888-8888"
    New-OVUser -UserName ServerAdmin -FullName "Server Administrator" -Password ServerPasswd -Roles "Server Administrator" -EmailAddress "server@hpe.com" -OfficePhone "(333) 333-3333" -MobilePhone "(777) 777-7777"
    New-OVUser -UserName StorageAdmin -FullName "Storage Administrator" -Password StoragePasswd -Roles "Storage Administrator" -EmailAddress "storage@hpe.com" -OfficePhone "(444) 444-4444" -MobilePhone "(666) 666-6666"
    New-OVUser -UserName SoftwareAdmin -FullName "Software Administrator" -Password SoftwarePasswd -Roles "Software Administrator" -EmailAddress "software@hpe.com" -OfficePhone "(555) 555-5555" -MobilePhone "(123) 234-3456"
    Write-Host "$(Get-TimeStamp) All New Users Added"
}


function Add_Scopes
{
    Write-Host "$(Get-TimeStamp) Adding New Scopes"
    New-OVScope -Name FinanceScope -Description "Finance Scope of Resources"
    $Resources += Get-OVNetwork -Name Prod*
    $Resources += Get-OVEnclosure -Name Synergy-Encl-1
    Get-OVScope -Name FinanceScope | Add-OVResourceToScope -InputObject $Resources
    Write-Host "$(Get-TimeStamp) All New Scopes Added"
}


##############################################################################
#
# Main Program
#
##############################################################################

#
# Unload any earlier versions of the HPOneView POSH modules
#
Remove-Module -ErrorAction SilentlyContinue HPOneView.120
Remove-Module -ErrorAction SilentlyContinue HPOneView.200
Remove-Module -ErrorAction SilentlyContinue HPOneView.300
Remove-Module -ErrorAction SilentlyContinue HPOneView.310
Remove-Module -ErrorAction SilentlyContinue HPOneView.400
Remove-Module -ErrorAction SilentlyContinue HPOneView.410
Remove-Module -ErrorAction SilentlyContinue HPOneView.420
Remove-Module -ErrorAction SilentlyContinue HPOneView.500
Remove-Module -ErrorAction SilentlyContinue HPOneView.520
Remove-Module -ErrorAction SilentlyContinue HPEOneView.530

if (-not (Get-Module HPEOneview.540))
{
    Import-Module -Name HPEOneView.540
}

if (-not $ConnectedSessions)
{
    $ApplianceIP     = Read-Host -Prompt "Synergy Composer IP Address [$OVApplianceIP]"
    if ([string]::IsNullOrWhiteSpace($ApplianceIP))
    {
        $ApplianceIP = $OVApplianceIP
    }

    $AdminName       = Read-Host -Prompt "Administrator Username [$OVAdminName]"
    if ([string]::IsNullOrWhiteSpace($AdminName))
    {
        $AdminName   = $OVAdminName
    }

    $AdminCred       = Get-Credential -UserName $AdminName -Message "Password required for the user '$AdminName'"
    if ([string]::IsNullOrWhiteSpace($AdminCred))
    {
        Write-Host "$(Get-TimeStamp) Blank Credential is not permitted.  Exiting."
        Exit
    }

    Connect-OVMgmt -Hostname $ApplianceIP -Credential $AdminCred -AuthLoginDomain $OVAuthDomain -ErrorAction Stop

    if (-not $ConnectedSessions)
    {
        Write-Host "$(Get-TimeStamp) Login to Synergy System failed.  Exiting."
        Exit
    }
} else { 
    $ApplianceIP = $ConnectedSessions[0] | Select-Object -ExpandProperty name
}

try {
    $schematic = GetSchematic($ApplianceIP)
}
catch {
    Write-Error $_
    Exit
}


Write-Host "$(Get-TimeStamp) Configuring HPE Synergy Appliance"

if ($schematic -eq "40Gb") {
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
        Write-Host "$(Get-TimeStamp) Configuration file '$config_file' not found.  Exiting."
        Exit
    }
}

Add_Firmware_Bundle
Add_Licenses
Configure_Address_Pools
if ($schematic -eq "40Gb") {
    Add_Remote_Enclosures
    Rename_Enclosures
} else {
    Rename_Enclosures_2encl
}
PowerOff_All_Servers
Configure_SAN_Managers
Configure_Networks($schematic)
Add_Storage($schematic)
Add_Users
if ($schematic -eq "40Gb") {
    Create_OS_Deployment_Server
}
Create_Logical_Interconnect_Groups($schematic)
Create_Uplink_Sets($schematic)
Create_Enclosure_Group($schematic)
Create_Logical_Enclosure
Add_Scopes
if ($schematic -eq "40Gb") {
    Create_Server_Profile_Template_SY480_Gen9_RHEL_Local_Boot
    Create_Server_Profile_Template_SY660_Gen9_Windows_SAN_Storage
    Create_Server_Profile_Template_SY480_Gen9_ESX_SAN_Boot
    Create_Server_Profile_Template_SY480_Gen10_ESX_SAN_Boot
    Create_Server_Profile_SY480_Gen9_RHEL_Local_Boot
    Create_Server_Profile_SY660_Gen9_Windows_SAN_Storage
    Create_Server_Profile_SY480_Gen9_ESX_SAN_Boot
    Create_Server_Profile_SY480_Gen10_ESX_SAN_Boot
} elseif ($schematic -eq "100Gb") {
    Create_Server_Profile_Template_SY480_Gen10_RHEL_Local_Boot
    Create_Server_Profile_Template_SY660_Gen10_Windows_SAN_Storage
    Create_Server_Profile_Template_SY480_Gen10_ESX_SAN_Boot
    Create_Server_Profile_SY480_Gen10_RHEL_Local_Boot
    Create_Server_Profile_SY660_Gen10_Windows_SAN_Storage
    Create_Server_Profile_SY480_Gen10_ESX_SAN_Boot
}

if ($schematic -eq "40Gb") {
    #
    # Add Second Enclosure Group for Remote Enclosures
    #
    Create_Logical_Interconnect_Groups_Remote
    Create_Enclosure_Group_Remote
    Create_Logical_Enclosure_Remote
}
Write-Host "$(Get-TimeStamp) HPE Synergy Appliance Configuration Complete"

Disconnect-OVMgmt