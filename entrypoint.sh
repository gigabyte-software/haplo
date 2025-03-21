#!/bin/bash

# Create the haplo user and give sudo access
useradd -m -s /bin/bash haplo
echo 'haplo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/haplo
chmod 0440 /etc/sudoers.d/haplo

# Create directories with proper permissions for the haplo user
mkdir -p /home/haplo/haplo-dev-support
chmod -R 777 /home/haplo
chown -R haplo:haplo /home/haplo

# Create directories that the script will need
mkdir -p /opt/haplo
chmod -R 777 /opt/haplo
chown -R haplo:haplo /opt/haplo

# Make sure the haplo directory has proper permissions
chmod -R 777 /haplo
chown -R haplo:haplo /haplo

# Keep container running
exec "$@" 