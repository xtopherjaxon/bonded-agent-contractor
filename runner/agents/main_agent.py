import time

from web3 import Web3

from runner.common.config import load_shared_config, load_role_pk, load_specialist_addresses
from runner.common.logging_utils import AgentLogger
from runner.common.chain import JOB_STATUS, checksum_equal, keccak_text, make_contract
from runner.common.jobs import job_tuple_to_dict, category_hex
from runner.common.tx import TxHelper

MAIN_SUBTASK_REWARD_WEI = Web3.to_wei(0.00001, "ether")
MAIN_LOOP_SLEEP_SECONDS = 10


class MainAgent:
    def __init__(self):
        self.role = "main"
        self.cfg = load_shared_config()
        self.logger = AgentLogger(self.role, self.cfg.log_api_url)

        self.w3 = Web3(Web3.HTTPProvider(self.cfg.rpc_url))
        if not self.w3.is_connected():
            raise RuntimeError(f"Could not connect to RPC: {self.cfg.rpc_url}")

        self.pk = load_role_pk("main")
        self.account = self.w3.eth.account.from_key(self.pk)
        self.address = self.account.address

        self.marketplace = make_contract(self.w3, self.cfg.job_marketplace_address, "JobMarketplace")
        self.directory = make_contract(self.w3, self.cfg.agent_directory_address, "AgentDirectory")
        self.policy = make_contract(self.w3, self.cfg.spending_policy_address, "SpendingPolicy")

        self.report_cat = keccak_text(self.w3, "eth_market_report")
        self.price_cat = keccak_text(self.w3, "price_data")
        self.volume_cat = keccak_text(self.w3, "volume_data")
        self.yield_cat = keccak_text(self.w3, "yield_data")

        keys = load_specialist_addresses()
        self.price_address = self.w3.eth.account.from_key(keys["price_pk"]).address
        self.volume_address = self.w3.eth.account.from_key(keys["volume_pk"]).address
        self.yield_address = self.w3.eth.account.from_key(keys["yield_pk"]).address

        self.tx = TxHelper(self.w3, self.pk, self.address, self.logger)
        self.policy_checked = False

    def all_jobs(self):
        next_job_id = self.marketplace.functions.nextJobId().call()
        jobs = []
        for job_id in range(1, next_job_id):
            raw = self.marketplace.functions.jobs(job_id).call()
            jobs.append(job_tuple_to_dict(raw))
        return jobs

    def child_jobs(self, parent_job_id: int):
        child_ids = self.marketplace.functions.getChildJobs(parent_job_id).call()
        return [job_tuple_to_dict(self.marketplace.functions.jobs(i).call()) for i in child_ids]

    def parent_jobs(self, jobs):
        return [job for job in jobs if not job["isSubtask"]]

    def open_report_jobs(self, jobs):
        now_ts = int(time.time())
        return [
            job
            for job in self.parent_jobs(jobs)
            if job["status"] == JOB_STATUS["Open"]
            and job["category"] == self.report_cat
            and int(job["deadline"]) > now_ts
        ]

    def accepted_main_jobs(self, jobs):
        return [
            job
            for job in self.parent_jobs(jobs)
            if job["status"] == JOB_STATUS["Accepted"]
            and checksum_equal(job["assignedAgent"], self.address)
        ]

    def ensure_policy(self):
        pol = self.policy.functions.policies(self.address).call()
        active = pol[5]
        if not active:
            self.tx.send(
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
            self.tx.send(
                "approve_marketplace_target",
                self.policy.functions.setApprovedTarget(
                    self.address,
                    self.marketplace.address,
                    True,
                ).build_transaction({"from": self.address}),
                {"agent": self.address},
            )

    def tick(self):
        self.logger.log("main_tick_start")

        jobs = self.all_jobs()
        open_report_jobs = self.open_report_jobs(jobs)
        accepted_main_jobs = self.accepted_main_jobs(jobs)

        self.logger.log(
            "main_tick_summary",
            {
                "total_jobs": len(jobs),
                "open_report_jobs": [job["id"] for job in open_report_jobs],
                "accepted_main_jobs": [job["id"] for job in accepted_main_jobs],
            },
        )

        for job in open_report_jobs:
            self.logger.log("attempt_accept_job", {"job_id": job["id"]})
            tx_hash = self.tx.send(
                "accept_job",
                self.marketplace.functions.acceptJob(job["id"]).build_transaction({"from": self.address, "value": 0}),
                {"job_id": job["id"]},
            )
            if tx_hash:
                return

        for job in accepted_main_jobs:
            children = self.child_jobs(job["id"])
            existing_categories = {c["category"] for c in children}
            subtask_specs = [
                (self.price_cat, "ipfs://price-task", self.price_address),
                (self.volume_cat, "ipfs://volume-task", self.volume_address),
                (self.yield_cat, "ipfs://yield-task", self.yield_address),
            ]

            self.logger.log(
                "parent_progress",
                {
                    "job_id": job["id"],
                    "child_ids": [c["id"] for c in children],
                    "child_statuses": [{"id": c["id"], "status": c["status"]} for c in children],
                },
            )

            for category, spec_uri, preferred in subtask_specs:
                if category in existing_categories:
                    continue

                now_ts = int(time.time())
                parent_deadline = int(job["deadline"])
                safe_deadline = min(now_ts + 12 * 3600, parent_deadline)

                if safe_deadline <= now_ts:
                    self.logger.log(
                        "skip_create_subtask_deadline",
                        {
                            "parent_job_id": job["id"],
                            "category_hex": Web3.to_hex(category),
                            "parent_deadline": parent_deadline,
                            "now": now_ts,
                        },
                    )
                    continue

                self.logger.log(
                    "attempt_create_subtask",
                    {
                        "parent_job_id": job["id"],
                        "category_hex": Web3.to_hex(category),
                        "preferred_agent": preferred,
                        "subtask_deadline": safe_deadline,
                        "reward_wei": str(MAIN_SUBTASK_REWARD_WEI),
                    },
                )

                tx_hash = self.tx.send(
                    "create_subtask",
                    self.marketplace.functions.createSubtask(
                        job["id"],
                        category,
                        spec_uri,
                        MAIN_SUBTASK_REWARD_WEI,
                        safe_deadline,
                        preferred,
                    ).build_transaction({"from": self.address, "value": MAIN_SUBTASK_REWARD_WEI}),
                    {
                        "parent_job_id": job["id"],
                        "category_hex": Web3.to_hex(category),
                        "preferred_agent": preferred,
                        "subtask_deadline": safe_deadline,
                    },
                )
                if tx_hash:
                    return

            for child in children:
                if child["status"] == JOB_STATUS["Submitted"]:
                    self.logger.log(
                        "attempt_mark_subtask_completed",
                        {
                            "subtask_job_id": child["id"],
                            "parent_job_id": job["id"],
                        },
                    )
                    tx_hash = self.tx.send(
                        "mark_subtask_completed",
                        self.marketplace.functions.markCompleted(child["id"]).build_transaction({"from": self.address}),
                        {"subtask_job_id": child["id"]},
                    )
                    if tx_hash:
                        return

            children = self.child_jobs(job["id"])
            if children and all(c["status"] == JOB_STATUS["Completed"] for c in children):
                self.logger.log("attempt_submit_parent_result", {"job_id": job["id"]})
                tx_hash = self.tx.send(
                    "submit_parent_result",
                    self.marketplace.functions.submitResult(job["id"], "ipfs://final-report").build_transaction({"from": self.address}),
                    {"job_id": job["id"]},
                )
                if tx_hash:
                    return

        self.logger.log("main_tick_complete")

    def run(self):
        self.logger.log("agent_started", {
            "role": self.role,
            "address": self.address,
            "rpc_connected": self.w3.is_connected(),
        })

        while True:
            try:
                if not self.policy_checked:
                    self.ensure_policy()
                    self.logger.log("main_policy_checked")
                    self.policy_checked = True

                self.tick()
            except Exception as e:
                self.logger.log_exception("main_agent_error", e)

            time.sleep(MAIN_LOOP_SLEEP_SECONDS)


if __name__ == "__main__":
    MainAgent().run()