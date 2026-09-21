{
  lib,
  buildPythonPackage,
  fetchPypi,
  greenlet,
  pyee,
}:

buildPythonPackage rec {
  format = "wheel";
  pname = "patchright";
  version = "1.62.2";

  src = fetchPypi {
    inherit pname version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    abi = "none";
    platform = "manylinux1_x86_64";
    hash = "sha256-G5C2wxwWzo7ZzpMsFo//0Me0Us7dgz/vQnHmmJtWt70=";
  };

  dependencies = [
    greenlet
    pyee
  ];

  pythonImportsCheck = [ ];
  doCheck = false;

  meta = {
    description = "Undetected Python version of the Playwright automation library";
    homepage = "https://github.com/Kaliiiiiiiiii-Vinyzu/patchright-python";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
