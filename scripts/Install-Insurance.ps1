param (
    [string]$dsnMssqlDatabase,
    [string]$dsnMssqlPassword,
    [string]$dsnMssqlServer,
    [string]$dsnMssqlUsername
)


$msiPath = "C:\Insurance\InsuranceHostInstaller.msi"
$logPath = "C:\Insurance\InsuranceHostInstall.log"
 
Start-Process msiexec.exe -ArgumentList @(
    "/i `"$msiPath`"",
    "DSN_MSSQL_SERVER=$dsnMssqlServer",
    "DSN_MSSQL_DATABASE=$dsnMssqlDatabase",
    "DSN_MSSQL_USERNAME=$dsnMssqlUsername",
    "DSN_MSSQL_PASSWORD=$dsnMssqlPassword",
    "DSN_USER_LANGUAGE=en",
    "/qn",                             # silent install
    "/l*v `"$logPath`""                # full logging
) -Wait