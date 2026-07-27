#!/usr/bin/env node
/**
 * FlowGate MCP Server
 *
 * 将 FlowGate 本地 REST API 暴露为 MCP tools，
 * 使 AI agent 可以通过 MCP 协议控制 VPN 客户端。
 *
 * 使用方式：
 *   node index.js [--port 19840]
 *
 * 环境变量：
 *   FLOWGATE_API_PORT - API 端口（默认 19840）
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const API_PORT = process.env.FLOWGATE_API_PORT || "19840";
const BASE_URL = `http://127.0.0.1:${API_PORT}/api/v1`;

// ─── HTTP Helper ──────────────────────────────────────────────────────────

async function api(method, path, body = null) {
  const opts = { method, headers: {} };
  if (body) {
    opts.headers["Content-Type"] = "application/json";
    opts.body = JSON.stringify(body);
  }
  try {
    const res = await fetch(`${BASE_URL}${path}`, opts);
    const json = await res.json();
    if (!json.ok) {
      return { error: json.error || `HTTP ${res.status}` };
    }
    return json.data;
  } catch (e) {
    return { error: `Connection failed: ${e.message}. Is FlowGate running?` };
  }
}

// ─── MCP Server ───────────────────────────────────────────────────────────

const server = new McpServer({
  name: "flowgate",
  version: "1.0.0",
});

// VPN Control
server.tool(
  "vpn_status",
  "Get current VPN connection state, traffic stats, and duration",
  {},
  async () => {
    const data = await api("GET", "/vpn/status");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.tool(
  "vpn_start",
  "Start VPN connection with optional config/remark",
  {
    config: z.string().optional().describe("Full Xray JSON config"),
    remark: z.string().optional().describe("Connection remark/name"),
    proxyOnly: z.boolean().optional().describe("Proxy-only mode (no TUN)"),
  },
  async ({ config, remark, proxyOnly }) => {
    const data = await api("POST", "/vpn/start", { config, remark, proxyOnly: proxyOnly || false });
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.tool(
  "vpn_stop",
  "Stop VPN connection",
  {},
  async () => {
    const data = await api("POST", "/vpn/stop");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

// Node Management
server.tool(
  "nodes_list",
  "List all proxy nodes",
  {},
  async () => {
    const data = await api("GET", "/nodes");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.tool(
  "nodes_import",
  "Import nodes from share links or base64 content",
  {
    content: z.string().describe("Share links or base64-encoded content"),
    type: z.enum(["base64", "url", "raw"]).optional().describe("Content type (auto-detect if omitted)"),
    subscriptionId: z.string().optional().describe("Associate with subscription"),
  },
  async ({ content, type, subscriptionId }) => {
    const data = await api("POST", "/nodes/import", { content, type, subscriptionId });
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.tool(
  "nodes_delete",
  "Delete a node by ID",
  { id: z.string().describe("Node ID") },
  async ({ id }) => {
    const data = await api("DELETE", `/nodes/${id}`);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.tool(
  "nodes_test",
  "Test latency of a single node (TCP connect)",
  { id: z.string().describe("Node ID") },
  async ({ id }) => {
    const data = await api("POST", `/nodes/${id}/test`);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.tool(
  "nodes_test_all",
  "Start batch latency test for all nodes (async, returns taskId)",
  {},
  async () => {
    const data = await api("POST", "/nodes/test-all");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.tool(
  "nodes_test_progress",
  "Get progress of a batch test task",
  { taskId: z.string().describe("Task ID from nodes_test_all") },
  async ({ taskId }) => {
    const data = await api("GET", `/nodes/test-all/${taskId}`);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

// Subscription Management
server.tool(
  "subscriptions_list",
  "List all subscriptions",
  {},
  async () => {
    const data = await api("GET", "/subscriptions");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.tool(
  "subscriptions_add",
  "Add a new subscription",
  {
    name: z.string().describe("Subscription name"),
    url: z.string().describe("Subscription URL"),
    autoUpdate: z.boolean().optional().describe("Enable auto-update"),
  },
  async ({ name, url, autoUpdate }) => {
    const data = await api("POST", "/subscriptions", { name, url, autoUpdate: autoUpdate || false });
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.tool(
  "subscriptions_delete",
  "Delete a subscription",
  {
    id: z.string().describe("Subscription ID"),
    deleteNodes: z.boolean().optional().describe("Also delete associated nodes"),
  },
  async ({ id, deleteNodes }) => {
    const data = await api("DELETE", `/subscriptions/${id}?deleteNodes=${deleteNodes || false}`);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.tool(
  "subscriptions_refresh",
  "Manually refresh a subscription (fetch and update nodes)",
  { id: z.string().describe("Subscription ID") },
  async ({ id }) => {
    const data = await api("POST", `/subscriptions/${id}/update`);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

// Routing Rules
server.tool(
  "routing_get",
  "Get current routing rules",
  {},
  async () => {
    const data = await api("GET", "/routing");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.tool(
  "routing_update",
  "Update routing rules (partial update supported)",
  {
    domainStrategy: z.string().optional().describe("AsIs | IPIfNonMatch | IPOnDemand"),
    bypassLan: z.boolean().optional().describe("Bypass LAN addresses"),
    bypassChina: z.boolean().optional().describe("Bypass China mainland"),
    proxyDomains: z.array(z.string()).optional().describe("Force-proxy domains"),
    directDomains: z.array(z.string()).optional().describe("Force-direct domains"),
  },
  async (params) => {
    const data = await api("PUT", "/routing", params);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

// System
server.tool(
  "system_info",
  "Get FlowGate version, core version, platform info",
  {},
  async () => {
    const data = await api("GET", "/system/info");
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

server.tool(
  "system_logs",
  "Get recent server logs",
  { limit: z.number().optional().describe("Max log entries (default 100)") },
  async ({ limit }) => {
    const data = await api("GET", `/system/logs?limit=${limit || 100}`);
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }
);

// ─── Start ────────────────────────────────────────────────────────────────

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error(`FlowGate MCP Server running (API: ${BASE_URL})`);
}

main().catch((e) => {
  console.error("Fatal:", e);
  process.exit(1);
});
