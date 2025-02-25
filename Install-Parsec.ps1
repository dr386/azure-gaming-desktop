#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Automated Parsec Application installation with virtual display driver.
.DESCRIPTION
    This script installs Parsec and its Virtual Display Driver, configures necessary settings,
    and disables conflicting display adapters.
.NOTES
    Version: 1.1
    Requires: PowerShell 5.0+, Administrator rights
#>

# Configuration variables
$Global:TempDir = "C:\ParsecTemp"
$Global:AppsDir = "$TempDir\Apps"
$Global:ParsecInstallerUrl = "https://builds.parsecgaming.com/package/parsec-windows.exe"
$Global:ParsecVddUrl = "https://builds.parsec.app/vdd/parsec-vdd-0.37.0.0.exe"
$Global:ParsecConfigPath = "C:\ProgramData\Parsec\config.txt"
$Global:ParsecCertPath = "$env:ProgramData\ParsecLoader\parsecpublic.cer"
$Global:ProgressActivity = "Setting Up Parsec"
$Global:ErrorLog = "$TempDir\parsec_install_errors.log"

# Function to write progress with error handling
Function Write-InstallProgress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Status,
        
        [Parameter(Mandatory=$true)]
        [int]$PercentComplete
    )
    
    try {
        Write-Progress -Activity $Global:ProgressActivity -Status $Status -PercentComplete $PercentComplete
    }
    catch {
        Write-Warning "Failed to display progress: $_"
    }
}

# Function to log errors
Function Write-ErrorLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    
    if ($ErrorRecord) {
        $logEntry += "`nError Details: $($ErrorRecord.Exception.Message)"
        $logEntry += "`nStack Trace: $($ErrorRecord.ScriptStackTrace)"
    }
    
    try {
        Add-Content -Path $Global:ErrorLog -Value $logEntry -ErrorAction Stop
        Write-Warning $Message
    }
    catch {
        Write-Warning "Failed to write to error log: $_"
        Write-Warning $Message
    }
}

# Create required directories
Function Initialize-Directories {
    [CmdletBinding()]
    param()
    
    Write-InstallProgress -Status "Creating installation directories" -PercentComplete 5
    
    try {
        foreach ($dir in @($Global:TempDir, $Global:AppsDir)) {
            if (-not (Test-Path -Path $dir)) {
                New-Item -Path $dir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Verbose "Created directory: $dir"
            }
            else {
                Write-Verbose "Directory already exists: $dir"
            }
        }
        return $true
    }
    catch {
        Write-ErrorLog -Message "Failed to create directories" -ErrorRecord $_
        return $false
    }
}

# Download required files with retry logic
Function Get-ParsecResources {
    [CmdletBinding()]
    param()
    
    Write-InstallProgress -Status "Downloading Parsec installation files" -PercentComplete 15
    
    $files = @{
        "Parsec Application" = @{
            Url = $Global:ParsecInstallerUrl
            Destination = "$Global:AppsDir\parsec-windows.exe"
        }
        "Parsec Virtual Display Driver" = @{
            Url = $Global:ParsecVddUrl
            Destination = "$Global:AppsDir\parsec-vdd.exe"
        }
    }
    
    $allDownloadsSucceeded = $true
    
    foreach ($name in $files.Keys) {
        $maxRetries = 3
        $retryCount = 0
        $downloadSuccess = $false
        
        Write-InstallProgress -Status "Downloading $name" -PercentComplete 15
        
        while (-not $downloadSuccess -and $retryCount -lt $maxRetries) {
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent", "PowerShell Script")
                $wc.DownloadFile($files[$name].Url, $files[$name].Destination)
                
                if (Test-Path -Path $files[$name].Destination) {
                    $downloadSuccess = $true
                    Write-Verbose "Successfully downloaded $name"
                }
                else {
                    throw "Download completed but file not found at destination"
                }
            }
            catch {
                $retryCount++
                Write-Warning "Attempt $retryCount of $maxRetries to download $name failed: $_"
                
                if ($retryCount -ge $maxRetries) {
                    Write-ErrorLog -Message "Failed to download $name after $maxRetries attempts" -ErrorRecord $_
                    $allDownloadsSucceeded = $false
                }
                else {
                    Start-Sleep -Seconds ($retryCount * 2)
                }
            }
            finally {
                if ($wc) {
                    $wc.Dispose()
                }
            }
        }
    }
    
    return $allDownloadsSucceeded
}

# Install Parsec application
Function Install-ParsecApplication {
    [CmdletBinding()]
    param()
    
    Write-InstallProgress -Status "Installing Parsec application" -PercentComplete 40
    
    try {
        $installerPath = "$Global:AppsDir\parsec-windows.exe"
        
        if (-not (Test-Path -Path $installerPath)) {
            throw "Parsec installer not found at $installerPath"
        }
        
        $process = Start-Process -FilePath $installerPath -ArgumentList "/silent", "/shared" -Wait -PassThru -ErrorAction Stop
        
        # Verify installation by checking for Parsec executable
        $parsecExe = "$env:ProgramFiles\Parsec\parsecd.exe"
        
        if (-not (Test-Path -Path $parsecExe)) {
            throw "Parsec installation verification failed - executable not found"
        }
        
        Write-Verbose "Parsec application installed successfully"
        return $true
    }
    catch {
        Write-ErrorLog -Message "Failed to install Parsec application" -ErrorRecord $_
        return $false
    }
}

# Install Parsec Virtual Display Driver
Function Install-ParsecVDD {
    [CmdletBinding()]
    param()
    
    Write-InstallProgress -Status "Installing Parsec Virtual Display Driver" -PercentComplete 60
    
    try {
        # Import certificate first
        if (-not (Test-Path -Path $Global:ParsecCertPath)) {
            throw "Parsec certificate not found at $Global:ParsecCertPath"
        }
        
        Import-Certificate -CertStoreLocation "Cert:\LocalMachine\TrustedPublisher" -FilePath $Global:ParsecCertPath -ErrorAction Stop | Out-Null
        Write-Verbose "Parsec certificate imported successfully"
        
        # Install VDD
        $vddPath = "$Global:AppsDir\parsec-vdd.exe"
        
        if (-not (Test-Path -Path $vddPath)) {
            throw "Parsec VDD installer not found at $vddPath"
        }
        
        $process = Start-Process -FilePath $vddPath -ArgumentList "/silent" -PassThru
        
        # Wait for installation to complete with timeout
        $maxWaitSeconds = 60
        $timeout = New-TimeSpan -Seconds $maxWaitSeconds
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $driverInstalled = $false
        
        Write-Verbose "Waiting for VDD installation to complete (timeout: $maxWaitSeconds seconds)..."
        
        while ($stopwatch.Elapsed -lt $timeout -and -not $driverInstalled) {
            Start-Sleep -Seconds 2
            
            # Check if driver is installed
            $device = Get-PnpDevice | Where-Object { $_.Name -eq "Parsec Virtual Display Adapter" } -ErrorAction SilentlyContinue
            
            if ($null -ne $device) {
                $driverInstalled = $true
                Write-Verbose "Parsec Virtual Display Adapter detected"
            }
        }
        
        # Clean up installer process if still running
        if (Get-Process -Name parsec-vdd -ErrorAction SilentlyContinue) {
            Stop-Process -Name parsec-vdd -Force -ErrorAction SilentlyContinue
            Write-Verbose "Stopped parsec-vdd installer process"
        }
        
        if (-not $driverInstalled) {
            throw "Failed to detect Parsec Virtual Display Adapter within $maxWaitSeconds seconds"
        }
        
        return $true
    }
    catch {
        Write-ErrorLog -Message "Failed to install Parsec Virtual Display Driver" -ErrorRecord $_
        return $false
    }
}

# Configure Parsec settings
Function Set-ParsecConfiguration {
    [CmdletBinding()]
    param()
    
    Write-InstallProgress -Status "Configuring Parsec settings" -PercentComplete 80
    
    try {
        if (-not (Test-Path -Path $Global:ParsecConfigPath)) {
            # Create empty config if it doesn't exist
            New-Item -Path $Global:ParsecConfigPath -ItemType File -Force -ErrorAction Stop | Out-Null
            Write-Verbose "Created new Parsec config file"
        }
        
        # Read existing config
        $configContent = Get-Content -Path $Global:ParsecConfigPath -ErrorAction Stop
        
        # Add required settings if not already present
        $settingsToAdd = @(
            "host_virtual_monitors = 1",
            "host_privacy_mode = 1"
        )
        
        foreach ($setting in $settingsToAdd) {
            $settingName = $setting.Split("=")[0].Trim()
            
            # Check if setting already exists
            $settingExists = $configContent | Where-Object { $_ -match "^$settingName\s*=" }
            
            if (-not $settingExists) {
                $configContent += $setting
                Write-Verbose "Added setting: $setting"
            }
        }
        
        # Save the updated config
        $configContent | Out-File -FilePath $Global:ParsecConfigPath -Encoding ascii -Force -ErrorAction Stop
        Write-Verbose "Parsec configuration updated successfully"
        
        return $true
    }
    catch {
        Write-ErrorLog -Message "Failed to configure Parsec settings" -ErrorRecord $_
        return $false
    }
}

# Disable conflicting display adapters
Function Disable-ConflictingDisplayAdapters {
    [CmdletBinding()]
    param()
    
    Write-InstallProgress -Status "Disabling conflicting display adapters" -PercentComplete 90
    
    try {
        $adaptersToDisable = @(
            "Microsoft Basic Display Adapter",
            "Microsoft Hyper-V Video"
        )
        
        foreach ($adapterName in $adaptersToDisable) {
            $devices = Get-PnpDevice | Where-Object { 
                $_.FriendlyName -like $adapterName -and $_.Status -eq "OK" 
            } -ErrorAction SilentlyContinue
            
            if ($devices) {
                foreach ($device in $devices) {
                    Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop
                    Write-Verbose "Disabled device: $($device.FriendlyName)"
                }
            }
            else {
                Write-Verbose "No active $adapterName devices found"
            }
        }
        
        return $true
    }
    catch {
        Write-ErrorLog -Message "Failed to disable conflicting display adapters" -ErrorRecord $_
        return $false
    }
}

# Main installation function
Function Install-Parsec {
    [CmdletBinding()]
    param()
    
    Write-Host "Starting Parsec installation..." -ForegroundColor Cyan
    
    # Check for admin rights
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host "This script requires administrator privileges. Please run PowerShell as Administrator." -ForegroundColor Red
        return
    }
    
    # Create error log directory
    if (-not (Test-Path -Path (Split-Path -Path $Global:ErrorLog -Parent))) {
        New-Item -Path (Split-Path -Path $Global:ErrorLog -Parent) -ItemType Directory -Force | Out-Null
    }
    
    $overallSuccess = $true
    
    # Execute installation steps
    $steps = @(
        @{ Name = "Initialize-Directories"; Status = "Creating directories" },
        @{ Name = "Get-ParsecResources"; Status = "Downloading resources" },
        @{ Name = "Install-ParsecApplication"; Status = "Installing Parsec" },
        @{ Name = "Install-ParsecVDD"; Status = "Installing Parsec Virtual Display Driver" },
        @{ Name = "Set-ParsecConfiguration"; Status = "Configuring Parsec" },
        @{ Name = "Disable-ConflictingDisplayAdapters"; Status = "Disabling conflicting adapters" }
    )
    
    $totalSteps = $steps.Count
    $currentStep = 0
    
    foreach ($step in $steps) {
        $currentStep++
        $percentComplete = [math]::Floor(($currentStep - 1) / $totalSteps * 100)
        
        Write-InstallProgress -Status $step.Status -PercentComplete $percentComplete
        
        try {
            $result = & $step.Name
            
            if (-not $result) {
                $overallSuccess = $false
                Write-Warning "Step '$($step.Name)' failed"
            }
        }
        catch {
            $overallSuccess = $false
            Write-ErrorLog -Message "Unhandled error in step '$($step.Name)'" -ErrorRecord $_
        }
    }
    
    # Complete the progress bar
    Write-InstallProgress -Status "Installation complete" -PercentComplete 100
    
    # Final status message
    if ($overallSuccess) {
        Write-Host "Parsec installation completed successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "Parsec installation completed with errors. Check the log at $Global:ErrorLog for details." -ForegroundColor Yellow
    }
}

Install-Parsec