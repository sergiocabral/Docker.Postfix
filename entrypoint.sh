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
else
    printf "This is NOT the first run.\n";
fi

sleep infinity;
