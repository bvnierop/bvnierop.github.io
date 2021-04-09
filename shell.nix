with import <nixpkgs> { };

let jekyll_env = bundlerEnv rec {
    name = "jekyll_env";
    inherit ruby;
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
in
  stdenv.mkDerivation rec {
    name = "2021-03-26-jekyll";
    buildInputs = [ jekyll_env bundler ruby ];

    shellHook = ''
      echo exec ${jekyll_env}/bin/jekyll serve --watch
    '';
  }
