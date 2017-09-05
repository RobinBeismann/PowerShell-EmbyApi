# Powershell Emby User Management API
Emby API Functions for PowerShell

Those are just some basic functions, however I didn't implent much error handling so use it with care.

# Examples:

- Disable all Users without Password:
> Get-EmbyUsers | Where-Object { $_.HasPassword -eq "False" } | ForEach-Object { Set-EmbyUserPolicy -username $_.Name -attribute "IsDisabled" -value "True" }

- Create a user
> Create-EmbyUser -username "test" | Out-Null

- Remove a user
> Remove-EmbyUser -username "test" | Out-Null

- Set a users password
> Set-EmbyUserPassword -username "test" -newPassword "start12345" | Out-Null
