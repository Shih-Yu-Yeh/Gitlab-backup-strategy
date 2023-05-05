#!/bin/bash

## To-Do: Restore gitlab server from selected volumns

usage() {
    echo "Usage: /bin/bash /home/docker/gitlab/scripts/gitlab_restore.sh -r [TAR_FILE] -p [RESTORE_PATH]" | tee -a $log_file
    echo "  -r  the absolute path of backed up tar file" | tee -a $log_file
    echo "  -p  the absolute path to extract the content of the backed up tar file" | tee -a $log_file
    exit 1
}

error_permission() {
    echo "Check you have read/write permission on the restore path" | tee -a $log_file
    exit 1
}

error_path() {
    echo "Error: Check the restore path: "$0 | tee -a $log_file
    exit 1
}

error_tar_file() {
    echo "Error: Check the tar file: "$0 | tee -a $log_file
    exit 1
}

error_env_setting() {
    echo "Error: Failed to set .env.back to at path: "$0 | tee -a $log_file
    exit 1
}

recover_gitlab() {
    
    # Create new log
    echo "["$timestamp"] Start to recover gitlab with path:"$restore_tar_file | tee $log_file

    # # Extract
    # tar xvf $restore_tar_file -C $restore_path/gitlab_restore/
    # Check the tar file
    echo "Extract "$restore_tar_file"to "$restore_path | tee -a $log_file

    # cd /media/backups-3/gitlab/

    { time tar --same-owner --same-permissions -xvf $restore_tar_file -C $restore_path; } 2>&1 | tee -a $log_file

    sync

    temp_string=${restore_tar_file##*/}
    temp_string=${temp_string%\.tar}
    container_volumes_path=$restore_path/$temp_string
    restore_path=$container_volumes_path/$restore_container_folder

    gitlab_backup_prefix=${container_volumes_path#*gitlab_backup_}
    echo "gitlab_backup_prefix: "$gitlab_backup_prefix

    # Check restore folder
    if [ ! -d $restore_path ]; then
        usage
    fi
    if [ ! -d "$restore_path/data" ]; then
        usage
    fi

    echo "Uncompressed file: "$container_volumes_path | tee -a $log_file

    # Update .env.backup
    echo "FOLDER="$container_volumes_path > $restore_env_file

    # # Check content of env file
    # new_volume=$(cat $restore_env_file)
    # echo "new_volume: "$new_volume
    # if [ -z "$new_volume" ] || [ ! -d "${new_volume#FOLDER=}" ]; then
    #     error_env_setting
    # fi

    # # Move to the directory where docker-compose.yml exists
    # cd $current_folder

    # # Down current container
    # { time docker-compose down; } 2>&1 | tee -a $log_file

    # sync

    # # Up docker compose with new environment file
    # { time docker-compose --env-file $restore_env_file up -d; } 2>&1 | tee -a $log_file

    # sleep 2.5m

    # # Stop modules
    # docker exec $container_name /bin/bash -c "gitlab-ctl stop puma"
    # docker exec $container_name /bin/bash -c "gitlab-ctl stop sidekiq"

    # { time docker exec -t $container_name /bin/bash -c "GITLAB_ASSUME_YES=1 gitlab-backup restore BACKUP=$gitlab_backup_prefix"; } 2>&1 | tee -a $log_file

    # docker exec $container_name /bin/bash -c "gitlab-ctl reconfigure"

    # docker exec -t $container_name /bin/bash -c "gitlab-ctl start"
    # exit 0
}


timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

restore_container_folder="gitlab_14.4.1.ce-0"

current_folder=$(dirname $(realpath "$0"))
current_folder=${current_folder%\/scripts}
log_folder=$current_folder/log
if [ ! -d "$log_folder" ]; then
    mkdir -p $log_folder
fi
script_name=${0##*/}
script_name=${script_name%\.sh}

log_file=$log_folder/$script_name"_"$timestamp.log

restore_env_file=$current_folder/config/.env.recover
rm $restore_env_file
touch $restore_env_file
# Check env file existence
if [ ! -f "$restore_env_file" ]; then
    invalid_env_setting $restore_env_file
fi

# Delete old log
rm $log_folder/$script_name*.log
# Create new log
touch $log_file
chown gitlab:gitlab $log_file
chmod 664 $log_file
echo "["$timestamp"] Start to backup gitlab" | tee $log_file

container_name="gitlab"
restore_tar_file=""
restore_path=""

while getopts "hr:p:" op
do
    case $op in
        h) usage;;
        r) restore_tar_file=$OPTARG;;
        p) restore_path=$OPTARG;;
        *) usage;;
    esac
done

# TO-DO set container name
# if [ -z "$container_name" ]; then
#     usage
# fi

# check_container=$(docker ps | grep $container_name | awk '{print $16}')
# # Input container name does not match any active container
# if [ -z "$check_container" ] || [ $check_container -ne $container_name ]; then
#     usage
# fi

if [ -z "$restore_path" ] || [ -z "$restore_tar_file" ]; then
    usage
fi

# Check path
if [ ! -d $restore_path ];then
    error_path $restore_path
fi

# Check tar file
if [ ! -f "$restore_tar_file" ]; then
    error_tar_file $restore_tar_file
fi

# Create restore folder inside restore_path
command_result=$(mkdir $restore_path/gitlab_restore)
# if [ $command_result == *"tar: Exiting with failure status due to previous errors"* ];then
if [[ $command_result == *"Permission denied"* ]];then
    error_permission
fi

restore_path=$restore_path/gitlab_restore/

recover_gitlab