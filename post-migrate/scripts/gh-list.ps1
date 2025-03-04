function Test-GithubCLI {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "GitHub CLI (gh) is not installed. Please install it first."
        return $false
    }
    return $true
}

function Get-FilteredRepos {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SearchFilter
    )
    
    try { 
        $repos = gh repo list snowflakedb --json "name,description,url,visibility,createdAt,updatedAt,isPrivate" --limit 1000 | 
            ConvertFrom-Json | 
            Where-Object { $_.name -like "*$SearchFilter*" -or $_.description -like "*$SearchFilter*" }
        return $repos
    }
    catch {
        Write-Error "Failed to retrieve repositories: $_"
        return $null
    }
}

function Export-ReposToJson {
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$Repos,
        
        [Parameter(Mandatory=$false)]
        [string]$FilePath
    )
    
    try {
        $jsonOutput = $Repos | ConvertTo-Json -Depth 10
        
        if ($FilePath) {
            if (-not [System.IO.Path]::IsPathRooted($FilePath)) {
                $scriptDirectory = $PSScriptRoot
                if (-not $scriptDirectory) {
                    $scriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
                }
                $FilePath = Join-Path -Path $scriptDirectory -ChildPath $FilePath
            }
            
            $directory = Split-Path -Path $FilePath -Parent
            if ($directory -and -not (Test-Path -Path $directory)) {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
                Write-Host "Created directory: $directory"
            }
            
            $jsonOutput | Out-File -FilePath $FilePath -Force
            Write-Host "Exported results to $FilePath"
        }
        
        return $jsonOutput
    }
    catch {
        Write-Error "Failed to export repositories to JSON: $_"
        return $null
    }
}

function Search-Repositories {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SearchFilter,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputFile = "repo-list-$SearchFilter.json"
    )
    
    if (-not (Test-GithubCLI)) {
        return
    }
    
    $repos = Get-FilteredRepos -SearchFilter $SearchFilter
    
    if (-not $repos) {
        Write-Host "No repositories found matching '$SearchFilter'" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Found $($repos.Count) repositories matching '$SearchFilter'" -ForegroundColor Green
    
    $jsonOutput = Export-ReposToJson -Repos $repos -FilePath $OutputFile
    
    return $jsonOutput
}

$SearchFilter = "migrations-data"
$OutputFile = "gh-list-$SearchFilter.json"
Search-Repositories -SearchFilter $SearchFilter -OutputFile $OutputFile

$SearchFilter = "migrations-snowconvert"
$OutputFile = "gh-list-$SearchFilter.json"
Search-Repositories -SearchFilter $SearchFilter -OutputFile $OutputFile

$SearchFilter = "migrations-sma"
$OutputFile = "gh-list-$SearchFilter.json"
Search-Repositories -SearchFilter $SearchFilter -OutputFile $OutputFile

$SearchFilter = "migrations-ef"
$OutputFile = "gh-list-$SearchFilter.json"
Search-Repositories -SearchFilter $SearchFilter -OutputFile $OutputFile