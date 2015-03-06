#!/bin/sh

P_SINGLE_SCHEMA=$1

# load common and env params
. ./common.sh

P_ENV=$C_ENV_CONFIG_ENV
P_DB=$C_ENV_CONFIG_DB
P_DBCONN_MAIN=$C_ENV_CONFIG_DB

./run-export.sh $P_ENV $P_DB $P_DBCONN_MAIN $P_SINGLE_SCHEMA
