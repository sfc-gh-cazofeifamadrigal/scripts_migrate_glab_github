
# This script is used to move files from one directory to another directory in a git repository with history.
# How it works:
# clone the source repository and the target repository to local directories.
# move the files from the source directory to the target directory in the source repository.
# merge the source repository into the target repository.
# push the changes to the target repository.
# delete the local directories.

param (
    [string]$SrcRepoURL,
    [string]$SrcDirectory,
    [string]$TargetRepoURL,
    [string]$TargetDirectory,
    [string]$TempBranch,
    [string]$SrcBaseBranch,
    [string]$TargetBaseBranch,
    [string]$gitLabAccountUsername,
    [string]$gitLabAccountEmail,
    [string]$gitLabPat,
    [string]$SrcRepoPath,
    [string]$TargetRepoPath,
    [string]$TempBranchExists
)

$DefaultSourceBranchName = $SrcBaseBranch

$sa_username = $gitLabAccountUsername
$sa_usermail = $gitLabAccountEmail
$sa_pat = $gitLabPat

git config --global user.email "${sa_usermail}"  
git config --global user.name "${sa_username}" 
git config --global pull.ff only
git config --global pull.ff true


$SrcRepoUrl = $SrcRepoUrl.replace("https://", "https://${sa_username}:${sa_pat}@")
$TargetRepoUrl = $TargetRepoUrl.replace("https://", "https://${sa_username}:${sa_pat}@")

Set-Alias Show Write-Output

$info = @{
    "The Git Repository URL from copying"              = $SrcRepoUrl
    "The Git Repository URL to move"                   = $TargetRepoUrl
    "The local path for cloning the source repository" = $SrcRepoPath
    "The local path for cloning the target repository" = $TargetRepoPath
    "The Source Directory from copying files"          = $SrcDirectory
    "The Target Directory to move files"               = $TargetDirectory
    "Temporary Branch"                                 = $TempBranch
    "Working with Source Branch Name"                  = $DefaultSourceBranchName
}

foreach ($key in $info.Keys) {
    Show ("{0}: {1}" -f $key, $info[$key])
    Show "`r`n"
}

$ErrorActionPreference = "Stop"
$env:GIT_REDIRECT_STDERR = '2>&1'

function Test-UrlExists {
    param (
        [string]$Url
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "URL exists: $Url"
            return $true
        }
    }
    catch {
        Write-Host "URL does not exist: $Url"
        return $false
    }
}


function Test-Urls {
    param (
        [string[]]$Urls
    )

    foreach ($Url in $Urls) {
        if (-not (Test-UrlExists -Url $Url)) {
            Write-Error "URL is not valid: $Url, exiting script"
            exit 1
        }
    }
}

Test-Urls -Urls @($SrcRepoUrl, $TargetRepoUrl)


function CleanUpBranch() {
    git push origin --delete $TempBranch
}

function CleanUpLocalRepos() {
    Pop-Location
    Remove-Item -Recurse -Force -Path $SrcRepoPath -ErrorAction Ignore
    Remove-Item -Recurse -Force -Path $TargetRepoPath -ErrorAction Ignore
}

function CleanUpAll() {
    CleanUpLocalRepos
}

function ExecuteCommand ($commandPath, $commandArguments) {
    $ExitCode = 0
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $commandPath
    $pinfo.WorkingDirectory = Get-Location
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $commandArguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $ExitCode = $p.ExitCode
    return $ExitCode, $stdout, $stderr
}

function InvokeGitCommand($GitArguments) {
    Show "Running: git $GitArguments"
    $ExitCode, $stdout, $stderr = (ExecuteCommand -commandPath git -commandArguments "$GitArguments")
    Show "stdout: $stdout"
    Show "stderr: $stderr"
    $CommandSuccessful = $ExitCode -eq 0

    if (!$CommandSuccessful) {
        Show "Git command failure: $GitArguments"
        CleanUpAll
        Write-Error "An error has occurred"
    }
}

$SrcDirectoryPath = Join-Path -Path $SrcRepoPath -ChildPath $SrcDirectory
$TargetDirectoryPath = Join-Path -Path $SrcRepoPath -ChildPath $TargetDirectory

Show $SrcDirectoryPath
Show $TargetDirectoryPath

if (Test-Path -Path $SrcRepoPath) {
    Show ("Removing existing directory: {0}" -f $SrcRepoPath)
    Remove-Item -Recurse -Force -Path $SrcRepoPath
}
Show ("Cloning source repository to {0}" -f $SrcRepoPath)
InvokeGitCommand -GitArguments "clone $SrcRepoUrl $SrcRepoPath"

if (Test-Path -Path $TargetRepoPath) {
    Show ("Removing existing directory: {0}" -f $TargetRepoPath)
    Remove-Item -Recurse -Force -Path $TargetRepoPath
}
Show ("Cloning target repository to {0}" -f $TargetRepoPath)
InvokeGitCommand -GitArguments "clone $TargetRepoUrl $TargetRepoPath"

Push-Location $TargetRepoPath

if (![string]::IsNullOrEmpty($TempBranch)) {
    if ($TempBranchExists -eq "true") {
        Show "Switching to existing branch... $TempBranch"
        InvokeGitCommand -GitArguments "fetch  --all --tags --prune"
        InvokeGitCommand -GitArguments "checkout $TempBranch"
        InvokeGitCommand -GitArguments "status"
    }
    else {
        Show "Creating a new branch... $TempBranch"
        InvokeGitCommand -GitArguments "fetch  --all --tags --prune"
        InvokeGitCommand -GitArguments "checkout -b $TempBranch"
        InvokeGitCommand -GitArguments "status"
        InvokeGitCommand -GitArguments "push --set-upstream origin $TempBranch"
    }
}

try {
    Show "Setting $SrcRepoPath as current directory..."
    Push-Location $SrcRepoPath
    InvokeGitCommand -GitArguments "filter-branch --subdirectory-filter `"$SrcDirectory`" -- --all"
    Show "Cleaning unwanted data from source repository..."
    InvokeGitCommand -GitArguments "reset --hard"
    InvokeGitCommand -GitArguments "gc --aggressive"
    InvokeGitCommand -GitArguments "prune"
    InvokeGitCommand -GitArguments "clean -fd"
    Show "Creating the new directory structure..."
    New-Item -ItemType Directory -Path $TargetDirectoryPath -Force
    Show "Moving all files to the new directory structure..."
    $GitArguments = "mv -v -f -k (gci *) `"$TargetDirectoryPath`""
    Show $GitArguments
    & git mv -v -f -k (gci *) "$TargetDirectoryPath"
    if (!$?) {
        throw "Git command failure: $GitArguments"
    }
    InvokeGitCommand -GitArguments "add ."
    $changes = InvokeGitCommand -GitArguments "status --porcelain"
    if ($changes -ne "") {
        Show "Committing the changes locally..."
        $commitMessage = "Relocated files from $SrcDirectory to $TargetDirectory"
        InvokeGitCommand -GitArguments "commit -m `"$commitMessage`""
    }
    else {
        Show "No changes to commit."
    }

    Show(Get-ChildItem . -Recurse -Depth 2 | Format-Table)
    Show "Setting $TargetRepoPath as current directory..."
    Pop-Location
    Push-Location $TargetRepoPath

    git fetch origin 
    $branchExists = (git branch -r | Select-String -Pattern "origin/$DefaultSourceBranchName")
    if ($branchExists) {
        Show "Branch $DefaultSourceBranchName exists in remote. Proceeding with pull."
    }
    else {
        throw "Branch $DefaultSourceBranchName does not exist in remote. Aborting pull."
    }

    Show "Adding src repository as a branch to the target repository..."
    InvokeGitCommand -GitArguments "remote add reposource $SrcRepoPath"
    Show "Merging the src repository into the target repository with history..."

    Get-Location
    $GitArguments = "pull reposource $DefaultSourceBranchName --allow-unrelated-histories -Xours"
    Show $GitArguments

    InvokeGitCommand -GitArguments "pull reposource $DefaultSourceBranchName --allow-unrelated-histories -Xours"
    InvokeGitCommand -GitArguments "remote rm reposource"
    Show(Get-ChildItem . -Recurse -Depth 1 | Format-Table)
    Show "SUCCESS: Pushing changes to remote repository..."
    InvokeGitCommand -GitArguments "status"
    InvokeGitCommand -GitArguments "push"
}
catch {
    Show "ERROR: $_"
    CleanUpAll
    Write-Error "An exception has been found"
}
finally {
    CleanUpLocalRepos
    Pop-Location
}