[home](home.md) -> [documentation](documentation.md) -> [features](features.md) -> [featuresconfig](featuresconfig.md)

Defines process of managing environment configuration files.



---


# Deployment of configuration files #

  * configuration files are usually flat files allowing to view and edit them in the environment
  * release can introduce certain configuration files changes which URM can deploy to the environment
  * configuration files can be fully specified in release or can be template files
  * template files reference parameters defined elsewhere

```
URM will deploy configuration files ony if environment specification file has property:
	<property name="configuration-deploy" value="yes"/>

- product parameter file should have:
C_CONFIG_USE_TEMPLATES=yes

- redist.sh operation sets variables to templates when copying files from distributive to staging area
- variables are defined in environmet specification file
- before rolling out these files one can check validity of substitution
- alternatively one can run ./configure.sh to generate configuration file set locally
- last requires correct merge of release change to the full configuration set:
	$C_CONFIG_SOURCE_CFG_ROOTDIR/templates

redist.sh copies cold-deployed configuration archive to:
	<redist dir>/<server>/<releasedir>/config/[/<location>]/<component>.config.tar
- then rollout.sh extracts this archive to
	<server root dir>/<location>

hot-deployed configuration archive is copied to:
	<redist dir>/<server>/<releasedir>/hotdeploy/config/[/<location>]/<component>.config.tar
- then rollout.sh copies this archive to below dir and executes hot deploy command
	<server root dir>/<hotdeploydir>/<location>

Binaries can be deployed without changing configuration, by using:
	./redist.sh -noconf <release> ...

Otherwise, one can deploy only configuration files:
	./redist.sh -nobinary -conf <release> ...

Even if environment property is set to ignore configuration files, one can override this by using explicit option:
	./redist.sh -conf <release> ...
	./deployredist.sh -conf <release> ...
```

# Custom configuration components #

  * there are situations where having configuration template files is not enough
  * one case is when configuration files of given component for 2 environments are completely different in structure, so that it is not possible to have common template
  * another case is when you need to have in environment many simplar files, those are better to generate from meta-template to reduce redundancy and also substitute environment-dependent parameters
  * it means you need to add custom logic to generating final configuration files
  * URM allows to add custom logic by using custom scipt precongure.sh, stored in configuration component in source; it is executed in redist operation and deleted before rollout
```
script has predefined interface parameters:
P_PRECONFIGURE_ENV=$1 - environment ID
P_PRECONFIGURE_DC=$2 - datacenter ID
P_PRECONFIGURE_SERVER=$3 - server ID

if you need to keep one file for each environment:
- save in your component files: 
template-dev.xml
template-uat.xml
template-prod.xml
- add to component files preconfigure.sh script:
P_PRECONFIGURE_ENV=$1
cp template-$P_PRECONFIGURE_ENV.xml myconfig.xml
rm -rf template-*

if you need to generate set of files using ыещкув meta-template template-config.xml, add preconfigure.sh:
variants="a b c d e f g h"
for x in $variants; do 
	cat template-config.xml | sed "s/@myvar@/$x/g" > config-$x.xml
done
rm -rf template-*
```
  * you can use library functions to get variable value, possibly defined via another variable, to use in preconfigure.sh:
```
f_env_getserverpropertyfinalvalue $P_PRECONFIGURE_DC $P_PRECONFIGURE_SERVER "var"
F_MYVAR=$C_ENV_XMLVALUE

f_env_getdcpropertyfinalvalue $P_PRECONFIGURE_DC "var"
F_MYVAR=$C_ENV_XMLVALUE

f_env_getenvpropertyfinalvalue "var"
F_MYVAR=$C_ENV_XMLVALUE

f_env_getsecretpropertyfinalvalue "var"
F_MYVAR=$C_ENV_XMLVALUE
```

# Save and restore overall configuration #

  * environment configuration files can be saved in svn and restored from templates
  * all of the defined configuration components are updated
```
Configurations files are referenced in configuration components in distr.xml
- server configuration components are defined in environment specification file:
	<server name="pguapp" type="generic.server"
		...
		>
		...
		<configure component="commonapp.p6spy.conf" deploypath="jboss/server/default/conf"/>
		<configure component="pguapp.cryptopro.ca" deploypath="jboss_keys/ECPrOVrP.TEST"/>
		<configure component="pguapp.app.conf" deploypath="jboss/server/default/conf/pgu"/>
		<configure component="pguapp.config.ds" deploypath="jboss/server/default/deploy"/>

- mapping component to files is defined in distributive specification file:
		<component name="pguapp.cryptopro.ca" 		unit="core" type="dir" layer="server"/>
		<component name="pguapp.app.conf" 		unit="core" type="dir" layer="server"/>
		<component name="pguapp.jbossweb-sar.conf" 	unit="core" type="files" files="server.xml" 
			layer="server"/>

Environment configuration files are stored in $C_CONFIG_SOURCE_CFG_LIVEROOTDIR/<env> by calling:
	./svnsaveconfig.sh

Still, files are restored from template directory $C_CONFIG_SOURCE_CFG_ROOTDIR/templates by calling:
	./svnrestoreconfig.sh

- note, that svnrestoreconfig does not stop or start any server, 
so please execute them manually when required
- currently, restore of hotdeploy configuration is not supported
```

# Configuration categories #

  * configuration components can be grouped in custom category in svn
  * one can define different access rules to categories
```
e.g. one can define "prod" category and "dev" category
svn:releases/myproduct/configuration/templates/prod
svn:releases/myproduct/configuration/templates/dev
Developer can have access only to commit to dev configuration
In the same time release engineer can use prod to track prod configuration

component references category using subdir attribute:
<component name="osb.conf" subdir="prod" type="files" 
    files="smev-xquery.xml smev-xquery.properties" layer="server"/>
```
  * svnrestoreconfig.sh and svnsaveconfig.shg will use proper paths to find configuration component files