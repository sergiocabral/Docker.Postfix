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
SUFFIX_TEMPLATE=".template";
DIR_CONF="/etc/postfix";
DIR_CONF_BACKUP="$DIR_CONF.original";
DIR_CONF_TEMPLATES="$DIR_CONF.templates";
DIR_CONF_DOCKER="$DIR_CONF.conf";
DIR_SCRIPTS="${DIR_SCRIPTS:-/root}";
LS="ls --color=auto -CFl";

if [ ! -e "$POSTFIX_EXECUTABLE" ];
then
    printf "Postfix is not installed.\n" >> /dev/stderr;
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

    USER=postfix;
    chmod -R 755 $DIR_CONF_BACKUP       && chown -R $USER:$USER $DIR_CONF_BACKUP;
    chmod -R 755 $DIR_CONF_TEMPLATES    && chown -R $USER:$USER $DIR_CONF_TEMPLATES;
    chmod -R 755 $DIR_CONF_DOCKER       && chown -R $USER:$USER $DIR_CONF_DOCKER;
    
    $LS -d $DIR_CONF $DIR_CONF_BACKUP $DIR_CONF_TEMPLATES $DIR_CONF_DOCKER;
else
    printf "This is NOT the first run.\n";
fi

sleep infinity;
