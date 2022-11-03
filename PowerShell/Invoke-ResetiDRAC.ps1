<#
_author_ = Texas Roemer <Texas_Roemer@Dell.com>
_version_ = 4.0
Copyright (c) 2021, Dell, Inc.
This software is licensed to you under the GNU General Public License,
version 2 (GPLv2). There is NO WARRANTY for this software, express or
implied, including the implied warranties of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
along with this software; if not, see
http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>

<#
.Synopsis
   iDRAC cmdlet using Redfish API to reset(reboot) iDRAC.
.DESCRIPTION
   iDRAC cmdlet using Redfish API to reset(reboot) iDRAC. This cmdlet will only reboot the iDRAC, it will not reset iDRAC to default settings.
   Supported parameters to pass in for cmdlet:
   
   - idrac_ip: Pass in iDRAC IP
   - idrac_username: Pass in iDRAC username
   - idrac_password: Pass in iDRAC password
   - x_auth_token: Pass in iDRAC X-Auth token session to execute cmdlet instead of username / password (recommended)
.EXAMPLE
   Invoke-ResetIdracREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin
   # This example will reset iDRAC
.EXAMPLE
   Invoke-ResetIdracREDFISH -idrac_ip 192.168.0.120
   # This example will first prompt for iDRAC username/password using Get-Credential, then reset iDRAC
.EXAMPLE
   Invoke-ResetIdracREDFISH -idrac_ip 192.168.0.120 -x_auth_token 7bd9bb9a8727ec366a9cef5bc83b2708
   # This example using iDRAC X-auth token session will reset iDRAC
#>


# Required, optional parameters needed to be passed in when cmdlet is executed

param(
    [Parameter(Mandatory=$True)]
    [string]$idrac_ip,
    [Parameter(Mandatory=$False)]
    [string]$idrac_username,
    [Parameter(Mandatory=$False)]
    [string]$idrac_password
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
$user = $idrac_username
$pass = $idrac_password
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)
    
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

function reset_idrac
{
$JsonBody = @{"ResetType"="GracefulRestart"}
$JsonBody = $JsonBody | ConvertTo-Json -Compress
$uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Actions/Manager.Reset"
$post_result = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Method Post -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr

if ($post_result.StatusCode -eq 204)
{
    Write-Host "`n- PASS, POST command passed to reset iDRAC. iDRAC will be back up within a few minutes`n"
}
else
{
    [String]::Format("- FAIL, POST command failed to reset iDRAC, statuscode {0} returned. Detail error message: {1}",$post_result.StatusCode, $post_result)
    return
}

}
# Run cmdlet

$uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1"
$result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}

if ($result.StatusCode -eq 200 -or $result.StatusCode -eq 202)
{
    #pass
}
else
{
    $status_code = $result.StatusCode
    Write-Host "`n- FAIL, status code $status_code returned for GET request to validate iDRAC connection.`n"
    return
}

Set-CertPolicy
reset_idrac
