FROM nixos/nix:latest AS builder
RUN nix-env -iA nixpkgs.direnv
RUN nix-env -iA nixpkgs.just
RUN nix-env -iA nixpkgs.jq
RUN nix-env -iA nixpkgs.ps
RUN nix-env -iA nixpkgs.sops
RUN mkdir -p /etc/nix
RUN touch /etc/nix/nix.conf
RUN echo "donotUnpack = true" > /etc/nix/nix.conf && echo "experimental-features = nix-command flakes" > /etc/nix/nix.conf && echo "allow-import-from-derivation = true" >> /etc/nix/nix.conf && echo "extra-experimental-features = fetch-closure" >> /etc/nix/nix.conf
RUN mkdir /opt
RUN mkdir /opt/cardano
RUN cat /etc/nix/nix.conf
RUN ls -l
RUN cd /opt/cardano && git clone https://github.com/Emurgo/cardano-playground.git
WORKDIR /opt/cardano/cardano-playground
RUN nix build  --accept-flake-config .#cardano-cli-ng -o cardano-cli-ng-build
RUN nix build  --accept-flake-config .#cardano-node-ng -o cardano-node-ng-build
RUN nix build  --accept-flake-config .#cardano-node -o cardano-node-build
RUN nix build  --accept-flake-config .#cardano-cli -o cardano-cli-build
ENV PATH="/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/root/test-node/cardano-cli-ng-build/bin:/root/test-node/cardano-node-ng-build/bin:/root/test-node/cardano-cli-build/bin:$PATH"
RUN direnv allow
RUN nix develop
CMD just start-demo
