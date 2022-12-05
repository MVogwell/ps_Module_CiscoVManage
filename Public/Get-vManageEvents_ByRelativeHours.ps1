Function Get-vManageEvents_ByRelativeHours() {
    <#
        .SYNOPSIS
        This function simplifies requesting event data from the vManage API.

        .PARAMETER BaseUrl
        Mandatory. This should be the base URL of the targetted vManage API system

        .PARAMETER objConnectionData
        Mandatory. PSCustomObject. This is the object returned by the function Connect-CiscovManageAPI that contains the Session and Header data.

        .PARAMETER HoursToSearch
        Optional. String. Event log filter. The number of hours of event logs to search. By default this is 24

        .PARAMETER SystemIPAddress
        Optional. String. Event log filter. Specify the IP addresses of systems to monitor

        .PARAMETER Severity
        Optional. String. Event log filter. Specify the event severity to request from the log - examples; critical, major, minor

        .PARAMETER EventName
        Optional. String. Event log filter. Specify the event name (labelled Name in the GUI). Examples; interface-state-change, sla-change

        .PARAMETER Size
        Optional. Integer. Event log filter. Specify the number of events to return. Default is 1000.

        .EXAMPLE
		# Get the last 1000 event log entries for the last 24 hours
		
        Import-Module ps_Module_CiscoVManage

        $u = "MyUserName"
        $p = "MyPassword" | ConvertTo-SecureString -AsPlainText -Force
        $sBaseUrl = "https://My-vManage-URl/" 

        # Connect to vManage API
        $objConnectionData = Connect-CiscovManageAPI -Username $u -Password $p -Url $sBaseUrl

        $arrEvent = Get-CiscoVManageEvents_SearchByRelativeHours -BaseUrl $sBaseUrl -objConnectionData $objConnectionData -Size 10

        .EXAMPLE
		# Get the last 1000 event log entries for the last 1 hour for the system IP address "10.1.1.1"
		
        Import-Module ps_Module_CiscoVManage

        $u = "MyUserName"
        $p = "MyPassword" | ConvertTo-SecureString -AsPlainText -Force
        $sBaseUrl = "https://My-vManage-URl/" 

        # Connect to vManage API
        $objConnectionData = Connect-CiscovManageAPI -Username $u -Password $p -Url $sBaseUrl

        $arrEvent = Get-vManageEvents_ByRelativeHours -BaseUrl $sBaseUrl -objConnectionData $objConnectionData -SystemIPAddress 10.1.1.1 -HoursToSearch 1

        .EXAMPLE
		# Get the last 1000 event log entries for the last 1 hour for the system IP address "10.1.1.1" with the severity type of major
		
        Import-Module ps_Module_CiscoVManage

        $u = "MyUserName"
        $p = "MyPassword" | ConvertTo-SecureString -AsPlainText -Force
        $sBaseUrl = "https://My-vManage-URl/" 

        # Connect to vManage API
        $objConnectionData = Connect-CiscovManageAPI -Username $u -Password $p -Url $sBaseUrl

        $arrEvent = Get-CiscoVManageEvents_SearchByRelativeHours -BaseUrl $sBaseUrl -objConnectionData $objConnectionData -SystemIPAddress 10.1.1.1 -HoursToSearch 1 -Severity "major"

        .NOTES
        Version history:
            0.1 - Development
            1.0 - Initial release
    #>
    
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][PSCustomObject]$objConnectionData,
        [Parameter(Mandatory=$false)][string]$HoursToSearch = "24",
        [Parameter(Mandatory=$false)][string]$SystemIPAddress,
        [Parameter(Mandatory=$false)][string]$Severity,
        [Parameter(Mandatory=$false)][string]$EventName,
        [Parameter(Mandatory=$false)][int]$Size = 1000
    )

    BEGIN {
        # Set the error action preference to stop. Capture the existing preference so it can be reset before leaving the function
        $objErrActionPrefPreChange = $Global:ErrorActionPreference
        $Global:ErrorActionPreference = "Stop"

        # Check the provided BaseUrl is correct
        try {
            if (!($BaseUrl -match "^https")) {
                throw "vManage url must start with https"
            }

            # Check whether the URL ends with / and if it doesn't then add it.
            if ($BaseUrl.Substring($BaseUrl.Length-1) -ne "/") {
                $BaseUrl = $BaseUrl + "/"
            }
        }
        catch {
            # Reset the global error action preference
            $Global:ErrorActionPreference = $objErrActionPrefPreChange

            throw "Failed to parse the url. Please check the url is valid AND starts 'https' and try again"

            # Exit point
        }

        # Load the base query object
        $objBaseQuery = '{"query":{"condition": "AND","rules": [{"value": ["x"],"field": "entry_time","type": "date","operator": "last_n_hours"},{"value": ["x.x.x.x"],"field": "system_ip","type": "string","operator": "in"},{"value": ["xxx"],"field": "severity_level","type": "string", "operator": "in"},{"value": ["xxx"],"field": "eventname","type": "string", "operator": "in"}]},"size": 10000}' | ConvertFrom-Json

        # Set hours (or remove)
        ($objBaseQuery.Query.Rules | Where-Object {$_.field -eq "entry_time"}).value = @($HoursToSearch)

        # Set the number of records to return
        $objBaseQuery.size = $Size

        # Update the system_ip field (or remove it if it wasn't specified)
        if (($PSBoundParameters).Keys -contains "SystemIPAddress") {
            ($objBaseQuery.Query.Rules | Where-Object {$_.field -eq "system_ip"}).value = @($SystemIPAddress)

            Write-Verbose "`t+++ Updated system_ip"
        }
        else {
            # Remove the system_ip rule entry
            $objBaseQuery.query.rules = $objBaseQuery.query.rules | Where-Object {$_.field -ne "system_ip"}

            Write-Verbose "`t+++ Removed system_ip query rule as no data specified"
        }

        # Update the system_ip field (or remove it if it wasn't specified)
        if (($PSBoundParameters).Keys -contains "Severity") {
            ($objBaseQuery.Query.Rules | Where-Object {$_.field -eq "severity_level"}).value = @($Severity)

            Write-Verbose "`t+++ Updated severity_level"
        }
        else {
            # Remove the system_ip rule entry
            $objBaseQuery.query.rules = $objBaseQuery.query.rules | Where-Object {$_.field -ne "severity_level"}

            Write-Verbose "`t+++ Removed severity_level query rule as no data specified"
        }

        # Update the system_ip field (or remove it if it wasn't specified)
        if (($PSBoundParameters).Keys -contains "EventName") {
            ($objBaseQuery.Query.Rules | Where-Object {$_.field -eq "eventname"}).value = @($EventName)

            Write-Verbose "`t+++ Updated eventname"
        }
        else {
            # Remove the system_ip rule entry
            $objBaseQuery.query.rules = $objBaseQuery.query.rules | Where-Object {$_.field -ne "eventname"}

            Write-Verbose "`t+++ Removed eventname query rule as no data specified"
        }

        # Convert the updated query back to json
        $sQuery = $objBaseQuery | ConvertTo-Json -Depth 5 -Compress

        # By default, if there is only one query rule PowerShell will not make the rule section an array which is required by vManage
        # This section converts the rule section to array even if there is only one rule
        try {
            if ($sQuery -notmatch 'query.*rules\":\[') {
                $sQuery = $sQuery.Replace("rules`":{","rules`":[{")
                $sQuery = $sQuery.Replace("},`"size","]},`"size")
            }
        }
        catch {
            # Reset the global error action preference
            $Global:ErrorActionPreference = $objErrActionPrefPreChange

            throw "Failed to validate the query."

            # Exit point
        }
    }
    PROCESS {
        try {
            $sUrl = ($BaseUrl + "dataservice/event?query=" + $sQuery)

            $arrEventData = Get-vManageApiData -objConnectionData $objConnectionData -Url $sUrl | Select-Object *, @{n='entry_datetime';e={(Get-Date 01.01.1970)+([System.TimeSpan]::FromMilliseconds($_.entry_time))}}, @{n='event_data';e={$_.event | ConvertFrom-Json}}  -ExcludeProperty entry_time, event

            Write-Verbose "`t=== No errors discovered"
        }
        catch {
            # Reset the global error action preference
            $Global:ErrorActionPreference = $objErrActionPrefPreChange

            $sThrowMsg = ("Failed to request event data. Error: " + (($Global:Error[0].exception).toString()).replace("`r"," ").replace("`n"," "))
            throw $sThrowMsg
        }
    }
    END {
        # Reset the global error action preference
        $Global:ErrorActionPreference = $objErrActionPrefPreChange

        return $arrEventData
    }
}