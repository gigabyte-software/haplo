# Haplo Docker Build Log

## Initial Setup
1. Successfully built Docker image using the Dockerfile: `docker build -t haplo .`
2. Successfully started container: `docker run -d --name haplo-container -p 8080:8080 -p 8443:8443 haplo`

## Enhanced Docker Setup
1. Created modified Dockerfile with entrypoint.sh script
2. Built new image: `docker build -t haplo:v2 .`
3. Created new container: `docker run -d --name haplo-container -p 8080:8080 -p 8443:8443 haplo:v2`

## Successful Steps
1. The enhanced Docker container with entrypoint.sh properly configures permissions and users
2. PostgreSQL development database successfully initialized
3. Haplo repository successfully cloned from GitHub 
4. Directory permissions successfully set up via entrypoint.sh
5. Port forwarding configuration set up
6. Manually downloaded and extracted JRuby: 
```
docker exec -t haplo-container bash -c "cd /home/haplo && mkdir -p haplo-dev-support/vendor && cd haplo-dev-support/vendor && curl -o jruby.tar.gz https://s3.amazonaws.com/jruby.org/downloads/9.2.21.0/jruby-bin-9.2.21.0.tar.gz"
docker exec -t haplo-container bash -c "cd /home/haplo/haplo-dev-support/vendor && tar -xzf jruby.tar.gz && ln -sf jruby-9.2.21.0 jruby && chown -R haplo:haplo jruby jruby-9.2.21.0"
```
7. Successfully ran the fetch-and-compile.sh script:
```
docker exec -i haplo-container bash -c "cd /home/haplo/haplo && sudo -u haplo /usr/local/bin/fetch-and-compile.sh -n"
```

## Database Setup Progress
1. Successfully created a development database with proper UTF8 encoding:
```
docker exec -i haplo-container bash -c "sudo -u postgres psql -c 'CREATE DATABASE khq_development WITH TEMPLATE template0 ENCODING UTF8;'"
```

2. Successfully set up the database with required PostgreSQL extensions:
```
docker exec -i haplo-container bash -c "cd /home/haplo/haplo && sudo -u postgres psql -d khq_development -f db/database_setup.sql"
```

3. Successfully loaded global SQL tables:
```
docker exec -i haplo-container bash -c "cd /home/haplo/haplo && sudo -u postgres psql -d khq_development -f db/global.sql"
```

4. Successfully loaded object store global tables:
```
docker exec -i haplo-container bash -c "cd /home/haplo/haplo && sudo -u postgres psql -d khq_development -f db/objectstore_global.sql"
```

5. Successfully generated and loaded PostgreSQL functions for Xapian text indexing:
```
docker exec -i haplo-container bash -c "cd /home/haplo/haplo && sudo -u haplo /home/haplo/haplo-dev-support/vendor/jruby/bin/jruby lib/xapian_pg/function_sql.rb | sudo -u postgres psql khq_development"
```

## Server Startup
1. Successfully started the Haplo server in development mode:
```
docker exec -i haplo-container bash -c "cd /home/haplo/haplo && sudo -u haplo script/server"
```

Server output shows successful initialization:
```
===============================================================================
               Haplo Platform (c) Haplo Services Ltd 2006 - 2021
             Licensed under the Mozilla Public License Version 2.0
===============================================================================
Starting framework in /home/haplo/haplo with environment development
   **** PLUGIN DEBUGGING ENABLED ****
Components:
  enable info-geoip           IP Geographic database
  enable pdfbox               PDF file transforms with PDFBox
Installed DeveloperRuntimeModeSwitch as JS runtime cache class
INFO  2025-03-21 14:13:39,507 [org.haplo.app]: Application loaded (took 4944ms), logging started.
INFO  2025-03-21 14:13:39,507 [org.haplo.app]: JavaScript initialisation took 959ms
INFO  2025-03-21 14:13:39,507 [org.haplo.app]: JavaScript optimisation level 0
...
INFO  2025-03-21 14:13:39,827 [org.haplo.app]: Ready to handle requests. Boot took 5264ms
...
INFO  2025-03-21 14:13:42,840 [org.haplo.app]: Background tasks started.
```

2. The server is accessible via HTTP at http://localhost:8080
3. Initial request to the server returns a 404 because no application has been initialized yet

## Application Initialization
1. Successfully initialized the Haplo application using the init_app.sh script:
```
docker exec -i haplo-container bash -c "cd /home/haplo/haplo && sudo -u haplo db/init_app.sh haplo localhost 'Haplo Dev' sme 1"
```

This script:
- Created application-specific tables in the database
- Set initial application globals
- Loaded Dublin Core object schemas and types
- Configured the application with the name 'haplo' and hostname 'localhost'

## Application Initialization Challenges
We faced several challenges with initializing the application due to string escaping issues in the PowerShell environment when trying to run:
```
docker exec -i haplo-container bash -c "cd /home/haplo/haplo && sudo -u haplo script/runner 'KAppInit.create(\"haplo\", \"localhost\", \"Haplo Dev\", \"sme\", 1)'"
```

Several approaches were attempted:
1. Using the init_app.sh script directly
2. Using script/runner with different quoting styles
3. Creating a temporary file with the Ruby code
4. Passing the code via stdin to script/runner

These attempts failed with various syntax and escaping errors.

The solution was to directly call the init_app.sh script with properly quoted arguments.

## Next Steps
1. Create an initial user using create_app_user.sh
2. Access the Haplo application via the browser

## Database Setup Analysis

After analyzing the database scripts in the `/db` directory, here's how the Haplo database setup works:

### Key Database Scripts
1. `init_production_db.sh` - Sets up a production database
2. `init_dev_db.sh` - Sets up a development database
3. `do_init_db.sh` - Common database initialization script used by both production and development setups
4. `database_setup.sql` - Configures the base PostgreSQL database with required extensions
5. `global.sql` - Sets up global database tables in the public schema
6. `objectstore_global.sql` - Sets up the global object store tables
7. `app.sql` - Defines application-specific tables in a private schema
8. `appglobals.sql` - Sets default values for application settings
9. `prod_perm.sql` - Sets up production database permissions for the haplo user

### Database Initialization Process
1. The `init_dev_db.sh` or `init_production_db.sh` script is called
2. This sets environment variables and calls `do_init_db.sh`
3. `do_init_db.sh` creates a database (`khq_development` for dev, `haplo` for production)
4. Basic extensions are added via `database_setup.sql` (plpgsql, intarray, hstore)
5. PostgreSQL functions for Xapian text indexing are added
6. Global tables are created via `global.sql`
7. Object store global tables are created via `objectstore_global.sql`

### Application Setup Process
1. The `init_app.sh` script is called with app parameters (hostname, title, etc.)
2. This runs a Ruby script that:
   - Creates application-specific tables via `app.sql`
   - Sets initial application globals via `appglobals.sql`
   - Loads Dublin Core object schemas 
3. The `create_app_user.sh` script can be used to create the first user

## Summary
We've created a comprehensive Dockerfile (Dockerfile.complete) that incorporates all our learnings:

1. Uses Ubuntu 20.04 as the base image
2. Installs all required dependencies
3. Creates haplo user with proper permissions
4. Sets up port forwarding
5. Downloads and extracts JRuby
6. Clones the Haplo repository
7. Initializes PostgreSQL database

This Dockerfile can be used to create a complete development environment for Haplo. 