# Curios Manager

[![NixOS 26.05](https://img.shields.io/badge/NixOS-26.05-blue.svg?style=flat-square&logo=NixOS&logoColor=white)](https://nixos.org)
[![X Follow](https://img.shields.io/twitter/follow/CuriosLabs?style=social)](https://x.com/CuriosLabs)

A modern TUI to control your [CuriOS](https://github.com/CuriosLabs/CuriOS) system.

![CuriOS Manager TUI](https://github.com/CuriosLabs/CuriOS/blob/release/26.05.10/img/curios-manager_main-menu2.png?raw=true "CuriOS manager")

-----

## Build, Test, and Development Commands

This project uses [Just](https://github.com/casey/just) to manage development commands.
Use the appropriate shell environment before with `nix-shell shell.nix`.

- **Lint Files**: Check code quality for Nix and Bash files:

  ```bash
  nix-shell shell.nix --run "just lint"
  ```

- **Test Application**: Launch the `curios-manager` TUI:

  ```bash
  nix-shell shell.nix --run "just test"
  ```

- **Publish a new version**: Create a new git tag, push it, build it and update
the hash signature for the Nix package:

  ```bash
  nix-shell shell.nix --run "just publish 0.21"
  ```

- **Run**: Build the Nix package (from Github) and run it:

  ```bash
  nix-shell shell.nix --run "just run"
  ```

- **Clean**: Remove build artifacts:

  ```bash
  nix-shell shell.nix --run "just clean"
  ```

- **List Commands**: Show all available recipes:

  ```bash
  nix-shell shell.nix --run "just --list"
  ```

## License

Copyright (C) 2025-2026  David BASTIEN

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
