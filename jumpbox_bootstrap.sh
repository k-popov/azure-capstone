#!/bin/bash

function install_az_cli() {
    local AZ_REPO=$(lsb_release -cs)
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
        sudo tee /etc/apt/sources.list.d/azure-cli.list
    curl -L https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
    sudo apt-get update && sudo apt-get install -y apt-transport-https azure-cli
}

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

function set_up_mysql() {
    sudo apt-get -y  install mysql-client
    echo "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_WP_USER}'@'%' IDENTIFIED BY '${DB_WP_PASSWORD}';
        FLUSH PRIVILEGES;" | \
            mysql -h $DB_HOST --user "$DB_ADMIN_USER" -p"$DB_ADMIN_PASSWORD"
}

function set_up_wp() {
    cd
    wget http://wordpress.org/latest.tar.gz
    tar xzf latest.tar.gz -C "$LOCAL_WP_FILES_DIR" --strip-components=1
    sudo apt-get install -y php-cli
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    cd "$LOCAL_WP_FILES_DIR"
    php ~/wp-cli.phar config create --dbname=$DB_NAME --dbuser=$DB_WP_USER --dbpass=$DB_WP_PASSWORD --dbhost=$DB_HOST
}

STORAGE_ACCOUNT_NAME=""
FILE_SHARE_NAME=""
STORAGE_ACCOUNT_KEY=""
DB_HOST=""
DB_NAME=""
DB_ADMIN_USER=""
DB_ADMIN_PASSWORD=""
DB_WP_USER=""
DB_WP_PASSWORD=""

LOCAL_WP_FILES_DIR="/wpfiles"

while getopts "a:f:k:h:n:u:p:l:s:" opt; do
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
        h)
            DB_HOST="$OPTARG"
            ;;
        n)
            DB_NAME="$OPTARG"
            ;;
        u)
            DB_ADMIN_USER="$OPTARG"
            ;;
        p)
            DB_ADMIN_PASSWORD="$OPTARG"
            ;;
        l)
            DB_WP_USER="$OPTARG"
            ;;
        s)
            DB_WP_PASSWORD="$OPTARG"
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
    DB_HOST \
    DB_NAME \
    DB_ADMIN_USER \
    DB_ADMIN_PASSWORD \
    DB_WP_USER \
    DB_WP_PASSWORD \
    ; do
    eval "test -z \"\$$VAR_NAME\"" && { echo "$VAR_NAME is missing"; exit 1; }
done

install_az_cli
az login --identity
az storage share create --name "$FILE_SHARE_NAME" --quota 1 --account-name "$STORAGE_ACCOUNT_NAME"
setup_share_mount "$STORAGE_ACCOUNT_NAME" "$FILE_SHARE_NAME" "$STORAGE_ACCOUNT_KEY"
sudo mount -v "$LOCAL_WP_FILES_DIR"
set_up_mysql
set_up_wp
