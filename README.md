# herdr-nix

Nix flake packaging the [herdr](https://github.com/ogulcancelik/herdr) CLI — an agent multiplexer that lives in your terminal — with automated hourly updates tracking upstream GitHub releases.

Inspired by [sadjow/claude-code-nix](https://github.com/sadjow/claude-code-nix).

## Install

### Run once

```bash
nix run github:AodhanHayter/herdr-nix
```

### Project dev shell

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    herdr-nix.url = "github:AodhanHayter/herdr-nix";
  };

  outputs = { self, nixpkgs, herdr-nix }: {
    devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
      buildInputs = [ herdr-nix.packages.x86_64-linux.default ];
    };
  };
}
```

### Overlay

```nix
{
  inputs.herdr-nix.url = "github:AodhanHayter/herdr-nix";

  outputs = { nixpkgs, herdr-nix, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      modules = [
        {
          nixpkgs.overlays = [ herdr-nix.overlays.default ];
          environment.systemPackages = [ pkgs.herdr ];
        }
      ];
    };
  };
}
```

### Home Manager

```nix
{
  inputs.herdr-nix.url = "github:AodhanHayter/herdr-nix";

  outputs = { home-manager, herdr-nix, ... }: {
    homeConfigurations."me" = home-manager.lib.homeManagerConfiguration {
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ herdr-nix.overlays.default ];
          home.packages = [ pkgs.herdr ];
        })
      ];
    };
  };
}
```

## Supported platforms

| System            | Upstream asset       |
|-------------------|----------------------|
| `aarch64-darwin`  | `herdr-macos-aarch64`|
| `x86_64-darwin`   | `herdr-macos-x86_64` |
| `x86_64-linux`    | `herdr-linux-x86_64` |
| `aarch64-linux`   | `herdr-linux-aarch64`|

Pulls the prebuilt release binary directly from the upstream GitHub release. Linux binaries are patched via `autoPatchelfHook` to resolve the loader / glibc inside the Nix store.

## Update automation

| Workflow                              | Trigger                                  | Purpose                                                                 |
|---------------------------------------|------------------------------------------|-------------------------------------------------------------------------|
| `.github/workflows/update-herdr.yml`  | hourly cron + manual dispatch            | Polls latest GitHub release, bumps `package.nix`, opens auto-merge PR.  |
| `.github/workflows/test-pr.yml`       | PR touching nix files / scripts          | Builds on `ubuntu-latest` and `macos-latest`.                           |
| `.github/workflows/build.yml`         | push to `main`, completed update workflow| Builds + pushes binaries to Cachix when `CACHIX_AUTH_TOKEN` is set.     |
| `.github/workflows/create-version-tag.yml` | successful `Build and Cache` on `main` | Tags `vX.Y.Z`, plus moving `latest` and `vMAJOR`.                       |

### Manual update

```bash
./scripts/update-version.sh            # bump to latest
./scripts/update-version.sh --check    # exit 1 if update available
./scripts/update-version.sh --version 0.6.2
```

### Cachix (optional)

To enable a binary cache push from CI:

1. Create a Cachix cache (default name expected: `herdr-nix`).
2. Set the repo secret `CACHIX_AUTH_TOKEN`.
3. Optionally override the cache name via repo variable `CACHIX_CACHE_NAME`.

Without the secret, the cachix steps are skipped automatically — local builds still work.

## Repo layout

```
flake.nix                          # flake entrypoint, overlay, apps
package.nix                        # platform map + nativeHashes
scripts/update-version.sh          # automated version bumper
.github/workflows/                 # update / build / test / tag pipelines
.github/dependabot.yml             # weekly action bumps
```

## License

Packaging files (`flake.nix`, `package.nix`, scripts, workflows) are MIT.
herdr itself is AGPL-3.0-or-later — see <https://github.com/ogulcancelik/herdr/blob/master/LICENSE>.
