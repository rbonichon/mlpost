{ pkgs ? import <nixpkgs> { }
}:
let
  ocaml_pkgs = pkgs.ocaml-ng.ocamlPackages_4_07;

  ocamlPackages = (
    with ocaml_pkgs; [
      findlib
      bitstring
      ppx_tools_versioned
      ocaml-migrate-parsetree
      cairo2
      ocaml
      dune
    ]
  );
  packages = with pkgs; [
    cairo
    freetype
    m4
    ocamlformat
    pkgconfig
  ];

  file = builtins.toFile "foo" ''
    echo "foo"
  '';
in
rec {
  devshell = pkgs.mkShell {
    buildInputs = packages ++ ocamlPackages;
    shellHook = ''
      pkg-config --cflags cairo freetype2
      pkg-config --libs cairo freetype2
      sh ${file}
    '';
  };
}
