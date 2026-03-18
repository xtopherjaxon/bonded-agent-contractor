from __future__ import annotations

from eth_abi import encode
from eth_utils import keccak, to_checksum_address


def _normalize_address(address: str) -> str:
    return to_checksum_address(address)


def _normalize_bytes32(value: str) -> bytes:
    hex_value = value[2:] if value.startswith("0x") else value
    if len(hex_value) != 64:
        raise ValueError(f"Expected 32-byte hex value, got length {len(hex_value)}: {value}")
    return bytes.fromhex(hex_value)


def _keccak_hex(encoded: bytes) -> str:
    return "0x" + keccak(encoded).hex()


def hash_specialist_result(
    subtask_job_id: int,
    specialist_agent_address: str,
    result_uri: str,
) -> str:
    encoded = encode(
        ["uint256", "address", "string"],
        [
            int(subtask_job_id),
            _normalize_address(specialist_agent_address),
            str(result_uri),
        ],
    )
    return _keccak_hex(encoded)


def hash_parent_report(
    parent_job_id: int,
    price_subtask_job_id: int,
    volume_subtask_job_id: int,
    yield_subtask_job_id: int,
    price_result_hash: str,
    volume_result_hash: str,
    yield_result_hash: str,
    main_agent_address: str,
) -> str:
    encoded = encode(
        [
            "uint256",
            "uint256",
            "uint256",
            "uint256",
            "bytes32",
            "bytes32",
            "bytes32",
            "address",
        ],
        [
            int(parent_job_id),
            int(price_subtask_job_id),
            int(volume_subtask_job_id),
            int(yield_subtask_job_id),
            _normalize_bytes32(price_result_hash),
            _normalize_bytes32(volume_result_hash),
            _normalize_bytes32(yield_result_hash),
            _normalize_address(main_agent_address),
        ],
    )
    return _keccak_hex(encoded)
