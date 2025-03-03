#!/usr/bin/env pwsh

$glabStatus = glab auth status
Write-Output "glabStatus: $glabStatus"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: You are not authenticated with glab. Please authenticate before continuing."
    exit 1
}

$ghStatus = gh auth status
Write-Output "ghStatus: $ghStatus"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: You are not authenticated with gh. Please authenticate before continuing."
    exit 1
}

$configPath = Join-Path -Path $PSScriptRoot -ChildPath "cleaned_snowflakecorp_PS_mountain.json"
$workingDir = "$PSScriptRoot/reposSC"

if (-not (Test-Path -Path $workingDir)) {
    New-Item -ItemType Directory -Path $workingDir
    Write-Output "Target directory created: $workingDir"
}
else {
    Remove-Item -Recurse -Force $workingDir
    New-Item -ItemType Directory -Path $workingDir
    Write-Output "Target directory cleaned: $workingDir"
}

if (Test-Path -Path $configPath) {
    $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
    Write-Output "Total number of repositories: $($config.Count)"
    Write-Output "Starting migration of repositories..."
}
else {
    Write-Error "Config file not found: $configPath"
    exit 1
}

function Copy-Repo {
    param (
        [string]$repoUrl,
        [string]$destinationDir
    )
    try {
        Write-Output "Cloning $repoUrl as mirror..."
        git clone --mirror $repoUrl $destinationDir
        Write-Output "Cloned $repoUrl as mirror."
    }
    catch {
        Write-Error "Failed to clone $repoUrl as mirror. Error: $_"
        exit 1
    }
}

function New-GitHubRepo {
    param (
        [string]$repoName
    )
    $repoName = $repoName -replace '\.', '-' -replace ' ', '-' -replace '_', '-' -replace '[^a-zA-Z0-9-]', '' -replace '--+', '-' -replace '^-|-$', ''
    $repoName = $repoName.ToLower()
    $repoNewName = "migrations-$repoName"
    Write-Output ("Checking if repo exists: {0}" -f $repoNewName)

    $repoExists = gh repo view "snowflakedb/$repoNewName" -q .name 2>$null
    
    if (-not $repoExists) {
        gh repo create "snowflakedb/$repoNewName" --private
        Write-Output ("Repository {0} created." -f $repoNewName)
    }
    else {
        Write-Warning ("Repository {0} already exists. Skipping creation." -f $repoNewName)
    }
}

function Push-MirrorRepo {
    param (
        [string]$sourceDir,
        [string]$destinationUrl
    )
    try {
        Write-Output "Pushing mirror to $destinationUrl..."
        Write-Output "Source Dir: $sourceDir"
        Write-Output "Destination URL: $destinationUrl"
        git -C $sourceDir push --mirror $destinationUrl
        Write-Output "Pushed mirror to $destinationUrl."
    }
    catch {
        Write-Error "Failed to push mirror to $destinationUrl. Error: $_"
        exit 1
    }
}

function Edit-GitHubRepo {
    param (
        [string]$repoNameFullName
    )
    
    if ($repoNameFullName -match "desktop") {
        $repoDefaultBranch = "develop"
    } else {
        $repoDefaultBranch = "master"
        $branchExists = git ls-remote --heads "https://github.com/$repoNameFullName.git" $repoDefaultBranch
        
        if (-not $branchExists) {
            $repoDefaultBranch = "main"
        }
    }

    Write-Output ("Editing repository {0} with default branch {1}" -f $repoNameFullName, $repoDefaultBranch )
    gh repo edit $repoNameFullName --enable-squash-merge --enable-auto-merge --delete-branch-on-merge --default-branch $repoDefaultBranch --enable-merge-commit=false --enable-rebase-merge=false --enable-discussions=false --enable-issues=true --enable-wiki=false --enable-projects=false --allow-update-branch
    Write-Output ("Migration of repository {0} completed" -f $repoNameFullName )
}
    
foreach ($repo in $config) {
    $repoUrl = $repo.http_url_to_repo
    $repoName = $repo.path_with_namespace.Split('/')[-1]
    $repoName = $repoName -replace '\.', '-' -replace ' ', '-' -replace '_', '-' -replace '[^a-zA-Z0-9-]', '' -replace '--+', '-' -replace '^-|-$', ''
    $repoName = $repoName.ToLower()
    $destinationDir = Join-Path -Path $workingDir -ChildPath $repoName
    $repoNameFullName = "snowflakedb/migrations-$repoName"
    $destinationUrl = "https://github.com/snowflakedb/migrations-$repoName.git"

    Write-Output "Migrating $repoName..."
    Write-Output "Repo URL: $repoUrl"
    Write-Output "Destination Dir: $destinationDir" 
    Write-Output "Destination URL: $destinationUrl"
    
    if ($repoUrl -match "SMA.SnowflakeTools.git") {
        Write-Warning "Skipping $repoName as it is a Snowflake internal repository."
    }else{
        # Copy-Repo is a function that clones the repo as a mirror
        Copy-Repo -repoUrl $repoUrl -destinationDir $destinationDir
        
        # New-GitHubRepo is a function that creates a new GitHub repo
        New-GitHubRepo -repoName $repoName

        # Push-MirrorRepo is a function that pushes the mirror to the destination
        Push-MirrorRepo -sourceDir $destinationDir -destinationUrl $destinationUrl

        # Edit-GitHubRepo is a function that edits the GitHub repo
        Edit-GitHubRepo -repoNameFullName $repoNameFullName
    }
    
}