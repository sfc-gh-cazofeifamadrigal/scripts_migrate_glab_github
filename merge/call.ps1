# Example usage:
# ./merge_directories.ps1 -SrcRepoURL "https://gitlab.com/username/source-repo.git" -SrcDirectory "source-dir" -SrcRepoPath "source-repo" -TargetRepoURL "https://gitlab.com/username/target-repo.git" -TargetDirectory "target-dir" -TargetRepoPath "target-repo" -TempBranch "temp-branch" -SrcBaseBranch "master" -TargetBaseBranch "master" -gitLabAccountUsername "username" -gitLabAccountEmail "email" -gitLabPat "pat" -TempBranchExists "false"

chmod +x ./merge_directories.ps1

function Test-DirectoriesExist {
    param (
        [string]$SrcRepoPath,
        [string]$TargetRepoPath
    )

    if (Test-Path $SrcRepoPath) {
        Remove-Item -Recurse -Force -Path $SrcRepoPath -ErrorAction Ignore
        Write-Host "Source directory removed: $SrcRepoPath"
    }
    New-Item -ItemType Directory -Path $SrcRepoPath -Force
    Write-Host "Source directory created: $SrcRepoPath"

    if (Test-Path $TargetRepoPath) {
        Remove-Item -Recurse -Force -Path $TargetRepoPath -ErrorAction Ignore
        Write-Host "Target directory removed: $TargetRepoPath"
    }
    New-Item -ItemType Directory -Path $TargetRepoPath -Force
    Write-Host "Target directory created: $TargetRepoPath"
}

function Test-TempBranchExists {
    $tempBranchExistsInput = Read-Host "Does the temporary branch exist? (1 = true, 0 = false)"
    if ($tempBranchExistsInput -eq "1") {
        $TempBranchExists = "true"
        Write-Host "Temporary branch exists."
    } else {
        $TempBranchExists = "false"
        Write-Host "Temporary branch does not exist."
    }
    return $TempBranchExists
}

#*****************************************************Variables
$SrcRepoPath = "$PSScriptRoot/repos-source"
$TargetRepoPath = "$PSScriptRoot/repos-target"

#*****************************************************GitLab
$gitServer = "https://snow.gitlab-dedicated.com/snowflakecorp"
$gitLabAccountUsername = "svc_gitlab_snowflake_usernamespaces"
$gitLabAccountEmail = "svc_gitlab_snowflake_username@snowflake.com"
$gitLabPat = "glpat-******************"

#*****************************************************Target
$TargetRepoURL = $gitServer + "/SE/sit/SIT.SMA.Engine.git"
$TempBranch = "support/tmp-move-merge-all"
$SrcBaseBranch = "master"
$TargetBaseBranch = "master"

#*****************************************************Source
$IsMerged = $true
$SrcRepoURL = $gitServer + "/SE/sit/SIT.SMA.Scanner.GenericScanner.git"
if (-not $IsMerged) {
    
    $SrcDirectory = "GenericScannerAssessmentCore"
    $TargetDirectory = "GenericScanner/Assemblies"

    Test-DirectoriesExist -SrcRepoPath $SrcRepoPath -TargetRepoPath $TargetRepoPath
    $TempBranchExists = Test-TempBranchExists
    ./merge_directories.ps1 -SrcRepoURL $SrcRepoURL -SrcDirectory $SrcDirectory -SrcRepoPath $SrcRepoPath -TargetRepoURL $TargetRepoURL -TargetDirectory $TargetDirectory -TargetRepoPath $TargetRepoPath -TempBranch $TempBranch -SrcBaseBranch $SrcBaseBranch -TargetBaseBranch $TargetBaseBranch -gitLabAccountUsername $gitLabAccountUsername -gitLabAccountEmail $gitLabAccountEmail -gitLabPat $gitLabPat -gitLabGroup $gitLabGroup -TempBranchExists $TempBranchExists
}

#*****************************************************PR
if (-not (Test-Path $TargetRepoPath)) {
    New-Item -ItemType Directory -Path $SrcRepoPath -Force
    Write-Host "Target directory created: $TargetRepoPath"
    git clone $TargetRepoUrl $TargetRepoPath
    Push-Location $TargetRepoPath
    glab auth status
    glab mr create --target-branch $SrcBaseBranch --title "GitLab Migration merge" --description "DevOps GitLab Configuration Repositories Migration Merge" --label "devops"
    glab mr list -g "snowflakecorp/SE/sit" --label "devops" --merged=false
    Pop-Location
    Remove-Item -Recurse -Force -Path $TargetRepoPath -ErrorAction Ignore
}

