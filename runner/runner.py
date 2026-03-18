import argparse
import sys
import time

from runner.agents.main_agent import MainAgent
from runner.agents.price_agent import PriceAgent
from runner.agents.volume_agent import VolumeAgent
from runner.agents.yield_agent import YieldAgent


AGENT_MAP = {
    "main": MainAgent,
    "price": PriceAgent,
    "volume": VolumeAgent,
    "yield": YieldAgent,
}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Bonded agent runner")
    parser.add_argument(
        "--role",
        required=True,
        choices=["main", "price", "volume", "yield", "all"],
        help="Which agent role to run",
    )
    parser.add_argument(
        "--poll-seconds",
        type=float,
        default=10,
        help="Seconds to sleep between ticks",
    )
    return parser


def run_single(role: str, poll_seconds: float) -> int:
    agent = AGENT_MAP[role]()
    print(f"[runner] starting role={role} address={agent.address}", flush=True)

    while True:
        try:
            print(f"[runner] tick start role={role}", flush=True)
            agent.tick()
            print(f"[runner] tick complete role={role}", flush=True)
        except KeyboardInterrupt:
            print(f"[runner] stopping role={role}", flush=True)
            return 0
        except Exception as exc:
            print(f"[runner] tick error role={role}: {exc}", file=sys.stderr, flush=True)

        time.sleep(poll_seconds)


def run_all(poll_seconds: float) -> int:
    agents = {role: cls() for role, cls in AGENT_MAP.items()}
    addresses = {role: agent.address for role, agent in agents.items()}
    print(f"[runner] starting all roles addresses={addresses}", flush=True)

    while True:
        for role, agent in agents.items():
            try:
                print(f"[runner] tick start role={role}", flush=True)
                agent.tick()
                print(f"[runner] tick complete role={role}", flush=True)
            except KeyboardInterrupt:
                print("[runner] stopping all roles", flush=True)
                return 0
            except Exception as exc:
                print(f"[runner] tick error role={role}: {exc}", file=sys.stderr, flush=True)

        time.sleep(poll_seconds)


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if args.role == "all":
        return run_all(args.poll_seconds)

    return run_single(args.role, args.poll_seconds)


if __name__ == "__main__":
    raise SystemExit(main())