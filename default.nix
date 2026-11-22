# guile-dokgen --- API documentation for GNU Guile Scheme projects.
#
# SPDX-License-Identifier: MIT
# Copyright © Josep Bigorra <jjbigorra@gmail.com>

# A derivation for guile-dokgen, written once and called from wherever it is
# needed:
#
#   nix-build -E 'with import <nixpkgs> {}; callPackage ./default.nix { }'
#   callPackage ./default.nix { }    # from another expression or a flake
#
# `callPackage' passes the three dependencies and nothing else, and the source
# defaults to this directory, so this one file packages a checkout and a
# `git+https' input of a released tag without a second expression that could
# drift from it.  The argument is called `source' rather than `src' because
# `callPackage' fills an argument named `src' from nixpkgs, where it is a
# revision control system.
#
# The launcher finds its modules relative to itself, which is why they are
# installed under share/guile/site/3.0 -- the layout `maak install' produces --
# with the two dependencies on its own load path, so a dokgen run straight from
# the store finds (config) and (texinfo).  The compiled modules go beside them
# in Guile's site ccache, so the first run does not compile seven modules into
# a user's cache before it answers.

{ lib
, stdenv
, guile
, guile-config
, guile-lib
, gnuplot
, source ? ./.
}:

let
  # The version is stated once, in the command-line specification, and read
  # from there rather than restated here.
  cli = builtins.readFile "${source}/src/dokgen/cli.scm";
  version = builtins.head (builtins.match
    ".*\\(version \"([0-9]+\\.[0-9]+\\.[0-9]+)\"\\).*" cli);

  dependencySite = lib.makeSearchPath "share/guile/site/3.0" [ guile-config guile-lib ];
  dependencyFlags = lib.concatMapStrings (dir: " -L ${dir}")
    (lib.splitString ":" dependencySite);
in
stdenv.mkDerivation {
  pname = "guile-dokgen";
  inherit version;
  src = source;

  nativeBuildInputs = [ guile ];
  buildInputs = [ guile gnuplot ];

  # There is nothing to compile in the build phase: what is worth checking is
  # that the tool runs, that it documents its own sources, and that `check'
  # agrees the docstrings are all there.  That is the cheapest end-to-end test
  # that exists, and it fails for the same reasons a user would notice.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export GUILE_LOAD_PATH="${dependencySite}''${GUILE_LOAD_PATH:+:$GUILE_LOAD_PATH}"
    ./bin/dokgen --help > /dev/null
    ./bin/dokgen api --destination check-api ./src/dokgen
    test -s check-api/index.texi
    ./bin/dokgen check ./src/dokgen
    # The build tree carries no history, which is the fallback the
    # statistics chapter is written for: it runs, and says so.
    ./bin/dokgen stats --destination check-api ./src/dokgen
    test -s check-api/stats.texi
    grep -q 'no git history' check-api/stats.texi
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    site=$out/share/guile/site/3.0
    install -d "$site" "$out/bin"
    cp -r src/dokgen "$site/dokgen"

    install -m 755 bin/dokgen "$out/bin/dokgen"
    # A plot is drawn during a documentation build; a project that uses
    # dokgen should not have to install gnuplot itself.
    substituteInPlace "$out/bin/dokgen" \
      --replace-fail '$here/../src' "$site" \
      --replace-fail 'exec guile' "PATH=${gnuplot}/bin:\$PATH exec ${guile}/bin/guile -C $out/lib/guile/3.0/site-ccache${dependencyFlags}""}

    runHook postInstall
  '';

  postInstall = ''
    ccache=$out/lib/guile/3.0/site-ccache
    for source in $(find "$out/share/guile/site/3.0" -name '*.scm' | sort); do
      target="$ccache/''${source#"$out/share/guile/site/3.0/"}"
      mkdir -p "$(dirname "''${target%.scm}.go")"
      guild compile ${dependencyFlags} -L "$out/share/guile/site/3.0" \
        -o "''${target%.scm}.go" "$source"
    done
  '';

  meta = {
    description = "API documentation for GNU Guile Scheme projects";
    longDescription = ''
      Guile Dokgen extracts the API documentation of GNU Guile Scheme modules
      and writes it as Texinfo: every exported procedure, macro, variable,
      parameter object and record type, with the docstring that documents it.
      The documentation is read from the module that is loaded rather than
      parsed from its text, so a name the program can call is a name the manual
      documents.  A docstring may carry a mermaid or gnuplot diagram: mermaid
      is drawn in the page from a bundled renderer when no image was built,
      gnuplot is drawn at build time when it is installed, and either is kept
      as source when it cannot be drawn.  A `check' command reports the
      exported names that have no docstring, for a build that holds a library
      to a documented API.
    '';
    homepage = "https://github.com/jjba23/guile-dokgen";
    license = lib.licenses.mit;
    mainProgram = "dokgen";
    platforms = lib.platforms.unix;
  };
}
