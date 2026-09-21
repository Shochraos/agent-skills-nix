{
  lib,
  chromium,
  fetchurl,
  makeWrapper,
  nodejs,
  python3,
  runCommand,
}:
let
  python = python3.override {
    packageOverrides = final: prev: {
      cssselect = prev.cssselect.overridePythonAttrs (old: rec {
        version = "1.5.0";
        build-system = [ prev.hatchling ];
        src = prev.fetchPypi {
          pname = "cssselect";
          inherit version;
          hash = "sha256-PL6C3XrL7pup5XI7X55HSYJpEvH7Mc1/kqq+1f3hWxU=";
        };
      });

      curl-cffi = prev.curl-cffi.overridePythonAttrs (old: rec {
        version = "0.16.2";
        pyproject = null;
        format = "wheel";
        patches = [ ];
        postPatch = "";
        doCheck = false;
        src = fetchurl {
          url = "https://files.pythonhosted.org/packages/65/b0/b3dd929480f419f8aa921860afb44e15d2a22fd0be5c545296b9db865aa3/curl_cffi-0.16.2-cp310-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
          hash = "sha256-sqWXB/U0VJGgij1F9olbHJ3BktQDoevELB0e9DpYRT4=";
        };
      });

      mcp-types = final.callPackage ./mcp-types.nix { };
      mcp = final.callPackage ./mcp.nix { };
      patchright = final.callPackage ./patchright.nix { };
      scrapling = final.callPackage ./scrapling.nix { };
    };
  };

  env = python.withPackages (ps: [ ps.scrapling ]);
in
runCommand "scrapling-runtime-${python.pkgs.scrapling.version}"
  {
    meta = {
      description = "Scrapling MCP server runtime on nixpkgs Chromium";
      platforms = lib.platforms.linux;
    };
    nativeBuildInputs = [ makeWrapper ];
  }
  ''
    mkdir -p $out/bin
    makeWrapper ${env}/bin/scrapling-mcp $out/bin/scrapling-mcp \
      --set SCRAPLING_EXECUTABLE_PATH ${chromium}/bin/chromium \
      --set PLAYWRIGHT_NODEJS_PATH ${nodejs}/bin/node
  ''
