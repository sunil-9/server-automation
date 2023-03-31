#!/bin/bash

#if code didnot run properly copy pest the following command in the terminal
#sed -i 's/\r//' automation.sh  

#Colors settings
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;46m'
NC='\033[0m' # No Color


#check permissions
if [[ $EUID -ne 0 ]]; then
    echo ""
    echo -e "${RED}[-] This script must be run as root! Login as root, sudo or su.${NC}" 
    echo ""
    exit 1;
fi

installServerSetup(){
    echo -e "${RED}[*] Choose apache in the server list while installing phpmyadmin${NC}"
    echo -e "${YELLOW}[+] updating System first${NC}"
    sudo apt-get update -y > /dev/null && sudo apt-get upgrade -y > /dev/null
    echo -e "${YELLOW}[+] Installing apache2 server and its tools${NC}"
    sudo apt-get install apache2 apache2-doc apache2-utils libexpat1 ssl-cert -y > /dev/null
    echo -e "${YELLOW}[+] Installing php and its tools${NC}"
    sudo apt-get install php libapache2-mod-php zip -y > /dev/null
    echo -e "${YELLOW}[+] Installing Mysql Database${NC}"
    sudo apt-get install mysql-server mysql-client -y > /dev/null
    echo -e "${YELLOW}[+] Installing Phpmyadmin${NC}"
    sudo apt-get install phpmyadmin -y 
    echo -e "${YELLOW}[+] Changing permissions${NC}"
    sudo chown -R www-data:www-data /var/www
    echo -e "${YELLOW}[+] enable and restarting services${NC}"
    echo ""
    sudo service apache2 restart > /dev/null
    sudo service mysql restart > /dev/null
    sudo a2enmod rewrite > /dev/null
    sudo systemctl enable apache2 > /dev/null
    sudo systemctl enable mysql > /dev/null
    sudo systemctl restart apache2 > /dev/null
    sudo systemctl restart mysql > /dev/null
    echo  -e "${GREEN}[+] Done Click enter to continue${NC}"
    read
}

#remove disable swap, remove it and remove entry from fstab
function removeSwap(){
    echo -e "${YELLOW}[+] Removing swap and backup fstab.${NC}"
    echo ""

    #get the date time to help the scripts
    backupTime=$(date +%y-%m-%d--%H-%M-%S)

    #get the swapfile name
    swapSpace=$(swapon -s | tail -1 |  awk '{print $1}' | cut -d '/' -f 2)
    #debug: echo $swapSpace

    #turn off swapping
    swapoff /$swapSpace

    #make backup of fstab
    cp /etc/fstab /etc/fstab.$backupTime
    
    #remove swap space entry from fstab
    sed -i "/swap/d" /etc/fstab

    #remove swapfile
    rm -f "/$swapSpace"
    rm -f /swapfile;

    echo ""
    echo -e "${GREEN}[+] Removed old swap and save backup of your swap file at /etc/fstab /etc/fstab.$backupTime ${NC}"
    echo ""
}

#identifies available ram, calculate swap file size and configure
createSwap() {
    echo -e "${YELLOW}[+]Creating a swap and setup fstab.${NC}"
    echo ""

    #get available physical ram
    availMemMb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    #debug: echo $availMemMb
    
    #convert from kb to mb to gb
    gb=$(awk "BEGIN {print $availMemMb/1024/1204}")
    #debug: echo $gb
    
    #round the number to nearest gb
    gb=$(echo $gb | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}')
    #debug: echo $gb

    echo "[+] Available Physical RAM: $gb Gb"
    echo ""
    if [ $gb -eq 0 ]; then
        echo -e "${RED}[-]Something went wrong! Memory cannot be 0!${NC}"
        exit 1;
    fi

    if [ $gb -le 2 ]; then
        echo -e "${YELLOW}[+] Memory is less than or equal to 2 Gb${NC}"
        let swapSizeGb=$gb*2
        echo -e "${YELLOW}[+] Set swap size to $swapSizeGb Gb${NC}"
    fi
    if [ $gb -gt 2 -a $gb -lt 32 ]; then
        echo "${YELLOW}[+] Memory is more than 2 Gb and less than to 32 Gb.${NC}"
        let swapSizeGb=4+$gb-2
        echo -e "${YELLOW}[+] Set swap size to $swapSizeGb Gb.${NC}"
    fi
    if [ $gb -gt 32 ]; then
        echo -e "${YELLOW}[+] Memory is more than or equal to 32 Gb.${NC}"
        let swapSizeGb=$gb
        echo -e "${YELLOW}[+] Set swap size to $swapSizeGb Gb.${NC}"
    fi
    echo ""

    echo -e "${YELLOW}[+] Creating the swap file! This may take a few minutes...${NC}"
    echo ""

    #convert gb to mb to avoid error: dd-memory-exhausted-by-input-buffer-of-size-bytes
    let mb=$gb*1024

    #create swap file on root system and set file size to mb variable
    echo -e "${YELLOW}[+] Create swap file.${NC}"
    sudo fallocate -l ${swapSizeGb}G /swapfile
    dd if=/dev/zero of=/swapfile bs=1M count=$mb

    #set read and write permissions
    echo -e "${BLUE}[+] Swap file created setting up swap file permissions.${NC}"
    echo ""
    chmod 600 /swapfile

    #create swap area
    echo -e "${YELLOW}[+] Create swap area and trun it on.${NC}"
    echo ""
    mkswap /swapfile; swapon /swapfile
    #update the fstab
    if grep -q "swap" /etc/fstab; then
        echo -e "${RED}[-] The fstab contains a swap entry.${NC}"
        #do nothing
    else
        echo -e "${RED}[-] The fstab does not contain a swap entry. Adding an entry.${NC}"
        echo "/swapfile swap swap defaults 0 0" >> /etc/fstab    
    fi
    echo -e "${GREEN}[+] Done Press any Enter to go to home page.${NC}"
    read
}

#the main function that is run by the calling script.
function setupSwap() {
    #check if swap is on
    isSwapOn=$(swapon -s | tail -1)

    if [[ "$isSwapOn" == "" ]]; then
        echo -e  "${BLUE}[+] No swap has been configured! Will create.${NC}"
        echo ""

        createSwap
    else
        echo -e "${BLUE}[+] Swap has been configured. Will remove and then re-create the swap.${NC}"
        echo ""
        
        removeSwap
        createSwap
    fi
}

function setupSwapMain() {


    echo -e "${BLUE}[*] This will remove an existing swap file and then create a new one. "
    echo -e "[*] Please Know what you are doing first.${NC}"
    echo ""

    echo  "[?]Do you want to proceed? (Y/N): "; read proceed
    if [ "$proceed" == "y" ]; then
        echo "[+] setting up new swap memory"
        setupSwap
    else
    echo  -e "${GREEN}[+] Done Click enter to continue${NC}"
    fi
}
########### virtual host ######
virtualHost(){
        echo -e "${BLUE} You have following sites enabled"
    sudo ls -l /etc/apache2/sites-enabled/
    echo -e "${NC}"
  default_domain="example.com"
  read -p "[?] Enter domain name default name [$default_domain]: " name
  name="${name:-$default_domain}"
  DEFAULT_WEB_ROOT_DIR="/var/www/$name/public_html"
  read -p "[?] Enter web root default  WEB_ROOT_DIR [$DEFAULT_WEB_ROOT_DIR]: " WEB_ROOT_DIR
    WEB_ROOT_DIR="${WEB_ROOT_DIR:-$DEFAULT_WEB_ROOT_DIR}"
 DEFAULT_EMAIL="admin@$name"
  read -p "[?] Enter web root default  email [$DEFAULT_EMAIL]: " email
    email="${WEB_ROOT_DIR:-$DEFAULT_EMAIL}"
     
    email=${3-'webmaster@localhost'}
    sitesEnable='/etc/apache2/sites-enabled/'
    sitesAvailable='/etc/apache2/sites-available/'
    sitesAvailabledomain=$sitesAvailable$name.conf
    echo -e "${YELLOW}[+] Creating a vhost for $sitesAvailabledomain with a webroot $WEB_ROOT_DIR${NC}"
    echo -e "${YELLOW}[+]backing up the webroot dir if exits${NC}" 
    zip backup.zip * > /dev/null
    echo -e "${YELLOW}[+]Creating clean the webroot dir${NC}" 
    rm -rf "$WEB_ROOT_DIR" || true
    mkdir -p "$WEB_ROOT_DIR" > /dev/null
    echo -e "${YELLOW}[+]Provide permissions for apache2 web server${NC}" 
    sudo chown www-data:www-data -R "$WEB_ROOT_DIR"
    echo "
        <VirtualHost *:80>
          ServerAdmin $email
          ServerName $name
          ServerAlias www.$name
          DocumentRoot $WEB_ROOT_DIR
          <Directory $WEB_ROOT_DIR>
            Options Indexes FollowSymLinks
            AllowOverride all
          </Directory>
        </VirtualHost>" > $sitesAvailabledomain
    echo -e "${YELLOW}[+]New Virtual Host Created${NC}"

    sed -i "1s/^/127.0.0.1 $name\n/" /etc/hosts
    echo -e "${YELLOW}[+]Enabling webiste host file${NC}" 
    a2ensite $name > /dev/null
    echo -e "${YELLOW}[+]Reloading apache2 server configuration file${NC}" 

    service apache2 reload > /dev/null

    echo -e "${GREEN}[+] Done, please browse to http://$name to check! Click enter to go to main menu.${NC}"
    read
}
virtualHostDelete(){
    echo -e "${BLUE} You have following sites enabled"
    sudo ls -l /etc/apache2/sites-enabled/
    echo -e "${NC}"
    default_domain="example.com"
    read -p "[+] Enter domain name default name [$default_domain]: " name
    name="${name:-$default_domain}"
     DEFAULT_WEB_ROOT_DIR="/var/www/$name"
  read -p "[+] Enter web root default  WEB_ROOT_DIR [$DEFAULT_WEB_ROOT_DIR]: " WEB_ROOT_DIR
    WEB_ROOT_DIR="${WEB_ROOT_DIR:-$DEFAULT_WEB_ROOT_DIR}"
    echo -e "${YELLOW}[+] Deleting web root dir $WEB_ROOT_DIR${NC}"
    rm -f -r "$WEB_ROOT_DIR"

    # sed -i "/[$name]/d" /etc/hosts
      sed -i "s/^.*$name.*$//" /etc/hosts
      echo -e  "${GREEN}[+]Removed name from hosts file${NC}"


    echo -e "${GREEN}[+] $name is deleted${NC}" 
    sitesEnable='/etc/apache2/sites-enabled/'
    sitesAvailable='/etc/apache2/sites-available/'
    sitesAvailabledomain=$sitesAvailable$name.conf
    echo -e "${YELLOW}[+] Deleting a vhost for $sitesAvailabledomain with a webroot $WEB_ROOT_DIR${NC}"

   rm -f $sitesAvailabledomain
    echo -e "${GREEN}[+] Virtual Host Deleted${NC}"
    echo -e "${YELLOW}[+] Removing settings${NC}"
    a2dissite $name > /dev/null
    service apache2 reload > /dev/null

    echo  -e "${GREEN}[+] Done Click enter to continue${NC}"
    read

}
phpmyadmin(){ 
    echo "[?] Enter Domain name: "
    read domain
    # mkdir -p "/var/www/$domain/public_html"
    path=/var/www/$domain/public_html

    rm -rf "${path}/phpmyadmin" || true
    cd "$path"
    pwd
    echo -e "${YELLOW}[*] Installing Phpmyadmin on $domain please wait it will take a while."
    echo -e "${YELLOW}[*] Installing Composer${NC}"
    apt-get install composer -y > /dev/null;
    echo -e "${YELLOW}[*] creating project to install phpmyadmin${NC}"
    composer create-project phpmyadmin/phpmyadmin > /dev/null;
    echo -e "${YELLOW}[*] Installing Phpmyadmin${NC}"
    composer create-project phpmyadmin/phpmyadmin --repository-url=https://www.phpmyadmin.net/packages.json --no-dev > /dev/null
    echo  -e "${GREEN}[+] Done Click enter to continue${NC}"
  read
}
updateSystem(){
    echo -e "${YELLOW}[+] Updating system.${NC}"
    apt-get update && apt-get upgrade -y
}
fullAutomatedWP(){

    default_domain="example.com"
    read -p "[+] Enter domain name default name [$default_domain]: " name
    name="${name:-$default_domain}"
     DEFAULT_WEB_ROOT_DIR="/var/www/$name/public_html/"
    read -p "[+] Enter web root default  WEB_ROOT_DIR [$DEFAULT_WEB_ROOT_DIR]: " WEB_ROOT_DIR
    WEB_ROOT_DIR="${WEB_ROOT_DIR:-$DEFAULT_WEB_ROOT_DIR}"
    echo -e "${YELLOW}[+] Deleting web root dir $WEB_ROOT_DIR${NC}"
    rm -r "$WEB_ROOT_DIR"
    echo -e "${YELLOW}[+] Creating web root dir $WEB_ROOT_DIR${NC}"
    mkdir -p "$WEB_ROOT_DIR"
    echo  -e "${YELLOW}[+] Downloading wordpress${NC}"
    WORDPRESS_URL="https://wordpress.org/latest.tar.gz"

    # GET ALL USER INPUT
    echo "[?] Project folder name?(if any)"
    read PROJECT_FOLDER_NAME

    echo "[?] Setup wp_config? (y/n)"
    read SHOULD_SETUP_DB

    if [ $SHOULD_SETUP_DB = 'y' ]
    then
      echo "[?] Enter DB Name"
      read DB_NAME

      echo "[?] Enter DB Username"
      read DB_USERNAME


      echo "[?] Enter DB Password"
      read DB_PASSWORD
    fi

    #LETS START INSTALLING
    echo  -e "${YELLOW}[+] Sit back and relax :) ......${NC}"

    # CREATE PROJECT DIRECTORIES
    cd "$WEB_ROOT_DIR"
    echo -e "${YELLOW}[+] Creating $WEB_ROOT_DIR${NC}"
    mkdir -p "$PROJECT_FOLDER_NAME" > /dev/null
    cd "$PROJECT_FOLDER_NAME" > /dev/null

    # DOWNLOAD WORDPRESS
    echo  -e "${YELLOW}Downloading Wordpress${NC}"
    curl -O $WORDPRESS_URL

    # UNZIP WORDPRESS AND REMOVE ARCHIVE FILES
    echo -e  "${YELLOW}Unzipping Wordpress${NC}"
    tar -xzf latest.tar.gz
    rm -f latest.tar.gz
    mv wordpress/* . 

    if [ $SHOULD_SETUP_DB = 'y' ]
    then
      # SETUP WP CONFIG
      echo  -e "${YELLOW}[+] Create wp_config${NC}"
      mv wp-config-sample.php wp-config.php
      sed -i "s/^.*DB_NAME.*$/define('DB_NAME', '$DB_NAME');/" wp-config.php
      sed -i "s/^.*DB_USER.*$/define('DB_USER', '$DB_USERNAME');/" wp-config.php
      sed -i "s/^.*DB_PASSWORD.*$/define('DB_PASSWORD', '$DB_PASSWORD');/" wp-config.php
      echo ""
      echo ""
       echo -e "${YELLOW}[+] creating database${NC}"
      MYSQL=`which mysql`
      Q1="CREATE DATABASE IF NOT EXISTS $DB_NAME;"
      Q2="GRANT ALL ON *.* TO '$DB_USERNAME'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
      Q3="FLUSH PRIVILEGES;"
      SQL="${Q1}${Q2}${Q3}"
      $MYSQL -uroot -e "$SQL"
      echo  -e "${Green}Database $DB_NAME and user $DB_USERNAME created with your password.${NC}"
    fi
      echo  -e "${YELLOW}[+] Manage permissions${NC}"
      sudo chown -R www-data:www-data .
    echo  -e "${GREEN}[+] All done press enter to continue${NC}"
    read

}
installSSl(){
    echo -e "${BLUE}"
    default_domain="example.com"
    read -p "[+] Enter domain name default name [$default_domain]: " name
    name="${name:-$default_domain}"
    sudo ufw allow https
    sudo add-apt-repository ppa:certbot/certbot
    echo  -e "${YELLOW}[+] Installing packages${NC}"
    sudo apt install python-certbot-apache -y 
    sudo certbot --apache -d "${name}"
    echo -e "${NC}"
    echo  -e "${GREEN}[+] All done press enter to continue${NC}"
    read

}


WPbackup(){
        echo "Please provide mysql info"
    MYSQL_HOST="localhost"
    read -p "[+] Please enter NEW_MYSQL_HOST [$MYSQL_HOST]: " NEW_MYSQL_HOST
    NEW_MYSQL_HOST="${NEW_MYSQL_HOST:-$MYSQL_HOST}"
    # echo $NEW_MYSQL_HOST

    MYSQL_PORT="3306"
    read -p "[+] Please enter NEW_MYSQL_PORT [$MYSQL_PORT]: " NEW_MYSQL_PORT
    NEW_MYSQL_PORT="${NEW_MYSQL_PORT:-$MYSQL_PORT}"
    # echo $NEW_MYSQL_PORT

    MYSQL_USER="newuser"
    read -p "[+] Please enter NEW_MYSQL_USER [$MYSQL_USER]: " NEW_MYSQL_USER
    NEW_MYSQL_USER="${NEW_MYSQL_USER:-$MYSQL_USER}"
    # echo $NEW_MYSQL_USER

    MYSQL_PASSWORD="password"
    read -p "[+] Please enter NEW_MYSQL_PASSWORD [$MYSQL_PASSWORD]: " NEW_MYSQL_PASSWORD
    NEW_MYSQL_PASSWORD="${NEW_MYSQL_PASSWORD:-$MYSQL_PASSWORD}"
    # echo $NEW_MYSQL_PASSWORD

    DATABASE_NAME="DB_name"
    read -p "[+] Please enter NEW_DATABASE_NAME [$DATABASE_NAME]: " NEW_DATABASE_NAME
    NEW_DATABASE_NAME="${NEW_DATABASE_NAME:-$DATABASE_NAME}"
    # echo $NEW_DATABASE_NAME
    echo "you have following domain running"
    ls -l /etc/apache2/sites-enabled/

    echo " please provide domain name to backup"
    default_domain="example.com"
    read -p "[?] Enter domain name default name [$default_domain]: " name
    name="${name:-$default_domain}"
    DEFAULT_WEB_ROOT_DIR="/var/www/$name/public_html"
    read -p "[?] Enter web root default  WEB_ROOT_DIR [$DEFAULT_WEB_ROOT_DIR]: " WEB_ROOT_DIR
    WEB_ROOT_DIR="${WEB_ROOT_DIR:-$DEFAULT_WEB_ROOT_DIR}"

    NOW=$(date +"%Y-%m-%d-%H%M")
    FILE="${name}.${NOW}"

    echo "--------------------------------------------------------------------------------"
    echo "[?] Say yes if you want to remote back up and no if you want local backup? (y/n)"
    echo "--------------------------------------------------------------------------------"
    read backup_remote

    if [ $backup_remote = 'y' ]; then
      echo "[+] This feature is comming soon. Press enter to continue"
      read
    else
        mkdir backup/${name} > /dev/null
        mkdir backup/${name}-temp > /dev/null
        mv  backup/${name}/* backup/${name}-temp/ 
        echo "[+] local Backup started"
        mysqldump -h ${NEW_MYSQL_HOST} \
       -P ${NEW_MYSQL_PORT} \
       -u ${NEW_MYSQL_USER} \
       -p${NEW_MYSQL_PASSWORD} \
       ${NEW_DATABASE_NAME} | zip > backup/${name}/${NEW_DATABASE_NAME}-${FILE}.sql.zip
       zip -r backup/${name}/${FILE}.zip  $WEB_ROOT_DIR/* 
       rm -r backup/${name}-temp
    echo  -e "${GREEN}[+] All done press enter to continue${NC}"
       read
    fi
}
programStart(){
while true; do 
    clear
    echo -e "${GREEN}               ##########################################${NC}"
    echo -e "${GREEN}               ##${RED}                                     ${GREEN} ##${NC}"
    echo -e "${GREEN}               ##${RED}       Credits:Sunil Sapkota         ${GREEN} ##${NC}"
    echo -e "${GREEN}               ##${RED}   (Github: github.com/sunil-9)      ${GREEN} ##${NC}"
    echo -e "${GREEN}               ##${RED}  (Tested on amazon EC2 ubuntu VM)   ${GREEN} ##${NC}"
    echo -e "${GREEN}               ##${RED}                                     ${GREEN} ##${NC}"
    echo -e "${GREEN}               ##########################################${NC}"
    echo;echo;echo;echo;
    echo "[*] Welcome to the server management console"
    echo "[*] Enter 1 to install apache2 server and mysql server with phpmyadmin."
    echo "[*] Enter 2 to create swap Memory."
    echo "[*] Enter 3 to create virtual host."
    echo "[*] Enter 4 to Delete virtual host."

    echo "[*] Enter 5 to install phpmyadmin in a domain."
    echo "[*] Enter 6 to update your system."
    echo "[*] Enter 7 to install wordpress ."
    echo "[*] Enter 8 to install OR Renew SSL certificate(To make your website having https)."
    echo "[*] Enter 9 to backup wordpress"
    echo "[*] Any other number to exit."
    echo "[?] Enter Your choice: "
    read choice

    echo  "[+] you choose $choice  Please wait we are doing it for you..."
    echo ""

    case $choice in

       1)
        installServerSetup
        ;; 
       2)
        setupSwapMain
        ;;

       3)
        virtualHost
        ;;

       4)
        virtualHostDelete
        ;;

       5)
        phpmyadmin
        ;;

       6)
        updateSystem
        ;;

       7)
        fullAutomatedWP
        ;;

       8)
        installSSl
        ;;

       9)

        WPbackup
        ;;
      *)
        echo ""
        echo  "Good Bye !"
        read 
        clear
        exit 1;
        ;;
    esac

done
}
programStart
