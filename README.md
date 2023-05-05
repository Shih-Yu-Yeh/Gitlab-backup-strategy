<!--
*** Thanks for checking out the Best-README-Template. If you have a suggestion
*** that would make this better, please fork the repo and create a pull request
*** or simply open an issue with the tag "enhancement".
*** Thanks again! Now go create something AMAZING! :D
***
***
***
*** To avoid retyping too much info. Do a search and replace for the following:
*** github_username, repo_name, twitter_handle, email, project_title, project_description
-->



<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
[![Contributors][contributors-shield]][contributors-url]


<!-- PROJECT LOGO -->
<br />
<p align="center">
  <h3 align="center">Gitlab-backup-strategy</h3>

 
</p>


TABLE OF CONTENTS
<details open="open">
  <summary><h2 style="display: inline-block">Table of Contents</h2></summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#repository">Repository</a></li>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
        <li><a href="#scripts-for-gitlab-server">Scripts for Gitlab Server</a></li>
        <ul>
          <li><a href="#backup">Backup</a></li>
          <li><a href="#recover">Recover</a></li>
        </ul>
        <li><a href="#email-notification-smtp">Email Notification (SMTP)</a></li>
        <li><a href="#jira-integration-for-smart-commit">Jira Integration for Smart Commit</a></li>
        <li><a href="#usage">Usage</a></li>
        <li><a href="#troubleshooting">Troubleshooting</a></li>
      </ul>
    </li>
  </ol>
</details>


<!-- ABOUT THE PROJECT -->
## About The Project

This project is about to set up a self managed Gitlab.

The method to set up Gitlab is to use the Gitlab-ce docker image to create a container for self-hosted Gitlab on our local server.


### Built with

* Docker Compose

<!-- GETTING STARTED -->
## Getting Started

To set up Gitlab server from the docker images, follow the simple steps below.

### Prerequisites

*   create an user only for Gitlab and add it into the group of docker

    ```sh
    $ sudo adduser gitlab
    $ sudo usermod -aG docker gitlab
    ```

*   Download the repository

    ```sh
    $ git clone git@www.testarea.com:Gitlab-backup-strategy/gitlab.git
    ```

### Installation

1.  Create the folder for mapping volumes and save the path of the folder in .env

    ```sh
    $ mkdir /media/servers-3
    ```

    ```sh
    $ cat .env
    FOLDER=/media/servers-3
    ```

2.  Create the container

    ```sh
    $ cd gitlab
    # Change user to Gitlab
    $ su gitlab
    # Execute the script to set up the container
    $ ./gitlab_docker.sh
    ```

### Scripts for Gitlab Server

To keep the Gitlab server alive and face any damage happened unexpectedly, it is necessary to backup the important data daily and to be able to recover the server from backuped data immediately. To achieve this goal, we add the following 5 scripts:
-   gitlab_docker.sh (Set up container at beginning)
-   gitlab_backup.sh (Backup gitlab volume into a tar file)
-   gitlab_ftpupload.sh (Upload the tar files to remote Nas)
-   gitlab_recover.sh (Decompress a tar file to recover the server)
-   godaddy_verify.py (To prove the ownership of xsquareiot.serveexchange.com when Godady requests to verify)


#### Backup

1.  Backup data

    Add a crontab rule in user, root, to execute backup script everyday.

    ```sh
    $ sudo crontab -u root -e
    ```

    ```diff
    ...
    # For more information see the manual pages of crontab(5) and cron(8)
    #
    # m h  dom mon dow   command
    15 0 * * * /bin/bash /home/docker/redmine/scripts/redmine_compress.sh -c
    30 0 * * * cd /home/docker/nextcloud && /bin/bash ./scripts/nextcloud_backup.sh -b
    45 03 * * 7 cd /home/docker/nextcloud && /bin/bash ./scripts/nextcloud_ftpupload.sh -u
    + 0 1 * * * /bin/bash /home/docker/gitlab/scripts/gitlab_backup.sh
    ```

2.  Upload to remote Nas

    Upload the backup data to remote Nas server every two weeks.

    ```sh
    $ sudo crontab -u root -e
    ```

    ```diff
    # For more information see the manual pages of crontab(5) and cron(8)
    #
    # m h  dom mon dow   command
    ...
    0 1 * * * /bin/bash /home/docker/gitlab/scripts/gitlab_backup.sh
    + 0 2 * * 7 /bin/bash /home/docker/gitlab/scripts/gitlab_ftpupload.sh
    ```

#### Recover

Execute the gitlab_recover.sh with absolute path of the tar file.

```sh
$ ./gitlab_script.sh -r /media/backups-3/gitlab/XXXX.tar
```

### Email Notification (SMTP)

To notify the users with emails, the SMTP feature should be enabled.

*   Create a free account on [SendGrid](https://sendgrid.com/).
    -   Use the email of Gitlab to register an account which allow sending 100 emails per day for free.

*   Create a sender identity and a API key on [SendGrid](https://sendgrid.com/).
    

*   Update the configuration on Gitlab and then compose-down and compose-up the container
    -   docker-compose.yml
    -   SendGrid
        ```diff
        services:
          gitlab:
            image: 'gitlab/gitlab-ce'
            restart: always
            hostname: 'www.testarea.com'
            environment:
              GITLAB_OMNIBUS_CONFIG: |
                external_url 'https://www.testarea.com:8829'
                gitlab_rails['gitlab_shell_ssh_port'] = 2224
                gitlab_rails['initial_root_password'] = 'initial_root_password'
                gitlab_rails['backup_archive_permissions'] = 0644
                gitlab_rails['backup_keep_time'] = 604800
        +        gitlab_rails['smtp_enable'] = true
        +        gitlab_rails['smtp_address'] = "smtp.sendgrid.net"
        +        gitlab_rails['smtp_port'] = 587
        +        gitlab_rails['smtp_user_name'] = "apikey"
        +        gitlab_rails['smtp_password'] = "smtp_password"
        +        gitlab_rails['smtp_domain'] = "smtp.sendgrid.net"
        +        gitlab_rails['smtp_authentication'] = "plain"
        +        gitlab_rails['smtp_enable_starttls_auto'] = true
        +        gitlab_rails['smtp_tls'] = false
        +        gitlab_rails['gitlab_email_from'] = 'admin@admin.com'
        +        gitlab_rails['gitlab_email_reply_to'] = 'admin@admin.com'
            ports:
        ```
        The password in above is the API key generated in SendGrid.
    -   AWS
        ```diff
        version: '2'
        services:
          gitlab_14_9_4:
            image: 'gitlab/gitlab-ce:14.9.4-ce.0'
            restart: always
            hostname: 'www.testarea.com'
            container_name: gitlab_14_9_4
            environment:
              TZ:
                'Asia/Taipei'
              GITLAB_OMNIBUS_CONFIG: |
                external_url 'https://www.testarea.com'
                gitlab_rails['initial_root_password'] = 'initial_root_password'
                gitlab_rails['backup_archive_permissions'] = 0644
                gitlab_rails['backup_keep_time'] = 86400
        +       gitlab_rails['smtp_enable'] = true
        +       gitlab_rails['smtp_address'] = "email-smtp.ap-northeast-1.amazonaws.com"
        +       gitlab_rails['smtp_port'] = 465
        +       gitlab_rails['smtp_user_name'] = "smtp_user_name"
        +       gitlab_rails['smtp_password'] = "smtp_password"
        +       gitlab_rails['smtp_domain'] = "smtp_domain.com"
        +       gitlab_rails['smtp_authentication'] = "login"
        +       gitlab_rails['smtp_enable_starttls_auto'] = true
        +       gitlab_rails['smtp_tls'] = true
        +       gitlab_rails['gitlab_email_from'] = 'admin@admin.com'
        +       gitlab_rails['gitlab_email_reply_to'] = 'admin@admin.com'
                gitlab_rails['time_zone'] = 'Asia/Taipei'
            ports:
              - '443:443'
              - '2224:22'
            volumes:
              - '${FOLDER}/config:/etc/gitlab'
              - '${FOLDER}/logs:/var/log/gitlab'
              - '${FOLDER}/data:/var/opt/gitlab'
        ```

### Jira Integration for Smart Commit

Trusted CA signed SSL certificates is a must when integrating Gitlab to Jira.

### Usage

*   [Gitab Docker Images](https://docs.gitlab.com/ee/install/docker.html)

*   [SMTP With SendGrid](https://xsquareiot.atlassian.net/wiki/spaces/ATD/pages/118816769/SMTP+with+SendGrid)

### Troubleshooting

1.  Failed to recover gitlab
    - Error message in container: *Upgrade failed. Could not check for unmigrated data on legacy storage.*
    - Scenario: use user "gitlab" to execute the git_recover.sh with the tar file generated by gitlab_backup.sh under user "root"
    - Root cause: permission issue.
    - Solution: use user "root" to execute git_recover.sh to extract the compressed files