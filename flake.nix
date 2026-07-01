{
  description = "LaTeXML";

  outputs =
    { self, nixpkgs }:
    {
      devShells = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              (perl.withPackages (ps: [ ps.LaTeXML ]))
              imagemagick
              ghostscript
              gnumake
              sassc
              zip
              python3Packages.brotli
              python3Packages.fonttools
            ];
            shellHook = ''
              export PERL5LIB=$(perl -e 'print $ENV{PERL5LIB};')
              unset shell
            '';
          };
        }
      );
    };
}
