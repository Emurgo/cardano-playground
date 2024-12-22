# Use an official Ubuntu image as the base
FROM --platform=linux/amd64 ubuntu:latest as build
# Install necessary utilities
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    build-essential \
    direnv \
    just \
    jq \
    procps \
    gawk \
    nix \
    procps \
    net-tools \
    && apt-get clean
# Set up the environment for direnv and Nix-like configurations
RUN mkdir -p /etc/nix
RUN touch /etc/nix/nix.conf
# Configure some Nix-like settings in /etc/nix/nix.conf
RUN echo "donotUnpack = true" > /etc/nix/nix.conf && \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf && \
    echo "allow-import-from-derivation = true" >> /etc/nix/nix.conf && \
    echo "extra-experimental-features = fetch-closure" >> /etc/nix/nix.conf

# Create necessary directories for the project
RUN mkdir -p /opt/cardano/cardano-playground

# Clone the repository (uncomment the next line to enable cloning)
# RUN git clone https://github.com/Emurgo/cardano-playground.git /opt/cardano/cardano-playground
RUN mkdir /root/.local/ && mkdir /root/.local/share
# Set working directory to the project folder
WORKDIR /opt/cardano/cardano-playground
# Copy the local context into the container (if you have files in the current directory you want to copy)
COPY . .
# Build the projects (use equivalent build commands for your setup, if necessary)
# RUN ./build.sh # or any other build command your project requires (modify based on actual needs)
# Example using `just` for building
RUN nix build  --accept-flake-config .#cardano-cli-ng -o cardano-cli-ng-build
RUN nix build  --accept-flake-config .#cardano-node-ng -o cardano-node-ng-build
RUN nix build  --accept-flake-config .#cardano-cli -o cardano-cli-build
RUN nix build  --accept-flake-config .#cardano-node -o cardano-node
ENV PATH="/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/opt/cardano/cardano-playground/cardano-cli-ng-build/bin:/opt/cardano/cardano-playground/cardano-node-ng-build/bin:/opt/cardano/cardano-playground/cardano-node-ng-build/bin:/opt/cardano/cardano-playground/cardano-cli-build/bin:$PATH"
RUN nix develop
# Set environment variable for PATH
ENV PATH="/root/.nix-profile/bin:/usr/local/bin:$PATH"
# Allow direnv to load environment variables
RUN direnv allow
EXPOSE 3001

# Set the default command to run when the container starts
CMD just start-demo && tail -f /dev/null
