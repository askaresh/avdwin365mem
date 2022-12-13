#### This script enables all default reporting rules for Win365 and emails the address below

##Alerts Email
$email = "test@test.com"


##Enable Alerting

$uri = "https://graph.microsoft.com/beta/deviceManagement/monitoring/alertRules"
$rules = (Invoke-MgGraphRequest -Uri $uri -Method GET -OutputType PSObject).value


##Azure Network Failure

$networkrule = $rules | Where-Object DisplayName -eq "Azure network connection failure"
$networkruleid = $networkrule.id
$networkjson = @"
{
    "id": "$networkruleid",
    "displayName": "Azure network connection failure",
    "severity": "warning",
    "isSystemRule": true,
    "description": "Azure network connection checks have failed and is potentially blocking the provisioning of new Cloud PCs",
    "enabled": true,
    "alertRuleTemplate": "cloudPcOnPremiseNetworkConnectionCheckScenario",
    "threshold": {
        "aggregation": "affectedCloudPcCount",
        "operator": "greaterOrEqual",
        "target": 1
    },
    "notificationChannels": [
        {
            "notificationChannelType": "portal",
            "receivers": [
                ""
            ]
        },
        {
            "notificationChannelType": "email",
            "notificationReceivers": [
                {
                    "contactInformation": "$email",
                    "locale": "en-us"
                }
            ]
        }
    ]
}

"@

$patchuri = "https://graph.microsoft.com/beta/deviceManagement/monitoring/alertRules/$networkruleid"
Invoke-MgGraphRequest -Uri $patchuri -Method PATCH -Body $networkjson -ContentType "application/json"


##Custom Image Upload Failure

$imagerule = $rules | Where-Object DisplayName -eq "Upload failure for custom images"
$imageruleid = $imagerule.id
$imagejson = @"
{
    "id": "$imageruleid",
    "displayName": "Upload failure for custom images",
    "severity": "warning",
    "isSystemRule": true,
    "description": "Custom image uploads have failed and can delay the provisioning of new Cloud PCs.",
    "enabled": true,
    "alertRuleTemplate": "cloudPcImageUploadScenario",
    "threshold": {
        "aggregation": "count",
        "operator": "greaterOrEqual",
        "target": 1
    },
    "notificationChannels": [
        {
            "notificationChannelType": "portal",
            "receivers": [
                ""
            ]
        },
        {
            "notificationChannelType": "email",
            "notificationReceivers": [
                {
                    "contactInformation": "$email",
                    "locale": "en-us"
                }
            ]
        }
    ]
}
"@

$patchuri = "https://graph.microsoft.com/beta/deviceManagement/monitoring/alertRules/$imageruleid"
Invoke-MgGraphRequest -Uri $patchuri -Method PATCH -Body $imagejson -ContentType "application/json"

##Provisioning Failure

$provrule = $rules | Where-Object DisplayName -eq "Provisioning failure impacting Cloud PCs"
$provruleid = $provrule.id
$provjson = @"
{
    "id": "$provruleid",
    "displayName": "Provisioning failure impacting Cloud PCs",
    "severity": "warning",
    "isSystemRule": true,
    "description": "Provisioning has failed and is delaying end users from connecting to their Cloud PCs.  ",
    "enabled": true,
    "alertRuleTemplate": "cloudPcProvisionScenario",
    "threshold": {
        "aggregation": "affectedCloudPcCount",
        "operator": "greaterOrEqual",
        "target": 1
    },
    "notificationChannels": [
        {
            "notificationChannelType": "portal",
            "receivers": [
                ""
            ]
        },
        {
            "notificationChannelType": "email",
            "notificationReceivers": [
                {
                    "contactInformation": "$email",
                    "locale": "en-us"
                }
            ]
        }
    ]
}
"@

$patchuri = "https://graph.microsoft.com/beta/deviceManagement/monitoring/alertRules/$provruleid"
Invoke-MgGraphRequest -Uri $patchuri -Method PATCH -Body $provjson -ContentType "application/json"