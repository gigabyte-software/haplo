# Haplo Docker Setup Log

## Step 1: Initial Setup
- Built Docker image successfully
- Created container: `docker run -d --name haplo-dev-2 -p 8080:8080 -p 8443:8443 haplo`
- Container started, PostgreSQL service started successfully
- Created haplo role and database in PostgreSQL
- Ran haplo-install.sh script, which:
  - Attempted to install necessary packages
  - Set Java 8 as default
  - Updated CA certificates
  - Set up development PostgreSQL instance

## Step 2: Networking Issue
- **ERROR**: Unable to clone the Haplo repository from GitHub (`Could not resolve host: github.com`)
- This indicates a networking issue within the container
- Need to verify DNS resolution and internet connectivity inside the container

## Step 3: DNS Configuration Fix
- Updated entrypoint.sh to check for internet connectivity
- Started a new container with explicit DNS configuration: 
  ```
  docker run -d --name haplo-dev-3 --dns 8.8.8.8 --dns 8.8.4.4 -p 8080:8080 -p 8443:8443 haplo
  ```
- **SUCCESS**: Container successfully cloned the Haplo repository from GitHub
- Build process is continuing with downloading JRuby and other dependencies

## Step 4: Database Configuration Issues
- Discovered several database-related issues:
  - PostgreSQL wasn't being initialized correctly
  - Permission problems with database directories
  - The application was looking for `khq_development` but we were creating `haplo_development`
  - PostgreSQL wasn't starting reliably before the application tried to connect

## Step 5: Database Configuration Fix
- Updated entrypoint.sh with robust database handling:
  - Proper initialization of PostgreSQL
  - Creating both `haplo_development` and `khq_development` databases
  - Setting correct permissions on all directories
  - Adding wait logic to ensure PostgreSQL is ready before proceeding
  - Adding checks to restart PostgreSQL if it's down when the application starts
- Rebuilt Docker image with improved entrypoint.sh
- Started new container: 
  ```
  docker run -d --name haplo-dev-5 --dns 8.8.8.8 --dns 8.8.4.4 -p 8080:8080 -p 8443:8443 haplo
  ```

## Step 6: IPTables and Ownership Errors
- Encountered issues with:
  - IPTables errors during haplo-install.sh execution
  - Ownership mismatch between PostgreSQL config and data directories
  - Error: `Config owner (postgres:102) and data owner (haplo:1000) do not match`

## Step 7: PostgreSQL Ownership Fix
- Updated entrypoint.sh with enhanced PostgreSQL handling:
  - Added complete ownership consistency fix with correct permissions (700)
  - Added cleanup of any existing PostgreSQL data to start fresh
  - Fixed PostgreSQL startup using direct pg_ctl instead of system service
  - Added explicit database schema initialization by running init_dev_db.sh script
  - Rebuilt Docker image with the improved entrypoint script
- Started final container:
  ```
  docker run -d --name haplo-dev-7 --dns 8.8.8.8 --dns 8.8.4.4 -p 8080:8080 -p 8443:8443 haplo
  ```

## Step 8: Verification
- Docker container with completely automated setup
- PostgreSQL ownership issues resolved
- Database schema properly initialized
- Web application should be accessible at:
  - HTTP: http://localhost:8080
  - HTTPS: https://localhost:8443 