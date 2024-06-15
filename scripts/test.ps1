param(
    [parameter(Mandatory = $true)] [string] $EnvironmentName
)

#$Environment = Read-Host -Prompt "Enter the environment Name"
$ParamPath = ".\parameters\" + $EnvironmentName + ".parameters.json"


$json = Get-Content -Raw -Path $ParamPath | ConvertFrom-Json
$json

Write-Host "Getting Azure AD Group"
Get-AzADGroup -DisplayName "SG-IN-HP"

Get-Module -ListAvailable
