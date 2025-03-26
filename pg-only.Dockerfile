# Base image with necessary packages
FROM ubuntu:20.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Set up timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install PostgreSQL and sudo
RUN apt-get update && apt-get install -y \
    sudo \
    postgresql-12 \
    postgresql-client-12 \
    && rm -rf /var/lib/apt/lists/*

# Create a user for running the application
RUN useradd -m -s /bin/bash haplo && \
    echo 'haplo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/haplo && \
    chmod 0440 /etc/sudoers.d/haplo

# Make Haplo user a member of the postgres group and vice versa
RUN usermod -a -G postgres haplo && \
    usermod -a -G haplo postgres

# Setup PostgreSQL directories with proper permissions
RUN mkdir -p /var/run/postgresql && \
    chown -R postgres:postgres /var/run/postgresql && \
    chmod 2777 /var/run/postgresql

# Configure PostgreSQL
RUN echo "listen_addresses = '*'" >> /etc/postgresql/12/main/postgresql.conf && \
    echo "unix_socket_directories = '/var/run/postgresql'" >> /etc/postgresql/12/main/postgresql.conf && \
    echo "local all all trust" > /etc/postgresql/12/main/pg_hba.conf && \
    echo "host all all 127.0.0.1/32 trust" >> /etc/postgresql/12/main/pg_hba.conf && \
    echo "host all all ::1/128 trust" >> /etc/postgresql/12/main/pg_hba.conf && \
    echo "host all all 0.0.0.0/0 trust" >> /etc/postgresql/12/main/pg_hba.conf

# Copy a simple start script
COPY <<'EOF' /usr/local/bin/start-pg.sh
#!/bin/bash
set -e

# Initialize PostgreSQL if needed
if [ ! -f /var/lib/postgresql/12/main/PG_VERSION ]; then
  echo "Initializing PostgreSQL database cluster..."
  sudo -u postgres /usr/lib/postgresql/12/bin/initdb -D /var/lib/postgresql/12/main
fi

# Start PostgreSQL
echo "Starting PostgreSQL..."
sudo service postgresql start

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
max_attempts=10
attempts=0
until sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1 || [ $attempts -eq $max_attempts ]; do
  attempts=$((attempts+1))
  echo "Waiting for PostgreSQL to start ($attempts/$max_attempts)..."
  sleep 1
done

if [ $attempts -eq $max_attempts ]; then
  echo "ERROR: PostgreSQL failed to start within the allocated time."
  exit 1
fi

# Create haplo user if it doesn't exist
if ! sudo -u postgres psql -tAc "\\du" | grep -q "haplo"; then
  echo "Creating haplo database user..."
  sudo -u postgres psql -c "CREATE ROLE haplo WITH LOGIN CREATEDB PASSWORD 'haplo';"
fi

# Create haplo_development database if it doesn't exist
if ! sudo -u postgres psql -tAc "\\list" | grep -q "haplo_development"; then
  echo "Creating haplo_development database..."
  sudo -u postgres psql -c "CREATE DATABASE haplo_development OWNER haplo ENCODING 'UTF8' TEMPLATE template0;"
fi

# Keep container running
echo "PostgreSQL is running and configured. Press Ctrl+C to stop."
tail -f /dev/null
EOF

RUN chmod +x /usr/local/bin/start-pg.sh

# Expose PostgreSQL port
EXPOSE 5432

# Start PostgreSQL when container starts
CMD ["/usr/local/bin/start-pg.sh"] 