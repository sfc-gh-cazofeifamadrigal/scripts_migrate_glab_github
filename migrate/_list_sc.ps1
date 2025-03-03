
Set-Alias Show Write-Output

$organization = "snowflakecorp/ps/mountain"
$jsonFileName = "$PSScriptRoot/snowflakecorp_PS_mountain.json"
$Global:cleanedJsonFileName = "$PSScriptRoot/cleaned_snowflakecorp_PS_mountain.json"
$filteredStrings = @("snowflakecorp/ps/mountain/SC*", "snowflakecorp/ps/mountain/EF*")

glab auth status
glab repo list -g $organization --all --per-page 100 --output json > $jsonFileName

if (-not (Test-Path -Path $jsonFileName -PathType Leaf)) {
    Write-Error "Error: The file '$jsonFileName' does not exist or is not accessible."
    exit 1
}
else {
    $jsonContent = Get-Content -Raw -Path $jsonFileName | ConvertFrom-Json
    $filteredRepos = $jsonContent | Where-Object { $_.archived -eq $false -and ($_.path_with_namespace -like $filteredStrings[0] -or $_.path_with_namespace -like $filteredStrings[1]) }
    $cleanedRepos = $filteredRepos | ForEach-Object {
        [PSCustomObject]@{
            http_url_to_repo    = $_.http_url_to_repo
            path_with_namespace = $_.path_with_namespace
        }
    }
    
    $cleanedRepos | ConvertTo-Json -Depth 3 | Set-Content -Path $cleanedJsonFileName
    Write-Host "Clean JSON file generated: $cleanedJsonFileName"

    $cleanedJsonContent = Get-Content -Raw -Path $Global:cleanedJsonFileName | ConvertFrom-Json
    $totalRepos = $cleanedJsonContent.Count
    Write-Host "Total number of repositories: $totalRepos"
}
function Get-ContentFromJsonFile {
    param($file)
    
    if (-not (Test-Path $file)) {
        Write-Error "Source file does not exist: $file"
        exit 1
    }
    Get-Content -Path $file | Write-Host
}

Get-ContentFromJsonFile -file $Global:cleanedJsonFileName