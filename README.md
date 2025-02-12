# GitLab to GitHub Migration Scripts

This repository contains scripts to facilitate the migration of projects from GitLab to GitHub. These scripts automate various tasks involved in the migration process, ensuring a smooth and efficient transition.

## Features

- **Automated Migration**: Scripts to automate the migration of repositories, issues, and merge requests from GitLab to GitHub.
- **Data Integrity**: Ensures that all data is accurately transferred without loss.
- **Customizable**: Easily configurable to suit different project requirements.

## Prerequisites

- Git
- GLab
- GitHub CLI
- GitLab Personal Access Token

## Installation

1. Clone the repository:
    ```sh
    cd merge
    ```

## Usage

1. Configure your environment variables:
    create a GITLAB_TOKEN
    
2. Review and update the configuration section in `call.ps1`:

    ```
    $gitServer = "https://snow.gitlab-dedicated.com/snowflakecorp"
    $gitLabAccountUsername = "svc_gitlab_snowflake_usernamespaces"
    $gitLabAccountEmail = "svc_gitlab_snowflake_username@snowflake.com"
    $gitLabPat = "glpat-******************"
    ```

2. Run the migration script:
    ```sh
    pwsh -c ./call.ps1
    ```

## Configuration

You can customize the migration process by modifying the `call.ps1` file. This file allows you to specify various options such as repository names, issue labels, and more flagspwsh -c ./_merge_call.ps1

## License

This project is licensed under the Apache 2.0 License. See the  file for details.

## Acknowledgements

Special thanks to all contributors and the open-source community for their support.
