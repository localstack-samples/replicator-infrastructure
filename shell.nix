{ pkgs ? import <nixpkgs> { } }:
with pkgs;
mkShell {
  packages = [
    opentofu
    nodejs_22
  ];
}

