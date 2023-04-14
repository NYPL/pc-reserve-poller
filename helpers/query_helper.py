import os

_ENVISIONWARE_QUERY = '''
    SELECT
        pcrKey, pcrUserID, pcrMinutesUsed, pcrDateTime, pcrBranch,
        pcrArea, pcrUserData1
    FROM strad_bci
    WHERE pcrDateTime > '{date_time}'
        OR (pcrDateTime = '{date_time}' AND pcrKey > {key})
    ORDER BY pcrDateTime, pcrKey LIMIT {limit};'''

_SIERRA_QUERY = '''
    SELECT barcode, id, ptype_code, home_library_code, pcode3
    FROM sierra_view.patron_view
    WHERE barcode IN ({});'''

_REDSHIFT_QUERY = '''
    SELECT patron_id, postal_code, geoid
    FROM {table}
    WHERE patron_id IN ({ids});'''


def build_envisionware_query(date_time, key):
    return _ENVISIONWARE_QUERY.format(
        date_time=date_time, key=key,
        limit=os.environ['ENVISIONWARE_BATCH_SIZE'])


def build_sierra_query(barcodes):
    return _SIERRA_QUERY.format(barcodes)


def build_redshift_query(table, ids):
    return _REDSHIFT_QUERY.format(table=table, ids=ids)
