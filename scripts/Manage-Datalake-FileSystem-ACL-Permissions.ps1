
Clear-Variable *json*
Clear-Variable *ACL*
$json = Get-Content -Raw -Path .\param-file.json | ConvertFrom-Json
$json
Function CreateStorageContainer {
    param(
        [parameter(Mandatory = $true)] [string] $ContainerName,
        [parameter(Mandatory = $true)] [string] $Context
    )

    if (Get-AzStorageContainer -Name $containerName -Context $ctx -ErrorAction SilentlyContinue) {  
        Write-Host -ForegroundColor Magenta $containerName "- container already exists."  
    }  
    else {  
        Write-Host -ForegroundColor Magenta $containerName "- container does not exist."   
        ## Create a new Azure Storage Account  
        New-AzStorageContainer -Name $containerName -Context $ctx #-Permission Container  
    }
}

$SubDirectorySource = "SOURCE FILES"
$SubDirectoryOutput = "OUTPUT FILES"

Function CreateDatalakeSubFolders {
    param(
        [parameter(Mandatory = $true)] [string] $ParentDirectoryName,
        [parameter(Mandatory = $true)] [string] $ContainerName,
        [parameter(Mandatory = $true)] [string] $Context
    )

    if (Get-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $ParentDirectoryName -ErrorAction SilentlyContinue) {
        Write-Host -ForegroundColor Magenta "Parent directory - $ParentDirectoryName exist, creating sub-folders"

        if (Get-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $ParentDirectoryName"/"$SubDirectorySource -ErrorAction SilentlyContinue) {
            Write-Host -ForegroundColor Magenta "Sub-Directory - $SubDirectorySource already exist"
        }
        else {
            Write-Host -ForegroundColor Green "Sub-Directory - $SubDirectorySource does not exist, creating Source Sub-Directory..."
            New-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $ParentDirectoryName"/"$SubDirectorySource -Directory
        }


        if (Get-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $ParentDirectoryName"/"$SubDirectoryOutput -ErrorAction SilentlyContinue) {
            Write-Host -ForegroundColor Magenta "Sub-Directory - $SubDirectoryOutput already exist"
        }
        else {
            Write-Host -ForegroundColor Green "Sub-Directory - $SubDirectoryOutput does not exist, creating Output Sub-Directory..."
            New-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $ParentDirectoryName"/"$SubDirectoryOutput -Directory
        }
    }
}

Function CreateDatalakeParentFolders {
    param(
        [parameter(Mandatory = $true)] [string] $ParentDirectoryName,
        [parameter(Mandatory = $true)] [string] $ContainerName,
        [parameter(Mandatory = $true)] [string] $Context
    )

    if (Get-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $ParentDirectoryName -ErrorAction SilentlyContinue) {
        Write-Host -ForegroundColor Magenta "Parent directory - $ParentDirectoryName already exist"
    }
    else {
        Write-Host -ForegroundColor Green "Parent directory - $ParentDirectoryName does not exist, creating Parent Directory and Subdirectories"
        New-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $ParentDirectoryName -Directory
    }
}

ForEach ($storageAccountName in $json) {
    #$StorageAccountName = "storageAccountName: {0}" -f $storageAccountName.storageAccountName
    #$ResourceGroupName = "resourceGroupName: {0}" -f $storageAccountName.resourceGroupName
    #$ContainerName = "ContainerName: {0}" -f $storageAccountName.containerName
    #$storageAccountName.storageAccountName
    #$storageAccountName.resourceGroupName
    #$storageAccountName.containerName
    
    #Create ACL for Containers
    ForEach ($ADGroup in $storageAccountName.ADGroups) {
        $GetADGroup = Get-AzADGroup -DisplayName $ADGroup

        if ([string]::IsNullOrEmpty($ContainerAccessACL)) {   
            
            Write-Host "Creating Read Access ACL for Container : $storageAccountName.containerName with $ADGroup"
            $ContainerAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x
        }
        else {
            Write-Host "Creating Read Access ACL for Container : $storageAccountName.containerName with $ADGroup"
            $ContainerAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -InputObject $ContainerAccessACL
        }
        Clear-Variable GetADGroup
    }

    <#Create ACL for Service Principal
    ForEach ($ServicePrincipal in $storageAccountName.ServicePrincipals) {
        $SPName = Get-AzADApplication -DisplayName $ServicePrincipal
        if ($SPName.DisplayName -like "*sp-login*" ) {   
    
            $ProdSPParentReadAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType User -EntityId $SPName.ObjectId -Permission r-x
            $ProdSPSubDirWriteAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType User -EntityId $SPName.ObjectId -Permission rwx
            $ProdSPSubDirWriteDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType User -EntityId $SPName.ObjectId -Permission rwx -DefaultScope
        }
        elseif ($SPName.DisplayName -like "*sp-sec-dbw-adls-access*" ) {
            $StgSPParentReadAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType User -EntityId $SPName.ObjectId -Permission r-x
            $StgSPSubDirWriteAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType User -EntityId $SPName.ObjectId -Permission rwx 
            $StgSPSubDirWriteDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType User -EntityId $SPName.ObjectId -Permission rwx -DefaultScope
        }
    }
    #>

    #Create Storage Account Context
    $StgAcc = Get-AzStorageAccount -ResourceGroupName $storageAccountName.resourceGroupName -Name $storageAccountName.storageAccountName
    $ctx = $StgAcc.Context

    #Create Container and Assigning Read Access ACL Permission for all the AD Groups
    CreateStorageContainer -ContainerName $storageAccountName.containerName -Context $ctx 
    Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Acl $ContainerAccessACL

    ForEach ($ADGroup in $storageAccountName.ADGroups) {
        $GetADGroup = Get-AzADGroup -DisplayName $ADGroup
    
        If ($ADGroup -like "*-HP*") {
            Write-Host "I am HP"
            if ([string]::IsNullOrEmpty($HPReadAccessACL) -and $GetADGroup.DisplayName -like "*-HP*" ) {
                $HPReadAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x
                $HPReadDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -DefaultScope

                $HPSourceWriteAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx
                $HPSourceWriteDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -DefaultScope
    
                $ParentDirectory = "HIGHLY PROTECTED"
                Write-Host "Parent Directory : $ParentDirectory"
    
                #Create Parent Directory
                CreateDatalakeParentFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectory
                #Assign Access ACL On Parent Directory
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $HPReadAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $HPReadDefaultACL
            }
            else {
                $HPReadAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -InputObject $HPReadAccessACL
                $HPReadDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -InputObject $HPReadDefaultACL -DefaultScope

                $HPSourceWriteAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -InputObject $HPSourceWriteAccessACL
                $HPSourceWriteDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -InputObject $HPSourceWriteDefaultACL -DefaultScope
    
                $ParentDirectory = "HIGHLY PROTECTED"
                Write-Host "Parent Directory : $ParentDirectory"
                CreateDatalakeParentFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectory
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $HPReadAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $HPReadDefaultACL
            }
        }
        elseif ($ADGroup -like "*-CP*") {
            Write-Host "I am CP"
            if ([string]::IsNullOrEmpty($CPReadAccessACL) -and $GetADGroup.DisplayName -like "*-CP*" ) {
                $CPReadAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x
                $CPReadDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -DefaultScope
                    
                $CPSourceWriteAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx
                $CPSourceWriteDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -DefaultScope
    
                $ParentDirectory = "CUSTOMER AND PERSONAL"
                Write-Host "Parent Directory : $ParentDirectory"
                CreateDatalakeParentFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectory
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $CPReadAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $CPReadDefaultACL
            }
            else {
                $CPReadAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -InputObject $CPReadAccessACL
                $CPReadDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -InputObject $CPReadDefaultACL -DefaultScope

                $CPSourceWriteAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -InputObject $CPSourceWriteAccessACL
                $CPSourceWriteDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -InputObject $CPSourceWriteDefaultACL -DefaultScope
    
                $ParentDirectory = "CUSTOMER AND PERSONAL"
                Write-Host "Parent Directory : $ParentDirectory"
                CreateDatalakeParentFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectory
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $CPReadAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $CPReadDefaultACL
            }
        }
        elseif ($ADGroup -like "*-CF*") {
            Write-Host "I am CF"
            if ([string]::IsNullOrEmpty($CFReadAccessACL) -and $GetADGroup.DisplayName -like "*-CF*" ) {
                $CFReadAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x
                $CFReadDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -DefaultScope

                $CFSourceWriteAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx
                $CFSourceWriteDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -DefaultScope
    
                $ParentDirectory = "CONFIDENTIAL"
                Write-Host "Parent Directory : $ParentDirectory"
    
                CreateDatalakeParentFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectory
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $CFReadAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $CFReadDefaultACL
            }
            else {
                $CFReadAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -InputObject $CFReadAccessACL
                $CFReadDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -InputObject $CFReadDefaultACL -DefaultScope

                $CFSourceWriteAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -InputObject $CFSourceWriteAccessACL
                $CFSourceWriteDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -InputObject $CFSourceWriteDefaultACL -DefaultScope
    
                $ParentDirectory = "CONFIDENTIAL"
                Write-Host "Parent Directory : $ParentDirectory"
    
                CreateDatalakeParentFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectory
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $CFReadAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $CFReadDefaultACL
            }
        }
        elseif ($ADGroup -like "*-CU*") {
            Write-Host "I am CU"
            if ([string]::IsNullOrEmpty($CUReadAccessACL) -and $GetADGroup.DisplayName -like "*-CU*" ) {
                $CUReadAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x
                $CUReadDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -DefaultScope

                $CUSourceWriteAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx
                $CUSourceWriteDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -DefaultScope
    
                $ParentDirectory = "CFS USE ONLY"
                Write-Host "Parent Directory : $ParentDirectory"
    
                CreateDatalakeParentFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectory
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $CUReadAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $CUReadDefaultACL
            }
            else {
                $CUReadAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -InputObject $CUReadAccessACL
                $CUReadDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -InputObject $CUReadDefaultACL -DefaultScope

                $CUSourceWriteAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -InputObject $CUSourceWriteAccessACL
                $CUSourceWriteDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -InputObject $CUSourceWriteDefaultACL -DefaultScope
    
                $ParentDirectory = "CFS USE ONLY"
                Write-Host "Parent Directory : $ParentDirectory"
    
                CreateDatalakeParentFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectory
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $CUReadAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $CUReadDefaultACL
            }
        }
        elseif ($ADGroup -like "*-PB*") {
            Write-Host "I am PB"
            if ([string]::IsNullOrEmpty($PBReadAccessACL) -and $GetADGroup.DisplayName -like "*-PB*" ) {
                $PBReadAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x
                $PBReadDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -DefaultScope

                $PBSourceWriteAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx
                $PBSourceWriteDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -DefaultScope
    
                $ParentDirectory = "PUBLIC"
                Write-Host "Parent Directory : $ParentDirectory"
    
                CreateDatalakeParentFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectory
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $PBReadAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $PBReadDefaultACL
            }
            else {
                $PBReadAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -InputObject $PBReadAccessACL
                $PBReadDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission r-x -InputObject $PBReadDefaultACL -DefaultScope

                $PBSourceWriteAccessACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -InputObject $PBSourceWriteAccessACL
                $PBSourceWriteDefaultACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $GetADGroup.Id -Permission rwx -InputObject $PBSourceWriteDefaultACL -DefaultScope
    
                $ParentDirectory = "PUBLIC"
                Write-Host "Parent Directory : $ParentDirectory"
    
                CreateDatalakeParentFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectory
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $PBReadAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $storageAccountName.containerName -Path $ParentDirectory -Acl $PBReadDefaultACL
            }
        }
        else {
            Write-Host "No Matching AD Group Found"
        }
    }

    ForEach ($ContainerName in $storageAccountName.containerName) {

        ForEach ($ParentDirectoryName in $storageAccountName.parentFolder) {

            if ($ParentDirectoryName -eq "HIGHLY PROTECTED") {
                $SubDirSource = $ParentDirectoryName + "/" + $SubDirectorySource + "/"
                Write-Host "I am HIGHLY PROTECTED"
                Write-Host "Container name :"
                $storageAccountName.containerName

                #Assigning ACL Access for Prod and Stg on Parent Folders
                CreateDatalakeSubFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectoryName
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $SubDirSource -Acl $HPSourceWriteAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $SubDirSource -Acl $HPSourceWriteDefaultACL
            }
            if ($ParentDirectoryName -eq "CUSTOMER AND PERSONAL") {
                $SubDirSource = $ParentDirectoryName + "/" + $SubDirectorySource + "/"
                CreateDatalakeSubFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectoryName
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $SubDirSource -Acl $CPSourceWriteAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $SubDirSource -Acl $CPSourceWriteDefaultACL
            }
            if ($ParentDirectoryName -eq "CONFIDENTIAL") {
                $SubDirSource = $ParentDirectoryName + "/" + $SubDirectorySource + "/"
                CreateDatalakeSubFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectoryName
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $SubDirSource -Acl $CFSourceWriteAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $SubDirSource -Acl $CFSourceWriteDefaultACL
            }
            if ($ParentDirectoryName -eq "CFS USE ONLY") {
                $SubDirSource = $ParentDirectoryName + "/" + $SubDirectorySource + "/"
                CreateDatalakeSubFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectoryName
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $SubDirSource -Acl $CUSourceWriteAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $SubDirSource -Acl $CUSourceWriteDefaultACL
            }
            if ($ParentDirectoryName -eq "PUBLIC") {
                $SubDirSource = $ParentDirectoryName + "/" + $SubDirectorySource + "/"
                CreateDatalakeSubFolders -Context $ctx -ContainerName $storageAccountName.containerName -ParentDirectoryName $ParentDirectoryName
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $SubDirSource -Acl $PBSourceWriteAccessACL
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $SubDirSource -Acl $PBSourceWriteDefaultACL
            }
        }
    }
}
