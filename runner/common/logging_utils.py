import json
import time
import traceback
import urllib.request
from typing import Any


class AgentLogger:
    def __init__(self, role: str, log_api_url: str | None):
        self.role = role
        self.log_api_url = log_api_url
        self.step = 0

    def log(self, action: str, details: dict[str, Any] | None = None, tx_hash: str | None = None) -> None:
        self.step += 1
        payload = {
            "role": self.role,
            "action": action,
            "details": details or {},
            "tx_hash": tx_hash,
            "step": self.step,
            "timestamp": int(time.time() * 1000),
        }
        print(json.dumps(payload, default=str), flush=True)

        if not self.log_api_url:
            return

        try:
            req = urllib.request.Request(
                self.log_api_url,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=5):
                pass
        except Exception as e:
            print(json.dumps({
                "role": self.role,
                "action": "log_api_error",
                "details": {"message": str(e)},
                "step": self.step,
                "timestamp": int(time.time() * 1000),
            }), flush=True)

    def log_exception(self, action: str, e: Exception) -> None:
        traceback.print_exc()
        self.log(action, {"message": str(e), "error_type": type(e).__name__})