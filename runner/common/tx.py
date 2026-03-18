from typing import Any

from web3 import Web3

KNOWN_RACE_MARKERS = [
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


class TxHelper:
    def __init__(self, w3: Web3, private_key: str, address: str, logger):
        self.w3 = w3
        self.private_key = private_key
        self.address = address
        self.logger = logger

    def send(self, action: str, tx: dict[str, Any], details: dict[str, Any]) -> str | None:
        try:
            tx_hash = self._build_and_send(tx)
            self.logger.log(action, details, tx_hash)
            return tx_hash
        except Exception as e:
            message = str(e)
            if any(marker in message for marker in KNOWN_RACE_MARKERS):
                self.logger.log(f"{action}_skipped", {**details, "reason": message})
                return None
            raise

    def _build_and_send(self, tx: dict[str, Any]) -> str:
        nonce = self.w3.eth.get_transaction_count(self.address, "pending")
        latest_block = self.w3.eth.get_block("latest")
        base_fee = latest_block.get("baseFeePerGas", self.w3.eth.gas_price)
        priority_fee = self.w3.to_wei(1, "gwei")
        max_fee = base_fee * 2 + priority_fee

        tx.setdefault("from", self.address)
        tx.setdefault("nonce", nonce)
        tx.setdefault("chainId", self.w3.eth.chain_id)

        tx.pop("gasPrice", None)
        tx.setdefault("maxPriorityFeePerGas", priority_fee)
        tx.setdefault("maxFeePerGas", max_fee)

        try:
            gas_estimate = self.w3.eth.estimate_gas(tx)
            tx["gas"] = int(gas_estimate * 1.2)
        except Exception:
            tx["gas"] = 1_500_000

        signed = self.w3.eth.account.sign_transaction(tx, private_key=self.private_key)
        tx_hash = self.w3.eth.send_raw_transaction(signed.rawTransaction)
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
        return receipt.transactionHash.hex()