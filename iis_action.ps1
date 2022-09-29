Param(
    [parameter(Mandatory = $true)]
    [string]$server,
    [parameter(Mandatory = $true)]
    [string]$website_name,
    [parameter(Mandatory = $true)]
    [string]$app_pool_name,
    [parameter(Mandatory = $true)]
    [string]$website_host_header,
    [parameter(Mandatory = $true)]
    [string]$website_path,
    [parameter(Mandatory = $false)]
    [string]$website_cert_path,
    [parameter(Mandatory = $false)]
    [SecureString]$website_cert_password,
    [parameter(Mandatory = $true)]
    [string]$website_cert_friendly_name,
    [parameter(Mandatory = $false)]
    [string]$app_pool_user_id,
    [parameter(Mandatory = $false)]
    [SecureString]$app_pool_user_secret,
    [parameter(Mandatory = $true)]
    [string]$deploy_user_id,
    [parameter(Mandatory = $true)]
    [SecureString]$deploy_user_secret
)

$display_action = 'IIS Site Create'
$display_action_past_tense = 'IIS Site Created'

Write-Output $display_action

$credential = [PSCredential]::new($deploy_user_id, $deploy_user_secret)
$so = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck

$app_pool_credential = [PSCredential]::new($app_pool_user_id, $app_pool_user_secret)
$set_app_pool_secret = $app_pool_credential.GetNetworkCredential().Password

if (!$website_name -or !$website_path -or !$website_host_header -or !$website_cert_path -or !$website_cert_password -or !$website_cert_friendly_name) {
    "Create website requires site name, host header, website cert, website cert password, website cert friendly name, and directory path"
    exit 1
}

$script = {
    # create app pool if it doesn't exist
    if (Get-IISAppPool -Name $Using:app_pool_name) {
        Write-Output "The App Pool $Using:app_pool_name already exists"
    }
    else {
        Write-Output "Creating app pool $Using:app_pool_name"

        $system_path = [Environment]::GetFolderPath('System')
        $appcmd = '$system_path\inetsrv\AppCmd.exe'

        # Create the app pool
        $app_pool_args = @('add', 'apppool', "/name:$Using:app_pool_name")
        & $appcmd $app_pool_args

        if ($app_pool_user_id.Length -gt 0) {
            $app_pool_args = @(
                'set',
                'apppool',
                $Using:app_pool_name,
                "/processModel.identityType:SpecificUser",
                "-processModel.userName:$Using:app_pool_user_id",
                "-processModel.password:$Using:set_app_pool_secret"
            )
            & $appcmd $app_pool_args
        }
        Write-Output "App pool $Using:app_pool_name has been created"
    }

    # create the folder if it doesn't exist
    if (Test-path $Using:website_path) {
        Write-Output "The folder $Using:website_path already exists"
    }
    else {
        New-Item -ItemType Directory -Path $Using:website_path -Force
        Write-Output "Created folder $Using:website_path"
    }

    # create the site if it doesn't exist
    $iis_site = Get-IISSite -Name $Using:website_name
    if ($iis_site) {
        Write-Output "The site $Using:website_name already exists"
    }
    else {
        Write-Output "Creating IIS site $Using:website_name"
        New-WebSite -Name $Using:website_name `
            -HostHeader $Using:website_host_header `
            -Port 80 `
            -PhysicalPath $Using:website_path `
            -ApplicationPool $Using:app_pool_name

        New-WebBinding -Name $Using:website_name `
            -IPAddress "*" -Port 443 `
            -HostHeader $Using:website_host_header `
            -Protocol "https"

        $ssl_binding = Get-WebBinding -Name $Using:website_name | where { $_.Protocol -eq 'https' }

        $website_cert_store = 'cert:\LocalMachine\My'
        $cert_parts = $website_cert_store.Split('\')
        $location = $cert_parts[$cert_parts.Length - 1]

        $imported_cert = Get-ChildItem -Path $website_cert_store | where { $_.FriendlyName -eq $Using:website_cert_friendly_name }
        
        #write out the cert
        if (!$imported_cert -and $Using:website_cert_path.Length -gt 0) {
            # Get the key data
            [Byte[]]$website_cert_data = Get-Content -Path $website_cert_path -Encoding Byte
            
            $cert_file_parts = $($Using:website_cert_path).Replace('/', '\').Split('\')
            $cert_file_name = $cert_file_parts[$cert_file_parts.Length - 1]
            $cert_file_path = (Join-Path -Path $Using:website_path -ChildPath $cert_file_name)

            Set-Content -Path $cert_file_path -Value $Using:website_cert_data -Encoding Byte
            $imported_cert = Import-PfxCertificate `
                -CertStoreLocation $website_cert_store `
                -FilePath $cert_file_path `
                -Password $Using:website_cert_password
        }
        
        if (!$imported_cert) {
            throw "Unable to find certificate"
        }
        
        $ssl_binding.AddSslCertificate($imported_cert.Thumbprint, $location)
    }
}

Invoke-Command -ComputerName $server `
    -Credential $credential `
    -UseSSL `
    -SessionOption $so `
    -ScriptBlock $script

Write-Output $display_action_past_tense
