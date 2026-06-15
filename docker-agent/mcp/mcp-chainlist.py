#!/usr/bin/env python3
"""MCP server for chainlist.org RPC data.

Provides tools to search EVM chains and find their RPC endpoints.
Data sourced from https://chainlist.org/rpcs.json
"""
import json
import sys
import urllib.request
import re
from typing import Any

CHAINLIST_URL = "https://chainlist.org/rpcs.json"

chains: list[dict[str, Any]] = []
loaded = False


def load_chains():
    global chains, loaded
    if loaded:
        return
    try:
        req = urllib.request.Request(CHAINLIST_URL, headers={"User-Agent": "Mozilla/5.0 (compatible; opencode-mcp)"})
        resp = urllib.request.urlopen(req, timeout=30)
        chains = json.loads(resp.read())
        loaded = True
    except Exception as e:
        chains = []
        raise RuntimeError(f"Failed to load chainlist data: {e}")


def search_chains(query: str, limit: int = 10) -> str:
    load_chains()
    q = query.lower()
    results = []
    for c in chains:
        name = c.get("name", "")
        slug = c.get("chainSlug", "")
        short = c.get("shortName", "")
        chain_id = str(c.get("chainId", ""))
        symbol = c.get("nativeCurrency", {}).get("symbol", "")
        if (q in name.lower() or q in slug.lower() or
            q in short.lower() or q in chain_id or q in symbol.lower()):
            results.append({
                "name": name,
                "chainId": c.get("chainId"),
                "chainSlug": slug,
                "shortName": short,
                "nativeCurrency": c.get("nativeCurrency"),
                "rpcCount": len(c.get("rpc", [])),
                "explorers": [e["url"] for e in c.get("explorers", [])],
                "isTestnet": c.get("isTestnet", False),
            })
        if len(results) >= limit:
            break
    return json.dumps(results, indent=2)


def get_chain_rpcs(chain_id: int, tracking: str = "any") -> str:
    load_chains()
    for c in chains:
        if c.get("chainId") == chain_id:
            rpcs = c.get("rpc", [])
            if tracking == "none":
                rpcs = [r for r in rpcs if r.get("tracking") == "none"]
            elif tracking == "no-tracking":
                rpcs = [r for r in rpcs if r.get("tracking") in ("none", None)]
            return json.dumps({
                "name": c["name"],
                "chainId": chain_id,
                "rpc": [r["url"] for r in rpcs],
                "nativeCurrency": c.get("nativeCurrency"),
                "explorers": c.get("explorers", []),
            }, indent=2)
    return json.dumps({"error": f"Chain {chain_id} not found"})


def list_chains(page: int = 1, per_page: int = 50, testnets: bool = False) -> str:
    load_chains()
    filtered = [c for c in chains if c.get("isTestnet", False) == testnets]
    start = (page - 1) * per_page
    end = start + per_page
    page_chains = filtered[start:end]
    result = {
        "page": page,
        "perPage": per_page,
        "total": len(filtered),
        "chains": [{
            "name": c["name"],
            "chainId": c.get("chainId"),
            "slug": c.get("chainSlug"),
            "symbol": c.get("nativeCurrency", {}).get("symbol"),
        } for c in page_chains],
    }
    return json.dumps(result, indent=2)


TOOLS = {
    "search_chains": {
        "name": "search_chains",
        "description": "Search EVM chains by name, chain ID, symbol, or slug",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query (name, chainId, symbol, slug)"},
                "limit": {"type": "number", "description": "Max results (default 10)", "default": 10},
            },
            "required": ["query"],
        },
    },
    "get_chain_rpcs": {
        "name": "get_chain_rpcs",
        "description": "Get RPC endpoints for a specific chain by chain ID",
        "inputSchema": {
            "type": "object",
            "properties": {
                "chain_id": {"type": "number", "description": "EVM chain ID (e.g. 1 for Ethereum, 56 for BSC)"},
                "tracking": {
                    "type": "string",
                    "description": "Filter by tracking policy: 'any', 'none', 'no-tracking'",
                    "enum": ["any", "none", "no-tracking"],
                    "default": "any",
                },
            },
            "required": ["chain_id"],
        },
    },
    "list_chains": {
        "name": "list_chains",
        "description": "List all chains with pagination",
        "inputSchema": {
            "type": "object",
            "properties": {
                "page": {"type": "number", "description": "Page number (default 1)", "default": 1},
                "per_page": {"type": "number", "description": "Results per page (default 50, max 200)", "default": 50},
                "testnets": {"type": "boolean", "description": "Include testnets", "default": False},
            },
        },
    },
}


def handle_request(req: dict) -> dict:
    method = req.get("method", "")
    params = req.get("params", {}) or {}
    req_id = req.get("id")

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": "0.1.0",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "chainlist-mcp", "version": "1.0.0"},
            },
        }
    elif method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {"tools": list(TOOLS.values())},
        }
    elif method == "tools/call":
        tool_name = params.get("name", "")
        args = params.get("arguments", {}) or {}
        try:
            if tool_name == "search_chains":
                result = search_chains(args.get("query", ""), args.get("limit", 10))
            elif tool_name == "get_chain_rpcs":
                result = get_chain_rpcs(args.get("chain_id", 0), args.get("tracking", "any"))
            elif tool_name == "list_chains":
                result = list_chains(args.get("page", 1), args.get("per_page", 50), args.get("testnets", False))
            else:
                return {"jsonrpc": "2.0", "id": req_id, "error": {"code": -32601, "message": f"Tool not found: {tool_name}"}}
            return {"jsonrpc": "2.0", "id": req_id, "result": {"content": [{"type": "text", "text": result}]}}
        except Exception as e:
            return {"jsonrpc": "2.0", "id": req_id, "error": {"code": -32603, "message": str(e)}}
    elif method == "notifications/initialized":
        return None
    elif method == "ping":
        return {"jsonrpc": "2.0", "id": req_id, "result": {}}
    else:
        return {"jsonrpc": "2.0", "id": req_id, "error": {"code": -32601, "message": f"Method not found: {method}"}}


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            resp = handle_request(req)
            if resp is not None:
                print(json.dumps(resp), flush=True)
        except json.JSONDecodeError:
            continue
        except Exception as e:
            print(json.dumps({"jsonrpc": "2.0", "error": {"code": -32700, "message": str(e)}}), flush=True)


if __name__ == "__main__":
    main()
