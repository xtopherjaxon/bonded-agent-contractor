import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
ENV_CANDIDATES = [
    ROOT / "runner" / ".env",
    ROOT / ".env",
]

for env_path in ENV_CANDIDATES:
    if env_path.exists():
        load_dotenv(env_path, override=True)


def require_env(key: str) -> str:
    value = os.environ.get(key)
    if value is None:
        raise RuntimeError(f"Missing required environment variable: {key}")

    value = value.strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {key}")

    return value


@dataclass(frozen=True)
class SharedConfig:
    rpc_url: str
    job_marketplace_address: str
    agent_directory_address: str
    spending_policy_address: str
    escrow_bond_address: str
    log_api_url: str | None


def load_shared_config() -> SharedConfig:
    return SharedConfig(
        rpc_url=require_env("RPC_URL"),
        job_marketplace_address=require_env("JOB_MARKETPLACE_ADDRESS"),
        agent_directory_address=require_env("AGENT_DIRECTORY_ADDRESS"),
        spending_policy_address=require_env("SPENDING_POLICY_ADDRESS"),
        escrow_bond_address=require_env("ESCROW_BOND_ADDRESS"),
        log_api_url=(os.environ.get("LOG_API_URL") or "").strip() or None,
    )


def load_role_pk(role: str) -> str:
    mapping = {
        "main": "MAIN_AGENT_PK",
        "price": "PRICE_AGENT_PK",
        "volume": "VOLUME_AGENT_PK",
        "yield": "YIELD_AGENT_PK",
    }
    if role not in mapping:
        raise RuntimeError(f"Unsupported role: {role}")
    return require_env(mapping[role])


def load_specialist_addresses() -> dict[str, str]:
    return {
        "main": require_env("MAIN_AGENT_ADDRESS"),
        "price": require_env("PRICE_AGENT_ADDRESS"),
        "volume": require_env("VOLUME_AGENT_ADDRESS"),
        "yield": require_env("YIELD_AGENT_ADDRESS"),
        "main_pk": require_env("MAIN_AGENT_PK"),
        "price_pk": require_env("PRICE_AGENT_PK"),
        "volume_pk": require_env("VOLUME_AGENT_PK"),
        "yield_pk": require_env("YIELD_AGENT_PK"),
    }


def debug_config_snapshot() -> dict[str, str | None]:
    return {
        "rpc_url": (os.environ.get("RPC_URL") or "").strip() or None,
        "job_marketplace_address": (os.environ.get("JOB_MARKETPLACE_ADDRESS") or "").strip() or None,
        "agent_directory_address": (os.environ.get("AGENT_DIRECTORY_ADDRESS") or "").strip() or None,
        "spending_policy_address": (os.environ.get("SPENDING_POLICY_ADDRESS") or "").strip() or None,
        "escrow_bond_address": (os.environ.get("ESCROW_BOND_ADDRESS") or "").strip() or None,
        "log_api_url": (os.environ.get("LOG_API_URL") or "").strip() or None,
        "main_agent_address": (os.environ.get("MAIN_AGENT_ADDRESS") or "").strip() or None,
        "price_agent_address": (os.environ.get("PRICE_AGENT_ADDRESS") or "").strip() or None,
        "volume_agent_address": (os.environ.get("VOLUME_AGENT_ADDRESS") or "").strip() or None,
        "yield_agent_address": (os.environ.get("YIELD_AGENT_ADDRESS") or "").strip() or None,
        "has_main_agent_pk": bool((os.environ.get("MAIN_AGENT_PK") or "").strip()),
        "has_price_agent_pk": bool((os.environ.get("PRICE_AGENT_PK") or "").strip()),
        "has_volume_agent_pk": bool((os.environ.get("VOLUME_AGENT_PK") or "").strip()),
        "has_yield_agent_pk": bool((os.environ.get("YIELD_AGENT_PK") or "").strip()),
    }