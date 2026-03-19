

import time
from web3 import Web3

from runner.common.config import load_shared_config, load_role_pk
from runner.common.logging_utils import AgentLogger
from runner.common.chain import JOB_STATUS, checksum_equal, keccak_text, make_contract
from runner.common.jobs import job_tuple_to_dict, category_hex
from runner.common.tx import TxHelper


class YieldAgent:
    def __init__(self):
        self.role = "yield"
        self.cfg = load_shared_config()
        self.logger = AgentLogger(self.role, self.cfg.log_api_url)

        self.w3 = Web3(Web3.HTTPProvider(self.cfg.rpc_url))
        if not self.w3.is_connected():
            raise RuntimeError(f"Could not connect to RPC: {self.cfg.rpc_url}")

        self.pk = load_role_pk("yield")
        self.account = self.w3.eth.account.from_key(self.pk)
        self.address = self.account.address

        self.marketplace = make_contract(self.w3, self.cfg.job_marketplace_address, "JobMarketplace")
        self.directory = make_contract(self.w3, self.cfg.agent_directory_address, "AgentDirectory")

        self.category = keccak_text(self.w3, "yield_data")
        self.tx = TxHelper(self.w3, self.pk, self.address, self.logger)

    def all_jobs(self):
        next_job_id = self.marketplace.functions.nextJobId().call()
        jobs = []
        for job_id in range(1, next_job_id):
            raw = self.marketplace.functions.jobs(job_id).call()
            jobs.append(job_tuple_to_dict(raw))
        return jobs

    def tick(self):
        jobs = self.all_jobs()
        self.logger.log("specialist_scan_jobs", {
            "role": self.role,
            "category": "yield",
            "count": len(jobs),
        })

        for job in jobs:
            self.logger.log("inspect_specialist_job", {
                "job_id": job["id"],
                "status": job["status"],
                "is_subtask": job["isSubtask"],
                "preferred_agent": job["preferredAgent"],
                "assigned_agent": job["assignedAgent"],
                "category_hex": category_hex(job["category"]),
                "category": "yield",
            })

            if not job["isSubtask"]:
                continue
            if job["status"] != JOB_STATUS["Open"]:
                continue
            if job["category"] != self.category:
                continue
            if not checksum_equal(job["preferredAgent"], self.address):
                continue

            bond_bps = self.directory.functions.getBondBps(self.address).call()
            bond_wei = (job["rewardWei"] * bond_bps) // 10_000

            self.logger.log("attempt_accept_specialist_subtask", {
                "job_id": job["id"],
                "category": "yield",
                "bond_wei": str(bond_wei),
            })
            tx_hash = self.tx.send(
                "accept_subtask_and_post_bond",
                self.marketplace.functions.acceptJob(job["id"]).build_transaction({"from": self.address, "value": bond_wei}),
                {"job_id": job["id"], "bond_wei": str(bond_wei), "category": "yield"},
            )
            if tx_hash:
                return

        for job in jobs:
            if not job["isSubtask"]:
                continue
            if job["status"] != JOB_STATUS["Accepted"]:
                continue
            if not checksum_equal(job["assignedAgent"], self.address):
                continue

            result_uri = "ipfs://yield-result"
            self.logger.log("attempt_submit_specialist_result", {
                "job_id": job["id"],
                "category": "yield",
                "result_uri": result_uri,
            })
            tx_hash = self.tx.send(
                "submit_result",
                self.marketplace.functions.submitResult(job["id"], result_uri).build_transaction({"from": self.address}),
                {"job_id": job["id"], "result_uri": result_uri, "category": "yield"},
            )
            if tx_hash:
                return

    def run(self):
        self.logger.log("agent_started", {
            "role": self.role,
            "address": self.address,
            "rpc_connected": self.w3.is_connected(),
        })

        while True:
            try:
                self.tick()
            except Exception as e:
                self.logger.log_exception("yield_agent_error", e)
            time.sleep(10)


if __name__ == "__main__":
    YieldAgent().run()