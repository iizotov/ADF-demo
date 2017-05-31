<#TODO
- add parameter to supply RPs
#>

<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template
 
 .PARAMETER isInteractive
    Defines whether values will be prompted interactively or expected to be supplied as script parameters
 
 .PARAMETER resourceGroupPrefix
    Supply a Resource Group prefix for the interactive mode

 .PARAMETER subscriptionId
    The subscription id where the template will be deployed.

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER deploymentName
    The deployment name.

 .PARAMETER templateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.

 .PARAMETER sqlAdministratorPassword
    Required, SQL Admin password.

 .PARAMETER sqlAdministratorLogin
    Optional, SQL Admin Login, default = sqladmin.
#>
[CmdletBinding(DefaultParameterSetName="Interactive")]            

param(
 [Parameter(ParameterSetName='Interactive', Mandatory=$false)]
 [switch]$isInteractive,

 [Parameter(ParameterSetName='Interactive', Mandatory=$False)]
 [string]
 $resourceGroupPrefix = "ADF",
 
 [Parameter(ParameterSetName='Non-Interactive', Mandatory=$True)]
 [string]
 $subscriptionId,

 [Parameter(ParameterSetName='Non-Interactive', Mandatory=$True)]
 [string]
 $resourceGroupName,
 
 [Parameter(ParameterSetName='Non-Interactive', Mandatory=$false)]
 [string]
 $resourceGroupLocation,

 [Parameter(ParameterSetName='Interactive', Mandatory=$false)]
 [Parameter(ParameterSetName='Non-Interactive', Mandatory=$false)]
 [string]
 $templateFilePath = "./template-step-1.json",

 [Parameter(ParameterSetName='Interactive', Mandatory=$false)]
 [Parameter(ParameterSetName='Non-Interactive', Mandatory=$false)]
 [string]
 $parametersFilePath = "./parameters.json"

 <#[Parameter(ParameterSetName='Interactive', Mandatory=$true)]
 [Parameter(ParameterSetName='Non-Interactive', Mandatory=$true)]
 [Security.SecureString]$sqlAdministratorPassword,

 [Parameter(ParameterSetName='Interactive', Mandatory=$false)]
 [Parameter(ParameterSetName='Non-Interactive', Mandatory=$false)]
 [string]
 $sqlAdministratorLogin
 #>
)

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"
$resourceGroupName = "";
$resourceGroupLocation = "";
$resourceGroup = "";
$subscriptionId = "";
$allowedRegions = "";
$resourceProviders = @("microsoft.insights","microsoft.sql","microsoft.storage");

# sign in
Write-Host "Logging in...";
try
{
    $allowedRegions = (Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Compute).ResourceTypes.Where{($_.ResourceTypeName -eq 'virtualMachines')}.Locations | Sort;
}
catch {
    Login-AzureRmAccount
    $allowedRegions = (Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Compute).ResourceTypes.Where{($_.ResourceTypeName -eq 'virtualMachines')}.Locations | Sort;
}



#interactive branch
if($isInteractive -or $PSCmdlet.ParameterSetName -eq 'Interactive') {
    $resourceGroupName = ("rg" + "-" + $resourceGroupPrefix + "-" + -join ((65..90) + (97..122) | Get-Random -Count 6 | % {[char]$_})).ToLower()

    $subscriptionId = (Get-AzureRmSubscription | Out-GridView -Title "Pick a Subscription ..." -PassThru).Id
    Select-AzureRmSubscription -SubscriptionId $subscriptionId
    Write-Output "Selected $subscriptionId"
    $resourceGroupLocation = $allowedRegions | Out-GridView -Title "Pick a region" -PassThru

    #Create RG
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    $resourceGroup = New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
} 
else {
    # select subscription
    Write-Host "Selecting subscription '$subscriptionId'";
    Select-AzureRmSubscription -SubscriptionID $subscriptionId;

    #Create or check for existing resource group
    $resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if(!$resourceGroup)
    {
        Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
        if(!$resourceGroupLocation) {
            $resourceGroupLocation = Read-Host "resourceGroupLocation";
        }
        Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
        New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
    }
    else{
        Write-Host "Using existing resource group '$resourceGroupName'";
    }
}

# Register RPs

if(!$resourceProviders.length) {
    $allResourceProviders = @(Get-AzureRmResourceProvider -ListAvailable)

    foreach($resourceProvider in $allResourceProviders) {
        $resourceProviders.Add($resourceProvider.ProviderNamespace);
    }
}

Write-Host "Registering resource providers"
foreach($resourceProvider in $resourceProviders) {
    RegisterRP($resourceProvider);
}



# Start the deployment
Write-Host "Starting deployment...";
$output = "";

if(Test-Path $parametersFilePath) {
    $output = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -Verbose;
} else {
    $output = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -Verbose;
}

#Upload sample data & bacpac to Blob Storage
$storageAccountName = $output.Outputs['storageAccountName'].Value
$storageAccountKey = $output.Outputs['storageAccountKey'].Value

$blobContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

New-AzureStorageContainer -Name "input" -Permission Off –Context $blobContext -ErrorAction SilentlyContinue

ls -File –Recurse –Path './input/' | Set-AzureStorageBlobContent –Container 'input' –Context $blobContext  -ConcurrentTaskCount 10 -Force

#Provision the rest
if(Test-Path $parametersFilePath) {
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "./template-step-2.json" -TemplateParameterFile $parametersFilePath -Verbose;
} else {
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "./template-step-2.json" -Verbose;
}

#Remove-AzureRmResourceGroup -Name $resourceGroupName -Force