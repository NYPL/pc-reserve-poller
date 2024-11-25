import os

_ENVISIONWARE_QUERY = """
    SELECT
        pcrKey, pcrUserID, pcrMinutesUsed, pcrDateTime, pcrBranch, pcrArea, pcrUserData1
    FROM strad_bci
    WHERE pcrDateTime > '{date_time}'
        OR (pcrDateTime = '{date_time}' AND pcrKey > {key})
    ORDER BY pcrDateTime, pcrKey
    LIMIT {limit};"""


def build_envisionware_query(date_time, key):
    return _ENVISIONWARE_QUERY.format(
        date_time=date_time, key=key, limit=os.environ["ENVISIONWARE_BATCH_SIZE"]
    )
