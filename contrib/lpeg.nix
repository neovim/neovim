{
  luajit,
  luajitPackages,
  stdenv,
  fixDarwinDylibNames,
}:
stdenv.mkDerivation {
  pname = "liblpeg";
  inherit (luajitPackages.lpeg) version meta src;
  buildInputs = [luajit];
  buildPhase = ''
    sed -i makefile -e "s/CC = gcc/CC = clang/"
    sed -i makefile -e "s/-bundle/-dynamiclib/"

    make macosx
  '';

  installPhase = ''
    mkdir -p $out/lib
    mv lpeg.so $out/lib/lpeg.dylib
  '';

  nativeBuildInputs = [fixDarwinDylibNames];
}
