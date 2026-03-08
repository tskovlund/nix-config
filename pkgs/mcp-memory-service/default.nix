{
  lib,
  python312Packages,
  fetchFromGitHub,
}:

python312Packages.buildPythonPackage rec {
  pname = "mcp-memory-service";
  version = "10.26.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "doobidoo";
    repo = "mcp-memory-service";
    tag = "v${version}";
    hash = "sha256-7QeqLhdJ0hdcAqZYlLq6XZYncfKWqzg5Xcon0vlKQqI=";
  };

  # Patch out torch and sentence-transformers from project dependencies —
  # the ONNX embedding path (onnx_embeddings.py) doesn't import either;
  # they're only needed for the optional sentence-transformers embedding backend.
  # This reduces the closure from ~3-5GB (with torch) to ~500MB-1GB.
  # Also patch out python-semantic-release and build from build-system.requires —
  # they're not needed during the Nix build (hatchling alone suffices).
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail '"sentence-transformers>=2.2.2",' "" \
      --replace-fail '"torch>=2.0.0",' "" \
      --replace-fail '"python-semantic-release", "build"' "" \
      --replace-fail '"python-multipart>=0.0.22"' '"python-multipart>=0.0.20"' \
      --replace-fail '"sqlite-vec>=0.1.0"' '"sqlite-vec>=0.0.0"'
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
    apscheduler
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
    homepage = "https://github.com/doobidoo/mcp-memory-service";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
