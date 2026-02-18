{
  description = "Rehomify - Automatic standalone Home Manager activation for impermanent systems";

  outputs =
    { self }:
    {
      nixosModules.rehomify =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.rehomify;

          persistenceEnabled = config.environment.persistence != { };

          normalUsers = lib.filterAttrs (
            name: user: user.isNormalUser or false && name != "root"
          ) config.users.users;

          targetUsers =
            if cfg.users == null then
              normalUsers
            else
              lib.filterAttrs (name: _: lib.elem name cfg.users) normalUsers;
        in
        {
          options.rehomify = {
            enable = lib.mkEnableOption ''
              Automatic standalone Home Manager activation for impermanent system
            '';

            users = lib.mkOption {
              type = lib.types.nullOr (lib.types.listOf lib.types.str);
              default = null;
              example = [
                "alice"
                "bob"
              ];
              description = ''
                List of users to activate standalone Home Manager for.
                If null, all normal users are targeted.
              '';
            };

            extraAfter = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                Additional systemd units to order activation after.
                Useful for networking or other dependencies.
              '';
            };
          };
          # TODO: Add assertion for persisting $USER/home/.local/state/nix/profiles
          #                                    $USER/home/.local/state/nix, etc...
          config = lib.mkIf cfg.enable {
            assertions = [

              {
                assertion = config.nix.settings.use-xdg-base-directories or false;
                message = ''
                  rehomify requires:
                    nix.settings.use-xdg-base-directories = true;
                '';
              }
              {
                assertion = persistenceEnabled;
                message = ''
                  rehomify requires Impermanence.
                  You must configure environment.persistence.
                '';
              }
            ];
            systemd.services = lib.mapAttrs' (
              name: user:
              lib.nameValuePair "rehomify-${name}" {

                description = "Rehomify: Standalone Home Manager activation for ${name}";

                after = [
                  "nix-daemon.service"
                  "local-fs.target"
                ]
                ++ cfg.extraAfter;

                requires = [ "nix-daemon.service" ];
                before = [ "systemd-user-sessions.service" ];

                unitConfig.ConditionPathIsExecutable = "${user.home}/.local/state/nix/profiles/home-manager/activate";

                serviceConfig = {
                  Type = "oneshot";
                  requiresMountsFor = [ user.home ];
                  User = name;
                  ExecStart = "${user.home}/.local/state/nix/profiles/home-manager/activate";
                };
                path = with pkgs; [ nix ];

                wantedBy = [ "multi-user.target" ];
              }
            ) targetUsers;
          };
        };
    };
}
