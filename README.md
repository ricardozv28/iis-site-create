# IIS Website Create

This action will create an IIS website on a target Windows Server

## Index <!-- omit in toc -->

- [Inputs](#inputs)
- [Prerequisites](#prerequisites)
- [Example](#example)
- [Contributing](#contributing)
  - [Incrementing the Version](#incrementing-the-version)
- [Code of Conduct](#code-of-conduct)
- [License](#license)

## Inputs

| Parameter                           | Is Required | Description                                                             |
| ----------------------------------- | ----------- | ----------------------------------------------------------------------- |
| `server`                            | true        | The name of the target server                                           |
| `website-name`                      | true        | The name of the website                                                 |
| `app-pool-name`                     | true        | The name of the app pool                                                |
| `website-host-header`               | true        | The host-header the web site should respond to                          |
| `website-path`                      | true        | The local directory location of the web site, i.e., "c:\inetpub\webapp" |
| `website-cert-path`                 | false       | The private cert file path for site https binding                       |
| `website-cert-friendly-name`        | false       | The private cert's friendly name                                        |
| `website-cert-password`             | false       | The private cert's file password                                        |
| `app-pool-service-account-id`       | false       | The service account name used for the operation of the web site         |
| `app-pool-service-account-secret`   | false       | The service account secret used for the operation of the web site       |
| `deployment-service-account-id`     | true        | The service account id used to create the IIS site                      |
| `deployment-service-account-secret` | true        | The service account secret used to create the IIS site                  |

## Prerequisites

The IIS site create action uses Web Services for Management, [WSMan], and Windows Remote Management, [WinRM], to create remote administrative sessions. Because of this, Windows Actions Runners, `runs-on: [windows-2019]`, must be used. If the IIS server target is on a local network that is not publicly available, then specialized self-hosted runners, `runs-on: [self-hosted, windows-2019]`, will need to be used to broker commands to the server.

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
  create-iis-site:
   runs-on: [windows-2019]
   env:
      server: 'iis-server.domain.com'
      website-name: 'Default Website'
      apo-pool-name: 'website-pool'
      website-host-header: '*.defaultsite.com'
      website-path: 'c:\inetpub\wwwroot'
      website-cert-path: './src/site_cert.pfx'
      website-cert-password: '${{ secrets.site_cert_password }}'
      website-cert-friendly-name: '*.defaultsite.com'

   steps:
    - name: Checkout
      uses: actions/checkout@v2
    - name: Create Web Site
        uses: im-open/iis-site-create@v3.0.0
        with:
          server: '${{ env.server }}'
          website-name: '${{ env.website-name }}'
          app-pool-name: '${{ env.app-pool-name }}'
          website-host-header: '${{ env.website-host-header}}'
          website-path: '${{ env.website-path }}'
          website-cert-path: '${{ env.website-cert-path }}'
          website-cert-password: '${{ env.website-cert-password }}'
          website-cert-friendly-name: '${{ env.website-cert-friendly-name }}'
          app-pool-service-account-id: '${{ env.APP_POOL_SA_ID }}'
          app-pool-service-account-secret: '${{ env.APP_POOL_SA_SECRET }}'
          deployment-service-account-id: '${{ secrets.ON_PREM_DEPLOYMENT_SA_ID }}'
          deployment-service-account-secret: '${{ secrets.ON_PREM_DEPLOYMENT_SA_SECRET }}'

...
```

## Contributing

When creating new PRs please ensure:
1. For major or minor changes, at least one of the commit messages contains the appropriate `+semver:` keywords listed under [Incrementing the Version](#incrementing-the-version).
2. The `README.md` example has been updated with the new version.  See [Incrementing the Version](#incrementing-the-version).
3. The action code does not contain sensitive information.

### Incrementing the Version

This action uses [git-version-lite] to examine commit messages to determine whether to perform a major, minor or patch increment on merge.  The following table provides the fragment that should be included in a commit message to active different increment strategies.
| Increment Type | Commit Message Fragment                     |
| -------------- | ------------------------------------------- |
| major          | +semver:breaking                            |
| major          | +semver:major                               |
| minor          | +semver:feature                             |
| minor          | +semver:minor                               |
| patch          | *default increment type, no comment needed* |

## Code of Conduct

This project has adopted the [im-open's Code of Conduct](https://github.com/im-open/.github/blob/master/CODE_OF_CONDUCT.md).

## License

Copyright &copy; 2021, Extend Health, LLC. Code released under the [MIT license](LICENSE).

[git-version-lite]: https://github.com/im-open/git-version-lite
[PowerShell Remoting over HTTPS with a self-signed SSL certificate]: https://4sysops.com/archives/powershell-remoting-over-https-with-a-self-signed-ssl-certificate
[WSMan]: https://docs.microsoft.com/en-us/windows/win32/winrm/ws-management-protocol
[WinRM]: https://docs.microsoft.com/en-us/windows/win32/winrm/about-windows-remote-management