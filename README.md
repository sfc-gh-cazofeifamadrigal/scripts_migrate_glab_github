# GitLab to GitHub Migration Scripts

This repository contains scripts to facilitate the migration of projects from GitLab to GitHub. These scripts automate various tasks involved in the migration process, ensuring a smooth and efficient transition.

## Structure

The repository is organized into two main directories:

### /migrate
Contains the core migration scripts that handle:
- Repository transfer from GitLab to GitHub
- Initial setup and configuration
- Repository content migration

### /post-migrate
Contains scripts for post-migration tasks such as:
- Repository cleanup
- Verification of migrated content
- Configuration adjustments
- Additional setup requirements

## Usage

1. Configure your GitLab and GitHub credentials
2. Run the migration scripts from the `/migrate` directory
3. After successful migration, run the post-migration scripts from `/post-migrate` directory

## Requirements
- PowerShell
- GitLab API access token
- GitHub API access token
- Appropriate permissions on both platforms

## License
This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.