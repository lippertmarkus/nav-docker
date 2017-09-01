# create windows user
Write-Host "-----------------------------------------------------------------"
$username = Read-Host -Prompt "Username (without Domain)"
$password = Read-Host -AsSecureString -Prompt "Password"
Write-Host "-----------------------------------------------------------------"
Write-Host "- Setting up Windows User.."
New-LocalUser -Name $username -Password $password

# create nav user
Write-Host "- Setting up NAV User and Permissions.."
$nstFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
Import-Module (Join-Path $nstFolder 'Microsoft.Dynamics.Nav.Management.dll')
New-NavServerUser -ServerInstance NAV -WindowsAccount $username
New-NavServerUserPermissionSet -ServerInstance NAV -WindowsAccount $username -PermissionSetId SUPER

# create sql user
Write-Host "- Creating SQL user.."
$domain = $env:COMPUTERNAME
$sqlcmd = @"
IF NOT EXISTS 
(SELECT name  
FROM master.sys.server_principals
WHERE name = '$domain\$username')
BEGIN
CREATE LOGIN [$domain\$username] FROM WINDOWS
EXEC sp_addsrvrolemember '$domain\$username', 'sysadmin'
END

ALTER LOGIN [$domain\$username] ENABLE
GO
"@
        
& sqlcmd.exe -Q $sqlcmd

Write-Host "FINISHED"