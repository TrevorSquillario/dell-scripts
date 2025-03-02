
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
   Cmdlet used to get network card info including ports and transceivers
.DESCRIPTION
   - idrac_ip: Pass in iDRAC IP address
   - idrac_username: Pass in iDRAC username
   - idrac_password: Pass in iDRAC username password
.EXAMPLE
   .\Get-NetworkInventory.ps1 -idrac_ip 192.168.0.120 -username root -password 'calvin'
#>

param(
[Parameter(Mandatory=$True)]
[string]$ip,
[Parameter(Mandatory=$True)]
[string]$username,
[Parameter(Mandatory=$True)]
[string]$password,
[Parameter(Mandatory=$False)]
[string]$gid,
[Parameter(Mandatory=$false)]
[ValidateSet("Name", "Id", "ServiceTag", "Model", "Type")]
[String]$FilterBy = "ServiceTag"
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
$user = $username
$pass= $password
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)

Try {
    Set-CertPolicy
    $Output = @()
    # Get iDRAC Info
    $BaseUri = "https://$($ip)"
    $NextLinkUrl = $null
    $Type        = "application/json"
    $Headers     =  @{"Accept"="application/json"}
    $FilterMap = @{
        'Name'='DeviceName'
        'Id'='Id'
        'ServiceTag'='DeviceServiceTag'
        'Model'='Model'
        'Type'='Type'
    }
    #'NetworkAddress'='NetworkAddress' # Doesn't work
    $FilterExpr  = $FilterMap[$FilterBy]

    $DeviceData = @()

    # 
    # ValueFromPipeline will attempt to dynamically match the data piped in to a Type. 
    # [String] is a catch-all so we want to process that last as all Types can be converted to a string.
    #
    if ($gid) { # Filter Devices by Group
        $GroupUrl = $BaseUri + "/api/GroupService/Groups"
        $GroupUrl += "(" + $gid + ")/Devices"
        $GroupResp = Invoke-WebRequest -Uri $GroupUrl -UseBasicParsing -Method Get -Headers $Headers -ContentType $Type -Credential $credential
        if ($GroupResp.StatusCode -in 200, 201) {
            $GroupInfo = $GroupResp.Content | ConvertFrom-Json
            $GroupData = $GroupInfo.'value'
            foreach ($Device in $GroupData) {
                $DeviceData += $Device
            }
            if($GroupInfo.'@odata.nextLink')
            {
                $NextLinkUrl = $BaseUri + $GroupInfo.'@odata.nextLink'
            }
            while($NextLinkUrl)
            {
                Write-Verbose $NextLinkUrl
                $NextLinkResponse = Invoke-WebRequest -Uri $NextLinkUrl -UseBasicParsing -Method Get -Headers $Headers -ContentType $Type -Credential $credential
                if($NextLinkResponse.StatusCode -in 200, 201)
                {
                    $NextLinkData = $NextLinkResponse.Content | ConvertFrom-Json
                    foreach ($Device in $NextLinkData.'value') {
                        $DeviceData += $Device
                    }
                    if($NextLinkData.'@odata.nextLink')
                    {
                        $NextLinkUrl = $BaseUri + $NextLinkData.'@odata.nextLink'
                    }
                    else
                    {
                        $NextLinkUrl = $null
                    }
                }
                else
                {
                    Write-Warning "Unable to get nextlink response for $($NextLinkUrl)"
                    $NextLinkUrl = $null
                }
            }
        }
        else {
            Write-Warning "Unable to retrieve devices for group ($($Group.Name))"
        }
    }
    else { # Filter Devices directly
        $DeviceCountUrl = $BaseUri + "/api/DeviceService/Devices"
        $Filter = ""
        if ($Value) { # Filter By 
            if ($FilterBy -eq 'Id' -or $FilterBy -eq 'Type') {
                $Filter += "`$filter=$($FilterExpr) eq $($Value)"
            }
            else {
                $Filter += "`$filter=$($FilterExpr) eq '$($Value)'"
            }
        }
        $DeviceCountUrl = $DeviceCountUrl + "?" + $Filter
        Write-Verbose $DeviceCountUrl
        $DeviceResponse = Invoke-WebRequest -Uri $DeviceCountUrl -UseBasicParsing -Method Get -Headers $Headers -ContentType $Type -Credential $credential
        if ($DeviceResponse.StatusCode -in 200, 201)
        {
            $DeviceCountData = $DeviceResponse.Content | ConvertFrom-Json
            foreach ($Device in $DeviceCountData.'value') {
                $DeviceData += $Device
            }
            if($DeviceCountData.'@odata.nextLink')
            {
                $NextLinkUrl = $BaseUri + $DeviceCountData.'@odata.nextLink' + "&" + $Filter
            }
            while($NextLinkUrl)
            {
                Write-Verbose $NextLinkUrl
                $NextLinkResponse = Invoke-WebRequest -Uri $NextLinkUrl -UseBasicParsing -Method Get -Headers $Headers -ContentType $Type -Credential $credential
                if($NextLinkResponse.StatusCode -in 200, 201)
                {
                    $NextLinkData = $NextLinkResponse.Content | ConvertFrom-Json
                    foreach ($Device in $NextLinkData.'value') {
                        $DeviceData += $Device
                    }
                    if($NextLinkData.'@odata.nextLink')
                    {
                        $NextLinkUrl = $BaseUri + $NextLinkData.'@odata.nextLink' + "&" + $Filter
                    }
                    else
                    {
                        $NextLinkUrl = $null
                    }
                }
                else
                {
                    Write-Warning "Unable to get nextlink response for $($NextLinkUrl)"
                    $NextLinkUrl = $null
                }
            }
        }

        
    }
    return $DeviceData 
}
Catch {
    Write-Error ($_.ErrorDetails)
    Write-Error ($_.Exception | Format-List -Force | Out-String) 
    Write-Error ($_.InvocationInfo | Format-List -Force | Out-String)
}