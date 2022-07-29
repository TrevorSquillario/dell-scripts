
<#
_author_ = Trevor Squillario <Trevor_Squillario@Dell.com
_version_ = 3.0
Copyright (c) 2020, Dell, Inc.
This software is licensed to you under the GNU General Public License,
version 2 (GPLv2). There is NO WARRANTY for this software, express or
implied, including the implied warranties of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
along with this software; if not, see
http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>

<#
.Synopsis
   Cmdlet used to get system health rollup status
.DESCRIPTION
   - idrac_ip: Pass in iDRAC IP address
   - idrac_username: Pass in iDRAC username
   - idrac_password: Pass in iDRAC username password
.EXAMPLE
   .\Get-SystemHealth.ps1 -idrac_ip 192.168.0.120 -username root -password 'calvin'
#>

param(
[Parameter(Mandatory=$True)]
[string]$idrac_ip,
[Parameter(Mandatory=$True)]
[string]$idrac_username,
[Parameter(Mandatory=$True)]
[string]$idrac_password
)

# Function to ignore SSL certs
function Set-CertPolicy() {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        $PSDefaultParameterValues["Invoke-RestMethod:SkipCertificatcd eCheck"] = $true
        $PSDefaultParameterValues["Invoke-WebRequest:SkipCertificateCheck"] = $true
        #$PSDefaultParameterValues.Add("Invoke-RestMethod:SkipCertificateCheck", $true)
        #$PSDefaultParameterValues.Add("Invoke-WebRequest:SkipCertificateCheck", $true)
    } else {
        ## Trust all certs - for sample usage only
        try {
            Add-Type @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : ICertificatePolicy {
                public bool CheckValidationResult(
                    ServicePoint srvPoint, X509Certificate certificate,
                    WebRequest request, int certificateProblem) {
                    return true;
                }
            }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        }
        catch {
            Write-Error "Unable to add type for cert policy"
        }
    } 
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
$user = $idrac_username
$pass= $idrac_password
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)

class SystemHealthStatus {
    $Host
    $ServiceTag
    $SystemHealthStatus
    $SubSystem
    $SubSystemHealthStatus
}

Try {
    Set-CertPolicy
    $Output = @()
    # Get System Health Status
    $SystemHealthUri = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1"
    $SystemHealthResult = Invoke-WebRequest -Uri $SystemHealthUri -Credential $credential -Method Get -UseBasicParsing -Headers @{"Accept"="application/json"}
    if ($SystemHealthResult.StatusCode -eq 200 -or $SystemHealthResult.StatusCode -eq 202) {
        $SystemHealthResultJson = $SystemHealthResult.Content | ConvertFrom-Json
        $SystemHealthStatus = $SystemHealthResultJson.Status.Health
        $ServiceTag = $SystemHealthResultJson.Oem.Dell.DellSystem.ChassisServiceTag
    }
    else
    {
        Write-Error $SystemHealthResult
        return
    }

    # Get SubSystem Health Status
    $RollupStatusUri = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Oem/Dell/DellRollupStatus"
    $RollupStatusResult = Invoke-WebRequest -Uri $RollupStatusUri -Credential $credential -Method Get -UseBasicParsing -Headers @{"Accept"="application/json"}
    if ($RollupStatusResult.StatusCode -eq 200 -or $RollupStatusResult.StatusCode -eq 202) {
        $RollupStatusResultJson = $RollupStatusResult.Content | ConvertFrom-Json
        foreach ($RollupStatus in $RollupStatusResultJson.Members) {
            $SubSystemHealthOutput = [SystemHealthStatus]@{
                Host = $idrac_ip
                ServiceTag = $ServiceTag
                SystemHealthStatus = $SystemHealthStatus
                SubSystem = $RollupStatus.SubSystem
                SubSystemHealthStatus = $RollupStatus.RollupStatus
            }
            $Output += $SubSystemHealthOutput
        }
        return $Output
    }
    else
    {
        Write-Error $RollupStatusResult
        return
    }
}
Catch {
    Write-Error ($_.ErrorDetails)
}