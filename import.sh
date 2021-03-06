SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
CONFIGPATH=$SCRIPTPATH/config.sh
if [ -e $CONFIGPATH ]
then
    . $CONFIGPATH
else
    . $SCRIPTPATH/config.sample.sh
fi

DOMAIN=$1

DIRECTORY=$DOMAINS_PATH/$DOMAIN
MYSQL_DATABASE_NAME=$DOMAIN
URL="http://$DOMAIN"

if [ ! -d "$DIRECTORY" ]; then
        echo "Directory not found"
        exit;
fi

## Unpack the files
tar -xvf $DIRECTORY/files.tar --directory $DIRECTORY

## Create and import DB
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE_NAME\`"
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE_NAME < $DIRECTORY/structure.sql
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE_NAME < $DIRECTORY/data.sql

## Check if we are installing Magento 1 or 2
if [ ! -f "$DIRECTORY/app/etc/env.php" ]; then
        VERSION="M2"
else
		VERSION="M1"        
fi 

if [ "$VERSION" = "M2" ]; then
	## Create new env.php
	php Helper/updateEnv.php -f $DIRECTORY -d $MYSQL_DATABASE_NAME -u $MYSQL_USER -p $MYSQL_PASSWORD
else
	## Create new local.xml
	php Helper/updateLocal.php -f $DIRECTORY -d $MYSQL_DATABASE_NAME -u $MYSQL_USER -p $MYSQL_PASSWORD
fi	

## Set correct base urls
for CONFIG_PATH in 'web/unsecure/base_url' 'web/secure/base_url' 'web/unsecure/base_link_url' 'web/secure/base_link_url'
do
	mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -D $MYSQL_DATABASE_NAME -e "UPDATE \`core_config_data\` SET \`value\`='$URL' WHERE \`path\`='$CONFIG_PATH'"
done

## Developer Settings
php $DIRECTORY/bin/magento deploy:mode:set developer
php $DIRECTORY/bin/magento cache:disable layout block_html collections full_page

mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -D $MYSQL_DATABASE_NAME -e "INSERT INTO \`core_config_data\` (\`scope\`, \`scope_id\`, \`path\`, \`value\`) VALUES ('default', 0, 'admin/security/session_lifetime', '31536000') ON DUPLICATE KEY UPDATE value='31536000';"
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -D $MYSQL_DATABASE_NAME -e "INSERT INTO \`core_config_data\` (\`scope\`, \`scope_id\`, \`path\`, \`value\`) VALUES ('default', 0, 'web/cookie/cookie_lifetime', '31536000') ON DUPLICATE KEY UPDATE value='31536000';"
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -D $MYSQL_DATABASE_NAME -e "INSERT INTO \`core_config_data\` (\`scope\`, \`scope_id\`, \`path\`, \`value\`) VALUES ('default', 0, 'dev/static/sign', '0') ON DUPLICATE KEY UPDATE value='0';"
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -D $MYSQL_DATABASE_NAME -e "INSERT INTO \`core_config_data\` (\`scope\`, \`scope_id\`, \`path\`, \`value\`) VALUES ('default', 0, 'system/smtp/disable', '1') ON DUPLICATE KEY UPDATE value='1';"

## Remove the import files
rm $DIRECTORY/files.tar
rm $DIRECTORY/structure.sql
rm $DIRECTORY/data.sql