import json
from pathlib import Path
from typing import Any

from web3 import Web3
from web3.contract import Contract

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "out"

JOB_STATUS = {
    "None": 0,
    "Open": 1,
    "Accepted": 2,
    "Submitted": 3,
    "Completed": 4,
    "Failed": 5,
    "Cancelled": 6,
}


def load_abi(contract_name: str) -> list[dict[str, Any]]:
    path = OUT_DIR / f"{contract_name}.sol" / f"{contract_name}.json"
    if not path.exists():
        raise FileNotFoundError(f"ABI not found: {path}")
    with path.open() as f:
        artifact = json.load(f)
    return artifact["abi"]


def make_contract(w3: Web3, address: str, contract_name: str) -> Contract:
    return w3.eth.contract(
        address=Web3.to_checksum_address(address),
        abi=load_abi(contract_name),
    )


def keccak_text(w3: Web3, text: str) -> bytes:
    return w3.keccak(text=text)


def checksum_equal(a: str, b: str) -> bool:
    try:
        return Web3.to_checksum_address(a) == Web3.to_checksum_address(b)
    except Exception:
        return False