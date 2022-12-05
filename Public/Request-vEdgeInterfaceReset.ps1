Function Request-vEdgeInterfaceReset {
    <#
    .SYNOPSIS
    This function will request vManage reset the interface for a given System IP address

    It will return boolean $true if it was successful or will return an error is one is encountered

    .PARAMETER BaseUrl
    Mandatory. String. This is the root of the URL to connect to vManage with (the same one used by the function Connect-CiscovManageAPI)

    .PARAMETER objConnectionData
    Mandatory. PSCustomObject. This is the object returned by the function Connect-CiscovManageAPI that contains the Session and Header data.

    .PARAMETER SystemIPAddress
    Mandatory. String. This is the System IP Address of the vEdge that should be targetted by the request.

    .PARAMETER VpnID
    Mandatory. String. This is the VPN ID for the interface you wish to reset.

    .PARAMETER IfName
    Mandatory. String. This is the Interface Name for the interface you wish to reset.

    .EXAMPLE
    # This would request an interface reset to https://vmanage.mydomain.com/ for device System IP 192.168.0.1 on VpnId 255 and Interface name "ipsec1"

    $param_RequestInterfaceReset = @{
        BaseUrl = "https://vmanage.mydomain.com/"
        objConnectionData = $objConnectionData
        SystemIPAddress = "192.168.0.1"
        VpnID = "255"
        IfName = "ipsec1"
    }

    try {
        $bResult = Request-vEdgeInterfaceReset @param_RequestInterfaceReset

        Write-Output "Success"
    }
    catch {
        Write-Output "$($Error[0])"
    }

    .NOTES
    Version history:
        0.1 - Development
        1.0 - Release
        1.1 - 20220413 - Added -SkipHeaderValidation to invoke-webrequest due to .net core bug handling Content-Type header
    #>

    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][PSCustomObject]$objConnectionData,
        [Parameter(Mandatory=$true)][string]$SystemIPAddress,
        [Parameter(Mandatory=$true)][string]$VpnId,
        [Parameter(Mandatory=$true)][string]$IfName
    )

    BEGIN {
        Write-Verbose "Request-vEdgeInterfaceReset - request an interface reset for device $SystemIPAddress / $VpnId / $IfName from $BaseUrl"

        # Set the error action preference to stop. Capture the existing preference so it can be reset before leaving the function
        $objErrActionPrefPreChange = $Global:ErrorActionPreference
        $Global:ErrorActionPreference = "Stop"

        # Check that the Url provided starts with https. Append a "/" character to the end of the URL if it doesn't have one
        try {
            if (!($BaseUrl -match "^https")) {
                throw "vManage url must start with https"
            }

            # Check whether the URL ends with / and if it doesn't then add it.
            if ($BaseUrl.Substring($BaseUrl.Length-1) -ne "/") {
                $BaseUrl = $BaseUrl + "/"
            }

            # Set the variable sBaseUrl which will be used to connect to the API
            $sRequestUrl = $BaseUrl + "dataservice/device/tools/reset/interface/" + $SystemIPAddress
        }
        catch {
            # Reset the global error action preference
            $Global:ErrorActionPreference = $objErrActionPrefPreChange

            throw "Failed to parse the url. Please check the url is valid AND starts 'https' and try again"

            # Exit point
        }

        # Create the string containing the interface details
        $sIfaceResetBody = [PsCustomObject] @{
            vpnId = $VpnId
            ifname = $IfName
        } | ConvertTo-Json

        # Note: '' has been removed in v1.1 because it is already declared in the header. This causing
        # Invoke-WebRequest with the below params to fail.
        $param_ResetIface = @{
            Uri = $sRequestUrl
            WebSession = $objConnectionData.Session
            Headers = $objConnectionData.Header
            ContentType = "application/json"
            Body = $sIfaceResetBody
            Method = "Post"
        }
    }
    PROCESS {
        try {
            Write-Verbose "`t=== Sending request to $sRequestUrl"

            $objRtn = Invoke-WebRequest @param_ResetIface -UseBasicParsing -SkipHeaderValidation

            if ($null -eq $objRtn) {
                throw "Null returned - unspecified error"
            }
            elseif ($objRtn.StatusCode -ne 200) {
                $sThrowMsg =  "Status code returned: " + $objRtn.StatusCode + ". Full error message: " + ($objRtn.Content).replace("`r"," ").replace("`n","").replace(" ","")
                throw $sThrowMsg
            }
            elseif ($objRtn.Content -match "errorMessageBox") {
                $sThrowMsg =  "Request accepted but failed to execute. Full error message: " + ($objRtn.Content).replace("`r"," ").replace("`n","").replace(" ","")
                throw $sThrowMsg
            }
        }
        catch {
            # Reset the global error action preference
            $Global:ErrorActionPreference = $objErrActionPrefPreChange

            $sThrowMsg = ("Failed to request interface reset. Error: " + (($Global:Error[0].exception).toString()).replace("`r"," ").replace("`n"," "))
            throw $sThrowMsg

            # Exit point
        }
    }
    END {
        # Reset the global error action preference
        $Global:ErrorActionPreference = $objErrActionPrefPreChange

        return $true
    }
}