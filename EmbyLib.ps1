#Function from https://gallery.technet.microsoft.com/scriptcenter/Get-StringHash-aa843f71
function Get-StringHash([String] $String,$HashName = "MD5") 
{ 
    $StringBuilder = New-Object System.Text.StringBuilder 
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))|%{ 
    [Void]$StringBuilder.Append($_.ToString("x2")) 
    } 
    $StringBuilder.ToString() 
}

function Execute-EmbyQuery($method,$path,$data){
    $authResult = Get-EmbyAccessToken -Username $embyUsername -Password $embyPassword
    $user = $authResult.Content | ConvertFrom-Json

    $headers = @{ "X-MediaBrowser-Token"=$user.AccessToken }
    $url = $embyServerUrl + $path

    if($method -eq "POST" -and $data){
        return Invoke-RestMethod -uri $url -Method POST -Headers $headers -Body ($data | ConvertTo-Json) -ContentType "application/json"
    }elseif($method -eq "GET"){
        return Invoke-RestMethod -uri $url -Method GET -Headers $headers
    }elseif($method -eq "DELETE"){
        return Invoke-RestMethod -uri $url -Method DELETE -Headers $headers
    }
}

#Function from Emby Forum
function Get-EmbyAccessToken {
    [CmdletBinding()]
    param ($Username, $Password)
    $authUrl = "{0}/Users/AuthenticateByName?format=json" -f $embyServerUrl
    $sha1Pass = Get-StringHash -String $password -HashName "SHA1"
    $md5Pass = Get-StringHash -String $password 
    $postParams = (@{Username="$username";password="$sha1Pass";passwordMd5="$md5Pass"} | ConvertTo-Json)


    $headers = @{"Authorization"="MediaBrowser Client=`"$embyClientName`", Device=`"$embyDeviceName`", DeviceId=`"$embyDeviceId`", Version=`"$embyApplicationVersion`""}


    Write-Verbose ("authUrl={0},Username={1},sha1Pass={2},md5Pass={3},params={4}" -f $authUrl, $Username,$sha1Pass,$md5Pass,$postParams)
    return (Invoke-WebRequest -Uri $authUrl -Method POST -Body $postParams -ContentType "application/json" -Headers $headers)
} 

function Get-EmbyUsers(){
    $users = @{}
    $usersRaw = Execute-EmbyQuery -method "GET" -path "/Users/"

    $usersRaw | ForEach-Object {
        $users[$_.Name] = $_
    }

    return $users
}

function Get-EmbyUser($username){
    $users = @{}
    $usersRaw = Execute-EmbyQuery -method "GET" -path "/Users/"

    $user = $usersRaw | Where-Object { $_.Name -eq $username }
    if($user){
        return $user
    }else{
        return $false
    }
}

function Create-EmbyUser($username){
    
    if(! (Get-EmbyUser -username $username)){
        Execute-EmbyQuery -method "POST" -path "/Users/New" -data @{ Name = $username }
        Write-Host("Creating user $username")
        Set-EmbyUserPolicy -username $username -attribute "IsHidden" -value "true"
        Write-Host("Disabling user $username until a password is set")
        return Set-EmbyUserPolicy -username $username -attribute "IsDisabled" -value "true"
    }
    return $false
}

function Set-EmbyUserPassword($username, $newPassword){
    
    $userId =  (Get-EmbyUser -username $username).Id
    if(!$userId -or $newPassword -eq ""){ 
        Write-Error("Couldn't find $username"); 
        Set-EmbyUserPolicy -username $username -attribute "IsDisabled" -value "true"
        return $null
    }

    $emptyPassword = Get-StringHash -String "" -HashName "SHA1"
    $newPassword = Get-StringHash -String $newPassword -HashName "SHA1"
    
    Write-Host("Resetting $username Password")
    Execute-EmbyQuery -method "POST" -path "/Users/$userId/Password" -data @{ resetPassword = "true" }
    
    Write-Host("Activating $username")
    Set-EmbyUserPolicy -username $username -attribute "IsDisabled" -value "false"
            
    Write-Host("Setting $username Password")
    return Execute-EmbyQuery -method "POST" -path "/Users/$userId/Password" -data @{ currentPassword = $emptyPassword; newPassword = $newPassword }

}

function Remove-EmbyUser($username){
    $userId = (Get-EmbyUser -username $username).Id
    Write-Host("Deleting $username, ID: $userId")
    Execute-EmbyQuery -method "DELETE" -path "/Users/$userId"
}

function Set-EmbyUserPolicy($username,$attribute,$value){
    $user = Get-EmbyUser $username
    $policy = $user.Policy

    Write-Host("Modifying $attribute to $value on $username, old value: " + $policy.$attribute)
    $policy.$attribute=$value

    Execute-EmbyQuery -method "POST" -path "/Users/$($user.Id)/Policy" -data $policy
    return Get-EmbyUser $username
}

$embyServerUrl = "https://nerd-kino.de"
$embyClientName = "PowerShellScript"
$embyDeviceName = "PowerShellScript"
$embyDeviceId = "1"
$embyApplicationVersion = "1.0.0";
$embyUsername = ""
$embyPassword = ""
