#!/usr/bin/env python3
"""Fake IDE Index MCP server for the hook and launcher tests.

    fake-index-mcp.py <port> <state.json> <calls.log>

GET answers 404, like the real server. POST tools/call answers two tools from the state file, which a
test rewrites between cases:
  {"open": ["/abs/project", ...], "open_fails": false}
ide_project_status lists those projects as open. ide_open_project adds its `path` to "open", or
answers isError when "open_fails" is true. With more than one project open, a call without
`project_path` gets the live server's multiple_projects_open error instead. Every tool call is appended to calls.log as `<tool> <args>`.
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT, STATE, CALLS = int(sys.argv[1]), sys.argv[2], sys.argv[3]


def reply(handler, code, body):
    data = json.dumps(body).encode()
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(data)))
    handler.end_headers()
    handler.wfile.write(data)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        reply(self, 404, {"error": "not found"})

    def do_POST(self):
        req = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        name = req["params"]["name"]
        args = req["params"].get("arguments", {})
        with open(CALLS, "a") as log:
            log.write(f"{name} {json.dumps(args, sort_keys=True)}\n")
        with open(STATE) as f:
            state = json.load(f)
        error, text = False, ""
        if len(state["open"]) > 1 and "project_path" not in args:
            # Copied from the live server: with several projects open, every tool wants project_path.
            error, text = True, json.dumps({
                "error": "multiple_projects_open",
                "message": "Multiple projects are open. Please specify 'project_path' parameter with one of the available project paths. For workspace projects, use the sub-project path.",
                "available_projects": [{"name": p.rsplit("/", 1)[-1], "path": p} for p in state["open"]]})
        elif name == "ide_project_status":
            text = json.dumps({"projects": [{"name": p.rsplit("/", 1)[-1], "path": p, "open": True} for p in state["open"]]})
        elif name == "ide_open_project":
            if state.get("open_fails"):
                error, text = True, "Project could not be opened"
            else:
                state["open"].append(args["path"])
                with open(STATE, "w") as f:
                    json.dump(state, f)
                text = f"Project '{args['path']}' is open and ready."
        reply(self, 200, {"jsonrpc": "2.0", "id": req.get("id"),
                          "result": {"content": [{"type": "text", "text": text}], "isError": error}})


HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
