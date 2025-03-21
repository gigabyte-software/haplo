# Use Ubuntu 20.04 as it's one of the supported versions
FROM ubuntu:20.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Set up timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Copy installation scripts
COPY haplo-install.sh /usr/local/bin/haplo-install.sh
COPY fetch-and-compile.sh /usr/local/bin/fetch-and-compile.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/haplo-install.sh /usr/local/bin/fetch-and-compile.sh /usr/local/bin/entrypoint.sh

# Install dependencies and set up Haplo
RUN apt-get update && apt-get install -y \
    sudo \
    git \
    g++ \
    make \
    openjdk-8-jdk \
    maven \
    avahi-daemon \
    uuid-dev \
    curl \
    patch \
    zlib1g-dev \
    libxapian30 \
    libxapian-dev \
    postgresql-12 \
    postgresql-server-dev-12 \
    postgresql-contrib-12 \
    iputils-ping \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Create required directories
RUN mkdir -p /haplo/database \
    /haplo/log \
    /haplo/tmp \
    /haplo/run \
    /haplo/generated-downloads \
    /haplo/files \
    /haplo/textweighting \
    /haplo/plugins \
    /haplo/messages \
    /haplo/messages/app_create \
    /haplo/messages/app_modify \
    /haplo/messages/spool \
    /haplo/sslcerts \
    /haplo/textidx \
    /opt/haplo

# Expose the ports that Haplo uses
EXPOSE 8080 8443

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Keep container running
CMD ["tail", "-f", "/dev/null"]

