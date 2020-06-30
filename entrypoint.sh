#!/bin/bash

set -e;

printf "                                                     .                  \n";
printf "   ___      _                                       ":"                 \n";
printf "  / __\__ _| |__  _ __ ___  _ __   ___  ___       ___:____     |"\/"|   \n";
printf " / /  / _' | '_ \| '__/ _ \| '_ \ / _ \/ __|    ,'        '.    \  /    \n";
printf "/ /__| (_| | |_) | | | (_) | | | |  __/\__ \    |  O        \___/  |    \n";
printf "\____/\__,_|_.__/|_|  \___/|_| |_|\___||___/  ~^~^~^~^~^~^~^~^~^~^~^~^~ \n";
printf "        ___          _    __ _                                          \n";
printf "       / _ \___  ___| |_ / _(_)_  __                                    \n";
printf "      / /_)/ _ \/ __| __| |_| \ \/ /        https://github.com          \n";
printf "     / ___/ (_) \__ \ |_|  _| |>  <               /sergiocabral         \n";
printf "     \/    \___/|___/\__|_| |_/_/\_\             /Docker.Postfix        \n";
printf "                                                                        \n";
printf "\n";

printf "Entrypoint for docker image: postfix\n";

# Variables to configure externally.
POSTFIX_ARGS="$* $POSTFIX_ARGS";

POSTFIX_EXECUTABLE=$(which postfix || echo "");
POSTMAP_EXECUTABLE=$(which postmap || echo "");
RSYSLOG_EXECUTABLE=$(which rsyslogd || echo "");
SUFFIX_TEMPLATE=".template";
DIR_CONF="/etc/postfix";
DIR_CONF_BACKUP="$DIR_CONF.original";
DIR_CONF_TEMPLATES="$DIR_CONF.templates";
DIR_CONF_DOCKER="$DIR_CONF.conf";
DIR_SCRIPTS="${DIR_SCRIPTS:-/root}";
LS="ls --color=auto -CFl";

if [ ! -e "$POSTFIX_EXECUTABLE" ] || [ ! -e "$POSTMAP_EXECUTABLE" ];
then
    printf "Postfix is not installed.\n" >> /dev/stderr;
    exit 1;
fi

if [ ! -e "$RSYSLOG_EXECUTABLE" ];
then
    printf "Rsyslog is not installed.\n" >> /dev/stderr;
    exit 1;
fi

IS_FIRST_CONFIGURATION=$((test ! -d $DIR_CONF_BACKUP && echo true) || echo false);

if [ $IS_FIRST_CONFIGURATION = true ];
then
    printf "This is the FIRST RUN.\n";

    printf "Running postfix for the first time.\n";

    $POSTFIX_EXECUTABLE start;
    sleep 1;
    $POSTFIX_EXECUTABLE stop;
    sleep 1;

    printf "Configuring directories.\n";

    mkdir -p $DIR_CONF_DOCKER;
    cp -R $DIR_CONF $DIR_CONF_BACKUP;
    cp -R $DIR_CONF/* $DIR_CONF_DOCKER/;
    rm -R $DIR_CONF;
    ln -s $DIR_CONF_DOCKER $DIR_CONF;

    mkdir -p $DIR_CONF_TEMPLATES;

    if [ -d "$DIR_CONF_TEMPLATES" ] && [ ! -z "$(ls -A $DIR_CONF_TEMPLATES)" ];
    then
        printf "Warning: The $DIR_CONF_TEMPLATES directory already existed and will not have its content overwritten.\n";
    else
        printf "Creating file templates in $DIR_CONF_TEMPLATES\n";

        for FILE in $(ls -1 $DIR_CONF_DOCKER | grep -E "(\\.cf$|^[a-z]+$)");
        do
            FILE="$DIR_CONF_DOCKER/$FILE";
            if [ ! -d $FILE ];
            then
                cp $FILE $DIR_CONF_TEMPLATES;
            fi
        done;

        ls -1 $DIR_CONF_TEMPLATES | \
           grep -v $SUFFIX_TEMPLATE | \
           xargs -I {} mv $DIR_CONF_TEMPLATES/{} $DIR_CONF_TEMPLATES/{}$SUFFIX_TEMPLATE;
    fi
    $LS -Ad $DIR_CONF_TEMPLATES/*;

    printf "Configured directories:\n";

    USER=root;
    chown -R $USER:$USER $DIR_CONF_BACKUP;
    chown -R $USER:$USER $DIR_CONF_TEMPLATES;
    chown -R $USER:$USER $DIR_CONF_DOCKER;
    
    $LS -d $DIR_CONF $DIR_CONF_BACKUP $DIR_CONF_TEMPLATES $DIR_CONF_DOCKER;

    FILE_RSYSLOG_CONF="/etc/rsyslog.conf";
    cp $FILE_RSYSLOG_CONF "$FILE_RSYSLOG_CONF.original";
    sed -i -e "/imklog/ s/^/#/" $FILE_RSYSLOG_CONF;
    printf "Configured rsyslog at:\n";
    $LS $FILE_RSYSLOG_CONF*;
else
    printf "This is NOT the first run.\n";
fi

printf "Tip: Use files $DIR_CONF_TEMPLATES/*$SUFFIX_TEMPLATE to make the files in the $DIR_CONF directory with replacement of environment variables with their values.\n";

$DIR_SCRIPTS/envsubst-files.sh "$SUFFIX_TEMPLATE" "$DIR_CONF_TEMPLATES" "$DIR_CONF";
SENDER_ACCESS_FILE="$DIR_CONF/sender_access";
touch $SENDER_ACCESS_FILE;
SENDER_ACCESS_INDEX=0;
function register_sender_access {
    local MODE=$1;
    local LIST=$2;

    if [ -n "$LIST" ];
    then
        readarray -t LIST < <($DIR_SCRIPTS/split-to-lines.sh " " "$LIST");
        for DOMAIN in "${LIST[@]}";
        do
            SENDER_ACCESS_INDEX=$((SENDER_ACCESS_INDEX + 1));

            local EXISTS=$(\
                cat $SENDER_ACCESS_FILE |\
                grep "$DOMAIN" |\
                grep "$MODE" ||\
                echo "");

            printf "%5s" "$SENDER_ACCESS_INDEX: ";
            if [ -n "$EXISTS" ];
            then
                printf "[READY] ";
            else
                printf "%-60s $MODE\n" "$DOMAIN" >> $SENDER_ACCESS_FILE;
                printf "[ADDED] ";
            fi
            printf "Access: ";
            printf "%-7s" "$MODE";
            printf "Domain: $DOMAIN\n";        
        done
    fi
}

printf "Updating access level file by sender.\n";
register_sender_access "ALLOW" "$SENDER_ACCESS_ALLOW";
register_sender_access "REJECT" "$SENDER_ACCESS_REJECT";
$POSTMAP_EXECUTABLE "$SENDER_ACCESS_FILE";
printf "Updated files:\n";
$LS $SENDER_ACCESS_FILE*

SASL_PASSWORD_FILE="$DIR_CONF/sasl_password";
if [ -n "$SMTP_EXTERNAL" ];
then
    printf "Updating relay host password file.\n";
    readarray -t SMTP_EXTERNAL < <($DIR_SCRIPTS/split-to-lines.sh " " "$SMTP_EXTERNAL");

    SMTP_EXTERNAL_SERVER="${SMTP_EXTERNAL[0]}";
    SMTP_EXTERNAL_AUTH="${SMTP_EXTERNAL[@]:1}";

    readarray -t SMTP_EXTERNAL_SERVER < <($DIR_SCRIPTS/split-to-lines.sh ":" "$SMTP_EXTERNAL_SERVER");

    if [ ${#SMTP_EXTERNAL_SERVER[@]} != 2 ];
    then
        printf "Expected environment variable SMTP_EXTERNAL with format <hostname>:<port> [username]=[password]\n";
        SMTP_EXTERNAL_SERVER="";
    else
        printf "\n";
        printf "    Hostname = ${SMTP_EXTERNAL_SERVER[0]}\n";
        printf "        Port = ${SMTP_EXTERNAL_SERVER[1]}\n";
        if [ -n "$SMTP_EXTERNAL_AUTH" ];
        then
            readarray -t SMTP_EXTERNAL_AUTH_USER < <($DIR_SCRIPTS/split-to-lines.sh "=" "$SMTP_EXTERNAL_AUTH");
            SMTP_EXTERNAL_AUTH_USER=${SMTP_EXTERNAL_AUTH_USER[0]};
            SMTP_EXTERNAL_AUTH_USER_LENGTH=$((${#SMTP_EXTERNAL_AUTH_USER} + 1));
            SMTP_EXTERNAL_AUTH_PASS="${SMTP_EXTERNAL_AUTH:$SMTP_EXTERNAL_AUTH_USER_LENGTH}";
            printf "    Username = ${SMTP_EXTERNAL_AUTH_USER}\n";
            printf "    Password = ***\n";
            SMTP_EXTERNAL_AUTH="${SMTP_EXTERNAL_AUTH_USER}:${SMTP_EXTERNAL_AUTH_PASS}";
        fi
        printf "\n";
    fi
fi
if [ -n "$SMTP_EXTERNAL_SERVER" ];
then
    echo "[${SMTP_EXTERNAL_SERVER[0]}]:${SMTP_EXTERNAL_SERVER[1]} $SMTP_EXTERNAL_AUTH" | xargs > $SASL_PASSWORD_FILE;
else
    printf "No data for relay host password file.\n";
    echo "" > $SASL_PASSWORD_FILE;
fi
$POSTMAP_EXECUTABLE "$SASL_PASSWORD_FILE";
printf "Updated files:\n";
$LS $SASL_PASSWORD_FILE*

printf "Updating email redirects.\n";
VIRTUAL_FILE_TEMP="/tmp/virtual";
truncate -s 0 $VIRTUAL_FILE_TEMP;
VIRTUAL_FILE="$DIR_CONF/virtual";
EMAIL_REDIRECT_INDEX=1;
while [ -n "$(VAR_NAME="EMAIL_REDIRECT${EMAIL_REDIRECT_INDEX}"; echo "${!VAR_NAME}")" ];
do
    VAR_NAME="EMAIL_REDIRECT${EMAIL_REDIRECT_INDEX}";
    EMAIL_REDIRECT=${!VAR_NAME};
    readarray -t EMAIL_REDIRECT < <($DIR_SCRIPTS/split-to-lines.sh "=" "$EMAIL_REDIRECT");
    EMAIL_REDIRECT_FROM=${EMAIL_REDIRECT[0]};
    EMAIL_REDIRECT_TO=${EMAIL_REDIRECT[1]};

    if [ -n "$EMAIL_REDIRECT_TO" ];
    then
        readarray -t EMAIL_REDIRECT_TO < <($DIR_SCRIPTS/split-to-lines.sh " " "$EMAIL_REDIRECT_TO");
    fi

    printf "%3s: Redirect from: $EMAIL_REDIRECT_FROM\n" "$EMAIL_REDIRECT_INDEX";
    if [ -n "${EMAIL_REDIRECT_TO[0]}" ];
    then
        printf "%-40s" "$EMAIL_REDIRECT_FROM" >> $VIRTUAL_FILE_TEMP;
        FIRST=true;
        for TO in ${EMAIL_REDIRECT_TO[@]};
        do
            printf "                to: $TO\n";
            if [ "$FIRST" = false ];
            then
                printf "," >> $VIRTUAL_FILE_TEMP;
            fi
            printf " $TO" >> $VIRTUAL_FILE_TEMP;
            FIRST=false;
        done;
        printf "\n" >> $VIRTUAL_FILE_TEMP;
    else
        printf "     No destination email found. Redirection ignored.\n";
    fi

    EMAIL_REDIRECT_INDEX=$((EMAIL_REDIRECT_INDEX + 1));
done

if [ -z "$(cat $VIRTUAL_FILE_TEMP)" ];
then
    printf "No email redirection were found on the environment variables.\n";
    printf "Using the file the way it is.\n";
else
    printf "Recreating file with email redirects.\n";
    cp $VIRTUAL_FILE_TEMP $VIRTUAL_FILE;
fi
rm $VIRTUAL_FILE_TEMP;

$POSTMAP_EXECUTABLE "$VIRTUAL_FILE";
printf "Updated files:\n";
$LS $VIRTUAL_FILE*

printf "Starting rsyslog in background.\n";
$RSYSLOG_EXECUTABLE;

printf "Starting postfix in foreground.\n";
$POSTFIX_EXECUTABLE start-fg;
