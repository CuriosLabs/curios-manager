# CuriOS Development Guide

This guide provides instructions and best practices for developers contributing
to the curios-manager project. It is a NixOS package providing a TUI mostly
written in bash shell script.

## Context

You are an expert software architect and project analysis assistant. Analyze
the current project directory and help developers that interacts with this
project. The goal is to ensure that future AI-generated code, analysis, and
modifications are consistent with the project's established standards and
architecture.

## Project Overview

- **Project Name**: curios-manager
- **Purpose**: A modern TUI to manage a [CuriOS](https://github.com/CuriosLabs/CuriOS)
  system based on NixOS.
- **Target OS**: NixOS - A Linux based OS.
- **Project goal**: Manage the operating system packages and configurations/settings.

## Directory Structure

The project follows a modular architecture. The main directories are:

- `pkgs/curios-manager/`: The Nix custom package main directory.
- `pkgs/curios-manager/bin/`: The bash shell scripts subdirectory.
- `pkgs/curios-manager/bin/functions/`: The `curios-manager` TUI bash functions directory.

## Key Files

- `pkgs/curios-manager/default.nix`: The main nix package configuration file.
- `pkgs/curios-manager/bin/curios-manager`: The main bash script, entry point
  of the TUI. User interaction is made with [Gum](https://github.com/charmbracelet/gum).
- `pkgs/curios-manager/bin/curios-update`: A bash script that check if a new
  version of CuriOS is available on Github. It also can upgrade the whole
  system. `curios-update --check` can be called from a systemd timer.
- `default.nix`: The default nix build/import package file.
- `shell.nix`: A Nix configuration file for the `nix-shell` command. It will setup
a temporary environment with the specified dependencies, tools and configurations
for the bash scripts.

## Coding Style and Best Practices

- **Binaries Naming**: File name must start with `curios-` (e.g., `curios-update`).
- **Code Style**: Use 2 spaces for indentation in nix and bash files.
- **Comments**: Add short, descriptive comments to explain complex configurations.

## Build, Test, and Development Commands

- **Lint Nix Files**: Lint Nix files using `statix`:

  ```bash
  statix check pkgs/curios-manager/default.nix
  ```

- **Lint Shell Scripts**: Bash shell scripts must be checked with `shellcheck`:

  ```bash
  shellcheck --color=always -f tty -x -P pkgs/curios-manager/bin \
  pkgs/curios-manager/bin/curios-* \
  pkgs/curios-manager/bin/functions/*.sh
  ```

- **Supported Version**: NixOS 25.11 or later.
- **Bash script test:** The binaries could be tested from a nix-shell:

  ```bash
  nix-shell
  ```

  This uses the `shell.nix` in the project root to configure dependencies.

- **Test Custom Packages**: Test Nix package with:

  ```bash
  nix-build && nix-env -i -f default.nix
  ```

- **Analyze**: Get latest code changes from git:

  ```bash
  git log
  ```
