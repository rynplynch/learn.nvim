{ pkgs ? import <nixpkgs> { }
,
}:
with pkgs;  vimUtils.buildVimPlugin {
  name = "learn.nvim";
  src = ./.;
}
