#!/usr/bin/env pwsh
# The script performs the following steps:
# 1. Set the source local environment.
# 2. Set the target local environment.
# 3. Merge the source repository to the target repository.
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
# Example usage:
# ./merge_directories.ps1 -SrcRepoURL "https://gitlab.com/username/source-repo.git" -SrcDirectory "source-dir" -SrcRepoPath "source-repo" -TargetRepoURL "https://gitlab.com/username/target-repo.git" -TargetDirectory "target-dir" -TargetRepoPath "target-repo" -TempBranch "temp-branch" -SrcBaseBranch "master" -TargetBaseBranch "master" -gitLabAccountUsername "username" -gitLabAccountEmail "email" -gitLabPat "pat" -TempBranchExists "false"

chmod +x ./merge_directories.ps1

#*****************************************************Local
$SrcRepoPath = "$PSScriptRoot/repos-source"
$TargetRepoPath = "$PSScriptRoot/repos-target"

if (-not (Test-Path $SrcRepoPath)) {
    New-Item -ItemType Directory -Path $SrcRepoPath -Force
    Write-Host "Source directory created: $SrcRepoPath"
}
if (-not (Test-Path $TargetRepoPath)) {
    New-Item -ItemType Directory -Path $SrcRepoPath -Force
    Write-Host "Target directory created: $TargetRepoPath"
}
#*****************************************************GitLab
$gitServer = "https://snow.gitlab-dedicated.com/snowflakecorp"
$gitLabAccountUsername = "svc_gitlab_snowflake_usernamespaces"
$gitLabAccountEmail = "svc_gitlab_snowflake_username@snowflake.com"
$gitLabPat = "glpat-******************"

#*****************************************************Target
$TargetRepoURL = $gitServer + "/SE/sit/SIT.EF.SQL.git"
$SrcBaseBranch = "master"
$TempBranch = "support/tmp-move-merge-tests"

#*****************************************************Source-TestAssemblies
$SrcRepoURL = $gitServer + "/SE/sit/SIT.SMA.EngineCommon.git"
$SrcDirectory = "TestAssemblies"
$TargetDirectory = "SIT.SMA.EngineCommon/TestAssemblies"
$TempBranchExists = "false"
./merge_directories.ps1 -SrcRepoURL $SrcRepoURL -SrcDirectory $SrcDirectory -SrcRepoPath $SrcRepoPath -TargetRepoURL $TargetRepoURL -TargetDirectory $TargetDirectory -TargetRepoPath $TargetRepoPath -TempBranch $TempBranch -SrcBaseBranch $SrcBaseBranch -TargetBaseBranch $SrcBaseBranch -gitLabAccountUsername $gitLabAccountUsername -gitLabAccountEmail $gitLabAccountEmail -gitLabPat $gitLabPat -TempBranchExists $TempBranchExists

#*****************************************************Source-Assemblies
$SrcRepoURL = $gitServer + "/SE/sit/SIT.SMA.EngineCommon.git"
$SrcDirectory = "Assemblies"
$TargetDirectory = "SIT.SMA.EngineCommon/Assemblies"
$TempBranchExists = "true"
./merge_directories.ps1 -SrcRepoURL $SrcRepoURL -SrcDirectory $SrcDirectory -SrcRepoPath $SrcRepoPath -TargetRepoURL $TargetRepoURL -TargetDirectory $TargetDirectory -TargetRepoPath $TargetRepoPath -TempBranch $TempBranch -SrcBaseBranch $SrcBaseBranch -TargetBaseBranch $SrcBaseBranch -gitLabAccountUsername $gitLabAccountUsername -gitLabAccountEmail $gitLabAccountEmail -gitLabPat $gitLabPat -TempBranchExists $TempBranchExists

#*****************************************************Merge-Request-GitLab
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
#*****************************************************Merge-Request-GitLab
