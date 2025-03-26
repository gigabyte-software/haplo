## Haplo Platform

A platform and development environment for creating information applications which manage a semi-structured collection of information.

Highlights include:

 * A linked-data style object store, with pervasive multi-values and extensive hierarchy support
 * An expressive label-based permissions model
 * An extensive API for building server-side JavaScript plugins
 * Web interface providing an exceptional user experience
 * Customisable full-text search combined with object store graph queries
 * File handling, including conversion, previewing and version control
 * Lightweight "humane" workflow support
 * Designed to evolve as user needs change, enabling agile application development
 * Proven in production for over seven years, used by a diverse range of clients

For more information, and build instructions, please see the main [Haplo web site](http://haplo.org) and the [API documentation](http://docs.haplo.org/dev/plugin).

### License

Haplo is licensed under the Mozilla Public License Version 2.0. See the LICENSE file for full details.

### Copyright

Haplo is copyright [Haplo Services Ltd](http://www.haplo-services.com). See the COPYRIGHT file for full details.

### Dependencies

Haplo is built on:

 * Java
 * JRuby
 * Mozilla Rhino JavaScript interpreter
 * PostgreSQL
 * Xapian
 * Jetty
 * Apache POI

See the COPYRIGHT and pom.xml files for full dependency information.

# Haplo Docker Image

This repository contains a Dockerized version of the Haplo knowledge management platform.

## Quick Start

Pull the image from Docker Hub:

```bash
docker pull gigabytesoftware/haplo:latest
```

Run a container:

```bash
docker run -d --name haplo -p 8080:8080 -p 8443:8443 gigabytesoftware/haplo:latest
```

Access the application:
- HTTP: `http://localhost:8080`
- HTTPS: `https://localhost:8443` (uses a self-signed certificate)

## Container Details

The Docker image includes:

- Ubuntu 20.04
- PostgreSQL 12
- OpenJDK 8
- Haplo application server
- Self-signed SSL certificate

## Persisting Data

To persist data between container restarts, you can mount volumes:

```bash
docker run -d --name haplo \
  -p 8080:8080 -p 8443:8443 \
  -v haplo-data:/haplo \
  -v haplo-postgres:/var/lib/postgresql/12/main \
  gigabytesoftware/haplo:latest
```

## Environment Variables

No specific environment variables are required to run the container, but they can be used to customize behavior if needed.

## Configuration

The Haplo application code is located at `/home/haplo/haplo` inside the container. The database used is PostgreSQL 12, running in the same container.

## Creating an Application

After starting the container, you will see the message "Application not found for this hostname or URL" when accessing the server. To create an application:

1. Enter the container:
   ```bash
   docker exec -it haplo bash
   ```

2. Run the application setup script:
   ```bash
   cd /home/haplo/haplo
   sudo -u haplo bash db/init_app.sh haplo localhost "My Haplo App" sme 4000
   ```

3. Create an admin user:
   ```bash
   cd /home/haplo/haplo
   sudo -u haplo bash db/create_app_user.sh localhost "Admin User" admin@example.com password
   ```

4. Access the application at http://localhost:8080 or https://localhost:8443

## License

Haplo is licensed under the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, you can obtain one at http://mozilla.org/MPL/2.0/.

## Issues & Contributions

If you encounter any issues or would like to contribute to this Docker image, please open an issue or pull request on the GitHub repository.
