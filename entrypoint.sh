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
printf "Updating access level file by sender.\n";
readarray -t SENDER_ACCESS_LIST < <($DIR_SCRIPTS/split-to-lines.sh " " "$SENDER_ACCESS");
SENDER_ACCESS_INDEX=0;
for SENDER_ACCESS_ENTRY in "${SENDER_ACCESS_LIST[@]}";
do
    SENDER_ACCESS_INDEX=$((SENDER_ACCESS_INDEX + 1));

    readarray -t SENDER_ACCESS_ENTRY < <($DIR_SCRIPTS/split-to-lines.sh "=" "$SENDER_ACCESS_ENTRY");
    SENDER_ACCESS_MODE=${SENDER_ACCESS_ENTRY[0]};
    SENDER_ACCESS_DOMAIN=${SENDER_ACCESS_ENTRY[1]};

    SENDER_ACCESS_EXISTS=$(\
        cat $SENDER_ACCESS_FILE |\
        grep "$SENDER_ACCESS_DOMAIN" |\
        grep "$SENDER_ACCESS_MODE" ||\
        echo "");

    PADDING=$( test $SENDER_ACCESS_INDEX -lt 10 && echo "  " || ( test $SENDER_ACCESS_INDEX -lt 100 && echo " " || echo "" ) );
    printf "$PADDING$SENDER_ACCESS_INDEX: ";
    if [ -n "$SENDER_ACCESS_EXISTS" ];
    then
        printf "[READY] ";
    else
        echo "$SENDER_ACCESS_DOMAIN $SENDER_ACCESS_MODE" >> $SENDER_ACCESS_FILE;
        printf "[ADDED] ";
    fi
    printf "Access: $SENDER_ACCESS_MODE Domain: $SENDER_ACCESS_DOMAIN\n";
done
$POSTMAP_EXECUTABLE "$SENDER_ACCESS_FILE";
printf "Updated files:\n";
$LS $SENDER_ACCESS_FILE*

SASL_PASSWORD_FILE="$DIR_CONF/sasl_password";
if [ -n "$RELAY_HOST" ];
then
    printf "Updating relay host password file.\n";
    readarray -t RELAY_HOST < <($DIR_SCRIPTS/split-to-lines.sh ":" "$RELAY_HOST");

    if [ ${#RELAY_HOST[@]} != 2 ];
    then
        printf "Expected environment variable RELAY_HOST with format <hostname>:<port>\n";
        RELAY_HOST[0]="";
        RELAY_HOST[1]="";
    else
        printf "\n";
        printf "    Hostname = ${RELAY_HOST[0]}\n";
        printf "        Port = ${RELAY_HOST[1]}\n";
        if [ -n "$RELAY_HOST_AUTH" ];
        then
            readarray -t RELAY_HOST_AUTH < <($DIR_SCRIPTS/split-to-lines.sh "=" "$RELAY_HOST_AUTH");
            printf "    Username = ${RELAY_HOST_AUTH[0]}\n";
            printf "    Password = ***\n";
            RELAY_HOST_AUTH="${RELAY_HOST_AUTH[0]}:${RELAY_HOST_AUTH[1]}";
        fi
        printf "\n";
    fi
fi
if [ -n "$RELAY_HOST" ];
then
    echo "[${RELAY_HOST[0]}]:${RELAY_HOST[1]} $RELAY_HOST_AUTH" | xargs > $SASL_PASSWORD_FILE;
else
    printf "No data for relay host password file.\n";
    echo "" > $SASL_PASSWORD_FILE;
fi
$POSTMAP_EXECUTABLE "$SASL_PASSWORD_FILE";
printf "Updated files:\n";
$LS $SASL_PASSWORD_FILE*

printf "Starting rsyslog in background.\n";
$RSYSLOG_EXECUTABLE;

printf "Starting postfix in foreground.\n";
$POSTFIX_EXECUTABLE start-fg;
