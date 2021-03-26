#!/bin/bash
if [ ! -d .bundle ]; then
  nix-shell -p bundler -p bundix --run 'bundle package --no-install --path vendor'
fi
rm gemset.nix
nix-shell -p bundler -p bundix --run 'bundle update; bundle lock; bundle package --no-install --path vendor; bundix; rm -rf vendor'
echo "You can now run nix-shell"
