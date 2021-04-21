# AddLocalAdminComputers.ps1
# PURPOSE
#   This will take an entered UPN and add computers to their allowed ADM logon list
#
# Author: Stephen Kleine [kleines2015@gmail.com]
# Version 01.00 20210416
# Revision  
#	1.00 MVP

# KNOWN BUGS
#   

#Import needed modules
import-module ActiveDirectory -ea stop -wa STOP

#Create Global Variables
#$AdminAccountDN = "ou=Administrators,dc=cleanharbors,dc=com"
$AdminAccountPrefix = "ADM_"

#First, we need a valid name
Do {
    $UserAccount = read-host "What is the user principal name needing local admin permissions (or blank line to exit)?"
    $UserAccountValidFlag = $False
    if (!$UserAccount) {exit(0)} #Blank line exits
    try {
        $null = [mailaddress]$UserAccount
        $UserAccountValidFlag = $true
    }
	catch {
		Write-host " $UserAccount is not a valid UPN. "
		$UserAccountValidFlag = $False
		Continue
	}
    $null = $UserAccountDetails
    $UserAccountDetails = get-aduser -filter {UserPrincipalName -eq $UserAccount} -Properties AccountExpirationDate, AccountNotDelegated, AllowReversiblePasswordEncryption, Enabled, SmartcardLogonRequired, TrustedForDelegation, DisplayName, GivenName, Initials, OtherName, Surname, Description, City, Country, POBox, PostalCode, State, StreetAddress, Company, Department, Division, EmployeeID, EmployeeNumber, Manager, Office, Organization, Title, Fax, HomePhone, MobilePhone, OfficePhone, HomePage, ProfilePath, Certificates, LogonWorkstations -ea stop
    #$UserAccountDistinguishedName = $UserAccountDetails.DistinguishedName
    If ($null -eq $UserAccountDetails) {
        Write-host " $UserAccount as not found in Active Directory.  "
        $UserAccountValidFlag = $False
        Continue
    }
    else {
        $UserAccountSamAccountName = $UserAccountDetails.SamAccountName 
        #$UserUPNDomain = '@'+$UserAccountDetails.UserPrincipalName.split("@")[1]
    }
    #Does the admin account already exist?
    try {
        $AdminUserAccount = "$AdminAccountPrefix"+"$UserAccountSamAccountName"
        Get-ADUser -Identity $AdminUserAccount -ea stop | out-null #error is if it's NOT found
        $UserAccountValidFlag = $True
    }
    catch {
        Write-host " $AdminUserAccount does not exist and needs to be created first. "
        $UserAccountValidFlag = $False
        Continue
    }
}
Until ($UserAccountValidFlag -eq $True)

#Now to add the worksations - this will eventually be broken out into its own script for post-creation additions
do {
    [String]$ComputerAccount = read-host "To which computer does $AdminUserAccount need permissions or leave blank to exit"
    if (!$ComputerAccount) {exit (0)} 
    $ComputerAccountValidFlag = $False
        
    try {
        Get-ADComputer -Identity $ComputerAccount -properties name,samAccountName,dnsHostName -ea stop | out-null
        $ComputerAccountValidFlag = $True
    }
    catch {
        Write-host " $ComputerAccount was not found in Active Directory. "
        $ComputerAccountValidFlag = $False
        continue
    }
    try {
        $ExistingLogonWorkstations = Get-ADuser -Identity $AdminUserAccount -Properties logonWorkstations
        if ($ExistingLogonWorkstations) {$NewWorksationlist +=  ",$ComputerAccount"}
        else {$NewWorksationlist = $ComputerAccount}
        Set-ADUser -Identity $AdminUserAccount -replace @{userWorkstations=$NewWorksationlist} -ea stop | out-null
        $ComputerAccountValidFlag = $False
    }
    catch {
        Write-host " $ComputerAccount was not written to $AdminUserAccount for unknown reasons. "
        $ComputerAccountValidFlag = $False
        continue
    }
}
Until ($ComputerAccountValidFlag -eq $true)