#Requires -Version 5

Function Connect-CiscovManageAPI {
    <#
        .SYNOPSIS
        This function will create the session and AuthToken cookie required for communication with Cisco vManage API. The function will return an object containing the following properties:

        Session - Microsoft.PowerShell.Commands.WebRequestSession - object containing the websession data
        Header - System.Collections.Generic.Dictionary[[String],[String]] - object containing the request header

        .PARAMETER Username
        Mandatory. This should contain the username of the user account used to access the vManage API. The permission given to the user account will depend on what actions are required against the API.

        .PARAMETER Password
        Mandatory. This should contain the password of the user account used to access the vManage API - this must be passed as a SecureString type!

        .PARAMETER Url
        Mandatory. This should contain the base Url address for the vManage AP, e.g. https://MyVManageServer.domain.com/

        .PARAMETER IgnoreCertificateErrors
        Optional. Use this switch is the vManage does not have a trusted / valid certificate attached. Note: This parameter is untested!

        .EXAMPLE
        $ssPwd = "MyPassword" | ConvertTo-SecureString -AsPlainText -Force
        $objConnectionData = Connect-CiscovManageAPI -Username "myuser" -Password $ssPwd -Url "https://vManage.mydomain.com/"

        # This returns an object containing two properties; $objConnectionData.Session (containing the session data) and $objConnectionData.Header containing the header data including authentication data

        .NOTES
        Version history:
            0.1 - Development
            1.0 - Initial release
            1.1 - Release - removing content-type from the header object (objReturnHeader) as it appears to duplicate when calling for an interface reset
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$Username,
        [Parameter(Mandatory=$true)][securestring]$Password,
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$false)][switch]$IgnoreCertificateErrors
    )

    BEGIN {
        Write-Verbose "Connect-CiscovManageAPI - attempting to connect to Cisco vManage API"

        # Set the error action preference to stop. Capture the existing preference so it can be reset before leaving the function
        $objErrActionPrefPreChange = $Global:ErrorActionPreference
        $Global:ErrorActionPreference = "Stop"

        # This will be the return object
        $objConnectionData = [PsCustomObject] @{
            Session = $null
            Header = $null
        }

        # Check that the Url provided starts with https. Append a "/" character to the end of the URL if it doesn't have one
        try {
            if (!($Url -match "^https")) {
                throw "vManage url must start with https"
            }

            # Check whether the URL ends with / and if it doesn't then add it.
            if ($Url.Substring($Url.Length-1) -ne "/") {
                $Url = $Url + "/"
            }

            # Set the variable sBaseUri which will be used to connect to the API
            $sBaseUri = $Url
        }
        catch {
            # Reset the global error action preference
            $Global:ErrorActionPreference = $objErrActionPrefPreChange

            throw "Failed to parse the url. Please check the url is valid AND starts 'https' and try again"

            # Exit point
        }

        # Check if the startup param 'IgnoreCertificateErrors' has been specified. If yes then create the type to ignore certificate errors
        # Note: the certCallback declaration has to appear without space at the start of the line.
        if ($IgnoreCertificateErrors -eq $true) {
            try {
                if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)  {
$certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback +=
                    delegate
                    (
                        Object obj,
                        X509Certificate certificate,
                        X509Chain chain,
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
                    Add-Type $certCallback
                }

                [ServerCertificateValidationCallback]::Ignore()

                Write-Verbose "*** Ignoring TLS errors - success"
            }
            catch {
                # Failed to ignore certificate errors. Return an error from the function

                # Reset the global error action preference
                $Global:ErrorActionPreference = $objErrActionPrefPreChange

                $sThrowMsg = ("Failed to ignore certificate errors. Error: " + ("Error: " + (($Global:Error[0].Exception.Message).toString()).replace("`r"," ").replace("`n"," ")))
                throw $sThrowMsg

                # Exit point
            }
        } # End of: Check if the startup param 'IgnoreCertificateErrors' has been specified.

        # Set PowerShell 5 to use TLS1.2
        if ($PSVersionTable.PSVersion.Major -eq 5) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }

        # Extract the password from the secure string
        try {
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
            $sUnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

            if ([string]::IsNullOrEmpty($sUnsecurePassword)) {
                throw "Password value empty after extracting from SecureString"
            }
        }
        catch {
            # Reset the global error action preference
            $Global:ErrorActionPreference = $objErrActionPrefPreChange

            $sThrowMsg = ("Failed to extract the password from the SecureString. Error: " + ("Error: " + (($Global:Error[0].Exception.Message).toString()).replace("`r"," ").replace("`n"," ")))
            throw $sThrowMsg

            # Exit point
        }

        # Create the session object and address for session auth
        $objSession = new-object Microsoft.PowerShell.Commands.WebRequestSession
        $sAuthBody = "j_username=" + $Username + "&j_password=" + $sUnsecurePassword

        # Create the auth header required to create the token
        $Authorization = [Convert]::ToBase64String(
            [Text.Encoding]::ASCII.GetBytes(
                (
                    "{0}:{1}" -f ($Username , $sUnsecurePassword)
                )
            )
        )

        # Clear the cleartext variable
        $sUnsecurePassword = $null
    }
    PROCESS {
        #@# Request the session cookie
        try {
            Write-Verbose "*** Requesting SessionId from vManage"

            $objSessionResponse = Invoke-WebRequest ($sBaseUri + "j_security_check?" + $sAuthBody) -SessionVariable objSession -UseBasicParsing -Method Post

            # If the HTTP status code returned is not 200 then throw an error including the returned data from vManage
            if ($objSessionResponse.StatusCode -ne 200) {
                $sThrowMsg =  "Failed to obtain session with vManage (code returned was not 200): " + (($objSessionResponse.Content).toString()).replace("`r"," ").replace("`n"," ")
                throw $sThrowMsg
            }

            Write-Verbose "`t+++ Success `n"
        }
        catch {
            # Reset the global error action preference
            $Global:ErrorActionPreference = $objErrActionPrefPreChange

            $sThrowMsg = ("Failed to extract SessionId from vManage. Unable to continue. Error: " + (($Global:Error[0].exception).toString()).replace("`r"," ").replace("`n"," "))
            throw $sThrowMsg

            # Exit point
        }

        # Obtain the auth token and extract the cookie
        try {
            Write-Verbose "*** Requesting auth token from vManage"

            $objAuthHeader = @{"authorization" = "Basic "+$Authorization}
            $objToken = Invoke-RestMethod -Uri ($sBaseUri + "dataservice/client/token") -ContentType "application/json" -WebSession $objSession -Method Get -Headers $objAuthHeader
            $objCookie = ($objSession.Cookies.GetCookies(($sBaseUri + "dataservice/client/token"))).Value

            # Create the header object with the auth token, authentication and session data
            $objReturnHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $objReturnHeader.Add("X-XSRF-TOKEN", $objToken)
            $objReturnHeader.Add("Authorization", "Basic "+$Authorization)
            $objReturnHeader.Add("Cookie", "JSESSIONID="+$objCookie)

            Write-Verbose "`t+++ Success `n"
        }
        catch {
            # Reset the global error action preference
            $Global:ErrorActionPreference = $objErrActionPrefPreChange

            $sThrowMsg = ("Failed to extract Auth Token from vManage. Unable to continue. Error: " + (($Global:Error[0].exception).toString()).replace("`r"," ").replace("`n"," "))
            throw $sThrowMsg

            # Exit point
        }
    }
    END {
        # Update the return object
        $objConnectionData.Session = $objSession
        $objConnectionData.Header = $objReturnHeader

        # Tidy up
        $Authorization = $null
        $sAuthBody = $null

        # Reset the global error action preference
        $Global:ErrorActionPreference = $objErrActionPrefPreChange

        # Return the object containing the session and header objects
        return $objConnectionData
    }
}