{ lib, stdenv, fetchgit, jdk11, gradleGen, nodejs-12_x, makeWrapper
# runtime requirements for ort
, git, mercurial, cvs
, licensee, ruby
, python3, python3Packages
}:

let
  gradle_ = (gradleGen.override {
    java = jdk11;
  }).gradle_6_8;

  version = "master_76986516f8d72ff5aa343cd8eaf565c3b97531b4";

  deps = stdenv.mkDerivation {
    pname = "oss-review-toolkit-deps";
    inherit version;

    src = let
      jsonFile = ./. + "/ort.json";
      json = builtins.fromJSON (builtins.readFile jsonFile);
    in fetchgit {
      url = "https://github.com/oss-review-toolkit/ort";
      inherit (json) rev sha256;
      leaveDotGit = true;
      fetchSubmodules = true;
      deepClone = true;
    };

    nativeBuildInputs = [ gradle_ ];


    dontUseCmakeConfigure = true;

    buildPhase = ''
      runHook preBuild

      export GRADLE_USER_HOME=$(mktemp -d)
      export XDG_CONFIG_HOME=$GRADLE_USER_HOME/.config
      mkdir -p "''${GRADLE_USER_HOME}/nodejs"
      ln -s "${nodejs-12_x}" "''${GRADLE_USER_HOME}/nodejs/node-v12.16.1-linux-x64"

      gradle --no-daemon $gradleFlags installDist

      runHook postBuild
    '';

    installPhase = ''
      cp -r ./cli/build/install/* $out
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash =
      # Downloaded AWT jars differ by platform.
      if stdenv.system == "x86_64-linux" then "1000000000000000000000000000000000000000000000000000"
      else if stdenv.system == "i686-linux" then throw "Unsupported platform"
      else throw "Unsupported platform";
  };

in stdenv.mkDerivation {
  pname = "oss-review-toolkit";
  inherit version;

  src = deps;

  buildInputs = [ makeWrapper ];

  buildPhase = ''
    cp ${./ort.sh} ./bin/ort.sh
    sed -i -e 's%=ort%='"$out/bin/ort"'%' ./bin/ort.sh
    rm ./bin/ort.bat
  '';
  installPhase = ''
    mkdir -p $out
    cp -r ./* $out
    wrapProgram "$out/bin/ort" \
      --set LANG en_US.UTF-8 \
      --prefix PATH ":" "${git}/bin" \
      --prefix PATH ":" "${mercurial}/bin" \
      --prefix PATH ":" "${cvs}/bin" \
      --prefix PATH ":" "${licensee}/bin" \
      --prefix PATH ":" "${python3}/bin" \
      --prefix PATH ":" "${python3Packages.virtualenv}/bin"
      # --prefix PATH : "''${lib.makeBinPath [ git mercurial cvs licensee ruby python3 python3Packages ]}"
  '';

  stripDebugList = [ "." ];

  passthru.deps = deps;

  meta = with lib; {
    homepage = https://github.com/oss-review-toolkit/ort;
    license = "Apache-2.0";
    description = "The OSS Review Toolkit (ORT) aims to assist with the tasks that commonly need to be performed in the context of license compliance checks, especially for (but not limited to) Free and Open Source Software dependencies.";
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
