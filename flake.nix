{
  description = "Agent skills, packaged";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };

    nixos-skill = {
      url = "github:marceloeatworld/nixos-ai-skill";
      flake = false;
    };

    vercel-skills = {
      url = "github:vercel-labs/skills";
      flake = false;
    };

    wshobson-agents = {
      url = "github:wshobson/agents";
      flake = false;
    };

    qt-agent-skills = {
      url = "github:TheQtCompanyRnD/agent-skills";
      flake = false;
    };

    anthropics-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };

    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      superpowers,
      nixos-skill,
      vercel-skills,
      wshobson-agents,
      qt-agent-skills,
      anthropics-skills,
      hermes-agent,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = forAllSystems (system: import nixpkgs { inherit system; });

      perSystem = forAllSystems (
        system:
        let
          pkgs = pkgsFor.${system};
          lib = nixpkgs.lib;

          # Each payload file returns `{ payload; skillNames; }`; `prefix` names its
          # per-skill packages, and `skillNames` comes from the same data the
          # payload's build script copies, so the two cannot drift apart.
          #
          # `callPackage` wraps a non-derivation result in `makeOverridable`, which
          # tags on `override`/`overrideDerivation`; strip them so each record is
          # exactly `{ prefix; payload; skillNames; }` for the consumers below.
          payload =
            prefix: file: args:
            {
              inherit prefix;
            }
            // lib.removeAttrs (pkgs.callPackage file args) [
              "override"
              "overrideDerivation"
            ];

          payloads = {
            superpowers-skills = payload "superpowers" ./pkgs/superpowers-skills/package.nix {
              src = superpowers;
            };
            vendored-skills = payload "vendored" ./pkgs/vendored-skills/package.nix {
              inherit (inputs)
                nixos-skill
                vercel-skills
                wshobson-agents
                qt-agent-skills
                anthropics-skills
                ;
            };
            omp-managed-skills = payload "omp-managed" ./pkgs/omp-managed-skills/package.nix {
              src = ./skills/omp-managed;
            };
            shared-skills = payload "shared" ./pkgs/shared-skills/package.nix {
              src = ./skills/shared;
            };
            hermes-managed-skills = payload "hermes-managed" ./pkgs/hermes-managed-skills/package.nix {
              src = ./skills/hermes-managed;
            };
            hermes-skills = payload "hermes" ./pkgs/hermes-skills/package.nix {
              inherit (inputs) hermes-agent;
            };
          };

          payloadPackages = lib.mapAttrs (_: payload: payload.payload) payloads;
          skillPackages = (pkgs.callPackage ./pkgs/lib/slices.nix { }) payloads;
          mkSkillset = (pkgs.callPackage ./pkgs/lib/mk-skillset.nix { }) skillPackages;

          collisions = lib.intersectLists (lib.attrNames skillPackages) (lib.attrNames payloadPackages);
          expectedSkills = lib.foldl' (count: payload: count + builtins.length payload.skillNames) 0 (
            lib.attrValues payloads
          );
          problems =
            lib.optionals (collisions != [ ]) [
              "per-skill packages collide with payload packages: ${toString collisions}"
            ]
            ++ lib.optionals (builtins.length (lib.attrNames skillPackages) != expectedSkills) [
              "generated ${toString (builtins.length (lib.attrNames skillPackages))} of ${toString expectedSkills} per-skill packages"
            ];

          packages = lib.throwIf (problems != [ ]) "agent-skills-nix: ${lib.concatStringsSep "; " problems}" (
            payloadPackages
            // skillPackages
            // {
              scrapling-runtime = pkgs.callPackage ./pkgs/scrapling-runtime/package.nix { };
            }
          );
        in
        rec {
          inherit packages mkSkillset;

          checks = packages // {
            skillset-smoke = mkSkillset [
              "superpowers-brainstorming"
              "vendored-nixos"
              "omp-managed-end-of-task-memory-update"
              "shared-cloudflare-bypass"
              "hermes-managed-hermes-skill-library-management"
              "hermes-hermes-agent"
            ];
          };
        }
      );
    in
    {
      packages = forAllSystems (system: perSystem.${system}.packages);

      checks = forAllSystems (system: perSystem.${system}.checks);

      lib = forAllSystems (system: {
        inherit (perSystem.${system}) mkSkillset;
      });

      formatter = forAllSystems (system: pkgsFor.${system}.nixfmt-tree);

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixfmt
              pkgs.nixd
            ];
          };
        }
      );
    };
}
