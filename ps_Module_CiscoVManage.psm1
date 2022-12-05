# Standard psm1 loader - Version 0.1 - November 2021 - MVogwell

[CmdletBinding()]
param()

try {
	$arrPublic  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
	$arrPrivate = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )
}
catch {
	Write-Error -Message "Failed to enumerate function public or private functions"
}

# Loop through each ps1 file discovered below the module function folders public and private
Foreach($objImport in @($arrPublic + $arrPrivate))	{
	try {
		# dot source load
		Write-Verbose "Loading $($objImport.FullName)"
		. $objImport.FullName
	}
	catch {
		Write-Error -Message "Failed to import function $($import.fullname)"
	}
}

# Export the public functions available to the module
$arrPublic.Basename | Foreach-Object { Export-ModuleMember -Function $_ }