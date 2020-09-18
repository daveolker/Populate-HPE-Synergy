# Populate HPE Synergy
Configure and populate an HPE Synergy Data Center Simulator virtual appliance for demonstration, educational, and custom integration purposes.

#
## The HPE Synergy Data Center Simulator is an HPE proprietary tool available for HPE employee and Partner use only. 
#

The HPE Synergy Data Center Simulator (DCS) is a useful tool for learning about the HPE Synergy Composable Infrastructure platform and the HPE OneView management interface. The tool simulates a datacenter comprised of multiple racks of HPE Synergy hardware, 3PAR storage arrays, SAN managers, and other simulated infrastructure. The simulator looks and acts just like a real, physical Synergy environment. It uses the same RESTful interface as real Synergy and OneView instances, making it the perfect environment for learning how to implement and demonstrate Infrastructure-as-Code.

The Populate HPE Synergy scripts work with the Data Center Simulator to instantiate all of the simulated hardware and components available in the appliance, making it a much more feature-rich environment to demonstrate and learn how to use features such as Server Profile Templates, Server Profiles, etc.

# How to use the scripts
This package contains two primary scripts and one configuration file. These are PowerShell scripts and they require the HPE OneView PowerShell library found here: https://github.com/HewlettPackard/POSH-HPEOneView. It is strongly recommended to use the latest version of the PowerShell library to take advantage of the latest features, new OneView/Synergy capabilities, and defect fixes.

The script requires PowerShell Core version 6 or later. It will *NOT* work with Windows PowerShell 5.1, because it uses the PowerShell function Invoke-WebRequest with the option -SkipCertificateCheck and that option was only added in PowerShell 6.0. This option is used because DCS appliances typically use self-signed certificates and without the option the certificate check would fail and throw an error.

# What's New
The HPE OneView PowerShell library (POSH-HPEOneView) recently introduced a change to the naming convention used by the OneView commands used by the Populate_HPE_Synergy.ps1 and Cleanup_HPE_Synergy.ps1 scripts. The latest version of this Populate HPE Synergy toolkit (version 5.4) is designed to use the new naming convention, which means it will only work with versions of the POSH-HPEOneView library that use the new naming convention.

For this reason we are maintaining two "active" versions of this toolkit - one that supports the previous naming convention, and one that supports the new naming convention.  Eventually support for the older naming convention will be deprecated.

The change in naming convention was introduced in version 5.3 of the POSH-HPEOneView library, which was released to coincide with the release of version 5.3 of HPE OneView and version 5.3 of the HPE Synergy DCS tool.  

The below table lists the recommended combination of DCS versions, HPE OneView PowerShell library versions, and Populate_HPE_Synergy versions supported at this time:

| HPE OneView DCS Appliance Version | HPE OneView PowerShell Library Version | Populate-HPE-Synergy Tool Version |
|-----------------------------------|----------------------------------------|-----------------------------------|
| HPE_ONEVIEW_DCS_5.20_SYNERGY.*    | Release 5.20.*                         | 5.2 (Select the 5.2 branch)       |
| HPE_ONEVIEW_DCS_5.30_SYNERGY.*    | Release 5.30.*                         | 5.4 (Select the 5.4 branch)       |
| HPE_ONEVIEW_DCS_5.40A_SYNERGY.*   | Release 5.40.*                         | 5.4 (Select the 5.4 branch)       |

## Populate_HPE_Synergy.ps1
This script connects with the Synergy DCS appliance and discovers/configures all the simulated hardware.  When the script is run, it prompts for the hostname or IP address of the Synergy appliance, the Administrator user name (usually Administrator), and the Administrator password. Then it first detects the DCS schematic running on the appliance. It supports 2 schematics: synergy_3encl_demo and synergy_2encl_c2nitro. Any other schematic is unsupported and will make the script fail.

This script does the following:

* Prompts the user for the location of a Service Pack for ProLiant to upload as a Firmware Bundle
* Prompts the user for a text file containing Synergy Fibre Channel Licenses
* Configures two additional remote Synergy Enclosures (for the synergy_3encl_demo schematic only)
* Renames all Synergy Enclosures
* Powers off all Compute Modules
* Configures the simulated Cisco SAN Managers
* Configures multiple Ethernet, Fibre Channel, and FCoE Networks
* Configures multiple 3PAR Storage Arrays, Volume Templates, and Volumes
* Adds various Users with different permissions
* Deploys an HPE Image Streamer OS Deployment instance (for the synergy_3encl_demo schematic only)
* Creates Logical Interconnect Groups
* Creates multiple Uplink Sets
* Creates an Enclosure Group
* Creates a Logical Enclosure
* Creates multiple sample Server Profile Templates
* Creates multiple sample Server Profiles
* Adds various Scopes
* Configures remote resources including: LE, LI, LIGs, Enclosure Group (for the synergy_3encl_demo schematic only)

## Cleanup_HPE_Synergy.ps1
This script connects with the Synergy DCS appliance and de-configures all the simulated hardware.  It effectively backs-out all the changes made to the DCS appliance by the Populate_HPE_Synergy script. When the script is run, it prompts for the hostname or IP address of the Synergy appliance, the Administrator user name (usually Administrator), and the Administrator password.

This script does the following:

* Removes all Server Profiles
* Removes all Server Profile Templates
* Removes all Logical Enclosures
* Removes all Enclosure Groups
* Removes all Logical Interconnect Groups
* Renames all Enclosures back to their original names
* Removes all Storage Volume Templates, Volumes, Storage Pools, and 3PAR Arrays
* Removes all Networks, Network Sets, Address Pools, and Subnets
* De-configures all SAN Managers
* Removes all Licenses, both OneView and Fibre Channel
* Removes all non-default Users
* Removes all Scopes
* Deletes all uploaded Firmware Bundles (Service Pack for ProLiant)

## Populate_HPE_Synergy-Params.txt
This configuration file specifies the two networks used by the HPE Synergy DCS Appliance. The two networks are the "Production" and "Deployment" networks. Each network configuration consists of a Subnet definition, the Gateway for that subnet, the Subnet mask, and a pool of IP addresses in the subnet (starting and ending).

This configuration file is designed to work out-of-the-box when the HPE Synergy DCS appliance is deployed via VirtualBox using a host-only networking configuration. It may require changes depending on the Hypervisor (i.e. VMware, Hyper-V, VirtualBox) and the networking configuration used when deploying the DCS virtual appliance.

The parameters in the configuration file are:
```
prod_subnet            Production Subnet (192.168.56.0)
prod_gateway           Production Gateway (192.168.56.1)
prod_pool_start        Beginning of Production Subnet Pool (192.168.56.200)
prod_pool_end          End of Production Subnet Pool (192.168.56.254)
prod_mask              Production Subnet Mask (255.255.255.0)
deploy_subnet          Deployment Subnet (10.1.1.0)
deploy_gateway         Deployment Gateway (10.1.1.1)
deploy_pool_start      Beginning of Deployment Subnet Pool (10.1.1.2)
deploy_pool_end        End of Deployment Subnet Pool (10.1.1.254)
deploy_mask            Deployment Subnet Mask (255.255.255.0)
```
