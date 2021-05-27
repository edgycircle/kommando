{
  pkgs ? import (fetchGit {
    url = https://github.com/NixOS/nixpkgs-channels;
    ref = "nixos-20.03";
  }) {},
  ruby ? pkgs.ruby_2_7,
  bundler ? pkgs.bundler.override { inherit ruby; }
}:

pkgs.mkShell {
  buildInputs = with pkgs; [
    git
    ruby
    bundler
    postgresql_12
    parallel
  ];

  shellHook = ''
    mkdir -p .local-data/gems
    export GEM_HOME=$PWD/.local-data/gems
    export GEM_PATH=$GEM_HOME

    mkdir -p .local-data/postgresql/{sockets,data}
    unset PGHOST
    export PGHOST="$PWD/.local-data/postgresql/sockets"
    unset PGDATA
    export PGDATA="$PWD/.local-data/postgresql/data"

    if [ -z "$(ls -A $PGDATA)" ]; then
      initdb -D $PGDATA
    fi

    export PATH="$GEM_PATH/bin:$PATH"
  '';
}
