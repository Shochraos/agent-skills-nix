{
  lib,
  buildPythonPackage,
  fetchPypi,
  python,
  setuptools,
  anyio,
  apify-fingerprint-datapoints,
  browserforge,
  click,
  cssselect,
  curl-cffi,
  lxml,
  mcp,
  msgspec,
  orjson,
  patchright,
  playwright,
  protego,
  tld,
  typing-extensions,
  w3lib,
  markdownify,
}:

buildPythonPackage rec {
  pname = "scrapling";
  version = "0.4.15";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-ckBpAPQ3MWIJ3QXZhT2uBEIPHKsOEQcWBLtFiLbi9xM=";
  };

  pythonRelaxDeps = [ "playwright" ];

  build-system = [ setuptools ];

  dependencies = [
    anyio
    apify-fingerprint-datapoints
    browserforge
    click
    cssselect
    curl-cffi
    lxml
    markdownify
    mcp
    msgspec
    orjson
    patchright
    playwright
    protego
    tld
    typing-extensions
    w3lib
  ];

  postInstall = ''
    touch $out/${python.sitePackages}/scrapling/.scrapling_dependencies_installed
  '';

  pythonImportsCheck = [ ];
  doCheck = false;

  meta = {
    description = "Undetectable, Lightning-Fast, and Adaptive Web Scraping for Python";
    homepage = "https://github.com/D4Vinci/Scrapling";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
