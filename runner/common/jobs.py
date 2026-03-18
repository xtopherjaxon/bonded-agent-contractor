from typing import Any


def job_tuple_to_dict(raw: Any) -> dict[str, Any]:
    return {
        "id": raw[0],
        "parentJobId": raw[1],
        "creator": raw[2],
        "assignedAgent": raw[3],
        "preferredAgent": raw[4],
        "category": raw[5],
        "specURI": raw[6],
        "resultURI": raw[7],
        "rewardWei": raw[8],
        "bondWeiRequired": raw[9],
        "deadline": raw[10],
        "status": raw[11],
        "isSubtask": raw[12],
    }


def category_hex(category: Any) -> str:
    if isinstance(category, (bytes, bytearray)):
        return "0x" + bytes(category).hex()
    return str(category)


def is_open_job(job: dict[str, Any]) -> bool:
    # status 1 = Open
    return job.get("status") == 1 and job.get("assignedAgent") == "0x0000000000000000000000000000000000000000"


def is_assigned_to_agent(job: dict[str, Any], agent_address: str) -> bool:
    return job.get("assignedAgent", "").lower() == agent_address.lower()


def is_completed(job: dict[str, Any]) -> bool:
    # status 4 = Completed
    return job.get("status") == 4


def is_subtask(job: dict[str, Any]) -> bool:
    return bool(job.get("isSubtask"))


def is_parent_job(job: dict[str, Any]) -> bool:
    return not is_subtask(job)


def get_child_jobs(all_jobs: list[dict[str, Any]], parent_job_id: int) -> list[dict[str, Any]]:
    return [
        j for j in all_jobs
        if j.get("parentJobId") == parent_job_id and j.get("isSubtask")
    ]


def get_job_result_uri(job: dict[str, Any]) -> str | None:
    uri = job.get("resultURI")
    if uri is None or uri == "":
        return None
    return str(uri)


def get_assigned_agent(job: dict[str, Any]) -> str:
    return str(job.get("assignedAgent", "0x0000000000000000000000000000000000000000"))