param(
    [Parameter(Mandatory=$true)]
    [string]$GcsBucketName,           # GCS bucket name where certificate is stored

    [Parameter(Mandatory=$true)]
    [string]$GcsCertObjectName,       # Certificate file name in GCS (e.g. teamcity_cert.pfx)

    [Parameter(Mandatory=$true)]
    [string]$TeamCityConfDir,         # Path to TeamCity conf directory (contains server.xml)

    [Parameter(Mandatory=$true)]
    [string]$TeamCityCertDir,         # Target directory for certificate (e.g. C:\TeamCity\Cert)

    [Parameter(Mandatory=$false)]
    [String]$KeystorePassword = $env:KEYSTORE_PASSWORD,  # Keystore password (from env or param)

    [string]$TeamCityServiceName = "TeamCity"            # TeamCity Windows service name
)

if (-not $KeystorePassword) {
    throw "Keystore password not provided. Please pass it as a parameter or set environment variable KEYSTORE_PASSWORD."
}

function Find-Keytool {
    if ($env:JAVA_HOME) {
        $kt = Join-Path $env:JAVA_HOME "bin\keytool.exe"
        if (Test-Path $kt) { return $kt }
    }
    throw "keytool.exe not found. Please set JAVA_HOME environment variable."
}

function Get-KeystoreInfo {
    param([string]$ServerXmlPath)
    try {
        [xml]$xml = Get-Content $ServerXmlPath -ErrorAction Stop
    }
    catch {
        throw "Failed to read server.xml at $ServerXmlPath. $_"
    }

    $connector = $xml.Server.Service.Connector | Where-Object { $_.scheme -eq "https" }
    if (-not $connector) { throw "HTTPS connector not found in server.xml" }
    return @{
        KeystoreFile = $connector.keystoreFile
        KeystorePass = $connector.keystorePass
    }
}

function Get-CertFromGCS {
    param(
        [string]$Bucket,
        [string]$Object,
        [string]$Destination
    )
    Write-Host "Downloading certificate from gs://$Bucket/$Object to $Destination ..."
    $cmd = "gcloud storage cp gs://$Bucket/$Object `"$Destination`""
    $proc = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -Command $cmd" -Wait -NoNewWindow -PassThru
    if ($proc.ExitCode -ne 0) {
        throw "Failed to download certificate from GCS."
    }
    Write-Host "Download completed."
}

try {
    # Ensure certificate directory exists
    if (-not (Test-Path $TeamCityCertDir)) {
        Write-Host "Creating certificate directory: $TeamCityCertDir"
        New-Item -ItemType Directory -Path $TeamCityCertDir -Force | Out-Null
    }

    $serverXmlPath = Join-Path $TeamCityConfDir "server.xml"
    Write-Host "Reading keystore info from $serverXmlPath"
    $ksInfo = Get-KeystoreInfo -ServerXmlPath $serverXmlPath
    $keystoreFile = $ksInfo.KeystoreFile

    # Ensure keystore directory exists
    $keystoreDir = Split-Path $keystoreFile -Parent
    if (-not (Test-Path $keystoreDir)) {
        Write-Host "Creating keystore directory: $keystoreDir"
        New-Item -ItemType Directory -Path $keystoreDir -Force | Out-Null
    }

    $localCertPath = Join-Path $TeamCityCertDir (Split-Path $GcsCertObjectName -Leaf)

    # Download certificate from GCS
    Get-CertFromGCS -Bucket $GcsBucketName -Object $GcsCertObjectName -Destination $localCertPath

    # Stop TeamCity service
    Write-Host "Stopping TeamCity service '$TeamCityServiceName'..."
    Stop-Service -Name $TeamCityServiceName -Force -ErrorAction Stop
    Write-Host "TeamCity service stopped."

    # Locate keytool.exe
    $keytool = Find-Keytool
    Write-Host "Using keytool at: $keytool"

    # Prepare keytool import arguments
    $keytoolArgs = @(
        "-importkeystore",
        "-srckeystore", $localCertPath,
        "-srcstoretype", "pkcs12",
        "-srcstorepass", $KeystorePassword,
        "-destkeystore", $keystoreFile,
        "-deststorepass", $KeystorePassword,
        "-noprompt"
    )

    if (-not (Test-Path $keystoreFile)) {
        Write-Host "Keystore file not found at '$keystoreFile'. Creating new keystore by importing .pfx..."
    }
    else {
        Write-Host "Keystore file found at '$keystoreFile'. Updating keystore with new certificate..."
    }

    # Run keytool import to create or update keystore
    $proc = Start-Process -FilePath $keytool -ArgumentList $keytoolArgs -Wait -NoNewWindow -PassThru
    if ($proc.ExitCode -ne 0) {
        throw "Keystore import failed with exit code $($proc.ExitCode)"
    }
    Write-Host "Certificate imported successfully."

    # Start TeamCity service
    Write-Host "Starting TeamCity service '$TeamCityServiceName'..."
    Start-Service -Name $TeamCityServiceName -ErrorAction Stop
    Write-Host "TeamCity service started."

    Write-Host "TeamCity SSL certificate installation completed successfully." -ForegroundColor Green
}
catch {
    Write-Error "Error: $_"
    exit 1
}
