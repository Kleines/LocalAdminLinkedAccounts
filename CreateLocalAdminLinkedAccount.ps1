# CreateLocalAdminLinkedAccount.ps1
# PURPOSE
#   This will take an entered UPN, create a new account for local administartive purposes, and
#       allow the user to popuate the machines on which this account is valid.
#   The admin account DN is added to the original account's SeeAlso property, and vice-versus.
#
# Author: Stephen Kleine [kleines2015@gmail.com]
# Version 01.00 20210414
# Revision  
#	1.00 MVP

# KNOWN BUGS
#   

#Import needed modules
import-module ActiveDirectory -ea stop -wa STOP

#Create Global Variables
$AdminAccountDN = "ou=YOUROU,dc=YOURDOMAIN,dc=YOURTLD"
$AdminAccountPrefix = "ADM_"

#First, we need a valid name
Do {
    $UserAccount = read-host "What is the user principal name needing local admin permissions?"
    $UserAccountValidFlag = $False
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
    $UserAccountDistinguishedName = $UserAccountDetails.DistinguishedName
    If ($null -eq $UserAccountDetails) {
        Write-host " $UserAccount as not found in Active Directory.  "
        $UserAccountValidFlag = $False
        Continue
    }
    else {
        $UserAccountSamAccountName = $UserAccountDetails.SamAccountName 
        $UserUPNDomain = '@'+$UserAccountDetails.UserPrincipalName.split("@")[1]
    }
    #Does the admin account already exist?
    try {
        $AdminUserAccount = "$AdminAccountPrefix"+"$UserAccountSamAccountName"
        Get-ADUser -Identity $AdminUserAccount -ea stop | out-null
        Write-host " $AdminUserAccount already exists in Active Directory. "
        $UserAccountValidFlag = $False
        Continue
        
    }
    catch {
        #Creates user account copying relevant data from original and sets SeeAlso property
        $AdminUserAccountUpn = "$AdminUserAccount$UserUPNDomain"
        New-ADUser -instance $UserAccountDetails -Name $AdminUserAccount -Enabled $False -Path $AdminAccountDN -Description "Local administrator account for $UserAccountSamAccountName" -UserPrincipalName $AdminUserAccountUpn
        $AdminUserAccountDetails = get-aduser -identity $AdminUserAccount 
        Set-adobject -Identity $UserAccountDistinguishedName -replace @{SeeAlso=$AdminUserAccountDetails.DistinguishedName}
        # Do other things
        $UserAccountValidFlag = $True
    }
    try{
        #$AdminUserAccountDistinguishedName = get-aduser -identity $AdminUserAccount 
        Set-adobject -Identity $AdminUserAccountDetails.DistinguishedName -replace @{SeeAlso=$UseraccountDetails.DistinguishedName} -ea stop
        Write-host " $AdminUserAccount was created successfully. "
        $UserAccountValidFlag = $True
        # Do other things
    }
    catch {
        Write-host " $AdminUserAccount was not created for unknown reasons. "
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
        #set-aduser -Identity $AdminUserAccount -logonworkstations ("$_.logonworkstations + ',' + "$ComputerAccount) -ea stop | out-null 
        $ComputerAccountValidFlag = $False
    }
    catch {
        Write-host " $ComputerAccount was not written to $AdminUserAccount for unknown reasons. "
        $ComputerAccountValidFlag = $False
        continue
    }
}
Until ($ComputerAccountValidFlag -eq $true)
