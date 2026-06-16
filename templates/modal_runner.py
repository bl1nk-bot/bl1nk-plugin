import modal
import sqlite3
import json
import uuid
from datetime import datetime
from typing import Dict, Any, Optional

from templates.images.base import bl1nk_image

app = modal.App("bl1nk")

volume = modal.Volume.from_name("bl1nk-data")
DB_PATH = "/data/bl1nk.db"


@app.function(
    image=bl1nk_image,
    volumes={"/data": volume},
    secrets=[modal.Secret.from_name("bl1nk-secrets")]
)
@modal.asgi_app()
def webhook():
    """Entry point for all external triggers via FastAPI."""
    from fastapi import FastAPI, Request
    from fastapi.responses import JSONResponse

    web_app = FastAPI()

    @web_app.post("/")
    async def handle_webhook(payload: Dict[str, Any], request: Request):
        flow_id = request.headers.get("X-Bl1nk-Flow-ID")

        runner = ModalRunner()
        result = await runner.run_active_flow.remote.aio(payload, flow_id)
        return JSONResponse(content=result)

    return web_app


@app.cls(
    image=bl1nk_image,
    volumes={"/data": volume},
    secrets=[modal.Secret.from_name("bl1nk-secrets")]
)
class ModalRunner:
    def __init__(self):
        self.db_path = DB_PATH

    def _get_conn(self):
        return sqlite3.connect(self.db_path)

    @modal.method()
    async def run_active_flow(self, trigger_payload: Dict[str, Any], flow_id: Optional[str] = None):
        conn = self._get_conn()
        cursor = conn.cursor()

        # 1. Get active deployment
        if flow_id:
            cursor.execute("""
                SELECT d.flow_id, d.version_id, v.snapshot
                FROM flow_deployments d
                JOIN flow_versions v ON d.version_id = v.id
                WHERE d.flow_id = ? AND d.status = 'active' LIMIT 1
            """, (flow_id,))
        else:
            cursor.execute("""
                SELECT d.flow_id, d.version_id, v.snapshot
                FROM flow_deployments d
                JOIN flow_versions v ON d.version_id = v.id
                WHERE d.status = 'active' LIMIT 1
            """)
        row = cursor.fetchone()
        if not row:
            return {"status": "error", "message": "No active deployment found"}

        flow_id, version_id, snapshot_json = row
        snapshot = json.loads(snapshot_json)

        # 2. Initialize Run Log
        run_id = self._init_run(cursor, flow_id, version_id, "webhook")
        conn.commit()

        # 3. Execution Context
        context = {"trigger": trigger_payload}
        nodes = snapshot.get("nodes", [])
        edges = snapshot.get("edges", [])

        try:
            # 4. Execute Nodes (Spike: Linear execution based on nodes list)
            # Real version needs topological sort
            for node in nodes:
                node_key = node["node_key"]
                node_type = node["type"]
                config = node.get("config", {})

                # Resolve inputs from edges
                node_input = self._resolve_input(node_key, edges, context)

                # Execute node logic
                output = await self.execute_node(node_type, config, node_input)
                context[node_key] = output

            self._finalize_run(cursor, run_id, "success", context)
        except Exception as e:
            self._finalize_run(cursor, run_id, "failed", context, str(e))
            raise e
        finally:
            conn.commit()
            conn.close()

        return {"status": "success", "run_id": run_id, "output": context}

    def _init_run(self, cursor, flow_id, version_id, trigger_source):
        run_id = str(uuid.uuid4().hex)
        cursor.execute("""
            INSERT INTO flow_runs (id, flow_id, version_id, triggered_by, status, started_at)
            VALUES (?, ?, ?, ?, 'running', ?)
        """, (run_id, flow_id, version_id, trigger_source, datetime.utcnow().isoformat()))
        return run_id

    def _finalize_run(self, cursor, run_id, status, trace, error=None):
        cursor.execute("""
            UPDATE flow_runs
            SET status = ?, finished_at = ?, trace = ?, error = ?
            WHERE id = ?
        """, (status, datetime.utcnow().isoformat(), json.dumps(trace), error, run_id))

    def _resolve_input(self, node_key, edges, context):
        inputs = {}
        for edge in edges:
            if edge["to_node"] == node_key:
                from_node = edge["from_node"]
                if from_node in context:
                    inputs[edge.get("label") or from_node] = context[from_node]
        return inputs if inputs else context.get("trigger")

    async def execute_node(self, node_type: str, config: Dict[str, Any], input_data: Any):
        """Execute specific node logic."""
        if node_type == "trigger":  return input_data
        if node_type == "data":     return self._node_data(config, input_data)
        if node_type == "function": return self._node_function(config, input_data)
        if node_type == "db":       return self._node_db(config, input_data)
        if node_type == "storage":  return self._node_storage(config, input_data)
        if node_type == "cache":    return self._node_cache(config, input_data)
        if node_type == "output":   return self._node_output(config, input_data)
        if node_type == "notify":   return self._node_notify(config, input_data)
        return input_data

    def _node_data(self, config, data):
        return data

    def _node_function(self, config, data):
        # config['type'] == 'transform' | 'ai_call'
        return data

    def _node_db(self, config, data):
        return {"rows": []}

    def _node_storage(self, config, data):
        return {"url": "mock_url"}

    def _node_cache(self, config, data):
        return {"hit": False}

    def _node_output(self, config, data):
        return data

    def _node_notify(self, config, data):
        return {"status": "sent"}
