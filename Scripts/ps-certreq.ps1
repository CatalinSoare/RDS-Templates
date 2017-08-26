<#
script to generate a test self-signed certificate for use with testing rds deployments

to enable script execution, you may need to Set-ExecutionPolicy Bypass -Force

    Copyright 2017 Microsoft Corporation

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

# From <https://blog.kloud.com.au/2013/07/30/ssl-san-certificate-request-and-import-from-powershell/> 
#    New-CertificateRequest -subject mail1.showcase.kloud.com.au
#    New-CertificateRequest -subject *.contoso.com
#    New-CertificateRequest -subject remote.contoso.com -sans @("broker.contoso.com","broker.contoso.lab")

#>

param(
    [string]$subject = "", #"*.contoso.com",
    [array]$sans = @()
)

function New-CertificateRequest ()
{
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Please enter the subject beginning with CN=")]
        [ValidatePattern("CN=")]
        [string]$subject,
        [Parameter(Mandatory = $false, HelpMessage = "Please enter the SAN domains as a comma separated list")]
        [array]$SANs,
        [Parameter(Mandatory = $false, HelpMessage = "Please enter the Online Certificate Authority")]
        [string]$OnlineCA,
        [Parameter(Mandatory = $false, HelpMessage = "Please enter the Online Certificate Authority")]
        [string]$CATemplate = "WebServer"
    )

    ### Preparation
    $subjectDomain = $subject.split(',')[0].split('=')[1]
    if ($subjectDomain -match "\*.")
    {
        $subjectDomain = $subjectDomain -replace "\*", "star"
    }

    $CertificateINI = "$($env:TEMP)\$($subjectDomain).ini"
    $CertificateREQ = "$($env:TEMP)\$($subjectDomain).req"
    $CertificateRSP = "$($env:TEMP)\$($subjectDomain).rsp"
    $CertificateCER = "$($env:TEMP)\$($subjectDomain).cer"

    ### INI file generation
    new-item -type file $CertificateINI -force
    add-content $CertificateINI '[Version]'
    add-content $CertificateINI 'Signature="$Windows NT$"'
    add-content $CertificateINI ''
    add-content $CertificateINI '[NewRequest]'
    add-content $CertificateINI ('Subject="' + $subject + '"')
    add-content $CertificateINI 'Exportable=TRUE'
    add-content $CertificateINI 'KeyLength=2048'
    add-content $CertificateINI 'KeySpec=1'
    add-content $CertificateINI 'KeyUsage=0x30'
    add-content $CertificateINI 'MachineKeySet=True'
    add-content $CertificateINI 'ProviderName="Microsoft RSA SChannel Cryptographic Provider"'
    add-content $CertificateINI 'ProviderType=12'
    add-content $CertificateINI 'SMIME=FALSE'

    ### Date Ranges
    add-content $CertificateINI ('NotBefore="' + (get-date).ToShortDateString() + '"')
    ### Expire in 5 years
    add-content $CertificateINI ('NotAfter="' + (get-date).AddYears(5).ToShortDateString() + '"')

    add-content $CertificateINI 'RequestType=Cert'
    add-content $CertificateINI 'HashAlgorithm=sha256'
    add-content $CertificateINI '[EnhancedKeyUsageExtension]'
    add-content $CertificateINI 'OID=1.3.6.1.5.5.7.3.1 ; this is for Server Authentication / Token Signing'

    if ($SANs) 
    {
        add-content $CertificateINI '[Extensions]'
        add-content $CertificateINI '2.5.29.17 = "{text}"'

        foreach ($SAN in $SANs) 
        {
            add-content $CertificateINI ('_continue_ = "dns=' + $SAN + '&"')
        }
    }

    ### Certificate request generation
    if (test-path $CertificateREQ) {del $CertificateREQ}
    certreq -new $CertificateINI $CertificateREQ

    ### Online certificate request and import
    if ($OnlineCA)
    {
        if (test-path $CertificateCER) {del $CertificateCER}
        if (test-path $CertificateRSP) {del $CertificateRSP}
        certreq -submit -attrib "CertificateTemplate:$CATemplate" -config $OnlineCA $CertificateREQ $CertificateCER

        certreq -accept $CertificateCER
    }
}

New-CertificateRequest -subject "CN=$($subject)" -SANs $sans

