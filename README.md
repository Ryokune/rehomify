# Rehomify

**Automatically activate standalone Home Manager on ephemeral NixOS `/home`.**  

Rehomify ensures your standalone Home Manager configs are activated at boot **only on systems where `/home` is ephemeral** (e.g., tmpfs `/home` or ephemeral `/`).  
It is **not intended for systems with persistent `/home`**.


> TL;DR: Use this if `/home` disappears or is reset on reboot, and you rely on standalone Home Manager per user.
###### You do NOT need this module if your Home Manager config is integrated within your NixOS system config.

---

## Designed for systems using:
    - Impermanence (tmpfs / or ephemeral /home)
    - nix.settings.use-xdg-base-directories = true
    - Standalone Home Manager per-user profiles

## Designed for users that:
    - Want clear separation between their NixOS Config and Home Manager
    - Want Home Manager builds separate from their NixOS Builds
    - Is using NixOS.

    Must ensure persistence of: $HOME/.local/state/nix/profiles

---

## Requirements
- [github:nix-community/impermanence](https://github.com/nix-community/impermanence) – for persisting `$HOME/.local/state/nix/profiles`  
- `nix.settings.use-xdg-base-directories = true`  
- Standalone Home Manager

> Without impermanence support, Rehomify won’t be necessary.

---

## What it does

- Activates standalone Home Manager for each targeted user at boot.  
- Creates **per-user systemd services** automatically.  
- Lets you choose which users to target or defaults to all normal users except root.  
- Works cleanly with multi-user NixOS boot targets.  
- Skips activation if the Home Manager activation script doesn’t exist or isn’t executable.

---

## Quick Setup (flakes)

```nix
{
  inputs = {
    rehomify.url = "github:Ryokune/rehomify";
  };

  outputs = { self, nixpkgs, rehomify }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        rehomify.nixosModules.rehomify
      ];
    };
  };
}

```

## Example (configuration.nix)
>If `rehomify.users` is not set, it will apply to all non-priviledged users.  
**Only enable this if /home is ephemeral** — enabling on persistent `/home` is unnecessary.
```nix
{
  rehomify.enable = true;

  # Optional: pick specific users
  rehomify.users = [ "alice" "bob" ];

  # Optional: additional systemd units to order after
  rehomify.extraAfter = [ "network-online.target" ];
}
```


## How it works
- Rehomify creates a per-user systemd service called `rehomify-<username>`.

- Service only runs if the activation script exists and is executable. (``$HOME/.local/state/nix/profiles/home-manager/activate``)

- Systemd ordering ensures it runs after `nix-daemon` and `local-fs`.target (plus any additional units you specify).

- Integrates safely with `multi-user.target` without affecting other services.
