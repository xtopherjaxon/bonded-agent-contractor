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