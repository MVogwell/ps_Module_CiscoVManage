# ps_Module_Cisco-vManage

This PowerShell module can be used to connection to and request data from a Cisco vManage API using a username and password. It is recommended that the user account is local to the vManage system (and not from a third party identity source like Active Directory).


&nbsp; <br>

## Requirements
This module requires PowerShell v5 or higher (including PowerShell 7). PowerShell 7 is preferred for the performance benefits.

&nbsp; <br>

## Installing the module

### Automated
Open PowerShell (5.1 or 6+) and run the following command:

`Install-Module ps_Module_CiscoVManage -Scope CurrentUser`

This will install the module from the PowerShell Gallery


### Manual - For a single user only
Create a folder called 'ps_Module_CiscoVManage in "C:\Users\_UserName_\Documents\WindowsPowerShell\Modules" and copy files from this repository to the folder.

### Manual - All users - PowerShell 5.x
Create a folder called 'ps_Module_CiscoVManage in "C:\Program Files\WindowsPowerShell\Modules" and copy files from this repository to the folder.

&nbsp; <br>


# Functions available from the Module
Below is a list of the functions presented by the module with a description of each:

* Connect-CiscovManageAPI
  * This function creates the web session object and authenticates against vManage to return an authentication token and full header. <br><br>
* Get-vManageApiData
  * This function simplifies the process of requesting data from the vManage API and handles errors. <br><br>
* Request-vEdgeInterfaceReset
  * This function simplifies the process of resetting vEdge device interfaces. <br><br>
* Get-vManageEvents_ByRelativeHours
  * This function pulls event data from vManage with a number of options for filtering the data.

&nbsp; <br>

# Examples

## Example of how to connect, authenticate and request basic data

`Import-Module ps_Module_Cisco-vManage`

`$sBaseUri = "https://vmanage.mydomain.com/" ` \# Make sure the URL ends with a "/" for this example

`$Username = "MyApiUser" `

`$ssPwd = "MyPassword" | ConvertTo-SecureString -AsPlainText -Force `

`$objConnectionData = Connect-CiscovManageAPI -Username $Username -Password $ssPwd -Url $sBaseUri `

\# At this point, if successful, the variable objConnectionData will contain two properties: "Session" which contains the websession data, and "Header" which contains the authentication header including the Authentication Token. Data can now be requested from the API:

\# Using the module:

`$objContent = Get-vManageApiData -objConnectionData $objConnectionData -Url ($sBaseUri + "dataservice/admin/user")`

`$objContent | Format-Table `   \# The data will be displayed in table

\# This will return a PowerShell object containing the results from the API call.

\# Calling the API manually without using Get-vManageApiData

`$objData = Invoke-WebRequest -Uri ($sBaseUri + "dataservice/admin/user") -WebSession $objConnectionData.Session -Headers $objConnectionData.Header -ContentType "application/json" -UseBasicParsing `

`($objData | ConvertFrom-Json).Data | Format-Table `   \# The data will be displayed in table

&nbsp; <br>

## Example to reset a vEdge interface

`Import-Module ps_Module_Cisco-vManage`

`$sBaseUri = "https://vmanage.mydomain.com/" ` \# Make sure the URL ends with a "/" for this example

`$Username = "MyApiUser" `

`$ssPwd = "MyPassword" | ConvertTo-SecureString -AsPlainText -Force `

`$objConnectionData = Connect-CiscovManageAPI -Username $Username -Password $ssPwd -Url $sBaseUri `

`$param_RequestInterfaceReset = @{` <br>
`    BaseUrl = $sBaseUri` <br>
`    objConnectionData = $objConnectionData` <br>
`    SystemIPAddress = "10.0.10.200"` <br>
`    VpnID = "255"` <br>
`    IfName = "ipsec2"` <br>
`}`

`$objReturn = Request-vEdgeInterfaceReset @param_RequestInterfaceReset`

\# If successful $objRtn will contain true otherwise an error will be returned

&nbsp; <br>

## Example to request data from the vManage event log

`Import-Module ps_Module_Cisco-vManage`

`$sBaseUri = "https://vmanage.mydomain.com/" ` \# Make sure the URL ends with a "/" for this example

`$Username = "MyApiUser" `

`$ssPwd = "MyPassword" | ConvertTo-SecureString -AsPlainText -Force `

`$objConnectionData = Connect-CiscovManageAPI -Username $Username -Password $ssPwd -Url $sBaseUri `

\# The example below will return the last 1000 (by default) events in the last hour: <br>
`$param_EventDataCall = @{`
  `BaseUrl = $sBaseUrl` <br>
  `objConnectionData = $objConnectionData` <br>
  `HoursToSearch = "1"` <br>
`}`

`$arrEvent = Get-CiscoVManageEvents_SearchByRelativeHours @param_EventDataCall`  

<br>

\# The example below will return the last 1000 (by default) events in the last hour where the severity is Major and the system IP is 10.1.1.1:<br>
`$param_EventDataCall = @{` <br>
  `BaseUrl = $sBaseUrl` <br>
  `objConnectionData = $objConnectionData` <br>
  `SystemIPAddress = "10.1.1.1"`    \# Change the IP address to the system you want to call  <br>
  `HoursToSearch = "1"`  <br>
  `Severity = "major"`  <br>
`}` <br>

`$arrEvent = Get-CiscoVManageEvents_SearchByRelativeHours @param_EventDataCall`


&nbsp; <br>

# More information

Each function has it's own help which is available by running (in PowerShell) `help <cmdlet-name>` <br>

See https://developer.cisco.com/docs/sdwan/#!sd-wan-vmanage-v20-4 for details of API calls (This URL also contains links for other versions of the API reference documentation)