# ProcessLocalAdminExceptions.ps1
# PURPOSE
#   This is a logon script that will analyze a user's logon name against the computer's name to determine is
#       if the user shpould be added to the local administrator's group on the machine by polling the logon 
#       user's account for the SeeAlso attribute for this machine's DN.
# 	This will strip ALL other members of the local admins group from the machine.
#
# Author: Stephen Kleine [kleines2015@gmail.com]
# Version 01.01 20210416
# Revision  
#	01.01 - strip ALL other users from administrators immedately
#	01.00 MVP
# KNOWN BUGS
#

#Import needed modules
import-module ActiveDirectory -ea stop -wa STOP
#Set global variables
$AllAllowedLocalAdministrators = `
	"$env:COMPUTERNAME\Administrator", `
	"CLEANHARBORS\CLHB Helpdesk", `
	"CLEANHARBORS\ClientMachines_LocalAdmin", `
	"CLEANHARBORS\Domain Admins", `
	"CLEANHARBORS\Hardware Support"
#Check if this workstation 
$LogonWorkstationAttributes = Get-aduser -Identity $Env:USERNAME -Properties userWorkstations, UserPrincipalName,SeeAlso -ea stop -wa stop
Foreach ($FoundSeeAlso in $LogonWorkstationAttributes.SeeAlso){
    $AdminUser = Get-aduser -identity $FoundSeeAlso -properties SamAccountName,userWorkstations,UserPrincipalName
    if ($env:COMPUTERNAME -eq $AdminUser.userWorkstations) {
        $AllAllowedLocalAdministrators += $AdminUser.UserPrincipalName
    }
}
#Add All required administrators
$AllAllowedLocalAdministrators | Foreach-Object {Add-LocalGroupMember -Name "Administrators" -Member $_} 
#Now strip everyone not on the list
$AllLocalAdmins = Get-LocalGroupmember -Group "Administrators"
Foreach ($LocalAdminAccount in $AllLocalAdmins.name) {
	$RemoveFromList = $true
	Foreach ($AllowedAdmin in $AllAllowedLocalAdministrators) {
		if ($LocalAdminAccount -eq $AllowedAdmin) {
			$RemoveFromList = $False
		}
	}
	if ($RemoveFromList) {
		Remove-LocalGroupMember -Group "Administrators" -member $LocalAdminAccount
	}
}
