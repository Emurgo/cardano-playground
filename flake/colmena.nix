{
  inputs,
  config,
  lib,
  ...
}: let
  inherit (config.flake) nixosModules nixosConfigurations;
in {
  flake.colmena = let
    # Region defs:
    eu-central-1.aws.region = "eu-central-1";
    eu-west-1.aws.region = "eu-west-1";
    us-east-2.aws.region = "us-east-2";

    # Instance defs:
    t3a-micro.aws.instance.instance_type = "t3a.micro";
    t3a-small.aws.instance.instance_type = "t3a.small";
    t3a-medium.aws.instance.instance_type = "t3a.medium";
    m5a-large.aws.instance.instance_type = "m5a.large";
    r5-xlarge.aws.instance.instance_type = "r5.xlarge";
    r5-2xlarge.aws.instance.instance_type = "r5.2xlarge";

    # Helper fns:
    ebs = size: {aws.instance.root_block_device.volume_size = lib.mkDefault size;};

    # Helper defs:
    # delete.aws.instance.count = 0;

    # Cardano group assignments:
    group = name: {cardano-parts.cluster.group = config.flake.cardano-parts.cluster.group.${name};};

    # Cardano-node modules for group deployment
    node = {
      imports = [
        # Base cardano-node service
        config.flake.cardano-parts.cluster.group.default.meta.cardano-node-service

        # Config for cardano-node group deployments
        inputs.cardano-parts.nixosModules.profile-cardano-node-group
      ];
    };

    # Snapshots: add this to a dbsync machine defn and deploy; remove once the snapshot is restored.
    # Snapshots for mainnet can be found at: https://update-cardano-mainnet.iohk.io/cardano-db-sync/index.html#13.1/
    # snapshot = {services.cardano-db-sync.restoreSnapshot = "$SNAPSHOT_URL";};

    dbsync = {
      imports = [
        config.flake.cardano-parts.cluster.group.default.meta.cardano-node-service
        config.flake.cardano-parts.cluster.group.default.meta.cardano-db-sync-service
        inputs.cardano-parts.nixosModules.profile-cardano-db-sync
        inputs.cardano-parts.nixosModules.profile-cardano-node-group
        inputs.cardano-parts.nixosModules.profile-cardano-postgres
      ];
    };

    # Profiles
    topoSimple = {imports = [inputs.cardano-parts.nixosModules.profile-topology-simple];};
    # pre = {imports = [inputs.cardano-parts.nixosModules.profile-pre-release];};

    node821 = {
      imports = [
        (nixos: {
          cardano-parts.perNode.pkgs = rec {
            inherit (inputs.cardano-node-821-pre.packages.x86_64-linux) cardano-cli cardano-node cardano-submit-api;
            cardano-node-pkgs = {
              inherit cardano-cli cardano-node cardano-submit-api;
              inherit (nixos.config.cardano-parts.perNode.lib) cardanoLib;
            };
          };
        })
      ];
    };

    nodeHd = {
      imports = [
        (nixos: {
          cardano-parts.perNode.pkgs = rec {
            inherit (inputs.cardano-node-hd.packages.x86_64-linux) cardano-cli cardano-node cardano-submit-api;
            cardano-node-pkgs = {
              inherit cardano-cli cardano-node cardano-submit-api;
              inherit (nixos.config.cardano-parts.perNode.lib) cardanoLib;
            };
          };
        })
      ];
    };

    lmdb = {services.cardano-node.extraArgs = ["--lmdb-ledger-db-backend"];};

    # Roles
    rel = {imports = [inputs.cardano-parts.nixosModules.role-relay topoSimple];};
    bp = {imports = [inputs.cardano-parts.nixosModules.role-block-producer topoSimple];};
  in {
    meta = {
      nixpkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
      };

      nodeSpecialArgs =
        lib.foldl'
        (acc: node: let
          instanceType = node: nixosConfigurations.${node}.config.aws.instance.instance_type;
        in
          lib.recursiveUpdate acc {
            ${node} = {
              nodeResources = {
                inherit
                  (config.flake.cardano-parts.aws.ec2.spec.${instanceType node})
                  provider
                  coreCount
                  cpuCount
                  memMiB
                  nodeType
                  threadsPerCore
                  ;
              };
            };
          })
        {} (builtins.attrNames nixosConfigurations);
    };

    defaults.imports = [
      inputs.cardano-parts.nixosModules.module-aws-ec2
      inputs.cardano-parts.nixosModules.module-cardano-parts
      inputs.cardano-parts.nixosModules.profile-basic
      inputs.cardano-parts.nixosModules.profile-common
      inputs.cardano-parts.nixosModules.profile-grafana-agent
      nixosModules.common
    ];

    # Setup cardano-world networks:
    # ---------------------------------------------------------------------------------------------------------
    # Preprod, two-thirds on release tag, one-third on pre-release tag
    preprod1-bp-a-1 = {imports = [eu-central-1 t3a-medium (ebs 40) (group "preprod1") node topoSimple];};
    preprod1-rel-a-1 = {imports = [eu-central-1 t3a-medium (ebs 40) (group "preprod1") node rel];};
    preprod1-rel-b-1 = {imports = [eu-west-1 t3a-medium (ebs 40) (group "preprod1") node rel];};
    preprod1-rel-c-1 = {imports = [us-east-2 t3a-medium (ebs 40) (group "preprod1") node rel];};
    preprod1-dbsync-a-1 = {imports = [eu-central-1 m5a-large (ebs 40) (group "preprod1") dbsync];};

    # preprod2-bp-b-1 = {imports = [eu-west-1 t3a-medium (ebs 40) (group "preprod2") node topoSimple];};
    # preprod2-rel-a-1 = {imports = [eu-central-1 t3a-medium (ebs 40) (group "preprod2") node rel];};
    # preprod2-rel-b-1 = {imports = [eu-west-1 t3a-medium (ebs 40) (group "preprod2") node rel];};
    # preprod2-rel-c-1 = {imports = [us-east-2 t3a-medium (ebs 40) (group "preprod2") node rel];};

    # preprod3-bp-c-1 = {imports = [us-east-2 t3a-medium (ebs 40) (group "preprod3") node topoSimple pre];};
    # preprod3-rel-a-1 = {imports = [eu-central-1 t3a-medium (ebs 40) (group "preprod3") node rel pre];};
    # preprod3-rel-b-1 = {imports = [eu-west-1 t3a-medium (ebs 40) (group "preprod3") node rel pre];};
    # preprod3-rel-c-1 = {imports = [us-east-2 t3a-medium (ebs 40) (group "preprod3") node rel pre];};
    # ---------------------------------------------------------------------------------------------------------

    # ---------------------------------------------------------------------------------------------------------
    # Preview, one-third on release tag, two-thirds on pre-release tag
    preview1-bp-a-1 = {imports = [eu-central-1 t3a-medium (ebs 40) (group "preview1") node topoSimple];};
    preview1-rel-a-1 = {imports = [eu-central-1 t3a-medium (ebs 40) (group "preview1") node rel];};
    preview1-rel-b-1 = {imports = [eu-west-1 t3a-medium (ebs 40) (group "preview1") node rel];};
    preview1-rel-c-1 = {imports = [us-east-2 t3a-medium (ebs 40) (group "preview1") node rel];};
    preview1-dbsync-a-1 = {imports = [eu-central-1 m5a-large (ebs 40) (group "preview1") dbsync];};

    # preview2-bp-b-1 = {imports = [eu-west-1 t3a-medium (ebs 40) (group "preview2") node topoSimple pre];};
    # preview2-rel-a-1 = {imports = [eu-central-1 t3a-medium (ebs 40) (group "preview2") node rel pre];};
    # preview2-rel-b-1 = {imports = [eu-west-1 t3a-medium (ebs 40) (group "preview2") node rel pre];};
    # preview2-rel-c-1 = {imports = [us-east-2 t3a-medium (ebs 40) (group "preview2") node rel pre];};

    # preview3-bp-c-1 = {imports = [us-east-2 t3a-medium (ebs 40) (group "preview3") node topoSimple pre];};
    # preview3-rel-a-1 = {imports = [eu-central-1 t3a-medium (ebs 40) (group "preview3") node rel pre];};
    # preview3-rel-b-1 = {imports = [eu-west-1 t3a-medium (ebs 40) (group "preview3") node rel pre];};
    # preview3-rel-c-1 = {imports = [us-east-2 t3a-medium (ebs 40) (group "preview3") node rel pre];};
    # ---------------------------------------------------------------------------------------------------------

    # ---------------------------------------------------------------------------------------------------------
    # Sanchonet, pre-release
    sanchonet1-bp-a-1 = {imports = [eu-central-1 t3a-micro (ebs 40) (group "sanchonet1") node bp];};
    sanchonet1-rel-a-1 = {imports = [eu-central-1 t3a-micro (ebs 40) (group "sanchonet1") node rel];};
    sanchonet1-rel-b-1 = {imports = [eu-west-1 t3a-micro (ebs 40) (group "sanchonet1") node rel];};
    sanchonet1-rel-c-1 = {imports = [us-east-2 t3a-micro (ebs 40) (group "sanchonet1") node rel];};
    sanchonet1-dbsync-a-1 = {imports = [eu-central-1 t3a-small (ebs 40) (group "sanchonet1") dbsync];};

    sanchonet2-bp-b-1 = {imports = [eu-west-1 t3a-micro (ebs 40) (group "sanchonet2") node topoSimple];};
    sanchonet2-rel-a-1 = {imports = [eu-central-1 t3a-micro (ebs 40) (group "sanchonet2") node rel];};
    sanchonet2-rel-b-1 = {imports = [eu-west-1 t3a-micro (ebs 40) (group "sanchonet2") node rel];};
    sanchonet2-rel-c-1 = {imports = [us-east-2 t3a-micro (ebs 40) (group "sanchonet2") node rel];};

    # sanchonet3-bp-c-1 = {imports = [us-east-2 t3a-micro (ebs 40) (group "sanchonet3") node topoSimple];};
    # sanchonet3-rel-a-1 = {imports = [eu-central-1 t3a-micro (ebs 40) (group "sanchonet3") node rel];};
    # sanchonet3-rel-b-1 = {imports = [eu-west-1 t3a-micro (ebs 40) (group "sanchonet3") node rel];};
    # sanchonet3-rel-c-1 = {imports = [us-east-2 t3a-micro (ebs 40) (group "sanchonet3") node rel];};
    # ---------------------------------------------------------------------------------------------------------

    # ---------------------------------------------------------------------------------------------------------
    # Shelley-qa, pre-release
    shelley-qa1-bp-a-1 = {imports = [eu-central-1 t3a-micro (ebs 40) (group "shelley-qa1") node topoSimple];};
    shelley-qa1-rel-a-1 = {imports = [eu-central-1 t3a-micro (ebs 40) (group "shelley-qa1") node rel];};
    shelley-qa1-dbsync-a-1 = {imports = [eu-central-1 t3a-small (ebs 40) (group "shelley-qa1") dbsync];};

    # shelley-qa2-bp-b-1 = {imports = [eu-west-1 t3a-micro (ebs 40) (group "shelley-qa2") node topoSimple];};
    # shelley-qa2-rel-b-1 = {imports = [eu-west-1 t3a-micro (ebs 40) (group "shelley-qa2") node rel];};

    # shelley-qa3-bp-c-1 = {imports = [us-east-2 t3a-micro (ebs 40) (group "shelley-qa3") node topoSimple];};
    # shelley-qa3-rel-c-1 = {imports = [us-east-2 t3a-micro (ebs 40) (group "shelley-qa3") node rel];};
    # ---------------------------------------------------------------------------------------------------------

    # ---------------------------------------------------------------------------------------------------------
    # Mainnet
    mainnet1-dbsync-a-1 = {imports = [eu-central-1 r5-2xlarge (ebs 1000) (group "mainnet1") dbsync];};
    mainnet1-rel-a-1 = {imports = [eu-central-1 r5-xlarge (ebs 300) (group "mainnet1") node];};
    mainnet1-rel-a-2 = {imports = [eu-central-1 r5-xlarge (ebs 300) (group "mainnet1") node nodeHd];};
    mainnet1-rel-a-3 = {imports = [eu-central-1 r5-xlarge (ebs 300) (group "mainnet1") node nodeHd lmdb];};
    mainnet1-rel-a-4 = {imports = [eu-central-1 r5-xlarge (ebs 300) (group "mainnet1") node node821];};
  };
}
