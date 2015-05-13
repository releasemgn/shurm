[home](home.md) -> [documentation](documentation.md) -> [monitoring](monitoring.md)

Defines how to setup easy and useful monitoring of your environment.



---


# Definitions #

  * **monitoring server** - server where there are regular scheduled scipts to check data and produce report files
  * **presentation server** - HTTP-server, which makes report files available to end-users
  * **rrd-file** - round-robin file, storing monitoring data metrics by means of rrdtool utility

# Overview #

  * **monitoring** module - allows to view total status of environment evailability, based on checkev.sh sctipt outputs
  * **monitoring** module - tracks basic environment availability metrics and generates history graphs
  * **monitoring** module - enables to drill from top sign of unhealthy state to specific process or host

# Scripts #

  * check.sh
  * report.sh
  * limittime.sh
  * run-checkenv.sh
  * run-checkweb.sh
  * creategraph.sh
  * showenvstatus-image.sh