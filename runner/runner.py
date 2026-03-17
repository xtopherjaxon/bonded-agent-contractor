import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

import urllib.request

from dotenv import load_dotenv
from web3 import Web3
from web3.contract import Contract


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "out"
AGENTS_DIR = ROOT / "agents"

JOB_STATUS = {
    "None": 0,
    "Open": 1,
    "Accepted": 2,
    "Submitted": 3,
    "Completed": 4,
    "Failed": 5,
    "Cancelled": 6,
}


def load_abi(contract_name: str) -> List[Dict[str, Any]]:
    path = OUT_DIR / f"{contract_name}.sol" / f"{contract_name}.json"
    if not path.exists():
        raise FileNotFoundError(f"ABI not found: {path}")
    with path.open() as f:
        artifact = json.load(f)
    return artifact["abi"]


def ensure_dir(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def keccak_text(w3: Web3, text: str) -> bytes:
    return w3.keccak(text=text)


class Runner:
    def __init__(self, role: str, once: bool = False, poll_seconds: int = 5) -> None:
        load_dotenv(ROOT / "runner" / ".env")

        self.role = role
        self.once = once
        self.poll_seconds = poll_seconds

        rpc_url = os.environ["RPC_URL"]
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))

        if not self.w3.is_connected():
            raise RuntimeError(f"Could not connect to RPC: {rpc_url}")

        self.marketplace = self._contract(
            os.environ["JOB_MARKETPLACE_ADDRESS"],
            load_abi("JobMarketplace"),
        )
        self.directory = self._contract(
            os.environ["AGENT_DIRECTORY_ADDRESS"],
            load_abi("AgentDirectory"),
        )
        self.policy = self._contract(
            os.environ["SPENDING_POLICY_ADDRESS"],
            load_abi("SpendingPolicy"),
        )

        self.report_cat = keccak_text(self.w3, "eth_market_report")
        self.price_cat = keccak_text(self.w3, "price_data")
        self.volume_cat = keccak_text(self.w3, "volume_data")
        self.yield_cat = keccak_text(self.w3, "yield_data")

        self.pk = self._private_key_for_role(role)
        self.account = self.w3.eth.account.from_key(self.pk)
        self.address = self.account.address

        self.log_path = self._log_path_for_role(role)

        # preferred specialist addresses from env private keys
        self.main_address = self.w3.eth.account.from_key(os.environ["MAIN_AGENT_PK"]).address
        self.price_address = self.w3.eth.account.from_key(os.environ["PRICE_AGENT_PK"]).address
        self.volume_address = self.w3.eth.account.from_key(os.environ["VOLUME_AGENT_PK"]).address
        self.yield_address = self.w3.eth.account.from_key(os.environ["YIELD_AGENT_PK"]).address

    def _private_key_for_role(self, role: str) -> str:
        mapping = {
            "main": os.environ["MAIN_AGENT_PK"],
            "price": os.environ["PRICE_AGENT_PK"],
            "volume": os.environ["VOLUME_AGENT_PK"],
            "yield": os.environ["YIELD_AGENT_PK"],
        }
        if role not in mapping:
            raise ValueError(f"Unknown role: {role}")
        return mapping[role]

    def _log_path_for_role(self, role: str) -> Path:
        mapping = {
            "main": AGENTS_DIR / "main_agent" / "agent_log.json",
            "price": AGENTS_DIR / "price_scout" / "agent_log.json",
            "volume": AGENTS_DIR / "volume_scout" / "agent_log.json",
            "yield": AGENTS_DIR / "yield_scout" / "agent_log.json",
        }
        return mapping[role]

    def _contract(self, address: str, abi: List[Dict[str, Any]]) -> Contract:
        return self.w3.eth.contract(address=Web3.to_checksum_address(address), abi=abi)

    def _build_and_send(self, tx: Dict[str, Any]) -> str:
        nonce = self.w3.eth.get_transaction_count(self.address)
        latest_block = self.w3.eth.get_block("latest")
        base_fee = latest_block.get("baseFeePerGas", self.w3.eth.gas_price)
        priority_fee = self.w3.to_wei(1, "gwei")
        max_fee = base_fee * 2 + priority_fee

        tx.setdefault("from", self.address)
        tx.setdefault("nonce", nonce)
        tx.setdefault("chainId", self.w3.eth.chain_id)

        # EIP-1559 fee fields
        tx.pop("gasPrice", None)
        tx.setdefault("maxPriorityFeePerGas", priority_fee)
        tx.setdefault("maxFeePerGas", max_fee)

        try:
            gas_estimate = self.w3.eth.estimate_gas(tx)
            tx["gas"] = int(gas_estimate * 1.2)
        except Exception:
            tx["gas"] = 1_500_000

        signed = self.w3.eth.account.sign_transaction(tx, private_key=self.pk)
        tx_hash = self.w3.eth.send_raw_transaction(signed.rawTransaction)
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
        return receipt.transactionHash.hex()
    
    def _safe_send(self, action: str, tx: Dict[str, Any], details: Dict[str, Any]) -> Optional[str]:
        try:
            tx_hash = self._build_and_send(tx)
            self._write_log({
                "action": action,
                "details": details,
                "tx_hash": tx_hash,
            })
            return tx_hash
        except Exception as e:
            message = str(e)

            known_race_markers = [
                "job not open",
                "job not accepted",
                "job not submitted",
                "not preferred agent",
                "not assigned agent",
                "execution reverted",
                "replacement transaction underpriced",
                "nonce too low",
                "already known",
            ]

            if any(marker in message for marker in known_race_markers):
                self._write_log({
                    "action": f"{action}_skipped",
                    "details": {**details, "reason": message},
                })
                return None

            raise

    
    def _write_log(self, entry: Dict[str, Any]) -> None:
        ensure_dir(self.log_path)
        if self.log_path.exists():
            with self.log_path.open() as f:
                data = json.load(f)
        else:
            data = {
                "run_id": f"run-{self.role}-live",
                "agent_name": self.role,
                "status": "running",
                "steps": [],
                "tx_hashes": [],
            }

        if "steps" not in data:
            data["steps"] = []
        if "tx_hashes" not in data:
            data["tx_hashes"] = []

        step = len(data["steps"]) + 1
        entry["step"] = step
        data["steps"].append(entry)

        tx_hash = entry.get("tx_hash")
        if tx_hash:
            data["tx_hashes"].append(tx_hash)

        print(f"[{self.role}] step={entry['step']} action={entry['action']} details={entry.get('details', {})}")

        with self.log_path.open("w") as f:
            json.dump(data, f, indent=2)

        # send log entry to hosted dashboard API if configured
        log_api_url = os.environ.get("LOG_API_URL")
        if log_api_url:
            try:
                payload = {
                    "role": self.role,
                    "action": entry.get("action"),
                    "details": entry.get("details", {}),
                    "tx_hash": entry.get("tx_hash"),
                    "step": entry.get("step"),
                    "timestamp": int(time.time() * 1000),
                }

                req = urllib.request.Request(
                    log_api_url,
                    data=json.dumps(payload).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                with urllib.request.urlopen(req, timeout=5) as _:
                    pass
            except Exception as e:
                print(f"[{self.role}] log_api_error={e}")



    def _job_tuple_to_dict(self, raw: Any) -> Dict[str, Any]:
        return {
            "id": raw[0],
            "parentJobId": raw[1],
            "creator": raw[2],
            "assignedAgent": raw[3],
            "preferredAgent": raw[4],
            "category": raw[5],
            "specURI": raw[6],
            "resultURI": raw[7],
            "rewardWei": raw[8],
            "bondWeiRequired": raw[9],
            "deadline": raw[10],
            "status": raw[11],
            "isSubtask": raw[12],
        }

    def _all_jobs(self) -> List[Dict[str, Any]]:
        next_job_id = self.marketplace.functions.nextJobId().call()
        jobs = []
        for job_id in range(1, next_job_id):
            raw = self.marketplace.functions.jobs(job_id).call()
            jobs.append(self._job_tuple_to_dict(raw))
        return jobs

    def _child_jobs(self, parent_job_id: int) -> List[Dict[str, Any]]:
        child_ids = self.marketplace.functions.getChildJobs(parent_job_id).call()
        return [self._job_tuple_to_dict(self.marketplace.functions.jobs(i).call()) for i in child_ids]

    def _ensure_main_policy(self) -> None:
        if self.role != "main":
            return

        pol = self.policy.functions.policies(self.address).call()
        active = pol[5]
        if not active:
            self._safe_send(
                "set_policy",
                self.policy.functions.setPolicy(
                    self.address,
                    Web3.to_wei(1, "ether"),
                    Web3.to_wei(20, "ether"),
                    int(time.time()) - 10,
                    int(time.time()) + 86400,
                ).build_transaction({"from": self.address}),
                {"agent": self.address},
            )

        approved = self.policy.functions.approvedTargets(
            self.address,
            self.marketplace.address,
        ).call()

        if not approved:
            self._safe_send(
                "approve_marketplace_target",
                self.policy.functions.setApprovedTarget(
                    self.address,
                    self.marketplace.address,
                    True,
                ).build_transaction({"from": self.address}),
                {"agent": self.address},
            )

    def run_forever(self) -> None:
        while True:
            try:
                if self.role == "main":
                    self._ensure_main_policy()
                    self._tick_main()
                elif self.role == "price":
                    self._tick_specialist(self.price_cat, "price")
                elif self.role == "volume":
                    self._tick_specialist(self.volume_cat, "volume")
                elif self.role == "yield":
                    self._tick_specialist(self.yield_cat, "yield")
                else:
                    raise ValueError(f"Unsupported role: {self.role}")
            except Exception as e:
                self._write_log({
                    "action": "error",
                    "details": {"message": str(e)},
                })

            if self.once:
                break

            time.sleep(self.poll_seconds)

    def _tick_main(self) -> None:
        jobs = self._all_jobs()

        # 1) accept matching open top-level jobs
        for job in jobs:
            if (
                not job["isSubtask"]
                and job["status"] == JOB_STATUS["Open"]
                and job["category"] == self.report_cat
            ):
                tx_hash = self._safe_send(
                    "accept_job",
                    self.marketplace.functions.acceptJob(job["id"]).build_transaction(
                        {"from": self.address, "value": 0}
                    ),
                    {"job_id": job["id"]},
                )
                if tx_hash:
                    return

        # 2) for accepted top-level jobs owned by main agent, create missing subtasks
        for job in jobs:
            if (
                not job["isSubtask"]
                and job["status"] == JOB_STATUS["Accepted"]
                and Web3.to_checksum_address(job["assignedAgent"]) == self.address
            ):
                children = self._child_jobs(job["id"])
                existing_categories = {c["category"] for c in children}

                subtask_specs = [
                    (self.price_cat, "ipfs://price-task", self.price_address),
                    (self.volume_cat, "ipfs://volume-task", self.volume_address),
                    (self.yield_cat, "ipfs://yield-task", self.yield_address),
                ]

                for category, spec_uri, preferred in subtask_specs:
                    if category in existing_categories:
                        continue

                    now_ts = int(time.time())
                    parent_deadline = int(job["deadline"])
                    proposed_subtask_deadline = now_ts + 12 * 3600
                    safe_subtask_deadline = min(proposed_subtask_deadline, parent_deadline)

                    if safe_subtask_deadline <= now_ts:
                        self._write_log({
                            "action": "create_subtask_skipped",
                            "details": {
                                "parent_job_id": job["id"],
                                "category_hex": category.hex(),
                                "preferred_agent": preferred,
                                "reason": "parent deadline too close or already expired",
                                "parent_deadline": parent_deadline,
                                "now": now_ts,
                            },
                        })
                        return

                    tx_hash = self._safe_send(
                        "create_subtask",
                        self.marketplace.functions.createSubtask(
                            job["id"],
                            category,
                            spec_uri,
                            Web3.to_wei(0.00001, "ether"),
                            safe_subtask_deadline,
                            preferred,
                        ).build_transaction(
                            {"from": self.address, "value": Web3.to_wei(0.00001, "ether")}
                        ),
                        {
                            "parent_job_id": job["id"],
                            "category_hex": category.hex(),
                            "preferred_agent": preferred,
                            "subtask_deadline": safe_subtask_deadline,
                        },
                    )
                    if tx_hash:
                        return

                # 3) complete any submitted subtasks
                for child in children:
                    if child["status"] == JOB_STATUS["Submitted"]:
                        tx_hash = self._safe_send(
                            "mark_subtask_completed",
                            self.marketplace.functions.markCompleted(child["id"]).build_transaction(
                                {"from": self.address}
                            ),
                            {"subtask_job_id": child["id"]},
                        )
                        if tx_hash:
                            return

                # 4) if all subtasks completed, submit final report
                children = self._child_jobs(job["id"])
                if children and all(c["status"] == JOB_STATUS["Completed"] for c in children):
                    tx_hash = self._safe_send(
                        "submit_parent_result",
                        self.marketplace.functions.submitResult(
                            job["id"],
                            "ipfs://final-report",
                        ).build_transaction({"from": self.address}),
                        {"job_id": job["id"]},
                    )
                    if tx_hash:
                        return

    def _tick_specialist(self, category: bytes, label: str) -> None:
        jobs = self._all_jobs()

        # 1) accept open preferred subtasks
        for job in jobs:
            if (
                job["isSubtask"]
                and job["status"] == JOB_STATUS["Open"]
                and job["category"] == category
                and Web3.to_checksum_address(job["preferredAgent"]) == self.address
            ):
                bond_bps = self.directory.functions.getBondBps(self.address).call()
                bond_wei = (job["rewardWei"] * bond_bps) // 10_000

                tx_hash = self._safe_send(
                    "accept_subtask_and_post_bond",
                    self.marketplace.functions.acceptJob(job["id"]).build_transaction(
                        {"from": self.address, "value": bond_wei}
                    ),
                    {
                        "job_id": job["id"],
                        "bond_wei": str(bond_wei),
                        "category": label,
                    },
                )
                if tx_hash:
                    return

        # 2) submit results for accepted subtasks owned by this specialist
        for job in jobs:
            if (
                job["isSubtask"]
                and job["status"] == JOB_STATUS["Accepted"]
                and Web3.to_checksum_address(job["assignedAgent"]) == self.address
            ):
                result_uri = f"ipfs://{label}-result"
                tx_hash = self._safe_send(
                    "submit_result",
                    self.marketplace.functions.submitResult(
                        job["id"],
                        result_uri,
                    ).build_transaction({"from": self.address}),
                    {
                        "job_id": job["id"],
                        "result_uri": result_uri,
                        "category": label,
                    },
                )
                if tx_hash:
                    return


def main() -> None:
    import argparse
    import traceback
    import time

    parser = argparse.ArgumentParser()
    parser.add_argument("--role", required=True, choices=["main", "price", "volume", "yield"])
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--poll-seconds", type=int, default=10)
    args = parser.parse_args()

    while True:
        try:
            runner = Runner(role=args.role, once=args.once, poll_seconds=args.poll_seconds)
            runner.run_forever()
            if args.once:
                break
        except KeyboardInterrupt:
            raise
        except Exception as e:
            print(f"[{args.role}] fatal_runner_error={e}")
            traceback.print_exc()
            if args.once:
                raise
            time.sleep(10)