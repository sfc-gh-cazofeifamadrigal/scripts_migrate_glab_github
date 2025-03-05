function Read-RepositoryData {
    param (
        [string]$JsonFilePath
    )
    
    try {
        if (Test-Path -Path $JsonFilePath) {
            $reposJson = Get-Content -Path $JsonFilePath -ErrorAction Stop | ConvertFrom-Json
            Write-Output "Found JSON file at specified path: $JsonFilePath" 
            return $reposJson
        }
        
        $scriptDirectory = $PSScriptRoot
        Push-Location $scriptDirectory

        Write-Output "JSON file not found at $JsonFilePath, searching recursively..." 
        $foundFiles = Get-ChildItem -Path . -Filter (Split-Path $JsonFilePath -Leaf) -Recurse -File -ErrorAction Stop
        
        if ($foundFiles.Count -eq 0) {
            $alternateNames = @(
                "gh-list-migrations-ef.json",
                "gh-list-migrations-sc.json", 
                "gh-list-migrations-sma.json"
            )
            
            foreach ($name in $alternateNames) {
                $foundFiles = Get-ChildItem -Path . -Filter $name -Recurse -File -ErrorAction SilentlyContinue
                if ($foundFiles.Count -gt 0) {
                    Write-Output "Found alternative JSON file: $name"
                    break
                }
            }
            
            if ($foundFiles.Count -eq 0) {
                throw "Could not find JSON file $JsonFilePath or any alternatives in any subdirectory"
            }
        }
        
        $actualPath = $foundFiles[0].FullName
        Write-Output "Found JSON file at: $actualPath" 
        $reposJson = Get-Content -Path $actualPath -ErrorAction Stop | ConvertFrom-Json
        return $reposJson
    }
    catch {
        Write-Error "Error reading JSON file: $_"
        exit 1
    }
}

function Initialize-CloneDirectory {
    param (
        [string]$DirectoryPath
    )
    
    Set-Location $PSScriptRoot
    Write-Output "Initializing clone directory..."
    Write-Output "Clone directory path: $DirectoryPath"

    $fullPath = Join-Path -Path $PSScriptRoot -ChildPath $DirectoryPath
    Write-Output "Full path: $fullPath"

    if (Test-Path -Path $fullPath) {
        Write-Output "Clone directory already exists!"  
    }
    else {
        New-Item -ItemType Directory -Path $fullPath | Out-Null
        Write-Output "Created directory: $DirectoryPath" 
    }

    return $fullPath
}

function Copy-Repository {
    param (
        [string]$RepositoryUrl,
        [string]$RepositoryName
    )
    
    if ([string]::IsNullOrEmpty($RepositoryUrl)) {
        Write-Error "Repository URL is empty for $RepositoryName"
        return $false
    }
    
    Write-Output "Cloning $RepositoryUrl..."
        
    try {
        $process = Start-Process -FilePath "git" -ArgumentList "clone", $RepositoryUrl -NoNewWindow -PassThru -Wait
        if ($process.ExitCode -ne 0) {
            Write-Error "Git clone failed with exit code $($process.ExitCode)"
            return $false
        }
        return $true
    }
    catch {
        Write-Error "Error cloning repository"
        return $false
    }
}

function ReplacePreCommitHook {
    param (
        [string]$RepositoryName
    )

    Get-Location 
    Write-Output "Checking for pre-commit hook in $RepositoryName..."
    $preCommitConfig = "../config/.pre-commit-config.yaml"
    $preCommitConfigPath = Join-Path $PSScriptRoot -ChildPath $preCommitConfig
    write-host "preCommitConfigPath: $preCommitConfigPath"
    
    if (-not (Test-Path -Path $preCommitConfigPath)) {
        Write-Error "Source pre-commit config file not found at: $preCommitConfigPath"
        return $false
    }else {
        Write-Output "Found .pre-commit-config.yaml in repository, replacing it..."
        Copy-Item -Path $preCommitConfigPath -Destination "./.pre-commit-config.yaml" -Force
        Write-Output "Pre-commit hook config replaced successfully."
        return $true
    }
}

function ReplaceFilesGitlabDirectory {
    param (
        [string]$RepositoryName
    )
    
    $configRoot = "../config"
    if (-not (Test-Path -Path $configRoot)) {
        $configRoot = "../../config"
        if (-not (Test-Path -Path $configRoot)) {
            Write-Output "Config directory not found, creating paths..." 
            $configRoot = "../config"
            New-Item -ItemType Directory -Path "$configRoot/sc/.github" -Force | Out-Null
            New-Item -ItemType Directory -Path "$configRoot/ef/.github" -Force | Out-Null
            New-Item -ItemType Directory -Path "$configRoot/sma/.github" -Force | Out-Null
        }
    }
    
    if (Test-Path -Path "./.gitlab") {
        Write-Output "Found .gitlab directory in $RepositoryName" 
        
        if (Test-Path -Path "./.github") {
            Write-Output ".github directory already exists, merging manual contents..." 
        } 
        else {
            Write-Output "Renaming .gitlab to .github..." 
            Rename-Item -Path "./.gitlab" -NewName ".github"

            if (Test-Path -Path "./.github/ci") {
                Write-Output "Removing .github/ci directory..." 
                Remove-Item -Path "./.github/ci" -Recurse -Force
            }
            
            $repoType = "sc"
            if ($RepositoryName -like "*snowconvert*") {
                $repoType = "sc"
            }
            elseif ($RepositoryName -like "*sma*") {
                $repoType = "sma"
            }
            elseif ($RepositoryName -like "*ef*") {
                $repoType = "ef"
            }
            
            $configPath = "$configRoot/$repoType/.github"
            if (Test-Path -Path $configPath) {
                Write-Output "Copying $repoType config files from $configPath..." 
                Copy-Item -Path "$configPath/*" -Destination "./.github/" -Recurse -Force
            }
            else {
                Write-Output "Config path $configPath not found!"
            }

        }
        
        Write-Output "Successfully processed .gitlab directory in $RepositoryName" 
        return $true
    } 
    else {
        Write-Output "No .gitlab directory found in $RepositoryName"
        if (Test-Path -Path "./.github") {
            Write-Output ".github directory already exists, ensuring contents..." 
            $repoType = "sc" 
            
            if ($RepositoryName -like "*snowconvert*") {
                $repoType = "sc"
            }
            elseif ($RepositoryName -like "*sma*") {
                $repoType = "sma"
            }
            elseif ($RepositoryName -like "*ef*") {
                $repoType = "ef"
            }
            
            $configPath = "$configRoot/$repoType/.github"
            if (Test-Path -Path $configPath) {
                Copy-Item -Path "$configPath/*" -Destination "./.github/" -Recurse -Force
            }
            
            Write-Output "Current directory and .github content:"
            Get-Location | Write-Output
            Get-ChildItem -Path .github -Recurse | Format-Table
        } 
        else {
            Write-Output "Creating .github directory..." 
            New-Item -ItemType Directory -Path "./.github" -Force | Out-Null
            
            $repoType = "sc"  
            if ($RepositoryName -like "*snowconvert*") {
                $repoType = "sc"
            }
            elseif ($RepositoryName -like "*sma*") {
                $repoType = "sma"
            }
            elseif ($RepositoryName -like "*ef*") {
                $repoType = "ef"
            }
            
            $configPath = "$configRoot/$repoType/.github"
            if (Test-Path -Path $configPath) {
                Copy-Item -Path "$configPath/*" -Destination "./.github/" -Recurse -Force
            }
        }
    }
}

function Copy-Repositories {
    param (
        [array]$Repositories,
        [string]$CloneDirectory
    )
        
    foreach ($repo in $Repositories) {
        $repoUrl = $null
        $repoName = $null
        
        if ($repo.url) {
            $repoUrl = $repo.url
            $repoName = $repo.name
        }
        elseif ($repo.http_url_to_repo) {
            $repoUrl = $repo.http_url_to_repo
            $repoName = ($repo.path_with_namespace -split '/')[-1]
        }
        
        if (-not $repoUrl -or -not $repoName) {
            Write-Output "Skipping repository with invalid format: $($repo | ConvertTo-Json -Compress)" 
            continue
        }
        
        Write-Output "Processing repository: $repoName" 
        
        $cloneSuccess = Copy-Repository -RepositoryUrl $repoUrl -RepositoryName $repoName
        
        if ($cloneSuccess) {
            Push-Location $repoName
            gh auth status
            gh secret set PR_LIMIT_FILES --body "20" --repo snowflakedb/$repoName
            
            ReplaceFilesGitlabDirectory -RepositoryName $repoName
            ReplacePreCommitHook -RepositoryName $repoName
            
            git status
            git checkout -b support/github-migration
            git add . --verbose
            git commit -m "Add GitHub configuration files"
            git push --set-upstream origin support/github-migration
            
            Pop-Location
        }
        else {
            Write-Output "Failed to clone repository: $repoName, skipping..." 
        }
        
        Write-Output "Completed processing $repoName" 
    }
    
    Pop-Location
}

function MainData {
    Write-Output "Starting migration script..." 
    #$jsonFilePath = "gh-list-migrations-data.json"
    #$jsonFilePath = "gh-list-migrations-ef.json"
    #$jsonFilePath = "gh-list-migrations-sma.json"
    $jsonFilePath = "gh-list-migrations-snowconvert.json"
    $repos = Read-RepositoryData -JsonFilePath $jsonFilePath
    
    Write-Output "Repositories read from JSON file!" 
    Write-Output "Found $($repos.Count) repositories to process"

    $cloneDir = Initialize-CloneDirectory -DirectoryPath "cloned-repos"
    Write-Output "Clone directory initialized!" 

    Copy-Repositories -Repositories $repos -CloneDirectory $cloneDir
    Write-Output "All repositories processed!" 
}

MainData