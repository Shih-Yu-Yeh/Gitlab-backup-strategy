#!/bin/bash

## To-Do: backup the volumns of gitlab server

usage() {
    echo "Unknown Error" | tee -a $log_file_name
    exit 1
}

invalid_user() {
    echo "Please execute backup gitlab script with user \"root\"" | tee -a $log_file_name
    exit 1
}

print_error_msg() {
    echo "[Error] No such service $0" | tee -a $log_file_name
    exit 1
}

do_discard_old_folder() {
    backup_folder_amount=$(ls -drt gitlab_backup_[0-9\-]* | wc -l)
    while [ $backup_folder_amount -gt $limit_amount ]; do
        echo "Discard "$(ls -drt gitlab_backup_[0-9\-]* | awk -v line=$backup_folder_amount 'FNR == line {print $1}') | tee -a $log_file_name
        $(rm -rf $(ls -drt gitlab_backup_[0-9\-]* | awk -v line=$backup_folder_amount 'FNR == line {print $1}')) | tee -a $log_file_name
        backup_folder_amount=$((backup_folder_amount-1))
    done
}

do_discard_old_tar_file() {
    backup_folder_amount=$(ls -alt *.tar | wc -l)
    while [ $backup_folder_amount -gt $limit_amount ]; do
        echo "Discard "$(ls -at *.tar | awk -v line=$backup_folder_amount 'FNR == line {print $1}') | tee -a $log_file_name
        $(rm $(ls -at *.tar | awk -v line=$backup_folder_amount 'FNR == line {print $1}')) | tee -a $log_file_name
        backup_folder_amount=$((backup_folder_amount-1))
    done
}

backup_gitlab() {

    if [ $(whoami) != "root" ]; then
        invalid_user
    fi

    # Enter the folder where the docker compose file is
    cd $target_folder

    # Stop the running container
    container_id=$(docker ps -a --filter name=$gitlab_container_name -q)
    if [ ! -z "$container_id" ] ; then
        # Remove old backups
        { time docker exec -t $gitlab_container_name /bin/bash -c "rm /var/opt/gitlab/backups/*_gitlab_backup.tar"; } 2>&1 | tee -a $log_file
        { time docker exec -t $gitlab_container_name /bin/bash -c "rm /etc/gitlab/config_backup/gitlab_config_*.tar"; } 2>&1 | tee -a $log_file
        # Backup by Gitlab command
        { time docker exec -t $gitlab_container_name gitlab-backup create BACKUP=$timestamp; } 2>&1 | tee -a $log_file_name
        { time docker exec -t $gitlab_container_name /bin/bash -c "gitlab-ctl backup-etc"; } 2>&1 | tee -a $log_file_name
        # Stop container
        { time docker-compose stop gitlab; } 2>&1 | tee -a $log_file_name
        sync
    else
        print_error_msg "gitlab"
    fi

    # Move to the folder to backup 1 layer folder
    cd $tar_path
    mkdir $tar_folder
    rsync -avh $source_folder $tar_folder/

    # Tar folder
    { time tar --numeric-owner -cvf $tar_folder.tar $tar_folder; } 2>&1 | tee -a $log_file_name
    sync

    df -h | tee -a $log_file_name

    rm -rf $tar_folder
    sync

    cd -

    # Move back to the folder where the docker compose file is
    { time docker-compose start $gitlab_container_name; } 2>&1 | tee -a $log_file_name

    cd $tar_path
    # Remain only latest 14 days backup
    #do_discard_old_folder
    do_discard_old_tar_file
}


timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
target_folder="/home/docker/gitlab"
gitlab_container_name="gitlab_14_9_4"
limit_amount=7
script_name=${0%.*}
script_name=${script_name##*/}
log_file_prefix=$target_folder"/log/"$script_name
log_file_name=$log_file_prefix"_"$timestamp".log"

source_folder="/media/servers-3/gitlab_14.9.4-ce.0_20220503"
tar_path="/media/backups-1/gitlab"
tar_folder="gitlab_backup_"$timestamp
tar_file=$tar_folder".tar"

# Delete old log
rm $log_file_prefix\_*.log
touch $log_file_name
chown gitlab:gitlab $log_file_name
chmod 664 $log_file_name
# Create new log
echo "["$timestamp"] Start to backup gitlab" | tee $log_file_name

# Start to backup
backup_gitlab