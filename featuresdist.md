[home](home.md) -> [documentation](documentation.md) -> [features](features.md) -> [featuresdist](featuresdist.md)

Explains how to create and maintain distributives using URM.



---


# Location of distributives #

  * location of distributives is defined in environment specification file
  * practically physical location can be the same for environments but different environments can be deployed from different administration hosts; e.g. production environment can be deployed from protected host, while specific test environment can be deployed from ordinary administration host, available for developrs
  * environment specification file defines distributive location using below properties:
```
if environment administration box and distributive box are the same, add just local path:
	<property name="distr-path" value="/distr/myproduct"/>
then calling for release 1.2.3 means accessing folder /distr/myproduct/1.2.3

if deployment box differs from distributive box then you need to define source box and login:
	<property name="distr-use-local" value="false"/>
	<property name="distr-remotehost" value="release-reader@myhost"/>

to access this host under provided login URM uses private key
implicitely user can have private key located in ~/.ssh/id_dsa

otherwise you can specify exactly path to private key file:
	<property name="keyname" value="/path/to/keyfile/prodlogin.ppk"/>
```
  * if distributive is on remote host, then it first copied to localhost and then applied to environment
  * it is possible to override port 22 to access distributive box
```
<property name="distr-remotehost" value="release-reader@host:11111"/>
```

# Define distributive items #

  * all possible binary and configuration distributive items are defined in distr.xml
  * distr.xml file split items on categories, arranges them in groups, defines names, defines versioning approach and enables to store binary items in separate folders
  * see Define Codebase to understand product configuration and Prepare and Apply Database Changes to understand database items in distributive
  * built binary items disregarding of whether they are built or prebuilt, are defined in the same section
```
<module>
  <distributive>
    <binary-list>
      <!-- carcass binaries -->
      <distitem name="frgu-integration-ws" type="binary" extension=".war" deployversion="midpound"/>
...
      <distitem name="log4j-1.2.16" type="binary" extension=".jar" deployversion="none"/>
...

in fact you can have no source.xml data at all and prepare distributive manually
```
  * for the purpose of deployment, binary items are grouped in deployment components
```
<module>
	<deployment-binaries>
		<component name="pguweb.fedwar" unit="core">
			<distitem name="fms-web"/>
			<distitem name="pfr-web"/>
			<distitem name="rosreestr-web"/>
			<distitem name="pgu-fed-web"/>
			<distitem name="pgu-poltava-web"/>
		</component>

one binary distributive item can be part of several deployment components
see see Application Deployment for further details
```
  * binary distributive item has below attributes:
```
"name" - reference name, to use in deployment components, source.xml, release.xml

"type" - binary, war, archive.direct, archive.subdir, archive.child
- binary: one file in distributive copied to one file in environment
- war: 2 files - web application and its static stored separately and deployed to another server
- archive.direct: archive content is full content of deployment location
- archive.subdir: archive content is full content of subfolder of deployment location
subdir name is equal to archive basename
- archive.child: archive contains one folder named by archive basename
should be deployed to corresponding subfolder of deployment location 

"obsolete" - applicable only for refactoring-aligned environments and releases
- e.g.:
<release>
	<property name="obsolete" value="false"/>

"distname" - if reference name differs from basename of filename then you need to specify distname
- e.g.:
<distitem name="privateoffice-ear" type="binary" extension=".ear" distname="privateoffice"/>
<distitem name="privateoffice-war" type="binary" extension=".war" distname="privateoffice"/>

"folder" - item is located in distibutive in corresponding subfolder 
- e.g.:
<distitem name="ojdbc6" type="binary" extension=".jar" folder="thirdparty"/>
will lead to file path - $DISTPATH/thirdparty/ojdbc6.jar

"deployname" - distributive item basename will be changed in environment to specified value

"deployversion" - defines how to add version information
- see Application Deployment for details

"extension" - defines extention, including all characters after basename excluding version
- e.g.:
<distitem name="backend-pg" type="binary" extension=".war"/>
<distitem name="frgu-integration-groovy" type="archive.direct" extension="-groovy.tar.gz"/>
```

# Release planning and updates #

  * release planning is performed using release specification file release.xml located in distributive folder
  * release.xml defines components included in release
  * create distributive folder and release.xml manually
  * example of release definition aimed to build and deploy all binaries and configuration:
```
<release>
	<build>
		<buildset type="core" all="true"/>
		<buildset type="prebuilt" all="true"/>
	</build>

	<configure all="true"/>
</release>
```
  * more specific incremental release can limit projects and components included:
```
<release>
	<build>
		<buildset type="core">
			<project name="pgu-paygate"/>
			<project name="pgu-portal"/>
			<project name="pgu-forms-core-front"/>
			<project name="pgu-forms-svc"/>
			<project name="sp"/>
			<project name="pgu-forms-core-back"/>
			<project name="bem"/>
			<project name="pgu-core">
				<distitem name="smev-lk-service"/>
				<distitem name="drafts"/>
				<distitem name="pgu-worker"/>
			</project>
		</buildset>

		<buildset type="prebuilt">
                        <project name="carcass" buildversion="3.12">
         	                <distitem name="frgu-integration-inc"/>
         	                <distitem name="frgu-integration-groovy"/>
                        </project>
		</buildset>
	</build>

        <configure>
                <component partial="true" name="serviceregistry.settings.conf"/>
                <component partial="true" name="jms.conf"/>
        </configure>
</release>

Last example means:
- building project pgu-portal and deploying all its registered binaries
- building project pgu-core and deploying only listed 3 binaries
- downloading 2 listed prebuild dependency binaries

Configure:
- download and deploy 2 configuration components - only present in release repository
```
  * if you need to update release scope and make additional build, you need to keep in mind dependencies and hidden rules:
```
your incremental build is affected by previous builds
if you increase the scope and performing full release build it does not cause any problems

if you reduce release scope then you need to rebuild descoped projects by production tag
then you need to rebuild new release scope
it is recommended to mark descoped items by changing elements to descopedproject, descopeddistitem
do not delete anything from release.xml after build

if you have increased release scope you can run limited build only according to dependencies
```

# Prepare binary updates #

  * normally codebase update means regenerating related binary files and deploying these files to production environment
  * practically there are cases where some binaries have to be changed due to codebase change are not part of specific release; also there are  cases when release item is updated in one location of production environment and and stays the same in another production location
  * whatever situation is in place you need to understand what and why should be changed, and define it in deployment plan; default URM behavior will lead to normal scenario
```
for default scenario add projects which have planned update according to release planning
		<buildset type="core">
			<project name="pgu-paygate"/>
this means that all binaries defined in source.xml are included in release
see also Build Projects for details on modifying tags and branches to be built if required

if you have some project required to be built but you know that not all of its binaries are in release - 
then specify exactly what binaries should be included in release
		<buildset type="core">
			<project name="pgu-core">
				<distitem name="smev-lk-service"/>
				<distitem name="drafts"/>
				<distitem name="pgu-worker"/>
			</project>

see Application Deployment for details on how to limit deployment
```
  * to download items:
```
to download all items:
./getall.sh

to download all core non-release items:
./getall.sh core

to download all prebuilt non-release items:
./getall.sh prebuilt

to download binaries of selected proejcts:
./getall.sh core project1 project1
./getall.sh prebuilt project3 project4

to download next planned release binaries without affecting distributive folder:
./getall-release.sh ...
use the same parameters as for getall.sh
items will be downloaded to folder defined in config.sh
C_CONFIG_ARTEFACTDIR=~/build/artefacts/$C_CONFIG_PRODUCT

to download specific release binaries without affecting distributive folder:
./getall-release.sh -release 1.2.3 ...

to download next planned release binaries and copy to distributive folder:
./getall-release.sh -dist ...
this will overwrites previous binary content of distributive

note, that any binaries in distributive are not deleted and can be only overwritten by getall
if some binary was descoped you need manually delete it from distributive
```
  * option -release is processed differently depending on release type:
```
- if release name is X.Y then it is treated as major release
major release has source folder major-release-X.Y in releases svn

- if release name is like "NNN-demo-ZZZ" then it is regarded as demo release
demo release has source folder demo-ZZZ-NNN, where ZZZ - demo id and NNN - baseline version

- otherwise release RRR is ordinary patch release
patch release has source folder prod-patch-RRR
```
  * standard URM release process requires that projects included in product have version in pom.xml equal to last major release; this version is not changed in minor releases - hence not requiring dependency updates; it corresponds to rules of backward compatibility - items having the same build versions are backward compatible with each other
```
getall scripts download from nexus version according to setting in config.sh:
C_CONFIG_VERSIONBRANCH=$C_CONFIG_VERSION_BRANCH_MAJOR.$C_CONFIG_VERSION_BRANCH_MINOR

this version should be set in pom.xml
```
  * thirdparty items obviously have their own versions and should be defined separately
```
use dist item without version:
<project name="thirdparty" version="branch" group="core">
	<distitem name="xalan" type="svn" path="releases/fedpgu/thirdparty/xalan.jar"/>

use dist item with version being part of item name:
	<distitem name="xmlsec" type="svn" path="releases/fedpgu/thirdparty/xmlsec-1.4.3.jar"/>

use dist item with explicitly defined version:
	<distitem name="solr" type="nexus" extension=".war" path="org/apache/solr" version="3.3.0"/>
```
  * prebuilt items from another product can be downloaded by specifying version in release.xml:
```
		<buildset type="prebuilt">
                        <project name="carcass" buildversion="3.12">
         	                <distitem name="frgu-integration-inc"/>
         	                <distitem name="frgu-integration-groovy"/>
                        </project>
		</buildset>
```
  * buildable items are downloaded from nexus
```
nexus instance defined by variable in config.sh:
C_CONFIG_NEXUS_BASE=http://mynexus.com

nexus repository is defined by build mode in config.sh:
if [ "$VERSION_MODE" = "devtrunk" ]; then
	C_CONFIG_NEXUS_REPO=snapshots

nexus location in repository is defined in source.xml:
	<distitem name="equeue" type="nexus" extension=".war" path="ru/rtlabs/idecs/equeue"/>
```
  * prebuilt items can be downloaded from nexus or svn
```
nexus repository is defined by build mode in config.sh
if prebuilt project has name "thirdparty", its location is defined by variable in config.sh:
C_CONFIG_NEXUS_PATH_THIRDPARTY=$C_CONFIG_NEXUS_BASE/content/repositories/thirdparty

svn location is defined using:
	<distitem name="geodb" type="svn" path="releases/pgu/thirdparty/geodb.tar.gz"/>

svn instance url prefix is defined by variable in config.sh:
C_CONFIG_SVNOLD_PATH=http://mysvn.com/svn
```

# Prepare configuration updates #

  * configuration changes are defined in release folders stored in svn
```
svn instance is defined by variable in config.sh:
C_CONFIG_SOURCE_RELEASEROOTDIR=$C_CONFIG_SVNOLD_PATH/releases/$C_CONFIG_PRODUCT/changes

releases are grouped to folders using variable in config.sh, e.g. corresponding to next major release:
C_CONFIG_RELEASE_GROUPFOLDER=R_${C_CONFIG_VERSION_BRANCH_MAJOR}_${C_CONFIG_VERSION_BRANCH_NEXTMINOR}

configuration files should be commited to config/templates subdirectory of release folder
cofiguration updates are in fact part of product configuration codebase, store as templates
```
  * release folder is used to store configuration updates, database updates and other release-related artefacts:
```
for instance, release 1.2.3 configuration will be stored in
http://mysvn.com/svn/releases/myproduct/changes/R_1_3/1.2.3/config/templates
```
  * unit of configuration update is stored in svn as component directory in configuration subfolder in release:
```
if configuration component is defined as
<component name="forum.server.conf" subdir="prod" unit="core" type="files" 
files="server.xml log4j.xml logging.properties" layer="server"/>

then in release we can have one file:
http://mysvn.com/svn/releases/myproduct/changes/R_1_3/1.2.3/config/templates/forum.server.conf/server.xml

note that we can skip adding log4j.xml file - it means partial configuration component update
it requires adding to release.xml:
        <configure>
                <component partial="true" name="forum.server.conf"/>
        </configure>
```
  * template files are downloaded to distributive folder from svn:
```
target location is $DISTPATH/config
files are downloaded with unix/windows newlines translation
components downloaded are verified for correctness

to download to artefact directory only:
./getall-release.sh config

to download to distributive:
./getall-release.sh -dist config
this will replace previous configuration content of distributive
```
  * see further details on configuration files variables and deployment in Application Deployment

# Prepare database updates #

  * database changes are stored in svn release folder in sql subfolder
  * in distributive database changes are stored in SQL subfolder
  * to download database changes use:
```
to download changes for next planned release:
cd $MY_PRODUCT_HOME/master/makedistr/<buildmode>/database
./getsql.sh
previous content of SQL folder will be deleted

to download specific release:
cd $MY_PRODUCT_HOME/master/database
./getsql.sh prod-patch-1.2.3
./getsql.sh major-release-1.3
./getsql.sh demo-exotic-1.3
```
  * find further details on database updates in Prepare and Apply Database Changes