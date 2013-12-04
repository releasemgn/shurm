#!/bin/bash

cd `dirname $0`
./_proxy.sh `basename $0` "$@"
