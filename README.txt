This is a repository containing scripts to provision stand alone contrail system.
The script contrail.sh is the executive to invoke in different modes.
The command and its usage is as follows:

contrail.sh build
- Downloads the dependencies, source code and builds the contrail system based on INSTALL_PROFILE

contrail.sh install
- Installs the contrail system by placing the binaries (generated from build) and configuration files in the corresponding directories

contrail.sh configure
- Overrides the environment values in localrc and replaces the values in configuration files.

contrail.sh start
- Starts the daemons with out screen as default. If USE_SCREEN is set as True in localrc, it starts daemons with screen.

contrail.sh stop
- Stops the daemons

contrail.sh clean
- cleanup the database.
