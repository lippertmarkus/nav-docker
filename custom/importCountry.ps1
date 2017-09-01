$serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psm1"

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

$NavServiceName = 'MicrosoftDynamicsNavServer$NAV'
$SqlServiceName = 'MSSQL$SQLEXPRESS'
$SqlWriterServiceName = "SQLWriter"
$SqlBrowserServiceName = "SQLBrowser"

Write-Host "Downloading database"
$countryFile = "C:\COUNTRY.zip"
(New-Object System.Net.WebClient).DownloadFile("$env:COUNTRYURL", $countryFile)
[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
$countryFolder = "$PSScriptRoot\Country"
New-Item -Path $countryFolder -ItemType Directory -ErrorAction Ignore | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory($countryFile, $countryFolder)

Write-Host "Starting Local SQL Server"
Start-Service -Name $SqlBrowserServiceName -ErrorAction Ignore
Start-Service -Name $SqlWriterServiceName -ErrorAction Ignore
Start-Service -Name $SqlServiceName -ErrorAction Ignore

# Restore CRONUS Demo database to databases folder

Write-Host "Restore CRONUS Demo Database"
$databaseName = "$env:DatabaseName"
$databaseFolder = "c:\databases\$databaseName"
$databaseServer = "localhost"
$databaseInstance = "SQLEXPRESS"
$bak = (Get-ChildItem -Path "$countryFolder\*.bak")[0]
$databaseFile = $bak.FullName

# Restore database
New-Item -Path $databaseFolder -itemtype Directory | Out-Null
New-NAVDatabase -DatabaseServer $databaseServer `
                -DatabaseInstance $databaseInstance `
                -DatabaseName "$databaseName" `
                -FilePath "$databaseFile" `
                -DestinationPath "$databaseFolder" | Out-Null

# Shrink the demo database log file
& SQLCMD -Q "USE master;
ALTER DATABASE $DatabaseName SET RECOVERY SIMPLE;
GO
USE $DatabaseName;
GO
DBCC SHRINKFILE(2, 1)
GO
USE master;
ALTER DATABASE $DatabaseName SET RECOVERY FULL;
GO"

# run local installers if present
if (Test-Path "$countryFolder\Installers" -PathType Container) {
    Get-ChildItem "$countryFolder\Installers" | Where-Object { $_.PSIsContainer } | % {
        $dir = $_.FullName
        Get-ChildItem (Join-Path $dir "*.msi") | % {
            $filepath = $_.FullName
            if ($filepath.Contains('\WebHelp\')) {
                Write-Host "Skipping $filepath"
            } else {
                Write-Host "Installing $filepath"
                Start-Process -FilePath $filepath -WorkingDirectory $dir -ArgumentList "/qn /norestart" -Wait
            }
        }
    }
}

$CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
$CustomConfig = [xml](Get-Content $CustomConfigFile)
$customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value = "$databaseName"
$CustomConfig.Save($CustomConfigFile)

Write-Host "Start NAV Service Tier"
Start-Service -Name $NavServiceName -WarningAction Ignore

Write-Host "Import License file"
$licensefile = (Get-ChildItem -Path "$countryFolder\*.flf")[0]
Import-NAVServerLicense -LicenseFile $licensefile -ServerInstance 'NAV' -Database NavDatabase -WarningAction SilentlyContinue

Write-Host "Remove CRONUS DB"
$cronusFiles = Get-NavDatabaseFiles -DatabaseName "CRONUS"
& sqlcmd -Q "ALTER DATABASE [CRONUS] SET OFFLINE WITH ROLLBACK IMMEDIATE"
& sqlcmd -Q "DROP DATABASE [CRONUS]"
$cronusFiles | % { remove-item $_.Path }

Write-Host "Cleanup"
Remove-Item $countryFile -Force
Remove-Item $countryFolder -Force -Recurse
