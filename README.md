# Populate HPE Synergy
Configure and populate an HPE Synergy Data Center Simulator virtual appliance for demonstration, educational, and custom integration purposes.

#
## The HPE Synergy Data Center Simulator is an HPE proprietary tool available for HPE employee and Partner use only. 
#

The HPE Synergy Data Center Simulator (DCS) is a useful tool for learning about the HPE Synergy Composable Infrastructure platform and the HPE OneView management interface. The tool simulates a datacenter comprised of multiple racks of HPE Synergy hardware, 3PAR storage arrays, SAN managers, and other simulated infrastructure. The simulator looks and acts just like a real, physical Synergy environment. It uses the same RESTful interface as real Synergy and OneView instances, making it the perfect environment for learning how to implement and demonstrate Infrastructure-as-Code.

The Populate HPE Synergy scripts work with the Data Center Simulator to instantiate all of the simulated hardware and components availble in the appliance, making it a much more feature-rich environment to demonstrate and learn how to use features such as Server Profile Templates, Server Profiles, etc.

# How to use the scripts
This package contains two primary scripts and one configuration file. These are PowerShell scripts and they require the HPE OneView PowerShell library found here: https://github.com/HewlettPackard/POSH-HPOneView.

## Populate_HPE_Synergy.ps1
This script connects with the Synergy DCS appliance and discovers/configures all the simulated hardware.  When the script is run, it prompts for the hostname or IP address of the Synergy appliance, the Administrator user name (usually Administrator), and the Administrator password.

This script does the following:

* Prompts the user for the location of a Service Pack for ProLiant to upload as a Firmware Bundle
* Prompts the user for OneView Advanced Licenses, if available
* Prompts the user for Synergy 8GB Fibre Channel Licenses, if available
* Configures two additional Synergy Enclosures
* Renames all five Synergy Enclosures
* Powers off all Compute Modules
* Configures the simulated Cisco SAN Managers
* Configures multiple Ethernet, Fibre Channel, and FCoE Networks
* Configures multiple 3PAR Storage Arrays, Volume Templates, and Volumes
* Adds various Users with different permissions
* Deploys an HPE Image Streamer OS Deployment instance
* Creates Logical Interconnect Groups
* Creates multiple Uplink Sets
* Creates an Enclosure Group
* Creates a Logical Enclosure
* Creates multiple sample Server Profile Templates
* Creates multiple sample Server Profiles
* Adds various Scopes

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
