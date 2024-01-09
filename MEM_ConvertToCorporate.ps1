<#
.SYNOPSIS
    Script to Change Device Ownership in Microsoft Intune using Microsoft Graph API

.DESCRIPTION
    Script changes the ownership status of devices in Microsoft Intune from Personal to Corporate.
    It reads a list of device IDs from a CSV file and updates their ownership status using the Microsoft Graph API.

    Prerequisites:
       - Microsoft.Graph PowerShell module must be installed.
       - User running the script must have appropriate permissions in Azure AD and Intune.
       - A CSV file containing Intune Device IDs in a column named 'DeviceID'.

    .EXAMPLE
    .\MEM_ConvertToCorporatep.ps1 -DeviceIDs "MEM_DeviceIDs.csv" -TenantID "your-tenant-id"

    This example runs the script using a specified CSV file and Tenant ID.

.PARAMETER DeviceIDs
    The path to the CSV file containing the device IDs.

.PARAMETER TenantID
    The Tenant ID for Microsoft Intune. Optional if already set in the environment.

#>

#Region Settings

param (
    [Parameter(Mandatory=$true)]
    [string]$DeviceIDs,

    [Parameter(Mandatory=$false)]
    [string]$TenantID = $null,

    [Parameter(Mandatory=$false)]
    [string]$DeviceConfirm = "Y"
)

$Error.Clear()
$DeviceIDsFile = $DeviceIDs # So it does not get that confusing in the script.

#Endregion Settings

#Region Functions

# Check if CSV file exists
function Test-CSVFileExistence {
    <#
    .SYNOPSIS
        Checks for the existence of a CSV file at a specified path.

    .DESCRIPTION
        Test-CSVFileExistence function validates the existence of a CSV file at a given file path.
        Handles absolute and relative paths, ensures file is present before any operations that depend on it are executed.
        The function throws a terminating error if the file is not found, preventing the script from proceeding.

    .PARAMETER FilePath
        The path to the CSV file that needs to be validated. This can be an absolute or relative path.

    .EXAMPLE
        Test-CSVFileExistence -FilePath "C:\Data\MEM_DeviceIDs.csv"
        Checks if the file 'MEM_DeviceIDs.csv' exists in the 'C:\Data' directory and throws an error if it does not.

    .EXAMPLE
        Test-CSVFileExistence -FilePath ".\MEM_DeviceIDs.csv"
        Checks if 'MEM_DeviceIDs.csv' exists in the current directory of the script and throws an error if it does not.

    .OUTPUTS
        If the file does not exist, the function writes an error message and stops the script execution.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    try {
        # Resolve the FilePath to an absolute path
        $resolvedPath = Resolve-Path -Path $FilePath -ErrorAction Stop

        # Check if the file exists
        if (-not (Test-Path -Path $resolvedPath)) {
            throw "CSV file not found at path: $resolvedPath. Please check the file path and try again."
        }
        else {
            Write-Verbose "CSV file found at path: $resolvedPath."
            return $resolvedPath
        }
    }
    catch {
        Write-Error -Message $_.Exception.Message
        exit 1
    }
}


function Test-MicrosoftGraphModuleInstalled {
    <#
    .SYNOPSIS
        Checks if the Microsoft.Graph PowerShell module is installed.

    .DESCRIPTION
        Function verifies the presence of the Microsoft.Graph module in the PowerShell environment.
        If the module is not installed, it advises on the installation process. If an error occurs during the check, it captures and reports the error details.

    .EXAMPLE
        Test-MicrosoftGraphModuleInstalled
        Checks if the Microsoft.Graph module is installed and returns true if it is, false otherwise.

    .OUTPUTS
        Boolean
        Returns $true if the Microsoft.Graph module is installed, $false otherwise.

    #>
    try {
        # Attempt to retrieve the Microsoft.Graph module
        $module = Get-Module -Name Microsoft.Graph -ListAvailable

        # Check if the module was found
        if ($null -eq $module) {
            # Module not found, advise on installation
            Write-Warning "Microsoft.Graph module is not installed. Please install it using 'Install-Module Microsoft.Graph'."
            return $false
        }
        else {
            # Module is found, confirm its presence
            Write-Verbose "Microsoft.Graph module is installed."
            return $true
        }
    }
    catch {
        # Handle any exceptions that occur during the module check
        Write-Error -Message "An error occurred while checking for the Microsoft.Graph module. Error details: $_"
        return $false
    }
}


# Function to authenticate to Microsoft Graph
function Connect-GraphApi {
    <#
    .SYNOPSIS
        Connects to the Microsoft Graph API using the Microsoft.Graph PowerShell module.

    .DESCRIPTION
        Function establishes a connection to the Microsoft Graph API. 
        Supports connecting with a specific Tenant ID or defaults to the tenant associated with the current user's context.

    .PARAMETER TenantID
        The Tenant ID for the Microsoft Graph connection. This parameter is optional. If not provided, the connection uses the default tenant associated with the user.

    .EXAMPLE
        Connect-GraphApi -TenantID "your-tenant-id"
        Connects to the Microsoft Graph API using the specified Tenant ID.

    .EXAMPLE
        Connect-GraphApi
        Connects to the Microsoft Graph API using the default tenant associated with the current user.

    .OUTPUTS
        None. The function outputs messages indicating the success or failure of the connection attempt.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$TenantID
    )

    try {
        # Check if a Microsoft Graph session exists
        $existingSession = Get-MgContext -ErrorAction SilentlyContinue
        if ($existingSession) {
            # Disconnect the existing Microsoft Graph session
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            Write-Host "Disconnected from the existing Microsoft Graph session."
        }

        # Attempt to connect to Microsoft Graph API
        if ($TenantID) {
            # Connect using the specified Tenant ID
            Connect-MgGraph -NoWelcome -Scopes "DeviceManagementConfiguration.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All" -TenantId $TenantID
        }
        else {
            # Connect using the default tenant
            Connect-MgGraph -NoWelcome -Scopes "DeviceManagementConfiguration.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All"
        }
        Write-Verbose "Connected to Microsoft Graph API successfully."
    }
    catch {
        # Handle any exceptions that occur during the connection attempt
        Write-Error -Message "Failed to connect to Microsoft Graph API. Error details: $_"
        # Optionally, you can choose to exit the script or return a specific value
        # exit 1
        # return $false
    }
}

function Test-DeviceState {
    <#
    .SYNOPSIS
        Checks the current state of a device in Microsoft Intune.

    .DESCRIPTION
        Function verifies existence and ownership status of a device in Microsoft Intune using its Device ID.
        Checks if the device exists if it is already set to Corporate ownership.

    .PARAMETER DeviceId
        The unique identifier of the device in Microsoft Intune.

    .EXAMPLE
        Test-DeviceState -DeviceId "device123"
        Checks if the device with ID 'device123' exists in Intune and if its ownership is set to Corporate.

    .OUTPUTS
        Boolean
        Returns $true if the device exists and is not already set to Corporate, $false otherwise.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$DeviceId
    )

    try {
        # Retrieve the device information from Intune
        $device = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $DeviceId -ErrorAction Stop

        # Check if the device exists
        if ($null -eq $device) {
            Write-Warning "Device ID $DeviceId not found in Intune."
            return $false
        }

        # Check if the device is already set to Corporate ownership
        if ($device.ManagedDeviceOwnerType -eq "company") {
            Write-Warning "Device ID $DeviceId is already set as Corporate."
            return $false
        }

        # Device is valid for ownership change
        return $true
    }
    catch {
        # Handle any exceptions that occur during the device check
        Write-Host "Error occurred while checking Device ID $DeviceId." -ForegroundColor Red
        return $false
    }
}

function Set-DeviceOwnership {
    <#
    .SYNOPSIS
        Sets the ownership of a device in Microsoft Intune to Corporate.

    .DESCRIPTION
        Function changes the ownership status of a specified device in Microsoft Intune to Corporate.
        It first checks the current state of the device using the Test-DeviceState function. 
        If device is eligible for the ownership change (exists and not already Corporate), the function updates its ownership status.

    .PARAMETER DeviceId
        The unique identifier of the device in Microsoft Intune.

    .EXAMPLE
        Set-DeviceOwnership -DeviceId "device123"
        Sets the ownership of the device with ID 'device123' to Corporate in Intune.

    .OUTPUTS
        None. The function outputs messages indicating the success or failure of the ownership change.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$DeviceId
    )

    # Check the current state of the device
    if (Test-DeviceState -DeviceId $DeviceId) {
        try {
            # Prepare the parameters for updating the device
            $bodyParameters = @{
                ManagedDeviceOwnerType = "company"
            }

            # Update the device ownership in Intune
            Update-MgDeviceManagementManagedDevice -ManagedDeviceId $DeviceId -BodyParameter $bodyParameters
            Write-Host "Device $DeviceId ownership changed to Corporate."
        }
        catch {
            # Handle any exceptions that occur during the ownership update
            Write-Error -Message "Error: Failed to change ownership for Device ID $DeviceId."
        }
    }
}

#Endregion Functions

########################################################################

#Region Main

#Some space please
Write-Host "`n`n"

# Check if Microsoft.Graph module is installed
if (-not (Test-MicrosoftGraphModuleInstalled)) {
    Write-Error "Microsoft.Graph module is not installed. Exiting script."
    exit
}
else {
    Write-Host -NoNewline -ForegroundColor Green "Success: "
    Write-Host "Microsoft.Graph module is installed."
}

# Validate the CSV file existence
try {
    $DeviceIDsFile = Test-CSVFileExistence -FilePath $DeviceIDsFile
    Write-Host -NoNewline -ForegroundColor Green "Success: "
    Write-Host "CSV file found at path $DeviceIDsFile."
}
catch {
    Write-Error "Error: CSV file not found at path $DeviceIDsFile. Exiting script."
    exit
}

# Connect to Microsoft Graph API
try {
    Connect-GraphApi -TenantID $TenantID
    Write-Host -NoNewline -ForegroundColor Green "Success: "
    Write-Host "Connected to Microsoft Graph API."
}
catch {
    Write-Error "Error: Failed to connect to Microsoft Graph API. Exiting script."
    exit
}

# Reading Device IDs from CSV file
try {
    $devicesIds = Import-Csv -Path $DeviceIDsFile
    if ($devicesIds[0].PSObject.Properties.Name -contains "DeviceID") {
        foreach ($deviceId in $devicesIds) {
            # Check device state before proceeding
            if (Test-DeviceState -DeviceId $deviceId.DeviceID) {
                $proceed = $true

                # Ask for user confirmation if required
                if ($DeviceConfirm -ne "N") {
                    $userInput = Read-Host "Sure you want to change ownership of Device ""$($deviceId.'Device name')"", Device ID $($deviceId.DeviceID) [Y/N]"
                    $proceed = $userInput -eq "Y"
                }

                if ($proceed) {
                    Set-DeviceOwnership -DeviceId $deviceId.DeviceID
                    Write-Host "Ownership changed for ""$($deviceId.'Device name')"", Device ID: $($deviceId.DeviceID)"
                }
                else {
                    Write-Host "Skipped Device ID: $($deviceId.DeviceID)"
                }
            }
        }
    }
    else {
        Write-Error "CSV file does not contain a 'DeviceID' column."
    }
}
catch {
    Write-Error "Failed to import CSV file from path: $DeviceIDsFile. Please check the file path and format."
}

#Endregion Main