#!/bin/bash
set -e

echo "Starting Haplo setup..."

# Create the haplo user and give sudo access
if ! id -u haplo > /dev/null 2>&1; then
  echo "Creating haplo user..."
  useradd -m -s /bin/bash haplo
  echo 'haplo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/haplo
  chmod 0440 /etc/sudoers.d/haplo
fi

# Create directories with proper permissions
echo "Setting up directories..."
mkdir -p /home/haplo/haplo-dev-support
chmod -R 777 /home/haplo
chown -R haplo:haplo /home/haplo

mkdir -p /opt/haplo
chmod -R 777 /opt/haplo
chown -R haplo:haplo /opt/haplo

mkdir -p /haplo
chmod -R 777 /haplo
chown -R haplo:haplo /haplo

# Fix PostgreSQL ownership and permissions - CRITICAL for startup
echo "Setting up PostgreSQL directories and permissions..."
mkdir -p /home/haplo/haplo-dev-support/khq-dev/plugins/
chown -R haplo:haplo /home/haplo/haplo-dev-support
chmod -R 777 /home/haplo/haplo-dev-support

# Make sure the PostgreSQL socket directory exists and has correct permissions
mkdir -p /var/run/postgresql
chmod 777 /var/run/postgresql
chown postgres:postgres /var/run/postgresql

# Complete PostgreSQL ownership consistency fix
# Make sure ALL PostgreSQL directories have consistent ownership
echo "Ensuring PostgreSQL ownership consistency..."
mkdir -p /var/lib/postgresql/12/main
mkdir -p /var/log/postgresql
chmod -R 700 /etc/postgresql /var/lib/postgresql /var/log/postgresql
chown -R postgres:postgres /etc/postgresql
chown -R postgres:postgres /var/lib/postgresql
chown -R postgres:postgres /var/log/postgresql

# Update PostgreSQL configuration to use the correct socket directory
echo "Updating PostgreSQL configuration..."
if ! grep -q "unix_socket_directories" /etc/postgresql/12/main/postgresql.conf; then
  echo "unix_socket_directories = '/var/run/postgresql'" >> /etc/postgresql/12/main/postgresql.conf
fi

# Initialize and start PostgreSQL
echo "Initializing PostgreSQL database..."
if [ ! -f /var/lib/postgresql/12/main/PG_VERSION ]; then
  echo "Initializing main PostgreSQL cluster..."
  sudo -u postgres /usr/lib/postgresql/12/bin/initdb -D /var/lib/postgresql/12/main
fi

echo "Starting PostgreSQL service using pg_ctl..."
sudo -u postgres /usr/lib/postgresql/12/bin/pg_ctl -D /var/lib/postgresql/12/main -l /var/log/postgresql/postgresql-12-main.log start

# Wait for PostgreSQL to start
echo "Waiting for PostgreSQL to be ready..."
max_attempts=30
attempts=0
until sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1 || [ $attempts -eq $max_attempts ]; do
  attempts=$((attempts+1))
  echo "Waiting for PostgreSQL to start ($attempts/$max_attempts)..."
  sleep 1
done

if [ $attempts -eq $max_attempts ]; then
  echo "ERROR: PostgreSQL failed to start within the allocated time."
  echo "Checking PostgreSQL logs:"
  cat /var/log/postgresql/postgresql-12-main.log || true
  echo "Will continue, but application might fail to start properly."
fi

# If we got this far, ensure PostgreSQL is running
if sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1; then
  echo "PostgreSQL started successfully."

  # Create PostgreSQL role if it doesn't exist
  echo "Setting up PostgreSQL role..."
  if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='haplo'" | grep -q 1; then
    sudo -u postgres psql -c "CREATE ROLE haplo WITH LOGIN CREATEDB PASSWORD 'haplo';"
  fi

  # Create both database names the application might be looking for
  echo "Setting up PostgreSQL databases..."
  for db_name in "haplo_development" "khq_development"; do
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$db_name'" | grep -q 1; then
      echo "Creating database: $db_name"
      sudo -u postgres psql -c "CREATE DATABASE $db_name OWNER haplo ENCODING 'UTF8' TEMPLATE template0;"
    else
      echo "Database $db_name already exists."
    fi
  done
else
  echo "WARNING: PostgreSQL is not running! Application will likely fail to start."
fi

# Check internet connectivity before attempting to clone the repository
echo "Checking internet connectivity..."
if ping -c 1 github.com > /dev/null 2>&1; then
  echo "Internet connection is available."
  
  # Create a patched version of haplo-install.sh that doesn't try to set up iptables
  echo "Creating patched installation script..."
  cat /usr/local/bin/haplo-install.sh | sed 's/sudo iptables/echo "SKIPPED in Docker: sudo iptables"/g' > /tmp/haplo-install-docker.sh
  chmod +x /tmp/haplo-install-docker.sh
  
  # Run the modified installation script as the haplo user
  echo "Running Haplo installation script (Docker version)..."
  cd /home/haplo
  sudo -u haplo /tmp/haplo-install-docker.sh
  
  # Skip port forwarding error in Docker
  echo "Note: IPTables port forwarding errors in Docker are expected and can be ignored."
  
  # Check if the application was built correctly
  if [ -d /home/haplo/haplo ]; then
    echo "Haplo repository exists, checking for build artifacts..."
    
    # Explicitly initialize the database schema
    echo "Running database schema initialization scripts..."
    cd /home/haplo/haplo
    
    # Set required environment variables for the initialization scripts
    export KFRAMEWORK_ENV=development
    
    # Run the initialization scripts
    if [ -f db/init_dev_db.sh ]; then
      echo "Running db/init_dev_db.sh..."
      # Modify the script to use template0 to avoid encoding issues
      sed -i 's/createdb --encoding UTF8/createdb --encoding UTF8 --template template0/' db/do_init_db.sh || true
      sudo -u haplo bash -c "cd /home/haplo/haplo && bash db/init_dev_db.sh"
    elif [ -f db/do_init_db.sh ]; then
      echo "Running db/do_init_db.sh directly..."
      # Modify the script to use template0 to avoid encoding issues
      sed -i 's/createdb --encoding UTF8/createdb --encoding UTF8 --template template0/' db/do_init_db.sh || true
      sudo -u haplo bash -c "cd /home/haplo/haplo && KFRAMEWORK_ENV=development bash db/do_init_db.sh"
    else
      echo "WARNING: Could not find database initialization scripts!"
    fi
    
    if [ -d /opt/haplo/app ]; then
      echo "Haplo application was deployed to /opt/haplo"
      
      # Check if start script exists
      if [ -f /opt/haplo/script/server ]; then
        echo "Starting Haplo application..."
        cd /opt/haplo
        
        # Ensure PostgreSQL is running before starting the application
        if ! sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1; then
          echo "PostgreSQL is not running, attempting restart..."
          # Use pg_ctl directly instead of service
          sudo -u postgres /usr/lib/postgresql/12/bin/pg_ctl -D /var/lib/postgresql/12/main restart || {
            echo "Failed to restart PostgreSQL with pg_ctl, trying direct start..."
            sudo -u postgres /usr/lib/postgresql/12/bin/pg_ctl -D /var/lib/postgresql/12/main start
          }
          sleep 3
          
          # Verify PostgreSQL is running now
          if ! sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1; then
            echo "ERROR: PostgreSQL still not running! Application will likely fail to start."
          else
            echo "PostgreSQL restarted successfully."
          fi
        fi
        
        # Start the application
        sudo -u haplo script/server -d
      else
        echo "WARNING: Start script not found at expected location (/opt/haplo/script/server)"
        echo "Checking for alternative startup scripts..."
        find /opt/haplo -name "*.sh" -o -executable -type f | grep -v "\.git" || true
      fi
    else
      echo "WARNING: Haplo application was not deployed to /opt/haplo"
      echo "Checking where the build artifacts might be..."
      find /home/haplo -name "app" -type d || true
    fi
  else
    echo "WARNING: Haplo repository was not cloned correctly."
  fi
else
  echo "WARNING: No internet connection detected. Cannot clone the Haplo repository."
  echo "Please ensure the container has internet access and can resolve DNS for github.com."
  echo "You may need to check your Docker DNS settings."
  
  # Keep running for debugging
  echo "Container will continue running for debugging purposes."
fi

echo "Haplo setup complete!"

# Keep container running
exec "$@" 