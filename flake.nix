{
  description = "htt devshell";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs }:
    let
      allSystems = [
        "x86_64-linux" # AMD/Intel Linux
        "x86_64-darwin" # AMD/Intel macOS
        "aarch64-linux" # ARM Linux
        "aarch64-darwin" # ARM macOS
      ];

      forAllSystems = fn:
        nixpkgs.lib.genAttrs allSystems
        (system: fn { pkgs = import nixpkgs { inherit system; }; });

    in {
      # used when calling `nix fmt <path/to/flake.nix>`
      formatter = forAllSystems ({ pkgs }: pkgs.nixfmt);

      # nix develop <flake-ref>#<name>
      # -- 
      # $ nix develop <flake-ref>#blue
      # $ nix develop <flake-ref>#yellow
      devShells = forAllSystems ({ pkgs }: let
        buildInputs = with pkgs; [
          hugo
          # zig
        ];
      in
      {
        default = pkgs.mkShell {
          name = "devshell";
          inherit buildInputs;
        };
      });
    };
}

