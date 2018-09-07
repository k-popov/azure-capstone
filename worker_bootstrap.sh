#!/bin/bash

function setup_share_mount() {
    local STORAGE_ACCOUNT_NAME="$1"
    local FILE_SHARE_NAME="$2"
    local STORAGE_ACCOUNT_KEY="$3"

    grep -q -F "${STORAGE_ACCOUNT_NAME}.file.core.windows.net/${FILE_SHARE_NAME}" /etc/fstab && { echo 'already set up'; return 0; }

    sudo mkdir "$LOCAL_WP_FILES_DIR"
    chmod 0777 "$LOCAL_WP_FILES_DIR"

    sudo mkdir -p /etc/smbcredentials
    if [ ! -f "/etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred" ]; then
        echo -e "username=${STORAGE_ACCOUNT_NAME}\npassword=${STORAGE_ACCOUNT_KEY}" | sudo tee -a /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred
        sudo chmod 600 /etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred
    fi
    echo "//${STORAGE_ACCOUNT_NAME}.file.core.windows.net/${FILE_SHARE_NAME} "$LOCAL_WP_FILES_DIR" cifs nofail,vers=3.0,credentials=/etc/smbcredentials/${STORAGE_ACCOUNT_NAME}.cred,dir_mode=0777,file_mode=0677,serverino" | sudo tee -a /etc/fstab
}

STORAGE_ACCOUNT_NAME=""
FILE_SHARE_NAME=""
STORAGE_ACCOUNT_KEY=""

LOCAL_WP_FILES_DIR="/wpfiles"

while getopts "a:f:k:" opt; do
    case $opt in
        a)
            STORAGE_ACCOUNT_NAME="$OPTARG"
            ;;
        f)
            FILE_SHARE_NAME="$OPTARG"
            ;;
        k)
            STORAGE_ACCOUNT_KEY="$OPTARG"
            ;;
        *)
            echo "Invalid option: -$opt" >&2
            exit 1
            ;;
        :)
            echo "Option -$opt requires an argument." >&2
            exit 1
            ;;
    esac
done

for VAR_NAME in \
    STORAGE_ACCOUNT_NAME \
    FILE_SHARE_NAME \
    STORAGE_ACCOUNT_KEY \
    ; do
    eval "test -z \"\$$VAR_NAME\"" && { echo "$VAR_NAME is missing"; exit 1; }
done

setup_share_mount "$STORAGE_ACCOUNT_NAME" "$FILE_SHARE_NAME" "$STORAGE_ACCOUNT_KEY"
sudo mount -v "$LOCAL_WP_FILES_DIR"

sudo apt-get install -y nginx php-fpm php-mysql
sudo cp -v worker_nginx_virtualsite.conf /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
