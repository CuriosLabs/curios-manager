# Just recipes
# variables
name := 'curios-manager'
owner := 'CuriosLabs'

# Default option list available recipes.
default:
  @just --list

# Build the current version of the Nix package and install it in `/nix/store/`.
build:
  nix-build ./default.nix --show-trace

# Cleaning nix pkgs build result folder.
clean:
  rm -rf ./result

# Linting Bash scripts and Nix files.
lint:
  @echo 'Linting Nix files...'
  for file in `fd --type f ".nix" .`; do statix check $file; done
  @echo 'Linting Bash files...'
  shellcheck --color=always -f tty -x -P pkgs/curios-manager/bin pkgs/curios-manager/bin/curios-* pkgs/curios-manager/bin/functions/*.sh

# Complete publish process: lint, tag then build and update hash signature, finally push on github.
publish VERSION:
  git checkout testing
  @just clean
  @just lint
  @just tag {{VERSION}}
  sleep 5
  @just hash-update {{VERSION}}

# Update version number, create Git commit and tag and push it.
tag VERSION:
  @echo "Updating version number to {{VERSION}}..."
  sed "s/version = \".*/version = \"{{VERSION}}\";/g" -i ./pkgs/curios-manager/default.nix
  sed "s#hash = \".*#hash = \"\";#g" -i ./pkgs/curios-manager/default.nix
  sed "s/readonly SCRIPT_VERSION=\".*/readonly SCRIPT_VERSION=\"{{VERSION}}\"/g" -i ./pkgs/curios-manager/bin/constants.sh
  git commit -a -m "Release {{VERSION}}"
  git pull
  @echo "Tagging version: {{VERSION}}"
  git tag -a {{VERSION}} -m "Release {{VERSION}}"
  git push origin {{VERSION}}

# Remove Git tag locally and remotely
removetag VERSION:
  git tag -d {{VERSION}}
  git push --delete origin {{VERSION}}

# Build the Nix package and run it.
run:
  @just build
  ./result/bin/curios-manager

# Update the Nix package hash signature, commit and push to git.
hash-update VERSION:
  #!/usr/bin/env bash
  set -euxo pipefail
  sed "s/version = \".*/version = \"{{VERSION}}\";/g" -i ./pkgs/curios-manager/default.nix
  HASH=`nix --extra-experimental-features nix-command hash convert --hash-algo sha256 "$(nix-prefetch-url --unpack https://github.com/{{owner}}/{{name}}/archive/{{VERSION}}.tar.gz)"`
  sed "s/hash = \".*/hash = \"${HASH}\";/g" -i ./pkgs/curios-manager/default.nix
  git commit -a -m "Updated hash signature"
  git push

# Launch curios-manager bash script directly (not the Nix pkgs).
test:
  ./pkgs/curios-manager/bin/curios-manager

# Launch curios-update bash script directly (not the Nix pkgs).
test-update *FLAGS:
  ./pkgs/curios-manager/bin/curios-update {{FLAGS}}
