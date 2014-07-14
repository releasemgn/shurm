#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

P_ENVFILE=$1

. ./common.sh

C_ENV_FILE=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/env/$P_ENVFILE

# set environment file
f_env_setpath $C_ENV_FILE
