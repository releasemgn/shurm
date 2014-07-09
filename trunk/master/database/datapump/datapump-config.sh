#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

C_CONFIG_SVNPATH=$C_CONFIG_SVNOLD_PATH
C_CONFIG_SVNAUTH=$C_CONFIG_SVNOLD_AUTH
C_CONFIG_PRODUCT=$C_CONFIG_PRODUCT

C_CONFIG_SCRIPT_DROPUSERS=import_dropold.sql
C_CONFIG_PREPAREDATA_SQLFILE=import_preparedata.sql
C_CONFIG_TRUNCATEDATA_SQLFILE=import_truncate.sql
C_CONFIG_FINISHDATA_SQLFILE=import_finishdata.sql
C_CONFIG_CREATEDATA_SQLFILE=uattabs.sql
C_CONFIG_TABLE_FILE=datalight-tables.txt

C_CONFIG_DEFAULT_FULLSCHEMALIST=$C_CONFIG_SCHEMAALLLIST
C_CONFIG_DEFAULT_SCHMAPPING=
for schema in $C_CONFIG_DEFAULT_FULLSCHEMALIST; do
	C_CONFIG_DEFAULT_SCHMAPPING="$C_CONFIG_DEFAULT_SCHMAPPING $schema=$schema"
done
C_CONFIG_DEFAULT_SCHMAPPING=${C_CONFIG_DEFAULT_SCHMAPPING# }

C_CONFIG_DEFAULT_TABLESET=system.admindb_uatdata

# required env-defined params
# C_ENV_CONFIG_FULLSCHEMALIST="<schema list>"
# C_ENV_CONFIG_CONNECTION="<dbconn1>=<value> <dbconn2>=<value> ..."
# C_ENV_CONFIG_LOADDIR="<dbconn1>=<value> <dbconn2>=<value> ..."
# C_ENV_CONFIG_STAGINGDIR=<dumpfiles dir>
# C_ENV_CONFIG_REMOTE_HOSTLOGIN=<hostlogin>
# C_ENV_CONFIG_REMOTE_ROOT=<remote execution dir>
# C_ENV_CONFIG_LOCAL_DATADIR=<local export data dir>
# C_ENV_CONFIG_LOCAL_DATADIR_BACKUP=<local export data backup dir>
# C_ENV_CONFIG_TABLESET=<table where table set is stored>
# C_ENV_CONFIG_REMOTE_SETORAENV=<script to setup access to oracle sid on remote>
# C_ENV_CONFIG_SCHMAPPING="<original schema>=<real schema> <...>=<...> ..."
# C_ENV_CONFIG_RECREATETABLESPACES=yes/no
# C_ENV_CONFIG_DATAPUMP_DIR=<oracle data pump dir name>
# C_ENV_CONFIG_USETRANSFORM=yes/no
C_ENV_CONFIG_ADDTRANSFORM=

