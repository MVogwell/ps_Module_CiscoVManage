#Requires -Version 5

Function Get-vManageApiData {
    <#
        .SYNOPSIS
        This function simplifies requesting GET data from the vManage API.

        .PARAMETER objConnectionData
        Mandatory. This should be the object returned by the function Connect-CiscovManageAPI

        .PARAMETER Url
        Mandatory. This should be the URL of a vManage API GET call (see example)

        .EXAMPLE
        # This assumes you have already executed Connect-CiscovManageAPI - see function documentation on how to use this.
        # This example calls the API to return transport connection details for a specific vEdge system IP address.

        $param_GetData = @{
            objConnectionData = $objConnectionData
            Url = ($sBaseUri + "dataservice/device/transport/connection?deviceId=`ENTER-A-DEVICE-SYSTEM-IP-ADDRESS-HERE`")
        }

        $objContent = Get-vManageApiData @param_GetData

        # If there have been no errors, $objContent will contain the data

        .NOTES
        Version history:
            0.1 - Development
            1.0 - Initial release
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][PSCustomObject]$objConnectionData,
        [Parameter(Mandatory=$true)][string]$Url
    )

    BEGIN {
        Write-Verbose "*** Requesting data from API url $Url"

        # Set the error action preference to stop. Capture the existing preference so it can be reset before leaving the function
        $objErrActionPrefPreChange = $Global:ErrorActionPreference
        $Global:ErrorActionPreference = "Stop"
    }
    PROCESS {
        try {
            $objData = Invoke-WebRequest -Uri $Url -WebSession $objConnectionData.Session -Headers $objConnectionData.Header -ContentType "application/json" -UseBasicParsing

            if ($null -eq $objData) {
                throw "No data has been returned from the request"
            }
            else {
                Write-Verbose "`t+++ Call to the API Url was successful"
            }
        }
        catch {
            # Reset the global error action preference
            $Global:ErrorActionPreference = $objErrActionPrefPreChange

            $sThrowMsg = ("Failed to get data from vManage API. Error: " + ("Error: " + (($Global:Error[0].Exception.Message).toString()).replace("`r"," ").replace("`n"," ")))
            throw $sThrowMsg
        }
    }
    END {
        try {
            # Extract the body content from the returned data
            $objContent = ($objData | ConvertFrom-Json).Data

            Write-Verbose "`t+++ Successfully extracted content data"

            if ($null -eq $objContent) {
                Write-Verbose "`t--- WARNING: No data has been returned by the API"
            }
        }
        catch {
            # Reset the global error action preference
            $Global:ErrorActionPreference = $objErrActionPrefPreChange

            $sThrowMsg = ("Failed to get data from vManage API. Error: " + ("Error: " + (($Global:Error[0].Exception.Message).toString()).replace("`r"," ").replace("`n"," ")))
            throw $sThrowMsg

            # Exit point
        }

        # Reset the global error action preference
        $Global:ErrorActionPreference = $objErrActionPrefPreChange

        # Return the data
        return $objContent
    }
}