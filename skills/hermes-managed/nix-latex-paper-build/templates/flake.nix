{
  description = "<Paper name>: IEEEtran LaTeX sources built to PDF with a full TeX Live";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        default = paper;

        paper = pkgs.stdenvNoCC.mkDerivation {
          pname = "<paper-name>";
          version = "0.1.0";

          # builtins.path copies the tree into the store on its own terms;
          # the filter keeps VCS dirs, editor state and result links out of
          # the source hash so every build does not re-copy them.
          src = builtins.path {
            path = ./.;
            name = "paper-src";
            filter =
              path: _type:
              let
                base = baseNameOf path;
              in
              !(nixpkgs.lib.hasPrefix "result" base)
              && base != ".git"
              && base != ".omp"
              && base != ".direnv";
          };

          nativeBuildInputs = [
            (pkgs.texliveFull or pkgs.texlive.combined.scheme-full)
          ];

          buildPhase = ''
            runHook preBuild
            export HOME=$TMPDIR
            export TEXMFVAR=$TMPDIR/texmf-var
            latexmk -pdf -bibtex -interaction=nonstopmode -halt-on-error main.tex
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm644 main.pdf $out/main.pdf
            runHook postInstall
          '';
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            (pkgs.texliveFull or pkgs.texlive.combined.scheme-full)
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
