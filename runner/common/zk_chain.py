

from __future__ import annotations

from typing import Any

from web3 import Web3


def _require(value: Any, message: str):
    if value is None:
        raise RuntimeError(message)
    return value


def submit_zk_report(
    w3: Web3,
    account,
    verifier_address: str,
    verifier_abi: list[dict[str, Any]],
    job_id: int,
    report_hash: str,
    proof: bytes | None,
):
    """
    Submit zk report to on-chain verifier.

    V1: proof is optional (contract does not validate yet).
    """

    contract = w3.eth.contract(
        address=Web3.to_checksum_address(verifier_address),
        abi=verifier_abi,
    )

    tx = contract.functions.submitZKReport(
        int(job_id),
        report_hash,
        proof or b"",
    ).build_transaction(
        {
            "from": account.address,
            "nonce": w3.eth.get_transaction_count(account.address),
        }
    )

    signed = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)

    return tx_hash.hex()


def is_job_verified(
    w3: Web3,
    verifier_address: str,
    verifier_abi: list[dict[str, Any]],
    job_id: int,
) -> bool:
    contract = w3.eth.contract(
        address=Web3.to_checksum_address(verifier_address),
        abi=verifier_abi,
    )

    return contract.functions.isVerified(int(job_id)).call()


def get_verified_report_hash(
    w3: Web3,
    verifier_address: str,
    verifier_abi: list[dict[str, Any]],
    job_id: int,
) -> str:
    contract = w3.eth.contract(
        address=Web3.to_checksum_address(verifier_address),
        abi=verifier_abi,
    )

    value = contract.functions.getVerifiedReportHash(int(job_id)).call()
    return Web3.to_hex(value)