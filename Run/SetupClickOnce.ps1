﻿# INPUT
#     $navDvdPath
#     $publicDnsName 
#     $httpPath
#     $dnsIdentity
#     $Auth
#     $clickOnceInstallerToolsFolder
#     $roleTailoredClientFolder
#
# OUTPUT
#

Import-Module "$NAVAdministrationScriptsFolder\NAVAdministration.psm1"
Import-Module WebAdministration

$clickOnceDirectory = Join-Path $httpPath "NAV"
Remove-Item $clickOnceDirectory -Force -Recurse -ErrorAction SilentlyContinue
$webSiteUrl = "http://${publicDnsName}:$publicFileSharePort/NAV"

$ClientUserSettingsFileName = "$runPath\ClientUserSettings.config"
[xml]$ClientUserSettings = Get-Content $clientUserSettingsFileName
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='Server']").value = "$publicDnsName"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ServerInstance']").value="NAV"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ServicesCertificateValidationEnabled']").value="false"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ClientServicesPort']").value="$publicWinClientPort"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ACSUri']").value = ""
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='DnsIdentity']").value = "$dnsIdentity"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ClientServicesCredentialType']").value = "$Auth"

$applicationName = "NAV Windows Client for $publicDnsName"
$applicationNameFinSql = "NAV C/SIDE for $publicDnsName"
$applicationPublisher = "Microsoft Corporation"


# Create empty directory
New-Item $ClickOnceDirectory -type directory | Out-Null
New-Item (Join-Path $ClickOnceDirectory "Win") -type directory | Out-Null
New-Item (Join-Path $ClickOnceDirectory "Finsql") -type directory | Out-Null


# Copy file structure from the installation folder
$templateFilesFolder  = Join-Path $clickOnceInstallerToolsFolder 'TemplateFiles'
Copy-Item $templateFilesFolder\* -Destination (Join-Path $ClickOnceDirectory "Win") -Recurse
Copy-Item $templateFilesFolder\* -Destination (Join-Path $ClickOnceDirectory "Finsql") -Recurse
Copy-Item (Join-Path $runPath "NAVClientInstallation.html") -Destination $clickOnceDirectory

# Save config file and copy the relevant WinClient files to the Deployment\ApplicationFiles folder
$clickOnceApplicationFilesDirectoryWin = Join-Path $ClickOnceDirectory 'Win\Deployment\ApplicationFiles'
$clickOnceApplicationFilesDirectoryFinsql = Join-Path $ClickOnceDirectory 'Finsql\Deployment\ApplicationFiles'
$clientUserSettingsFile = Join-Path $ClickOnceApplicationFilesDirectoryFinsql 'ClientUserSettings.config'
$ClientUserSettings.Save($clientUserSettingsFile)
$clientUserSettingsFile = Join-Path $clickOnceApplicationFilesDirectoryWin 'ClientUserSettings.config'
$ClientUserSettings.Save($clientUserSettingsFile)
. (Get-MyFilePath "SetupClickOnceDirectory.ps1")

$MageExeLocation = Join-Path $runPath 'Install\mage.exe'

# Win Client
$applicationManifestFile = Join-Path $clickOnceApplicationFilesDirectoryWin 'Microsoft.Dynamics.Nav.Client.exe.manifest'
$applicationIdentityName = "$publicDnsName ClickOnce"
$applicationIdentityVersion = (Get-Item -Path (Join-Path $clickOnceApplicationFilesDirectoryWin 'Microsoft.Dynamics.Nav.Client.exe')).VersionInfo.FileVersion

Set-ApplicationManifestFileList `
    -ApplicationManifestFile $ApplicationManifestFile `
    -ApplicationFilesDirectory $ClickOnceApplicationFilesDirectoryWin `
    -MageExeLocation $MageExeLocation
Set-ApplicationManifestApplicationIdentity `
    -ApplicationManifestFile $ApplicationManifestFile `
    -ApplicationIdentityName $ApplicationIdentityName `
    -ApplicationIdentityVersion $ApplicationIdentityVersion

$deploymentManifestFile = Join-Path $clickOnceDirectory 'Win\Deployment\Microsoft.Dynamics.Nav.Client.application'
$deploymentIdentityName = "$publicDnsName ClickOnce"
$deploymentIdentityVersion = $applicationIdentityVersion
$deploymentManifestUrl = ($webSiteUrl + "/Win/Deployment/Microsoft.Dynamics.Nav.Client.application")
$applicationManifestUrl = ($webSiteUrl + "/Win/Deployment/ApplicationFiles/Microsoft.Dynamics.Nav.Client.exe.manifest")

Set-DeploymentManifestApplicationReference `
    -DeploymentManifestFile $DeploymentManifestFile `
    -ApplicationManifestFile $ApplicationManifestFile `
    -ApplicationManifestUrl $ApplicationManifestUrl `
    -MageExeLocation $MageExeLocation
Set-DeploymentManifestSettings `
    -DeploymentManifestFile $DeploymentManifestFile `
    -DeploymentIdentityName $DeploymentIdentityName `
    -DeploymentIdentityVersion $DeploymentIdentityVersion `
    -ApplicationPublisher $ApplicationPublisher `
    -ApplicationName $ApplicationName `
    -DeploymentManifestUrl $DeploymentManifestUrl

# Finsql
Rename-Item (Join-Path $clickOnceApplicationFilesDirectoryFinsql 'Microsoft.Dynamics.Nav.Client.exe.manifest') (Join-Path $clickOnceApplicationFilesDirectoryFinsql 'finsql.exe.manifest')
$applicationManifestFile = Join-Path $clickOnceApplicationFilesDirectoryFinsql 'finsql.exe.manifest'
(Get-Content $applicationManifestFile).replace('"msil"', '"x86"') | Set-Content $applicationManifestFile
$applicationIdentityName = "$publicDnsName Finsql ClickOnce"
$applicationIdentityVersion = (Get-Item -Path (Join-Path $clickOnceApplicationFilesDirectoryFinsql 'finsql.exe')).VersionInfo.FileVersion

Set-ApplicationManifestFileList `
    -ApplicationManifestFile $ApplicationManifestFile `
    -ApplicationFilesDirectory $ClickOnceApplicationFilesDirectoryFinsql `
    -MageExeLocation $MageExeLocation
Set-ApplicationManifestApplicationIdentity `
    -ApplicationManifestFile $ApplicationManifestFile `
    -ApplicationIdentityName $ApplicationIdentityName `
    -ApplicationIdentityVersion $ApplicationIdentityVersion

Rename-Item (Join-Path $clickOnceDirectory 'Finsql\Deployment\Microsoft.Dynamics.Nav.Client.application') (Join-Path $clickOnceDirectory 'Finsql\Deployment\finsql.application')
$deploymentManifestFile = Join-Path $clickOnceDirectory 'Finsql\Deployment\finsql.application'
(Get-Content $deploymentManifestFile).replace('"msil"', '"x86"') | Set-Content $deploymentManifestFile
$deploymentIdentityName = "$publicDnsName Finsql ClickOnce"
$deploymentIdentityVersion = $applicationIdentityVersion
$deploymentManifestUrl = ($webSiteUrl + "/Finsql/Deployment/Finsql.application")
$applicationManifestUrl = ($webSiteUrl + "/Finsql/Deployment/ApplicationFiles/Finsql.exe.manifest")

Set-DeploymentManifestApplicationReference `
    -DeploymentManifestFile $DeploymentManifestFile `
    -ApplicationManifestFile $ApplicationManifestFile `
    -ApplicationManifestUrl $ApplicationManifestUrl `
    -MageExeLocation $MageExeLocation
Set-DeploymentManifestSettings `
    -DeploymentManifestFile $DeploymentManifestFile `
    -DeploymentIdentityName $DeploymentIdentityName `
    -DeploymentIdentityVersion $DeploymentIdentityVersion `
    -ApplicationPublisher $ApplicationPublisher `
    -ApplicationName $applicationNameFinSql `
    -DeploymentManifestUrl $DeploymentManifestUrl


# Put a web.config file in the root folder, which will tell IIS which .html file to open
$sourceFile = Join-Path $runPath 'root_web.config'
$targetFile = Join-Path $clickOnceDirectory 'web.config'
Copy-Item $sourceFile -destination $targetFile

# Put a web.config file in the Deployment folder, which will tell IIS to allow downloading of .config files etc.
$sourceFile = Join-Path $runPath 'deployment_web.config'
$targetFile = Join-Path $clickOnceDirectory 'Win\Deployment\web.config'
Copy-Item $sourceFile -destination $targetFile
$targetFile = Join-Path $clickOnceDirectory 'Finsql\Deployment\web.config'
Copy-Item $sourceFile -destination $targetFile
