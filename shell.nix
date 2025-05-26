{mkShell, nixpkgs-fmt, neovim}:
mkShell {
  buildInputs = [
    nixpkgs-fmt
    neovim
  ];

  shellHook = ''
    # ...
  '';
}
