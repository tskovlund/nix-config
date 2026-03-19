{
  lib,
  python312Packages,
  fetchPypi,
}:

python312Packages.buildPythonPackage rec {
  pname = "mcp-memory-service";
  version = "10.26.0";
  pyproject = true;

  src = fetchPypi {
    pname = "mcp_memory_service";
    inherit version;
    hash = "sha256-Cu1BLBP/83bFaeaG/Q7TYEFKz48WLkgaEgrwY8T+F6Q=";
  };

  # Patch out optional/build-only dependencies:
  # - torch, sentence-transformers: only needed for the non-ONNX embedding backend
  # - python-semantic-release, build: not needed during Nix build (hatchling suffices)
  # - apscheduler: pulls in twisted which has flaky sandbox tests on macOS
  # Also relax version bounds for python-multipart and sqlite-vec.
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail '"sentence-transformers>=2.2.2",' "" \
      --replace-fail '"torch>=2.0.0",' "" \
      --replace-fail '"python-semantic-release", "build"' "" \
      --replace-fail '"python-multipart>=0.0.22"' '"python-multipart>=0.0.20"' \
      --replace-fail '"sqlite-vec>=0.1.0"' '"sqlite-vec>=0.0.0"' \
      --replace-fail '"apscheduler>=3.11.0",' ""
  '';

  build-system = with python312Packages; [
    hatchling
  ];

  dependencies = with python312Packages; [
    tokenizers
    mcp
    python-dotenv
    sqlite-vec
    aiosqlite
    build
    aiohttp
    fastapi
    uvicorn
    python-multipart
    sse-starlette
    aiofiles
    psutil
    zeroconf
    pypdf
    chardet
    click
    httpx
    authlib
    pyjwt
    requests
    # apscheduler removed — pulls in twisted which has flaky tests on macOS.
    # Only used for optional scheduled memory cleanup, not core functionality.
    # ONNX runtime for local embeddings (from [sqlite] extra)
    onnxruntime
  ];

  # No tests in the Nix build — they require network access and a running server.
  doCheck = false;

  # Import check disabled — the module tries to create directories on import,
  # which fails in the Nix sandbox. Runtime validation happens via the wrapper.
  pythonImportsCheck = [ ];

  meta = {
    description = "Persistent memory service with semantic search for AI agents via MCP";
    homepage = "https://pypi.org/project/mcp-memory-service/";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
