#######
## This script will create a user-assigned Windows 365 group and apply the Windows 365 license to the group
## This script will also create a dynamic group for all Windows 365 devices

##Create AAD Group
write-host "Creating Azure AD Groups"
##Create W365 Groups for W365 users, manually assigned
write-host "Creating W365 Users Group"
$w365users = New-MGGroup -DisplayName "W365-Users" -Description "Windows 365 Users" -MailEnabled:$False -MailNickName "W365Users" -SecurityEnabled -IsAssignableToRole
write-host "W365 Users Group Created"

##Create Devices Group with dynamic membership based on Cloud PC model type
write-host "Creating W365 Devices Group - Dynamically Assigned"
$w365devices = New-MGGroup -DisplayName "W365 Devices" -Description "Dynamic group for all Windows 365 devices" -MailEnabled:$False -MailNickName "w365devices" -SecurityEnabled -GroupTypes "DynamicMembership" -MembershipRule "(device.deviceModel -startsWith ""Cloud"")" -MembershipRuleProcessingState "On"
write-host "W365 Devices Group Created"

## Get the Group ID for our Win365 devices
$devicegroupid = $w365devices.id

##Assign Licenses to Group
write-host "Assigning Licenses to Group"
$groupid = $w365users.Id
$devicegroupid = $w365devices.Id

##Get Assigned SKUs
##Get All skus in the tenant
write-host "Getting SKUs"
$sku2 = ((Invoke-MgGraphRequest -uri "https://graph.microsoft.com/v1.0/subscribedSkus" -method get -OutputType PSObject).value)
##Loop through looking for W365 SKUs (currently start with either CPC or Windows_365
foreach ($sku in $sku2) {
    $part = $sku.skuPartNumber
    if (($part -like "*CPC*") -or ($part -like "*Windows_365*")) {
        $skuid = $sku.skuId
        break;
    }
}
write-host "SKU Found - $skuid"
##Assign the license to the group
write-host "Assigning License to Group - W365 Users"
$uri = "https://graph.microsoft.com/v1.0/groups/$groupid/assignLicense"
$body = @"
{
	"addLicenses": [{
		"disabledPlans": [],
		"skuId": "$skuid"
	}],
	"removeLicenses": []
}
"@
Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body -ContentType "application/json"
write-host "License Assigned to Group W365 Users"



