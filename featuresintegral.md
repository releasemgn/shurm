Functional Capabilities of URM - Integral Operations
[home](home.md) -> [documentation](documentation.md) -> [features](features.md) -> [featuresintegral](featuresintegral.md)

Features to perform on top level of release functions



---


# Complex Release Operations #

  * master/release.sh script allows to build, get configuration and DB changes and deploy all into uat environment using one command
```
./release.sh default uat - next planned release
./release.sh 1.13.5-demo uat - given release

./release.sh -env express default uat - next planned release but to express environment
```

# Update Environment Wrappers #

  * environment wrappers help to set context of deployment operations to avoid risk of harm something in undesired environment
  * if list of environments or their datacenters are changed, set of wrappers should be rebuilt
```
make sure etc is up to date:
~/svnget $MYPRODUCT_DEPLOYMENT_HOME/etc

recreate wrappers according to set of environments and datacenters in etc:
./configure.sh

update Your Product URM in svn:
./svnsave.sh
```

# Using predefined release labels #

  * URM supports using predefined release labels in any URM script instead of specific release label
  * predefined release label "last" - points to $C\_CONFIG\_VERSION\_LAST\_FULL value defined in product config.sh script
  * predefined release label "next" - points to $C\_CONFIG\_VERSION\_NEXT\_FULL value defined in product config.sh script
  * predefined release label "prod" means release marked with postfix "-prod" in distributive directory

# Command line output #

  * command line has two generic levels - standard and debug
  * to add debug information to output, use "-showall" option:
```
e.g. in rollout every command executing on remote host will be visible:
./rollout.sh -showall

it can be combined with noexecute option:
./rollout.sh -showall -showonly
```
