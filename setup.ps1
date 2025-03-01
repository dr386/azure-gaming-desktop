# Usage: setup.ps1 -environment [test|prod]
# Description: This script downloads the necessary scripts from the repository and runs them to set up the Cloud PC.
[CmdletBinding(DefaultParameterSetName = "_AllParameterSets")]
param (
    [string] $environment = "test"
)

if ($environment -eq "prod") {
    $branch = "master"
}
elseif ($environment -eq "test") {
    $branch = "test"
}
else {
    Write-Host "Invalid environment. Usage: setup.ps1 -environment [test|prod]"
    exit -1
}

$host.ui.RawUI.WindowTitle = "Cloud PC Set Up Tool"

$Global:TempDir = "C:\ParsecTemp"

function Get-UtilsScripts ($scriptName) {
    $url = "https://raw.githubusercontent.com/dr386/azure-gaming-desktop/${branch}/${scriptName}"
    Write-Host "Downloading utils script from ${url}"
    [Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    $webClient = new-object System.Net.WebClient
    $webClient.DownloadFile($url, "${$Global:TempDir}\${scriptName}")
}

Get-UtilsScripts "Install-Parsec.ps1"

& ./Install-Parsec.ps1
