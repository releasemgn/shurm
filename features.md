[home](home.md) -> [documentation](documentation.md) -> [features](features.md)

Defines features implemented in URM.



---


# Integral Operations #

  * [Integral Operations](featuresintegral.md)
    * Complex release operations
    * Update environment wrappers
    * Using predefined release labels
    * Command line output

# Build and Distributive Management #

  * [Define Codebase](featurescodebase.md)
    * Define product codebase
    * Define product buildable codebase
    * Define product configuration
    * Define product database
    * Define prebuilt items
    * Using git repositories
  * [Codebase Management](featurescodeops.md)
    * Bulk codebase operations
    * Tags and branches management
    * Bulk codebase updates
    * Custom operations
    * Find changeset tickets
  * [Build Projects](featuresbuild.md)
    * Multiple Java environments
    * Multiple Maven environments
    * Multiple Nexus environments
    * Build product codebase
    * Build logs
    * Release builds
    * Release tags and branches
  * [Distributive Management](featuresdist.md)
    * Location of distributives
    * Define distributive items
    * Release planning and updates
    * Prepare binary updates
    * Prepare configuration updates
    * Prepare database updates

# Application Deployment #

  * [Host Access, Operating System Activities and Operation Audit](featuresappaccess.md)
    * Operating system accounts
    * Operating system commands
    * Key-based access to hosts
    * Key management
    * File upload logging
    * Showonly mode
    * Execution logging
    * Track environment configuration changes
    * IM notifications
    * Operating system upgrades
  * [Copying Files to Environment](featuresredist.md)
    * Local and remote distributives
    * Renaming files in environment
    * Staging area
    * Partial deployments, using "-unit" option
    * Safe copy over network
    * Multiple server locations
    * Archive deployment
    * Static files deployment
    * Backup and rollack
    * Hot deployment
    * Redundancy check
    * Direct copy files and directories to environment
  * [Environment configuration](featuresconfig.md)
    * Deployment of configuration files
    * Custom configuration components
    * Save and restore overall configuration
    * Configuration categories
  * [Start and Stop Environment Processes](featurescontrol.md)
    * Start and stop of selected servers
    * Services and pure processes
    * Environment health check
    * Process start control
    * Process stop control
    * Auxilliary servers
    * Parallel start and stop of processes, start groups
    * Command servers
  * [Zero Downtime Deployment](featureszerodowntime.md)
    * Using deploygroup
    * Configuration switching deployment
    * Hot deploy

# Prepare and Apply Database Changes #

  * [Manage Databases](featuresdbmanage.md)
    * Complex database configurations
    * Using Oracle datapump to maintain databases
  * [Database Access and Operation Audit](featuresdbaccess.md)
    * Simple database authentification
    * Password file
    * Using database system account
    * Execution audit
    * Storing execution log files
  * [Prepare Database Distributive](featuresdbdist.md)
    * Source folders
    * Creating distributive
    * Declare manual database modifications
    * Prepare bulk load file set
    * Aligned-scripts
    * Pending folders
  * [Apply Database Changes](featuresdbapply.md)
    * Using sqlplus to apply changes
    * Select what and where to apply
    * Apply manual administration scripts using sys account
    * Load data using sqlldr
    * Handling errors
    * Configuring database scripts