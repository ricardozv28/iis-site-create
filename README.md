# IIS Website Create

This action will create an on-premises IIS website

## Index <!-- omit in toc -->

- [Inputs](#inputs)
- [Prerequisites](#prerequisites)
- [Example](#example)
- [Code of Conduct](#code-of-conduct)
- [License](#license)

## Inputs

| Parameter                    | Is Required | Description                                                             |
| ---------------------------- | ----------- | ----------------------------------------------------------------------- |
| `server`                     | true        | The name of the target server                                           |
| `website-name`               | true        | The name of the website                                                 |
| `app-pool-name`              | true        | The name of the app pool                                                |
| `website-host-header`        | true        | The host-header the web site should respond to                          |
| `website-path`               | true        | The local directory location of the web site, i.e., "c:\inetpub\webapp" |
| `website-cert-path`          | true        | The private cert file path for site https binding                       |
| `website-cert-friendly-name` | true        | The private cert's friendly name                                        |
| `website-cert-password`      | true        | The private cert's file password'                                       |
| `service-account-id`         | true        | The service account name                                                |
| `service-account-password`   | true        | The service account password                                            |
| `server-public-key`          | true        | Path to remote server public ssl key                                    |

## Prerequisites

The IIS site create action uses Web Services for Management, [WSMan], and Windows Remote Management, [WinRM], to create remote administrative sessions. Because of this, Windows OS GitHubs Actions Runners, `runs-on: [windows-2019]`, must be used. If the IIS server target is on a local network that is not publicly available, then specialized self hosted runners, `runs-on: [self-hosted, windows-2019]`,  will need to be used to broker commands to the server.

Inbound secure WinRm network traffic (TCP port 5986) must be allowed from the GitHub Actions Runners virtual network so that remote sessions can be received.

Prep the remote IIS server to accept WinRM management calls.  In general the IIS server needs to have a [WSMan] listener that looks for incoming [WinRM] calls. Firewall exceptions need to be added for the secure WinRM TCP ports, and non-secure firewall rules should be disabled. Here is an example script that would be run on the IIS server:

  ```powershell
  $Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName <<ip-address|fqdn-host-name>>

  Export-Certificate -Cert $Cert -FilePath C:\temp\<<cert-name>>

  Enable-PSRemoting -SkipNetworkProfileCheck -Force

  # Check for HTTP listeners
  dir wsman:\localhost\listener

  # If HTTP Listeners exist, remove them
  Get-ChildItem WSMan:\Localhost\listener | Where -Property Keys -eq "Transport=HTTP" | Remove-Item -Recurse

  # If HTTPs Listeners don't exist, add one
  New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $Cert.Thumbprint –Force

  # This allows old WinRm hosts to use port 443
  Set-Item WSMan:\localhost\Service\EnableCompatibilityHttpsListener -Value true

  # Make sure an HTTPs inbound rule is allowed
  New-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -Name "Windows Remote Management (HTTPS-In)" -Profile Any -LocalPort 5986 -Protocol TCP

  # For security reasons, you might want to disable the firewall rule for HTTP that *Enable-PSRemoting* added:
  Disable-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)"
  ```

  - `ip-address` or `fqdn-host-name` can be used for the `DnsName` property in the certificate creation. It should be the name that the actions runner will use to call to the IIS server.
  - `cert-name` can be any name.  This file will used to secure the traffic between the actions runner and the IIS server

## Example

```yml
...

jobs:
  stop-iis:
   runs-on: [windows-2019]
   env:
      server: 'iis-server.domain.com'
      pool-name: 'website-pool'
      cert-path: './server-cert'

   steps:
    - name: Checkout
      uses: actions/checkout@v2
    - name: Create Web Site
        uses: im-open/iis-site-create@v1.0.0
        with:
          server: '${{ secrets.iis_server }}'
          website-name: '${{env.WEBSITE_NAME}}'
          app-pool-name: '${{ secrets.pool-name }}'
          website-host-header: '${{env.WEBSITE_HOST_HEADER}}'
          website-path: '${{env.DEPLOYMENT_FOLDER}}'
          website-cert-path: '${{ env.WEBSITE_CERT_PATH}}'
          website-cert-password: '${{ secrets.site_cert_password }}'
          website-cert-friendly-name: '${{env.WEBSITE_CERT_FRIENDLY_NAME}}'
          service-account-id: '${{secrets.iis_admin_user}}'
          service-account-password: '${{secrets.iis_admin_password}}'
          server-public-key: ${{ env.IIS_SERVER_CERT_PATH}}

  ...
```

## Code of Conduct

This project has adopted the [im-open's Code of Conduct](https://github.com/im-open/.github/blob/master/CODE_OF_CONDUCT.md).

## License

Copyright &copy; 2021, Extend Health, LLC. Code released under the [MIT license](LICENSE).

<!-- Links -->
[PowerShell Remoting over HTTPS with a self-signed SSL certificate]: https://4sysops.com/archives/powershell-remoting-over-https-with-a-self-signed-ssl-certificate
[WSMan]: https://docs.microsoft.com/en-us/windows/win32/winrm/ws-management-protocol
[WinRM]: https://docs.microsoft.com/en-us/windows/win32/winrm/about-windows-remote-management