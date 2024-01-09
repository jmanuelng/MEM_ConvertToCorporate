# MEM Convert To Corporate

## Overview
`MEM_ConvertToCorporate.ps1` script is a PowerShell for bulk conversion of device ownership status in Microsoft Intune to "Corporate". This script was developed to address the lack of a native bulk operation feature in Intune (as of December 2023), made my life easier in large-scale device management scenarios.

<br><br>
## Features
- **Bulk Conversion**: Changes the ownership status of multiple devices in Microsoft Intune from "Personal" to "Corporate".
- **CSV Input**: Uses a CSV file for input to process large batches of devices.
- **User Confirmation Option**: Includes (default option) user confirmation before actually changing each device's ownership, ensuring control over the process.

<br><br>
## Prerequisites
- PowerShell 5.1 or higher.
- [Microsoft Graph PowerShell SDK](https://docs.microsoft.com/en-us/graph/powershell/installation) installed.
- Appropriate permissions in Microsoft Entra ID (Azure AD) and Intune to modify device ownership.

## Required Permissions
To use this script, the following permissions are required in Microsoft Graph:
- `DeviceManagementConfiguration.ReadWrite.All`
- `DeviceManagementManagedDevices.ReadWrite.All`

These permissions allows script to read device information and update ownership status.

## Configuration
Before running the script, ensure that the Microsoft Graph PowerShell SDK is configured correctly:
1. **Installing the SDK**: If not already installed, use the following PowerShell command:
   ```powershell
   Install-Module Microsoft.Graph
   ```
2. **Authentication**: The first time you use the SDK, you'll need to authenticate with your Azure credentials. The script will prompt for this authentication.
3. **Consent for Permissions**: Admin consent is required for the specified permissions. This can typically be granted in the Azure portal under Enterprise Applications.

For detailed instructions on configuring the Microsoft Graph PowerShell SDK, refer to the [official documentation](https://docs.microsoft.com/en-us/graph/powershell/installation).

**About Granting Admin Consent**: [This article](https://www.easy365manager.com/microsoft-graph-powershell-admin-consent/) provides a comprehensive walkthrough. I found it very useful.

<br><br>
## Usage

1. **Prepare a CSV File**: Create a CSV file containing the device IDs to be converted. The CSV file should have a column named 'DeviceID'. 

2. **Run the Script**: Execute the script in PowerShell. The script has the following parameters:

  - `-DeviceIDs`: Path to your CSV file containing the device IDs.
  - `-TenantID`: Your Microsoft Intune Tenant ID.
  - `-DeviceConfirm`: Controls whether the script asks for confirmation

   ```powershell
   .\MEM_ConvertToCorporate.ps1 -DeviceIDs "path_to_your_CSV_file.csv" -TenantID "your_tenant_id"
   ```
   &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Optionally, include the `-DeviceConfirm` parameter to control user confirmation for each device.

3. **Follow Prompts**: If user confirmation is enabled, respond to the prompts to proceed with the conversion for each device.

<br>
#### Using the `-DeviceConfirm` Parameter
The `-DeviceConfirm` parameter determines whether the script will ask for user confirmation for each device before changing its ownership status.

- By default, or if set to `"Y"`, the script will prompt for confirmation for each device. This is the recommended setting for ensuring control over the conversion process.
  
  Example:
  ```powershell
  .\MEM_ConvertToCorporate.ps1 -DeviceIDs "C:\DeviceList.csv" -TenantID "your_tenant_id" -DeviceConfirm "Y"
  ```
  If user confirmation is enabled (`-DeviceConfirm "Y"`), you will need to respond to the prompts to proceed with the conversion for each device. It is an extra layer of verification to ensure that changes are made intentionally.


- If set to `"N"`, the script will not ask for any confirmation and will proceed to change the ownership status of all devices listed in the CSV file without individual confirmations. Use this setting for a faster, automated process when you are confident about the changes being made.

  Example:
  ```powershell
  .\MEM_ConvertToCorporate.ps1 -DeviceIDs "C:\DeviceList.csv" -TenantID "your_tenant_id" -DeviceConfirm "N"
  ```


## Example
```powershell
.\MEM_ConvertToCorporate.ps1 -DeviceIDs "C:\DeviceList.csv" -TenantID "12345678-1234-1234-1234-1234567890ab" -DeviceConfirm "Y"
```

<br><br>
## Acknowledgments
- This script was created to address a specific need in a large-scale device management project.
- Special thanks to Timmy Anderson for the inspiration. His article on [Invoke Sync to All Intune Devices with Microsoft Graph PowerShell SDK](https://timmyit.com/2023/10/23/invoke-sync-to-all-intune-devices-with-microsoft-graph-powershell-sdk/) was instrumental in getting this script going.
- Additional gratitude goes to the Microsoft Intune and PowerShell communities for their invaluable resources and support.

<br><br>
## Contributing
Contributions to this script are welcome. Please feel free to fork the repository, make changes, and submit pull requests.

<br><br>
## License
The `MEM_ConvertToCorporate` repository and the `MEM_ConvertToCorporate.ps1` script are provided under the MIT License. The MIT License is a permissive free software license that imposes only very limited restrictions on reuse, thereby offering high license compatibility. It permits users to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the `MEM_ConvertToCorporate` - Bulk Device Ownership Conversion PowerShell Script.

