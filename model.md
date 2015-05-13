[home](home.md) -> [documentation](documentation.md) -> [model](model.md)

Defines declarative approach used to specify product sources, distributions and environments.



---


# Definitions #

  * **URM model** - set of files, xml element types and attributes to specify product codebase, distributive and environments for automated processing in build, distributive preparation and deployment
  * **URM specification** - xml file, part of URM model

# Overview #

  * declarative specifications define product to a level of detail, sufficient to perform generic release engineering activities
  * URM model allows to limit product knowledge, required from operation teams, and ensures product operating flexibility, which gives developer a means to deliver changes to production without risk and without explaining all the details to operation team
  * URM model allows to manage huge distributed system in a consistent manner with common terms and release approaches
  * URM model is quite compact and helps to engineer, review and re-engineer your IT system
  * as well as URM model is used for automated deployment and environment control in daily ongoing activity, it can be used as reliable source of information about specified physical attributes of elements of the system

# URM Model #

  * codebase URM specification - see [sample](https://code.google.com/p/shurm/source/browse/trunk/master/samples/etc/source.xml)
  * distributive URM specification - see [sample](https://code.google.com/p/shurm/source/browse/trunk/master/samples/etc/distr.xml)
  * environment URM specification - see [sample](https://code.google.com/p/shurm/source/browse/trunk/master/samples/etc/env/uat.xml)
  * URM release specification