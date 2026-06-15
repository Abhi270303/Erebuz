#!/usr/bin/env python3
"""MCP server for DefiLlama Free API (api.llama.fi) + dimension-adapters.

Provides tools to query DeFi analytics data — TVL, prices, yields,
stablecoins, DEX volumes, fees, and more — plus GitHub tools to
track new protocol additions via dimension-adapters. No auth required.
"""
import json
import sys
import urllib.request
import urllib.parse
import re

BASE = "https://api.llama.fi"
GH_API = "https://api.github.com"
GH_REPO = "DefiLlama/dimension-adapters"


def api_get(path: str) -> str:
    req = urllib.request.Request(f"{BASE}{path}", headers={"User-Agent": "opencode-mcp/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode()


def gh_get(path: str) -> str:
    req = urllib.request.Request(f"{GH_API}{path}", headers={"User-Agent": "opencode-mcp/1.0", "Accept": "application/vnd.github.v3+json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode()


TOOLS: dict = {}

def tool(name: str, description: str, properties: dict, required: list[str] | None = None):
    TOOLS[name] = {
        "name": name,
        "description": description,
        "inputSchema": {
            "type": "object",
            "properties": properties,
            "required": required or [],
        },
    }


# ── TVL ──

tool("get_protocols", "List all protocols on DefiLlama along with their TVL", {})

tool("get_protocol", "Get historical TVL of a protocol and breakdowns by token and chain", {
    "protocol": {"type": "string", "description": "Protocol slug, e.g. 'aave'"},
}, ["protocol"])

tool("get_historical_chain_tvl", "Get historical TVL of DeFi on all chains (excludes liquid staking and double counted)", {})

tool("get_historical_chain_tvl_by_chain", "Get historical TVL of a specific chain", {
    "chain": {"type": "string", "description": "Chain slug, e.g. 'Ethereum'"},
}, ["chain"])

tool("get_tvl", "Simplified endpoint to get current TVL of a protocol", {
    "protocol": {"type": "string", "description": "Protocol slug, e.g. 'uniswap'"},
}, ["protocol"])

tool("get_chains", "Get current TVL of all chains", {})

# ── Coins & Prices ──

tool("get_prices_current", "Get current prices of tokens by contract address", {
    "coins": {"type": "string", "description": "Comma-separated {chain}:{address}, e.g. 'ethereum:0xdF574c24545E5FfEcb9a659c229253D4111d87e1,coingecko:ethereum'"},
    "searchWidth": {"type": "string", "description": "Time range to find price data, e.g. '4h' (default 6h)", "default": "6h"},
}, ["coins"])

tool("get_prices_historical", "Get historical prices of tokens by contract address at a specific timestamp", {
    "coins": {"type": "string", "description": "Comma-separated {chain}:{address}"},
    "timestamp": {"type": "number", "description": "UNIX timestamp"},
    "searchWidth": {"type": "string", "description": "Time range to find price data, e.g. '4h'", "default": "6h"},
}, ["coins", "timestamp"])

tool("get_batch_historical", "Get historical prices for multiple tokens at multiple timestamps", {
    "coins": {"type": "string", "description": "JSON object: keys are {chain}:{address}, values are arrays of timestamps. E.g. '{\"coingecko:ethereum\": [1666869543]}'"},
    "searchWidth": {"type": "string", "description": "Time range in seconds, e.g. '600'", "default": "600"},
}, ["coins"])

tool("get_chart", "Get token prices at regular time intervals", {
    "coins": {"type": "string", "description": "Comma-separated {chain}:{address}"},
    "start": {"type": "number", "description": "Start unix timestamp"},
    "end": {"type": "number", "description": "End unix timestamp"},
    "span": {"type": "number", "description": "Number of data points"},
    "period": {"type": "string", "description": "Duration between data points, e.g. '2d' (default 24h)"},
    "searchWidth": {"type": "string", "description": "Time range to find price data"},
}, ["coins"])

tool("get_percentage", "Get percentage change in price over time", {
    "coins": {"type": "string", "description": "Comma-separated {chain}:{address}"},
    "timestamp": {"type": "number", "description": "Timestamp of data point"},
    "lookForward": {"type": "boolean", "description": "Look forward instead of backward", "default": False},
    "period": {"type": "string", "description": "Duration between data points, e.g. '3w' (default 24h)"},
}, ["coins"])

tool("get_prices_first", "Get earliest timestamp price record for coins", {
    "coins": {"type": "string", "description": "Comma-separated {chain}:{address}"},
}, ["coins"])

tool("get_block", "Get the closest block to a timestamp", {
    "chain": {"type": "string", "description": "Chain name, e.g. 'ethereum'"},
    "timestamp": {"type": "integer", "description": "UNIX timestamp"},
}, ["chain", "timestamp"])

# ── Stablecoins ──

tool("get_stablecoins", "List all stablecoins along with their circulating amounts", {
    "includePrices": {"type": "boolean", "description": "Include current stablecoin prices", "default": False},
})

tool("get_stablecoin_charts_all", "Get historical mcap sum of all stablecoins", {
    "stablecoin": {"type": "integer", "description": "Stablecoin ID from /stablecoins"},
})

tool("get_stablecoin_charts_chain", "Get historical mcap sum of all stablecoins in a chain", {
    "chain": {"type": "string", "description": "Chain slug, e.g. 'Ethereum'"},
    "stablecoin": {"type": "integer", "description": "Stablecoin ID from /stablecoins"},
}, ["chain"])

tool("get_stablecoin", "Get historical mcap and chain distribution of a stablecoin", {
    "asset": {"type": "integer", "description": "Stablecoin ID from /stablecoins"},
}, ["asset"])

tool("get_stablecoin_chains", "Get current mcap sum of all stablecoins on each chain", {})

tool("get_stablecoin_prices", "Get historical prices of all stablecoins", {})

# ── Yields & APY ──

tool("get_pools", "Retrieve latest data for all yield pools, including predictions", {})

tool("get_pool_chart", "Get historical APY and TVL of a pool", {
    "pool": {"type": "string", "description": "Pool ID from /pools"},
}, ["pool"])

# ── DEX Volumes ──

tool("get_dexs_overview", "List all DEXs with volume summaries", {
    "excludeTotalDataChart": {"type": "boolean", "description": "Exclude aggregated chart", "default": True},
    "excludeTotalDataChartBreakdown": {"type": "boolean", "description": "Exclude broken down chart", "default": True},
})

tool("get_dexs_overview_chain", "List all DEXs on a specific chain", {
    "chain": {"type": "string", "description": "Chain name, e.g. 'ethereum'"},
    "excludeTotalDataChart": {"type": "boolean", "description": "Exclude aggregated chart", "default": True},
    "excludeTotalDataChartBreakdown": {"type": "boolean", "description": "Exclude broken down chart", "default": True},
}, ["chain"])

tool("get_dexs_summary", "Get summary of DEX volume with historical data", {
    "protocol": {"type": "string", "description": "Protocol slug, e.g. 'uniswap'"},
    "excludeTotalDataChart": {"type": "boolean", "default": True},
    "excludeTotalDataChartBreakdown": {"type": "boolean", "default": True},
}, ["protocol"])

tool("get_options_overview", "List all options DEXs with volume summaries", {
    "excludeTotalDataChart": {"type": "boolean", "default": True},
    "excludeTotalDataChartBreakdown": {"type": "boolean", "default": True},
    "dataType": {"type": "string", "description": "dailyPremiumVolume or dailyNotionalVolume"},
})

tool("get_options_overview_chain", "List all options DEXs on a chain", {
    "chain": {"type": "string", "description": "Chain name"},
    "excludeTotalDataChart": {"type": "boolean", "default": True},
    "excludeTotalDataChartBreakdown": {"type": "boolean", "default": True},
    "dataType": {"type": "string", "description": "dailyPremiumVolume or dailyNotionalVolume"},
}, ["chain"])

tool("get_options_summary", "Get summary of options DEX volume with historical data", {
    "protocol": {"type": "string", "description": "Protocol slug, e.g. 'derive'"},
    "dataType": {"type": "string", "description": "dailyPremiumVolume or dailyNotionalVolume"},
}, ["protocol"])

# ── Perpetuals & Open Interest ──

tool("get_open_interest", "List all open interest DEX exchanges with summaries", {
    "excludeTotalDataChart": {"type": "boolean", "default": True},
    "excludeTotalDataChartBreakdown": {"type": "boolean", "default": True},
})

# ── Fees & Revenue ──

tool("get_fees_overview", "List all protocols with fees, revenue, and historical data", {
    "excludeTotalDataChart": {"type": "boolean", "default": True},
    "excludeTotalDataChartBreakdown": {"type": "boolean", "default": True},
    "dataType": {"type": "string", "description": "dailyFees, dailyRevenue, or dailyHoldersRevenue"},
})

tool("get_fees_overview_chain", "List protocols with fees and revenue by chain", {
    "chain": {"type": "string", "description": "Chain name"},
    "excludeTotalDataChart": {"type": "boolean", "default": True},
    "excludeTotalDataChartBreakdown": {"type": "boolean", "default": True},
    "dataType": {"type": "string", "description": "dailyFees, dailyRevenue, or dailyHoldersRevenue"},
}, ["chain"])

tool("get_fees_summary", "Get summary of protocol fees and revenue with historical data", {
    "protocol": {"type": "string", "description": "Protocol slug"},
    "dataType": {"type": "string", "description": "dailyFees, dailyRevenue, or dailyHoldersRevenue"},
}, ["protocol"])

# ── GitHub: dimension-adapters ──

tool("get_adapters_prs", "List open PRs in DefiLlama/dimension-adapters (new protocol additions)", {
    "state": {"type": "string", "description": "PR state: 'open', 'closed', 'all'", "default": "open"},
    "per_page": {"type": "number", "description": "Results per page (max 100)", "default": 10},
})

tool("get_adapters_pr", "Get details of a specific PR in dimension-adapters", {
    "pr_number": {"type": "number", "description": "PR number"},
}, ["pr_number"])

tool("search_adapters_code", "Search code in dimension-adapters repo (e.g. find new protocol adapters)", {
    "query": {"type": "string", "description": "GitHub code search query (scoped to repo automatically)"},
    "per_page": {"type": "number", "description": "Max results", "default": 10},
}, ["query"])

tool("get_adapters_recent_commits", "Get recent commits in dimension-adapters (detect new protocol additions)", {
    "per_page": {"type": "number", "description": "Max commits", "default": 15},
})

tool("get_adapters_protocols", "List protocol adapter folders in a category", {
    "path": {"type": "string", "description": "Category dir: 'dexs', 'fees', 'options', 'aggregators', 'incentives', 'users', 'adapters'", "default": "dexs"},
})

tool("get_adapters_file", "Get content of a specific file in dimension-adapters (e.g. a protocol adapter)", {
    "path": {"type": "string", "description": "File path in the repo, e.g. 'projects/aave/index.ts'"},
}, ["path"])


def build_path(name: str, args: dict) -> str:
    if name == "get_protocols":
        return "/protocols"
    elif name == "get_protocol":
        return f"/protocol/{urllib.parse.quote(args['protocol'])}"
    elif name == "get_historical_chain_tvl":
        return "/v2/historicalChainTvl"
    elif name == "get_historical_chain_tvl_by_chain":
        return f"/v2/historicalChainTvl/{urllib.parse.quote(args['chain'])}"
    elif name == "get_tvl":
        return f"/tvl/{urllib.parse.quote(args['protocol'])}"
    elif name == "get_chains":
        return "/v2/chains"
    elif name == "get_prices_current":
        qs = urllib.parse.urlencode({k: args[k] for k in ("searchWidth",) if args.get(k)})
        return f"/prices/current/{urllib.parse.quote(args['coins'], safe=',:')}?{qs}" if qs else f"/prices/current/{urllib.parse.quote(args['coins'], safe=',:')}"
    elif name == "get_prices_historical":
        qs = urllib.parse.urlencode({k: args[k] for k in ("searchWidth",) if args.get(k)})
        return f"/prices/historical/{args['timestamp']}/{urllib.parse.quote(args['coins'], safe=',:')}?{qs}" if qs else f"/prices/historical/{args['timestamp']}/{urllib.parse.quote(args['coins'], safe=',:')}"
    elif name == "get_batch_historical":
        params = {"coins": args["coins"]}
        if args.get("searchWidth"):
            params["searchWidth"] = args["searchWidth"]
        return f"/batchHistorical?{urllib.parse.urlencode(params)}"
    elif name == "get_chart":
        qs = "&".join(f"{k}={urllib.parse.quote(str(args[k]))}" for k in ("start", "end", "span", "period", "searchWidth") if args.get(k))
        return f"/chart/{urllib.parse.quote(args['coins'], safe=',:')}?{qs}" if qs else f"/chart/{urllib.parse.quote(args['coins'], safe=',:')}"
    elif name == "get_percentage":
        qs = "&".join(f"{k}={urllib.parse.quote(str(args[k]).lower() if isinstance(args[k], bool) else str(args[k]))}" for k in ("timestamp", "lookForward", "period") if args.get(k) is not None)
        return f"/percentage/{urllib.parse.quote(args['coins'], safe=',:')}?{qs}" if qs else f"/percentage/{urllib.parse.quote(args['coins'], safe=',:')}"
    elif name == "get_prices_first":
        return f"/prices/first/{urllib.parse.quote(args['coins'], safe=',:')}"
    elif name == "get_block":
        return f"/block/{urllib.parse.quote(args['chain'])}/{args['timestamp']}"
    elif name == "get_stablecoins":
        qs = urllib.parse.urlencode({"includePrices": str(args.get("includePrices", False)).lower()})
        return f"/stablecoins?{qs}"
    elif name == "get_stablecoin_charts_all":
        qs = urllib.parse.urlencode({k: args[k] for k in ("stablecoin",) if args.get(k)})
        return f"/stablecoincharts/all?{qs}" if qs else "/stablecoincharts/all"
    elif name == "get_stablecoin_charts_chain":
        qs = urllib.parse.urlencode({k: args[k] for k in ("stablecoin",) if args.get(k)})
        return f"/stablecoincharts/{urllib.parse.quote(args['chain'])}?{qs}" if qs else f"/stablecoincharts/{urllib.parse.quote(args['chain'])}"
    elif name == "get_stablecoin":
        return f"/stablecoin/{args['asset']}"
    elif name == "get_stablecoin_chains":
        return "/stablecoinchains"
    elif name == "get_stablecoin_prices":
        return "/stablecoinprices"
    elif name == "get_pools":
        return "/pools"
    elif name == "get_pool_chart":
        return f"/chart/{urllib.parse.quote(args['pool'])}"
    elif name == "get_dexs_overview":
        qs = urllib.parse.urlencode({k: str(args.get(k, True)).lower() for k in ("excludeTotalDataChart", "excludeTotalDataChartBreakdown")})
        return f"/overview/dexs?{qs}"
    elif name == "get_dexs_overview_chain":
        qs = urllib.parse.urlencode({k: str(args.get(k, True)).lower() for k in ("excludeTotalDataChart", "excludeTotalDataChartBreakdown")})
        return f"/overview/dexs/{urllib.parse.quote(args['chain'])}?{qs}"
    elif name == "get_dexs_summary":
        qs = urllib.parse.urlencode({k: str(args.get(k, True)).lower() for k in ("excludeTotalDataChart", "excludeTotalDataChartBreakdown")})
        return f"/summary/dexs/{urllib.parse.quote(args['protocol'])}?{qs}"
    elif name == "get_options_overview":
        qs_parts = [f"{k}={str(args.get(k, True)).lower()}" for k in ("excludeTotalDataChart", "excludeTotalDataChartBreakdown")]
        if args.get("dataType"):
            qs_parts.append(f"dataType={args['dataType']}")
        return f"/overview/options?{'&'.join(qs_parts)}"
    elif name == "get_options_overview_chain":
        qs_parts = [f"{k}={str(args.get(k, True)).lower()}" for k in ("excludeTotalDataChart", "excludeTotalDataChartBreakdown")]
        if args.get("dataType"):
            qs_parts.append(f"dataType={args['dataType']}")
        return f"/overview/options/{urllib.parse.quote(args['chain'])}?{'&'.join(qs_parts)}"
    elif name == "get_options_summary":
        qs = urllib.parse.urlencode({k: args[k] for k in ("dataType",) if args.get(k)})
        return f"/summary/options/{urllib.parse.quote(args['protocol'])}?{qs}" if qs else f"/summary/options/{urllib.parse.quote(args['protocol'])}"
    elif name == "get_open_interest":
        qs = urllib.parse.urlencode({k: str(args.get(k, True)).lower() for k in ("excludeTotalDataChart", "excludeTotalDataChartBreakdown")})
        return f"/overview/open-interest?{qs}"
    elif name == "get_fees_overview":
        qs_parts = [f"{k}={str(args.get(k, True)).lower()}" for k in ("excludeTotalDataChart", "excludeTotalDataChartBreakdown")]
        if args.get("dataType"):
            qs_parts.append(f"dataType={args['dataType']}")
        return f"/overview/fees?{'&'.join(qs_parts)}"
    elif name == "get_fees_overview_chain":
        qs_parts = [f"{k}={str(args.get(k, True)).lower()}" for k in ("excludeTotalDataChart", "excludeTotalDataChartBreakdown")]
        if args.get("dataType"):
            qs_parts.append(f"dataType={args['dataType']}")
        return f"/overview/fees/{urllib.parse.quote(args['chain'])}?{'&'.join(qs_parts)}"
    elif name == "get_fees_summary":
        qs = urllib.parse.urlencode({k: args[k] for k in ("dataType",) if args.get(k)})
        return f"/summary/fees/{urllib.parse.quote(args['protocol'])}?{qs}" if qs else f"/summary/fees/{urllib.parse.quote(args['protocol'])}"

    # ── GitHub tools (not API paths, handled in tools/call) ──
    raise ValueError(f"Unknown tool: {name}")


def handle_github(name: str, args: dict) -> str:
    if name == "get_adapters_prs":
        state = args.get("state", "open")
        per_page = min(int(args.get("per_page", 10)), 100)
        return gh_get(f"/repos/{GH_REPO}/pulls?state={state}&per_page={per_page}&sort=created&direction=desc")
    elif name == "get_adapters_pr":
        return gh_get(f"/repos/{GH_REPO}/pulls/{args['pr_number']}")
    elif name == "search_adapters_code":
        q = urllib.parse.quote(f"repo:{GH_REPO} {args['query']}")
        per_page = min(int(args.get("per_page", 10)), 100)
        return gh_get(f"/search/code?q={q}&per_page={per_page}")
    elif name == "get_adapters_recent_commits":
        per_page = min(int(args.get("per_page", 15)), 100)
        return gh_get(f"/repos/{GH_REPO}/commits?per_page={per_page}")
    elif name == "get_adapters_protocols":
        path = args.get("path", "dexs")
        data = gh_get(f"/repos/{GH_REPO}/contents/{urllib.parse.quote(path)}")
        items = json.loads(data)
        if isinstance(items, dict) and items.get("message"):
            return data
        result = [{"name": i["name"], "type": i["type"], "url": i["html_url"]} for i in items if i["type"] == "dir"]
        return json.dumps(result, indent=2)
    elif name == "get_adapters_file":
        path = args["path"]
        data = gh_get(f"/repos/{GH_REPO}/contents/{urllib.parse.quote(path)}")
        info = json.loads(data)
        if isinstance(info, list):
            return data
        if info.get("encoding") == "base64" and info.get("content"):
            import base64
            decoded = base64.b64decode(info["content"]).decode("utf-8")
            return decoded
        return data
    raise ValueError(f"Unknown GitHub tool: {name}")


def handle_request(req: dict) -> dict | None:
    method = req.get("method", "")
    params = req.get("params", {}) or {}
    req_id = req.get("id")

    if method == "initialize":
        return {
            "jsonrpc": "2.0", "id": req_id,
            "result": {
                "protocolVersion": "0.1.0",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "defillama-free-mcp", "version": "1.0.0"},
            },
        }
    elif method == "tools/list":
        return {"jsonrpc": "2.0", "id": req_id, "result": {"tools": list(TOOLS.values())}}
    elif method == "tools/call":
        tool_name = params.get("name", "")
        args = params.get("arguments", {}) or {}
        try:
            if tool_name.startswith("get_adapters") or tool_name == "search_adapters_code":
                data = handle_github(tool_name, args)
            else:
                path = build_path(tool_name, args)
                data = api_get(path)
            return {"jsonrpc": "2.0", "id": req_id, "result": {"content": [{"type": "text", "text": data}]}}
        except Exception as e:
            return {"jsonrpc": "2.0", "id": req_id, "error": {"code": -32603, "message": str(e)}}
    elif method in ("notifications/initialized", "ping"):
        return {"jsonrpc": "2.0", "id": req_id, "result": {}} if method == "ping" else None
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
