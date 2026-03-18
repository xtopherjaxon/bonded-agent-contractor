import os
from dataclasses import dataclass
from pathlib import Path
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / "runner" / ".env")


def require_env(key: str) -> str:
    value = os.environ.get(key)
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
        log_api_url=os.environ.get("LOG_API_URL"),
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
        "main_pk": require_env("MAIN_AGENT_PK"),
        "price_pk": require_env("PRICE_AGENT_PK"),
        "volume_pk": require_env("VOLUME_AGENT_PK"),
        "yield_pk": require_env("YIELD_AGENT_PK"),
    }