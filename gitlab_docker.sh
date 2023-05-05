#!/bin/bash

## ToDo: Create the container for gitlab server


usage() {
    echo "Unknown option" | tee -a $log_file_name
    echo "./gitlab_docker.sh" | tee -a $log_file_name
    exit 1
}

invalid_user() {
    echo "Please execute script with user \"gitlab\"" | tee -a $log_file_name
    exit 1
}

create_gitlab_container() {
    if [ $(whoami) != "gitlab" ]; then
        invalid_user
    fi

    cd $target_folder
    #echo "Current path: "$PWD | tee -a $log_file_name
    $(docker-compose up -d)
}

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
log_file_name="/home/docker/gitlab/log/gitlab_docker_"$timestamp".log"

rm /home/xsiot/docker/gitlab/log/gitlab_docker_*.log 2>&1
echo "["$timestamp"] Start to create the container for Gitlab" | tee $log_file_name

target_folder="/home/docker/gitlab"

create_gitlab_container