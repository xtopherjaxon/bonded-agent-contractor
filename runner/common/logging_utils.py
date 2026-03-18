import json
import time
import traceback
import urllib.request
from typing import Any

IMPORTANT_ACTIONS = {
    "main_tick_start",
    "main_tick_summary",
    "parent_progress",
    "attempt_create_subtask",
    "create_subtask",
    "attempt_accept_specialist_subtask",
    "accept_subtask_and_post_bond",
    "attempt_submit_specialist_result",
    "submit_result",
    "attempt_mark_subtask_completed",
    "mark_subtask_completed",
    "attempt_submit_parent_result",
    "submit_parent_result",
}


class AgentLogger:
    def __init__(self, role: str, log_api_url: str | None):
        self.role = role
        self.log_api_url = log_api_url
        self.step = 0
        self.verbose = False  # set True if you want full logs

    def log(self, action: str, details: dict[str, Any] | None = None, tx_hash: str | None = None) -> None:
        self.step += 1
        if not self.verbose and action not in IMPORTANT_ACTIONS:
            return
        payload = {
            "role": self.role,
            "action": action,
            "details": details or {},
            "tx_hash": tx_hash,
            "step": self.step,
            "timestamp": int(time.time() * 1000),
        }
        print(json.dumps(payload, default=str), flush=True)

        # skip external logging if not configured or pointing to localhost
        if (
            not self.log_api_url
            or "localhost" in self.log_api_url
            or "127.0.0.1" in self.log_api_url
        ):
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
            # suppress common auth/protection errors (e.g., 401/403 from Vercel)
            if hasattr(e, "code") and e.code in (401, 403):
                return

            # only print unexpected errors when verbose
            if self.verbose:
                print(f"[{self.role}] log_api_error: {e}", flush=True)

    def log_exception(self, action: str, e: Exception) -> None:
        traceback.print_exc()
        self.log(action, {"message": str(e), "error_type": type(e).__name__})