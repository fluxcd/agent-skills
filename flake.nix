{
  description = "Nix flake packaging for FluxCD agent skills";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      lib = nixpkgs.lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems =
        f:
        lib.genAttrs systems (
          system:
          f system (
            import nixpkgs {
              inherit system;
            }
          )
        );

      readSubdirs =
        dir:
        let
          entries = builtins.readDir dir;
        in
        builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);

      skillNames =
        builtins.filter
          (name: builtins.pathExists (./skills + "/${name}/SKILL.md"))
          (readSubdirs ./skills);

      agentProfileNames = readSubdirs ./agents;

      toolTargets = {
        codex = ".codex/skills";
        claude = ".claude/skills";
        claude-code = ".claude/skills";
        gemini = ".gemini/skills";
        gemini-cli = ".gemini/skills";
        gemeni = ".gemini/skills";
        kiro = ".kiro/skills";
        kiro-cli = ".kiro/skills";
      };

      supportedTools = lib.sort builtins.lessThan (builtins.attrNames toolTargets);

      toolTarget = tool: toolTargets.${tool};

      mkSkillEntries =
        target:
        map (name: {
          name = "${target}/${name}";
          value = {
            source = ./skills + "/${name}";
            recursive = true;
          };
        }) skillNames;

      mkHomeModule =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs."fluxcd-agent-skills";
          effectiveTargets = lib.unique (cfg.targets ++ map toolTarget cfg.tools);

          links = builtins.listToAttrs (lib.concatMap mkSkillEntries effectiveTargets);
        in
        {
          options.programs."fluxcd-agent-skills" = {
            enable = lib.mkEnableOption "FluxCD agent skills";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.skills;
              description = "Package containing all FluxCD skill directories.";
            };

            installPackage = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.install;
              description = "Installer helper package (fluxcd-agent-skills-install).";
            };

            targets = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ".agents/skills" ];
              example = [ ".agents/skills" ".tools/skills" ];
              description = "Home-relative or absolute directories where skills are linked.";
            };

            tools = lib.mkOption {
              type = lib.types.listOf (lib.types.enum supportedTools);
              default = [ ];
              example = [ "codex" "claude-code" ];
              description = "Convenience aliases that add tool-specific target directories.";
            };
          };

          config = lib.mkIf cfg.enable {
            home.file = links;
            home.packages = [ cfg.installPackage ];
          };
        };

      mkSystemModule =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs."fluxcd-agent-skills";
          targets = cfg.targets;
          targetArgs = map lib.escapeShellArg targets;
        in
        {
          options.programs."fluxcd-agent-skills" = {
            enable = lib.mkEnableOption "FluxCD agent skills";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.skills;
              description = "Package containing all FluxCD skill directories.";
            };

            installPackage = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.install;
              description = "Installer helper package (fluxcd-agent-skills-install).";
            };

            targets = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              example = [ "/home/alice/.agents/skills" "/Users/alice/.codex/skills" ];
              description = "Absolute directories where skills are linked during activation.";
            };
          };

          config = lib.mkIf cfg.enable {
            assertions = map (target: {
              assertion = lib.hasPrefix "/" target;
              message = "programs.fluxcd-agent-skills.targets entries must be absolute paths: ${target}";
            }) targets;

            environment.systemPackages = [ cfg.installPackage ];

            system.activationScripts.fluxcdAgentSkills = lib.mkIf (targets != [ ]) {
              text = ''
                set -eu

                skills_root=${lib.escapeShellArg cfg.package}

                for target in ${lib.concatStringsSep " " targetArgs}; do
                  mkdir -p "$target"

                  for skill_src in "$skills_root"/*; do
                    [ -d "$skill_src" ] || continue

                    name="$(basename "$skill_src")"
                    dst="$target/$name"

                    if [ -L "$dst" ] || [ -e "$dst" ]; then
                      rm -rf "$dst"
                    fi

                    ln -s "$skill_src" "$dst"
                  done
                done
              '';
            };
          };
        };
    in
    {
      lib = {
        inherit
          skillNames
          agentProfileNames
          supportedTools
          ;
      };

      homeManagerModules.default = mkHomeModule;
      nixosModules.default = mkSystemModule;
      darwinModules.default = mkSystemModule;

      packages = forAllSystems (
        system: pkgs:
        let
          skills = pkgs.linkFarm "fluxcd-agent-skills" (
            map (name: {
              name = name;
              path = ./skills + "/${name}";
            }) skillNames
          );

          agentProfiles = pkgs.linkFarm "fluxcd-agent-profiles" (
            map (name: {
              name = name;
              path = ./agents + "/${name}";
            }) agentProfileNames
          );

          install = pkgs.writeShellApplication {
            name = "fluxcd-agent-skills-install";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              set -euo pipefail

              usage() {
                cat <<'HELP'
              Usage: fluxcd-agent-skills-install [--tool <name>] [--target <path>] [--copy] [--force]

              Options:
                --tool <name>    Use a standard target path for a tool.
                                 Supported: codex, claude-code, gemini, kiro
                --target <path>  Explicit target directory (overrides --tool mapping)
                --copy           Copy skill directories instead of symlinking
                --force          Replace non-symlink existing skill directories
                --list           Print discovered skills and exit
                --help           Show this help

              Defaults:
                target: .agents/skills
                mode:   symlink
              HELP
              }

              mode="symlink"
              force=0
              tool=""
              target=""

              skills_root='${skills}'

              while [[ $# -gt 0 ]]; do
                case "$1" in
                  --tool)
                    tool="''${2:-}"
                    shift 2
                    ;;
                  --target)
                    target="''${2:-}"
                    shift 2
                    ;;
                  --copy)
                    mode="copy"
                    shift
                    ;;
                  --force)
                    force=1
                    shift
                    ;;
                  --list)
                    find "$skills_root" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
                    exit 0
                    ;;
                  --help|-h)
                    usage
                    exit 0
                    ;;
                  *)
                    echo "Unknown option: $1" >&2
                    usage
                    exit 2
                    ;;
                esac
              done

              if [[ -z "$target" ]]; then
                case "$tool" in
                  "")
                    target=".agents/skills"
                    ;;
                  codex)
                    target=".codex/skills"
                    ;;
                  claude|claude-code)
                    target=".claude/skills"
                    ;;
                  gemini|gemini-cli|gemeni)
                    target=".gemini/skills"
                    ;;
                  kiro|kiro-cli)
                    target=".kiro/skills"
                    ;;
                  *)
                    echo "Unsupported --tool value: $tool" >&2
                    echo "Supported values: codex, claude-code, gemini, kiro" >&2
                    exit 2
                    ;;
                esac
              fi

              mkdir -p "$target"

              installed=0
              for skill_src in "$skills_root"/*; do
                [[ -d "$skill_src" ]] || continue

                name="$(basename "$skill_src")"
                dst="$target/$name"

                if [[ -e "$dst" || -L "$dst" ]]; then
                  if [[ -L "$dst" ]]; then
                    rm -f "$dst"
                  elif [[ "$force" -eq 1 ]]; then
                    rm -rf "$dst"
                  else
                    echo "Skipping $name: $dst exists (use --force to replace)" >&2
                    continue
                  fi
                fi

                if [[ "$mode" == "copy" ]]; then
                  cp -a "$skill_src" "$dst"
                else
                  ln -s "$skill_src" "$dst"
                fi

                installed=$((installed + 1))
              done

              echo "Installed $installed skill(s) to $target"
            '';
          };
        in
        {
          default = skills;
          inherit
            install
            skills
            ;
          agent-profiles = agentProfiles;
        }
      );

      apps = forAllSystems (system: pkgs: {
        default = {
          type = "app";
          program = "${pkgs.lib.getExe self.packages.${system}.install}";
        };

        install = {
          type = "app";
          program = "${pkgs.lib.getExe self.packages.${system}.install}";
        };
      });
    };
}
