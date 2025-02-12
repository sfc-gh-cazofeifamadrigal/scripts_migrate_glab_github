
# This script is used to move a directory from one repository to another while preserving the history of the files.
# The script performs the following steps:
# 1. Clones the source repository to a local directory.
# 2. Clones the target repository to a local directory.
# 3. Changes the directory structure of the source repository to the desired structure.
# 4. Moves the files from the source repository to the target repository.
# 5. Commits the changes to the target repository.
# 6. Pushes the changes to the remote repository.
# The script requires the following parameters:
# - SrcRepoURL: The URL of the source repository.
# - SrcDirectory: The directory to move from the source repository.
# - SrcRepoPath: The local path to clone the source repository.
# - TargetRepoURL: The URL of the target repository.
# - TargetDirectory: The directory to move the files to in the target repository.
# - TargetRepoPath: The local path to clone the target repository.
# - TempBranch: The name of the temporary branch to use in the target repository.
# - SrcBaseBranch: The base branch of the source repository.
# - TargetBaseBranch: The base branch of the target repository.
# - gitLabAccountUsername: The username of the GitLab account.
# - gitLabAccountEmail: The email of the GitLab account.
# - gitLabPat: The personal access token (PAT) of the GitLab account.
# - TempBranchExists: A flag indicating whether the temporary branch exists in the target repository.

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
$DefaultTargetBranchName = $TargetBaseBranch

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

Show ("The Git Repository URL from copying: {0}" -f $SrcRepoUrl)
Show ("The Git Repository URL to move : {0}" -f $TargetRepoUrl)
Show ("The local path for cloning the source repository: {0}" -f $SrcRepoPath)
Show ("The local path for cloning the target repository: {0}" -f $TargetRepoPath)
Show ("The Source Directory from copying files: {0}" -f $SrcDirectory)
Show ("The Target Directory to move files: {0}" -f $TargetDirectory)
Show ("Temporary Branch: {0}" -f $TempBranch)
Show ("Working with Source Branch Name: {0}" -f $DefaultSourceBranchName)
Show ("Working with Target Branch Name: {0}" -f $DefaultTargetBranchName)

$ErrorActionPreference = "Stop"
$env:GIT_REDIRECT_STDERR = '2>&1'

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
    $p.WaitForExit()
    $ExitCode = $p.ExitCode
    return $ExitCode, $stdout
}

function InvokeGitCommand($GitArguments) {
    Show "Running: git $GitArguments"
    $ExitCode, $stdout, $stderr = (ExecuteCommand -commandPath git -commandArguments "$GitArguments")
    Show "stdout: $stdout"
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

Show ("Cloning source repository to {0}" -f $SrcRepoPath)
InvokeGitCommand -GitArguments "clone $SrcRepoUrl $SrcRepoPath"

Show ("Cloning target repository to {0}" -f $TargetRepoPath)
InvokeGitCommand -GitArguments "clone $TargetRepoUrl $TargetRepoPath"

Push-Location $TargetRepoPath
InvokeGitCommand -GitArguments "status"
Show "Setting $SrcRepoPath as current directory..."
Push-Location $SrcRepoPath
Write-host (gci *)
InvokeGitCommand -GitArguments "filter-branch --subdirectory-filter `"$SrcDirectory`" -- --all"
Show "Cleaning unwanted data from source repository..."
InvokeGitCommand -GitArguments "reset --hard"
InvokeGitCommand -GitArguments "gc --aggressive"
InvokeGitCommand -GitArguments "prune"
InvokeGitCommand -GitArguments "clean -fd"
Show "Creating the new directory structure..."
New-Item -ItemType Directory -Path $TargetDirectoryPath -Force
Show "Moving all files to the new directory structure..."
# This command is summoned using the & directive. The gci * causes issues when running it from the InvokeGitCommand
& git mv -v -f -k (gci *) "$TargetDirectoryPath"
if (!$?) {
    Show "Git command failure: $GitArguments"
    CleanUpAll
    Write-Error "ERROR: An exception has been found"
}
InvokeGitCommand -GitArguments "add . --verbose"
Show "Committing the changes locally..."
InvokeGitCommand -GitArguments "commit -m `"Relocated files from $SrcDirectory to $TargetDirectory`""
Show(Get-ChildItem . -Recurse -Depth 2 | Format-Table)
Show "Setting $TargetRepoPath as current directory..."
Pop-Location
Push-Location $TargetRepoPath

if (![string]::IsNullOrEmpty($TempBranch)) {
    if ($TempBranchExists -eq "true") {
        InvokeGitCommand -GitArguments "checkout $TempBranch"
    }
    else {
        InvokeGitCommand -GitArguments "checkout -b $TempBranch"
        InvokeGitCommand -GitArguments "status"
        InvokeGitCommand -GitArguments "push --set-upstream origin $TempBranch"
    }
}
Show "Adding src repository as a branch to the target repository..."
InvokeGitCommand -GitArguments "remote add reposource $SrcRepoPath"
Show "Merging the src repository into the target repository with history..."
InvokeGitCommand -GitArguments "pull reposource $DefaultSourceBranchName --allow-unrelated-histories -Xours"
InvokeGitCommand -GitArguments "remote rm reposource"
Show(Get-ChildItem . -Recurse -Depth 2 | Format-Table)
Show "SUCCESS: Pushing changes to remote repository..."
InvokeGitCommand -GitArguments "status"
InvokeGitCommand -GitArguments "push"
CleanUpLocalRepos
Pop-Location