<#
.SYNOPSIS
    Automates the process of downloading an SSL certificate from Google Cloud Storage (GCS),
    importing it into TeamCity's keystore, and restarting the TeamCity service.

.DESCRIPTION
    This script performs the following tasks:
    - Downloads a .pfx certificate from a specified GCS bucket.
    - Reads TeamCity's server.xml to locate the keystore path and password.
    - Imports the certificate into the keystore using keytool.
    - Restarts the TeamCity service to apply the new certificate.

.PARAMETERS
    GcsBucketName       - Name of the GCS bucket containing the certificate.
    GcsCertObjectName   - Name of the certificate file in the GCS bucket.
    TeamCityConfDir     - Path to TeamCity's configuration directory (contains server.xml).
    TeamCityCertDir     - Local directory to store the downloaded certificate.
    KeystorePassword    - Password for the keystore (can be passed or read from environment variable).
    TeamCityServiceName - Name of the TeamCity Windows service (default: "TeamCity").
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$GcsBucketName,  # GCS bucket name

    [Parameter(Mandatory = $true)]
    [string]$GcsCertObjectName,  # Certificate file name in GCS

    [Parameter(Mandatory = $true)]
    [string]$TeamCityConfDir,  # Path to TeamCity configuration directory

    [Parameter(Mandatory = $true)]
    [string]$TeamCityCertDir,  # Local directory to store the certificate

    [Parameter(Mandatory = $false)]
    [SecureString]$KeystorePassword = $env:KEYSTORE_PASSWORD,  # Keystore password from parameter or environment

    [Parameter(Mandatory = $false)]
    [string]$TeamCityServiceName = "TeamCity"  # Default TeamCity service name
)

# Validate that the keystore password is provided
if (-not $KeystorePassword) {
    throw "Keystore password not provided. Please pass it as a parameter or set the KEYSTORE_PASSWORD environment variable."
}

# Function to get the path to keytool.exe using JAVA_HOME
function Get-KeytoolPath {
    if ($env:JAVA_HOME) {
        $keytoolPath = Join-Path $env:JAVA_HOME "bin\keytool.exe"
        if (Test-Path $keytoolPath) {
            return $keytoolPath
        }
    }
    throw "keytool.exe not found. Please ensure JAVA_HOME is set correctly."
}

# Function to parse server.xml and extract keystore file path and password
function Get-KeystoreConfiguration {
    param([string]$ServerXmlPath)

    try {
        # Load XML content from server.xml
        [xml]$xml = Get-Content $ServerXmlPath -ErrorAction Stop
    } catch {
        throw "Failed to read server.xml at '$ServerXmlPath'. Error: $_"
    }

    # Find the HTTPS connector node
    $connector = $xml.Server.Service.Connector | Where-Object { $_.scheme -eq "https" }
    if (-not $connector) {
        throw "HTTPS connector not found in server.xml."
    }

    # Return keystore file path and password
    return @{
        KeystoreFile = $connector.keystoreFile
        KeystorePass = $connector.keystorePass
    }
}

# Function to copy the certificate from GCS to the local machine using gcloud CLI
function Copy-GcsCertificate {
    param(
        [string]$Bucket,
        [string]$Object,
        [string]$Destination
    )

    Write-Host "Downloading certificate from gs://$Bucket/$Object to $Destination ..."
    
    # Construct gcloud command
    $cmd = "gcloud storage cp gs://$Bucket/$Object `"$Destination`""
    
    # Execute the command in a new PowerShell process
    $proc = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -Command $cmd" -Wait -NoNewWindow -PassThru

    # Check if the command succeeded
    if ($proc.ExitCode -ne 0) {
        throw "Failed to download certificate from GCS. Exit code: $($proc.ExitCode)"
    }

    Write-Host "Download completed."
}

# Function to ensure a directory exists; creates it if it doesn't
function Test-DirectoryOrCreate  {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "Creating directory: $Path"
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

try {
    # Ensure the certificate directory exists
    Test-DirectoryOrCreate  -Path $TeamCityCertDir

    # Construct full path to server.xml
    $serverXmlPath = Join-Path $TeamCityConfDir "server.xml"
    Write-Host "Reading keystore info from: $serverXmlPath"

    # Extract keystore file path and password from server.xml
    $ksInfo = Get-KeystoreConfiguration -ServerXmlPath $serverXmlPath
    $keystoreFile = $ksInfo.KeystoreFile
    $keystoreDir = Split-Path $keystoreFile -Parent

    # Ensure the keystore directory exists
    Test-DirectoryOrCreate  -Path $keystoreDir

    # Construct local path for the downloaded certificate
    $localCertPath = Join-Path $TeamCityCertDir (Split-Path $GcsCertObjectName -Leaf)

    # Download the certificate from GCS
    Copy-GcsCertificate -Bucket $GcsBucketName -Object $GcsCertObjectName -Destination $localCertPath

    # Stop the TeamCity service before updating the keystore
    Write-Host "Stopping TeamCity service '$TeamCityServiceName'..."
    Stop-Service -Name $TeamCityServiceName -Force -ErrorAction Stop
    Write-Host "TeamCity service stopped."

    # Locate keytool.exe
    $keytool = Get-KeytoolPath
    Write-Host "Using keytool at: $keytool"

    # Prepare arguments for keytool import
    $keytoolArgs = @(
        "-importkeystore",
        "-srckeystore", "`"$localCertPath`"",
        "-srcstoretype", "pkcs12",
        "-srcstorepass", $KeystorePassword,
        "-destkeystore", "`"$keystoreFile`"",
        "-deststorepass", $KeystorePassword,
        "-noprompt"
    )

    # Check if keystore file exists and log appropriate message
    if (-not (Test-Path $keystoreFile)) {
        Write-Host "Keystore not found. Creating new keystore..."
    } else {
        Write-Host "Keystore found. Updating with new certificate..."
    }

    # Run keytool to import the certificate
    $proc = Start-Process -FilePath $keytool -ArgumentList $keytoolArgs -Wait -NoNewWindow -PassThru
    if ($proc.ExitCode -ne 0) {
        throw "Keystore import failed with exit code $($proc.ExitCode)"
    }

    Write-Host "Certificate imported successfully."

    # Restart the TeamCity service
    Write-Host "Starting TeamCity service '$TeamCityServiceName'..."
    Start-Service -Name $TeamCityServiceName -ErrorAction Stop
    Write-Host "TeamCity service started."

    # Final success message
    Write-Host "`n✅ TeamCity SSL certificate installation completed successfully." -ForegroundColor Green
}
catch {
    # Catch and display any errors that occur during execution
    Write-Error "`n❌ Error occurred: $_"
    exit 1
}