###This script will add the Win365 Preview app via new store integration and assign it to a group

$groupid = "YOUR GROUP ID HERE"



############################################################################################################
#####                                        FUNCTIONS                                               #######
############################################################################################################        

Function Add-MSStoreApp() {
        
    <#
    .SYNOPSIS
    This function adds Microsoft Store Apps using Winget
    .DESCRIPTION
    The function connects to the Graph API Interface and creates a Microsoft Store App using the new experience
    Thanks for Sander Rozemuller for this one: https://www.rozemuller.com/add-mirosoft-store-app-with-icon-into-intune-automated/
    .EXAMPLE
    Add-MSStoreApp -name "WhatsApp"
    .NOTES
    NAME: Add-MSStoreApp
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    $appName = $name
    $storeSearchUrl = "https://storeedgefd.dsx.mp.microsoft.com/v9.0/manifestSearch"
    $body = @{
        Query = @{
            KeyWord   = $appName
            MatchType = "Substring"
        }
    } | ConvertTo-Json
    $appSearch = Invoke-RestMethod -Uri $storeSearchUrl -Method POST -ContentType 'application/json' -body $body
    $exactApp = $appSearch.Data | Where-Object { $_.PackageName -eq $appName }

    $appUrl = "https://storeedgefd.dsx.mp.microsoft.com/v9.0/packageManifests/{0}" -f $exactApp.PackageIdentifier
    $app = Invoke-RestMethod -Uri $appUrl -Method GET 
    $appId = $app.Data.PackageIdentifier
    $appInfo = $app.Data.Versions[-1].DefaultLocale
    $appInstaller = $app.Data.Versions[-1].Installers


    $imageUrl = "https://apps.microsoft.com/store/api/ProductsDetails/GetProductDetailsById/{0}?hl=en-US&gl=US" -f $exactApp.PackageIdentifier
    $image = Invoke-RestMethod -Uri $imageUrl -Method GET 
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($image.IconUrl, "./temp.jpg")
    $base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes('./temp.jpg'))


    $deployUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
    $appBody = @{
        '@odata.type'         = "#microsoft.graph.winGetApp"
        description           = $appInfo.ShortDescription
        developer             = $appInfo.Publisher
        displayName           = $appInfo.packageName
        informationUrl        = $appInfo.PublisherSupportUrl
        largeIcon             = @{
            "@odata.type" = "#microsoft.graph.mimeContent"
            "type"        = "String"
            "value"       = $base64string 
        }
        installExperience     = @{
            runAsAccount = $appInstaller.scope
        }
        isFeatured            = $false
        packageIdentifier     = $appId
        privacyInformationUrl = $appInfo.PrivacyUrl
        publisher             = $appInfo.publisher
        repositoryType        = "microsoftStore"
        roleScopeTagIds       = @()
    } | ConvertTo-Json 
    $appDeploy = Invoke-MgGraphRequest -uri $deployUrl -method POST -body $appBody
    return $appDeploy
}


Function Add-MSStoreApp() {
        
    <#
    .SYNOPSIS
    This function adds Microsoft Store Apps using Winget
    .DESCRIPTION
    The function connects to the Graph API Interface and creates a Microsoft Store App using the new experience
    .EXAMPLE
    Add-MSStoreApp -name "WhatsApp"
    .NOTES
    NAME: Add-MSStoreApp
    #>
    
    [cmdletbinding()]
    
    param
    (
        $name
    )
    $appName = $name
    $storeSearchUrl = "https://storeedgefd.dsx.mp.microsoft.com/v9.0/manifestSearch"
    $body = @{
        Query = @{
            KeyWord   = $appName
            MatchType = "Substring"
        }
    } | ConvertTo-Json
    $appSearch = Invoke-RestMethod -Uri $storeSearchUrl -Method POST -ContentType 'application/json' -body $body
    $exactApp = $appSearch.Data | Where-Object { $_.PackageName -eq $appName }

    $appUrl = "https://storeedgefd.dsx.mp.microsoft.com/v9.0/packageManifests/{0}" -f $exactApp.PackageIdentifier
    $app = Invoke-RestMethod -Uri $appUrl -Method GET 
    $appId = $app.Data.PackageIdentifier
    $appInfo = $app.Data.Versions[-1].DefaultLocale
    $appInstaller = $app.Data.Versions[-1].Installers


    $imageUrl = "https://apps.microsoft.com/store/api/ProductsDetails/GetProductDetailsById/{0}?hl=en-US&gl=US" -f $exactApp.PackageIdentifier
    $image = Invoke-RestMethod -Uri $imageUrl -Method GET 
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($image.IconUrl, "./temp.jpg")
    $base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes('./temp.jpg'))

    $appdescription = ($appInfo.Shortdescription).ToString()
    $appdescription2 = $appdescription.replace("`n", " ").replace("`r", " ").replace("\n", " ").replace("\\n", " ")
    $appdeveloper = $appInfo.Publisher
    $appdisplayName = $appInfo.packageName
    $appinformationUrl = $appInfo.PublisherSupportUrl
    $apprunAsAccount = ($appInstaller.scope | select-object -First 1)
    $apppackageIdentifier = $appId
    $appprivacyInformationUrl = $appInfo.PrivacyUrl
    $apppublisher = $appInfo.publisher


    $deployUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
    $json = @"
{
	"@odata.type": "#microsoft.graph.winGetApp",
	"categories": [],
	"description": "$appdescription2",
	"developer": "$appdeveloper",
	"displayName": "$appdisplayName",
	"informationUrl": "$appinformationUrl",
	"installExperience": {
		"runAsAccount": "$apprunAsAccount"
	},
	"isFeatured": false,
	"largeIcon": {
        "@odata.type": "#microsoft.graph.mimeContent",
        "type": "string",
        "value": "$base64string"
    	},
	"notes": "",
	"owner": "",
	"packageIdentifier": "$apppackageIdentifier",
	"privacyInformationUrl": "$appprivacyInformationUrl",
	"publisher": "$apppublisher",
	"repositoryType": "microsoftStore",
	"roleScopeTagIds": []
}
"@

    $appDeploy = Invoke-mggraphrequest -uri $deployUrl -Method POST -Body $json -ContentType "application/JSON"



    return $appDeploy
}

Function Add-StoreAppAssignment() {

    <#
    .SYNOPSIS
    This function is used to add a store app assignment using the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and adds a store app assignment
    .EXAMPLE
    Add-StoreAppAssignment -StoreAppID $StoreAppIdId -TargetGroupId $TargetGroupId
    Adds a Store app assignment in Intune
    .NOTES
    NAME: Add-SStoreAppAssignment
    #>
    
    [cmdletbinding()]
    
    param
    (
        $StoreAppID,
        $TargetGroupId
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceAppManagement/mobileApps/$storeAppID/assign"
        
    try {
    
        if (!$StoreAppID) {
    
            write-host "No App Id specified, specify a valid App Id" -f Red
            break
    
        }
    
        if (!$TargetGroupId) {
    
            write-host "No Target Group Id specified, specify a valid Target Group Id" -f Red
            break
    
        }
    
        $JSON = @"
            {
                "mobileAppAssignments": [
                    {
                        "@odata.type": "#microsoft.graph.mobileAppAssignment",
                        "intent": "Required",
                        "settings": {
                            "@odata.type": "#microsoft.graph.winGetAppAssignmentSettings",
                            "installTimeSettings": null,
                            "notifications": "showAll",
                            "restartSettings": null
                        },
                        "target": {
                            "@odata.type": "#microsoft.graph.groupAssignmentTarget",
                            "groupId": "$targetgroupid"
                        }
                    }
                ]
            }
"@
    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType "application/json"
    
    
    }
        
    catch {
    
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        
    
    }
    
}


Function Get-MSStoreApps() {
        
    <#
        .SYNOPSIS
        This function is used to get MS Store Apps from the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets any MS Store Apps
        .EXAMPLE
        Get-MSStoreApps
        Returns any MS Store Apps configured in Intune

        Get-MSStoreApps -id $id
        Returns specific app
        .NOTES
        NAME: Get-MSStoreApps
        #>
        
    [cmdletbinding()]
        
    param
    (
        $id
    )
        
    $graphApiVersion = "beta"
    $DCP_resource = "deviceAppManagement/MobileApps"
        
    try {
        
        if ($Name) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
        ((Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value)

        }
        
        else {
        
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=(isof('microsoft.graph.winGetApp'))"
        (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
        
        }
        
    }
        
    catch {
        
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
            
        
    }
        
}


############################################################################################################
#####                                    END FUNCTIONS                                               #######
############################################################################################################        


###Add Store App
write-host "Adding W365 Store App"
$addapp = Add-MSStoreApp -name "Windows 365 Preview"
write-host "W365 Store App Added"

### Assign Store App
write-host "Assigning W365 Store App"
$appid = $addapp.Id
Add-StoreAppAssignment -StoreAppID $appid -TargetGroupId $groupid
write-host "W365 Store App Assigned"
