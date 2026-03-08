#!/usr/bin/env python3
"""Migrate memories from @modelcontextprotocol/server-memory JSONL to mcp-memory-service.

Reads the knowledge graph JSONL file (entities + relations + observations) and
stores each entity's observations as individual memories in mcp-memory-service
via its MCP tools.

Usage:
  python3 scripts/migrate-memory.py [--jsonl PATH] [--dry-run]

Defaults:
  --jsonl  ~/.local/share/claude-memory/memory.jsonl
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path


def load_jsonl(path: Path) -> list[dict]:
    """Load and parse the JSONL knowledge graph file."""
    entries = []
    with open(path) as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError as e:
                print(f"  Warning: skipping malformed line {line_num}: {e}", file=sys.stderr)
    return entries


def extract_memories(entries: list[dict]) -> list[dict]:
    """Convert knowledge graph entries into flat memory records.

    Each entity's observations become individual memories, tagged with
    the entity name and type for searchability.
    """
    memories = []
    entities = {}

    # First pass: collect entities
    for entry in entries:
        if entry.get("type") == "entity":
            name = entry.get("name", "unknown")
            entity_type = entry.get("entityType", "unknown")
            observations = entry.get("observations", [])
            entities[name] = {"entityType": entity_type, "observations": observations}

            for obs in observations:
                memories.append(
                    {
                        "content": f"[{name}] ({entity_type}): {obs}",
                        "tags": [name.lower().replace(" ", "-"), entity_type.lower(), "migrated"],
                    }
                )

    # Second pass: collect relations as memories
    for entry in entries:
        if entry.get("type") == "relation":
            from_entity = entry.get("from", "unknown")
            to_entity = entry.get("to", "unknown")
            relation_type = entry.get("relationType", "relates-to")
            memories.append(
                {
                    "content": f"[Relation] {from_entity} --{relation_type}--> {to_entity}",
                    "tags": ["relation", "migrated"],
                }
            )

    return memories


def store_memory_via_cli(content: str, tags: list[str]) -> bool:
    """Store a memory using the mcp-memory-service CLI."""
    try:
        cmd = ["memory", "store", "--content", content]
        for tag in tags:
            cmd.extend(["--tag", tag])
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        print(f"  Error: {e}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(description="Migrate JSONL knowledge graph to mcp-memory-service")
    parser.add_argument(
        "--jsonl",
        type=Path,
        default=Path.home() / ".local/share/claude-memory/memory.jsonl",
        help="Path to the JSONL knowledge graph file",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print memories that would be stored without actually storing them",
    )
    args = parser.parse_args()

    if not args.jsonl.exists():
        print(f"Error: JSONL file not found: {args.jsonl}", file=sys.stderr)
        sys.exit(1)

    print(f"Loading knowledge graph from {args.jsonl}")
    entries = load_jsonl(args.jsonl)
    print(f"  Found {len(entries)} entries")

    memories = extract_memories(entries)
    print(f"  Extracted {len(memories)} memories to migrate")

    if args.dry_run:
        print("\n--- DRY RUN: memories that would be stored ---\n")
        for i, mem in enumerate(memories, 1):
            tags_str = ", ".join(mem["tags"])
            print(f"{i:3d}. [{tags_str}]")
            print(f"     {mem['content'][:120]}")
            print()
        print(f"Total: {len(memories)} memories")
        return

    print("\nStoring memories...")
    success = 0
    failed = 0
    for i, mem in enumerate(memories, 1):
        ok = store_memory_via_cli(mem["content"], mem["tags"])
        if ok:
            success += 1
            print(f"  [{i}/{len(memories)}] Stored: {mem['content'][:80]}...")
        else:
            failed += 1
            print(f"  [{i}/{len(memories)}] FAILED: {mem['content'][:80]}...")

    print(f"\nMigration complete: {success} stored, {failed} failed out of {len(memories)} total")
    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
