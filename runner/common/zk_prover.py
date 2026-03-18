from __future__ import annotations

from typing import Any

from runner.common.zk import (
    hash_specialist_result,
    hash_parent_report,
)
from runner.common.jobs import (
    get_child_jobs,
    get_job_result_uri,
    get_assigned_agent,
    is_completed,
)


class ZKProverInputError(Exception):
    pass


def _require(value: Any, message: str):
    if value is None:
        raise ZKProverInputError(message)
    return value


def build_parent_report_input(
    parent_job: dict[str, Any],
    all_jobs: list[dict[str, Any]],
    main_agent_address: str,
) -> dict[str, Any]:
    parent_job_id = parent_job.get("jobId")
    _require(parent_job_id, "Missing parent job id")

    children = get_child_jobs(all_jobs, parent_job_id)

    if len(children) < 3:
        raise ZKProverInputError(f"Expected 3 subtasks, found {len(children)}")

    # Only completed subtasks are valid inputs
    completed_children = [c for c in children if is_completed(c)]

    if len(completed_children) < 3:
        raise ZKProverInputError("Not all subtasks are completed yet")

    # Deterministic ordering by job id
    completed_children.sort(key=lambda j: int(j.get("jobId", 0)))

    # Assign by order (price, volume, yield)
    price_job, volume_job, yield_job = completed_children[:3]

    def _extract(job: dict[str, Any]):
        job_id = int(_require(job.get("jobId"), "Missing subtask job id"))
        agent = get_assigned_agent(job)
        result_uri = _require(get_job_result_uri(job), "Missing result URI")

        result_hash = hash_specialist_result(
            subtask_job_id=job_id,
            specialist_agent_address=agent,
            result_uri=result_uri,
        )

        return {
            "job_id": job_id,
            "agent": agent,
            "result_uri": result_uri,
            "result_hash": result_hash,
        }

    price = _extract(price_job)
    volume = _extract(volume_job)
    yield_ = _extract(yield_job)

    parent_report_hash = hash_parent_report(
        parent_job_id=int(parent_job_id),
        price_subtask_job_id=price["job_id"],
        volume_subtask_job_id=volume["job_id"],
        yield_subtask_job_id=yield_["job_id"],
        price_result_hash=price["result_hash"],
        volume_result_hash=volume["result_hash"],
        yield_result_hash=yield_["result_hash"],
        main_agent_address=main_agent_address,
    )

    return {
        "parent_job_id": int(parent_job_id),
        "main_agent": main_agent_address,
        "price": price,
        "volume": volume,
        "yield": yield_,
        "parent_report_hash": parent_report_hash,
    }


def generate_parent_report_proof(input_data: dict[str, Any]) -> dict[str, Any]:
    """
    Placeholder for zk proof generation.

    For now, returns a stub structure so the system can run end-to-end
    without blocking on circuit implementation.
    """
    return {
        "proof": None,
        "public_signals": {
            "parent_report_hash": input_data["parent_report_hash"],
        },
    }
