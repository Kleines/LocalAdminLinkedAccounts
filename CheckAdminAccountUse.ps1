# CheckAdminAccountUse.ps1
# PURPOSE
#   This cript automatically polls all active ADM accounts and disables those without a logon witin ninety (90) days
#
# Author: Stephen Kleine [kleines2015@gmail.com]
# Version 01.00 20210421
# Revision  
#	1.00 MVP

# KNOWN BUGS
#   

#Import needed modules
import-module ActiveDirectory -ea stop -wa STOP

$AllAdminAccountsFound = get-aduser -f {(SamAccountName -like "ADM_*") -and (enabled -eq $True)} -Properties SamAccountName, LastLogon, lastlogondate | Where-Object {$_.lastlogondate -le (get-date).AddDays(-90)}
Foreach ($AdminUser in $AllAdminAccountsFound) {
    Try {
        Set-aduser $AdminUser.samAccountName -enabled:$False -ea stop
        Write-host "Disabled $AdminUser.SamAccountName . "
    }
    Catch {
        Write-host "Tried to disabled $AdminUser.SamAccountName but failed. "
    }
}