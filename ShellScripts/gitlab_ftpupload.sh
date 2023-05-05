#!/bin/bash

## Upload daily backup to Synology Nas server



invalid_user() {
    echo "Please execute ftp uploadomg with user \"root\"" | tee -a $log_file_name
    exit 1
}

notUploadInDualWeek() {
    echo "Not upload on even weeks" | tee -a $log_file_name
    exit 1
}

upload_gitlab_to_ftp() {
    if [ $(expr $(date +%W) % 2) -eq 0 ]; then
        notUploadInDualWeek
    fi

    if [ $(whoami) != "root" ]; then
        invalid_user
    fi

    # Move to the folder where saving the backup folders
    cd $backup_folder

    #tar_list=$(ls -drt gitlab_backup_[0-9\-]*)
    tar_list=$(find ./ -type f -name "gitlab_backup_*.tar" -printf "%p\n" | sort -nr)

    # Create folder on Nas
    check_dir=$(lftp $user_name:$user_passwd@$host_name -e "set ssl:verify-certificate false; ls $target_directory | grep $nas_upload_folder;exit" 2>&1 | tee -a $log_file_name)
    if [ -z "$check_dir" ]; then
        lftp $user_name:$user_passwd@$host_name -e "set ssl:verify-certificate false; cd $target_directory;mkdir $nas_upload_folder;exit" 2>&1 | tee -a $log_file_name
    fi

    target_directory=$target_directory$nas_upload_folder
    echo "Upload to Nas:"$target_directory | tee -a $log_file_name

    while [ $try_round -le $round_limit ]; do
        echo ">>> Round "$try_round | tee -a $log_file_name
        echo "Upload files: "$tar_list | tee -a $log_file_name
        # Upload to nas through lftp
        for uploading_tar in $tar_list; do
            if [ -f $uploading_tar ]; then
                uploading_size=$(ls -al $uploading_tar | awk '{print $5}')
                # Upload file
                { time lftp $user_name:$user_passwd@$host_name -e "set ssl:verify-certificate false; cd $target_directory; put $uploading_tar;exit"; } 2>&1 | tee -a $log_file_name

                # Check if file is successfully uploaded to nas
                check_upload=$(lftp $user_name:$user_passwd@$host_name -e "set ssl:verify-certificate false; ls $target_directory'/'$uploading_tar;exit" 2>&1 | tee -a $log_file_name)
                echo "check_upload: "$check_upload | tee -a $log_file_name
                uploaded_size=$(echo $check_upload | awk '{print $5}')
                echo "Size (to uploading/uploaded): "$uploading_size"/ "$uploaded_size | tee -a $log_file_name
                if [ "$uploading_size" -eq "$uploaded_size" ]; then
                    echo "[Successed $(date +"%Y-%m-%d_%H-%M-%S") ] Upload '"$uploading_tar"' with size="$uploading_size | tee -a $log_file_name
                else
                    echo "[Failed $(date +"%Y-%m-%d_%H-%M-%S") ] Upload '"$uploading_tar"' with size="$uploading_size" with error - "$check_upload | tee -a $log_file_name
                    # Add failed updating file to retry list
                    if [ ! -z "$retry_tar_list" ]; then
                        retry_tar_list=$retry_tar_list" "
                    fi
                    retry_tar_list=$retry_tar_list$uploading_tar
                fi
            else
                echo "File, "$tar_file_name", doesn't exist." | tee -a $log_file_name
            fi
        done

        # Retry if needs
        # Update list for re-try to the one for upload
        tar_list=$retry_tar_list
        retry_tar_list=""
        if [ -z "$tar_list" ]; then
            try_round=4
        else
            try_round=$((try_round+1))
        fi
    done
    # Show final result
    if [ ! -z "$tar_list" ]; then
        echo "RESULT: The following files are failed to upload: "$tar_list | tee -a $log_file_name
    else
        echo "RESULT: All files are uploaded" | tee -a $log_file_name
    fi
    cd -
}

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
nas_upload_folder="`date +'%Y-%m-%d_%H-%M'`"
main_folder=${0%/scripts/*}
script_name=${0%.*}
script_name=${script_name##*/}
# echo "script_name: "$script_name
backup_folder="/media/backups-1/gitlab"

host_name='testarea.ddns.net'
user_name='user_name'
user_passwd='user_passwd'
target_directory="/Backup/Gitlab-Server/"
retry_tar_list=""
round_limit=3
try_round=1


log_file_prefix=$main_folder"/log/"$script_name
log_file_name=$log_file_prefix"_"$timestamp".log"
# Remove old log
rm $log_file_prefix\_*.log
# Create new log
touch $log_file_name
# Set owner and permission
chown gitlab:gitlab $log_file_name
chmod 664 $log_file_name
echo "["$timestamp"] Start to upload gitlab backup to remote Nas" | tee $log_file_name

upload_gitlab_to_ftp