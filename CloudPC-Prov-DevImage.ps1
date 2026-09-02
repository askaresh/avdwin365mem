#############################################################################################
# Windows 365 Dedicated Cloud PC Provisioning Policy via PowerShell
# Entra Join + Single Sign-On + Automatic (Recommended) Region + Dev Box Gallery Image
# Comment or Un-comment the components that do not apply to your environment
#
# Only requires the Microsoft.Graph.Authentication module - all work is done with raw
# Graph calls so the heavier SDK sub-modules are never loaded.
# Blog - askaresh.com
#############################################################################################

$ErrorActionPreference = "Stop"

#---------------------------------------------------------------------------------------------
# STEP 0 - Module + Authentication
#---------------------------------------------------------------------------------------------

# Install once if needed:
# Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force

Import-Module Microsoft.Graph.Authentication

# Set your tenant explicitly - avoids home-tenant guessing and some consent failures
$TenantId = "d7XX6-4XXc-4XX4-8XXc-fe7XXXXXX65"

Connect-MgGraph -TenantId $TenantId -Scopes "CloudPC.ReadWrite.All","Group.Read.All"

# If Connect-MgGraph throws AADSTS650051, see the troubleshooting block at the bottom.

# Hard stop if we are not actually connected - prevents the rest of the script running blind
$ctx = Get-MgContext
if (-not $ctx) { throw "Not connected to Microsoft Graph. Resolve the sign-in error before continuing." }
Write-Host "Connected as $($ctx.Account) to tenant $($ctx.TenantId)" -ForegroundColor Cyan

# Confirm you hold the Cloud PC RBAC permissions before you start
Invoke-MgGraphRequest -Method GET -OutputType PSObject `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/getEffectivePermissions"


#---------------------------------------------------------------------------------------------
# STEP 1 - Discovery (optional, but confirms your inputs are valid in THIS tenant)
#---------------------------------------------------------------------------------------------

# 1a. What Cloud PC SKUs have you actually purchased?
(Invoke-MgGraphRequest -Method GET -OutputType PSObject `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/retrievePurchasedServicePlans?`$select=id,displayName,type,vCpuCount,ramInGB,storageInGB,userProfileInGB,category,supportedSolution,provisioningType").value |
    Format-Table displayName, vCpuCount, ramInGB, storageInGB -AutoSize

# 1b. Which regions are available? Grab exact regionName / regionGroup strings here.
(Invoke-MgGraphRequest -Method GET -OutputType PSObject `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/supportedRegions?`$filter=supportedSolution%20eq%20%27windows365%27&`$select=id,displayName,regionStatus,regionGroup,geographicLocationType").value |
    Format-Table id, displayName, regionGroup, regionStatus -AutoSize

# 1c. Gallery images - confirm the imageId below exists and is 'supported' in this tenant.
(Invoke-MgGraphRequest -Method GET -OutputType PSObject `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/galleryImages").value |
    Where-Object { $_.status -eq "supported" } |
    Format-Table id, displayName, status -AutoSize

# 1d. Custom (uploaded) images - use these instead if imageType = "custom"
# (Invoke-MgGraphRequest -Method GET -OutputType PSObject `
#     -Uri "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/deviceImages").value |
#     Format-Table id, displayName, status, osBuildNumber -AutoSize

# 1e. Only needed for Hybrid Entra Join. Skip entirely for Entra Join (this script).
# (Invoke-MgGraphRequest -Method GET -OutputType PSObject `
#     -Uri "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/onPremisesConnections?`$select=id,displayName,healthCheckStatus,adDomainName").value |
#     Format-Table id, displayName, healthCheckStatus -AutoSize


#---------------------------------------------------------------------------------------------
# STEP 2 - Build the Provisioning Policy body
#---------------------------------------------------------------------------------------------

$params = @{
    displayName        = "W365-Developer-SKU-Image"
    description        = "A Cloud PC for the Developers"

    # dedicated = 1:1 Cloud PC per user.
    # Alternatives: sharedByUser | sharedByEntraGroup (Frontline)
    provisioningType   = "dedicated"

    # cloudPc = full desktop. Alternative: privateCloudPc
    userExperienceType = "cloudPc"

    # windows365 = licence-based W365. Alternative: devBox
    managedBy          = "windows365"

    #-----------------------------------------------------------------------------------------
    # Image - verify this ID appeared in the Step 1c output before running.
    # Swap imageType to "custom" and use a deviceImages ID for your own uploaded image.
    #-----------------------------------------------------------------------------------------
    imageId            = "microsoftwindowsdesktop_windows-ent-cpc_win11-25h2-ent-cpc-devready"
    imageDisplayName   = "Windows 11 Enterprise Developer Configuration + Microsoft 365 Apps (preview) 25H2"
    imageType          = "gallery"

    #-----------------------------------------------------------------------------------------
    # Microsoft Managed Desktop / Windows 365 Enterprise management
    #-----------------------------------------------------------------------------------------
    microsoftManagedDesktop = @{
        type    = "notManaged"
        profile = $null
    }

    #-----------------------------------------------------------------------------------------
    # Single Sign-On - requires the Entra Kerberos / SSO prerequisites to be in place
    #-----------------------------------------------------------------------------------------
    enableSingleSignOn = $true

    #-----------------------------------------------------------------------------------------
    # Entra Join with AUTOMATIC region selection inside the Australia/New Zealand geography.
    # To pin a region instead: regionGroup = "australia"; regionName = "australiaeast"
    # and drop geographicLocationType.
    #-----------------------------------------------------------------------------------------
    domainJoinConfigurations = @(
        @{
            type                   = "azureADJoin"
            geographicLocationType = "australiaNewZealand"
            regionGroup            = "automatic"
            regionName             = "automatic"
        }
    )

    # Hybrid Entra Join variant - comment out the block above and use this instead:
    # domainJoinConfigurations = @(
    #     @{
    #         type                   = "hybridAzureADJoin"
    #         onPremisesConnectionId = "<connection-id-from-step-1e>"
    #     }
    # )

    windowsSettings = @{
        language = "en-US"
    }

    #-----------------------------------------------------------------------------------------
    # Naming template. %RAND:x% where x is 5-11. Total name must stay <= 15 chars.
    # "CPC-DEV-" (8) + 5 random = 13 chars. Safe.
    #-----------------------------------------------------------------------------------------
    cloudPcNamingTemplate = "CPC-DEV-%RAND:5%"

    # Scope tags. "0" is the built-in Default scope - omit this line entirely to inherit it.
    scopeIds = @("0")

    # Windows Autopatch - $null means no Autopatch group assigned
    autopatch = @{
        autopatchGroupId = $null
    }

    # User settings persistence - only meaningful for shared/non-dedicated types.
    # NOTE: the top-level userSettingsPersistenceEnabled is flagged deprecated by Graph
    # (sunset advertised via response Link headers). Use the nested configuration object.
    # userSettingsPersistenceEnabled = $false
    userSettingsPersistenceConfiguration = @{
        userSettingsPersistenceEnabled             = $false
        userSettingsPersistenceStorageSizeCategory = "sixteenGB"
    }

    # Autopilot device preparation - not used here
    autopilotConfiguration = $null
}


#---------------------------------------------------------------------------------------------
# STEP 3 - Create the policy
#---------------------------------------------------------------------------------------------

$policy = Invoke-MgGraphRequest -Method POST -OutputType PSObject `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies" `
    -Body ($params | ConvertTo-Json -Depth 10) -ContentType "application/json"

if (-not $policy.id) { throw "Policy creation returned no ID - stopping before assignment." }
Write-Host "Created provisioning policy: $($policy.displayName) [$($policy.id)]" -ForegroundColor Green


#---------------------------------------------------------------------------------------------
# STEP 4 - Assign the policy to an Entra security group
#---------------------------------------------------------------------------------------------

# Option A - resolve by display name
$groupName = "W365-CPC-Grp"
$filterEnc = [uri]::EscapeDataString("displayName eq '$groupName'")
$group = (Invoke-MgGraphRequest -Method GET -OutputType PSObject `
    -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=$filterEnc&`$select=id,displayName,securityEnabled,groupTypes").value |
    Select-Object -First 1

# Option B - hard-code the object ID instead:
# $group = Invoke-MgGraphRequest -Method GET -OutputType PSObject `
#     -Uri "https://graph.microsoft.com/v1.0/groups/01eecc64-c3bb-4c47-85ce-bafb18feef12?`$select=id,displayName,securityEnabled,groupTypes"

if (-not $group)               { throw "Group '$groupName' not found in tenant $($ctx.TenantId)." }
if (-not $group.securityEnabled) { throw "Group '$($group.displayName)' is not security-enabled - assignment will fail." }
Write-Host "Assignment target: $($group.displayName) [$($group.id)]" -ForegroundColor Cyan

$assign = @{
    assignments = @(
        @{
            id     = ""
            target = @{
                "@odata.type" = "#microsoft.graph.cloudPcManagementGroupAssignmentTarget"
                groupId       = $group.id
            }
        }
    )
}

Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/$($policy.id)/assign" `
    -Body ($assign | ConvertTo-Json -Depth 10) -ContentType "application/json"

Write-Host "Assigned policy to $($group.displayName)" -ForegroundColor Green


#---------------------------------------------------------------------------------------------
# STEP 5 - Verify
#---------------------------------------------------------------------------------------------

Invoke-MgGraphRequest -Method GET -OutputType PSObject `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/provisioningPolicies/$($policy.id)?`$expand=assignments&`$select=id,displayName,description,imageId,imageDisplayName,imageType,enableSingleSignOn,cloudPcNamingTemplate,provisioningType,managedBy,scopeIds,autopilotConfiguration,domainJoinConfigurations,microsoftManagedDesktop,autopatch,windowsSettings,lastModifiedDateTime,createdBy,createdDateTime,lastModifiedBy,assignments,userExperienceType,userSettingsPersistenceEnabled,userSettingsPersistenceConfiguration" |
    ConvertTo-Json -Depth 10

# Disconnect-MgGraph
