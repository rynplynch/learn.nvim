{
 description = "An over-engineered learn-nvim World in C";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let

      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        hello = with final; stdenv.mkDerivation rec {
          pname = "hello";
          inherit version;

          src = ./.;

          nativeBuildInputs = [ autoreconfHook ];
        };

      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) learn-nvim;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.learn-nvim);

      devShells = forAllSystems (system:
        {
          default = import ./shell.nix { pkgs = nixpkgsFor.${system}; };
        });

      # A NixOS module, if applicable (e.g. if the package provides a system service).
      nixosModules.learn-nvim =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlay ];

          environment.systemPackages = [ pkgs.learn-nvim ];

          #systemd.services = { ... };
        };

      # Tests run by 'nix flake check' and by Hydra.
      checks = forAllSystems
        (system:
          with nixpkgsFor.${system};

          {
            inherit (self.packages.${system}) learn-nvim;

            # Additional tests, if applicable.
            test = stdenv.mkDerivation {
              pname = "learn-nvim-test";
              inherit version;

              buildInputs = [ learn-nvim ];

              dontUnpack = true;

              buildPhase = ''
                echo 'running some integration tests'
                [[ $(learn-nvim) = 'Hello Nixers!' ]]
              '';

              installPhase = "mkdir -p $out";
            };
          }

          // lib.optionalAttrs stdenv.isLinux {
            # A VM test of the NixOS module.
            vmTest =
              with import (nixpkgs + "/nixos/lib/testing-python.nix")
                {
                  inherit system;
                };

              makeTest {
                nodes = {
                  client = { ... }: {
                    imports = [ self.nixosModules.learn-nvim ];
                  };
                };

                testScript =
                  ''
                    start_all()
                    client.wait_for_unit("multi-user.target")
                    client.succeed("learn-nvim")
                  '';
              };
          }
        );

    };
}
