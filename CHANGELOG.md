## 2024-11-22 -- v2.0.1
### Added
- Use nypl-py-utils patron_data_helper methods to get Sierra and Redshift patron info

## 2024-11-05 -- v2.0.0
### Added
- Rewrite Sierra barcode --> patron_id query to use more efficient phrase_entry table
- Delete Sierra query retry logic
- Increase batch size to 10k

### Fixed
- Upgrade from Python 3.9 to Python 3.12
- Upgrade to `nypl-py-utils` v1.4.0
- Add .python-version, devel_requirements, and conftest files

## 2024-06-21 -- v1.1.0
### Fixed
- Handle patron_home_library_code in standardized way (convert empty strings and 'none' to NULL)

## 2023-07-12 -- v1.0.1
### Fixed
- Increase max Sierra query attempts to 10

## 2023-07-07 -- v1.0.0
### Fixed
- Manually set Sierra query timeout to 5 minutes in order to prevent a bug in ECS where a query will time out after 10 minutes (the PostgreSQL default) but the error will not be propagated and the connection will hang for the next 2 hours. Through trial and error, 5 minutes was found to be the maximum timeout before this bug occurs. The root cause of the bug is still unknown.

## 2023-06-29 -- v0.0.4
### Added
- Updated `configure-aws-credentials` GitHub action version
- Updated `nypl-py-utils` version
- Only convert datatypes where necessary -- ensures patron ids are obfuscated as integer strings

## 2023-05-25 -- v0.0.3
### Fixed
- If a barcode corresponds to multiple Sierra patron records, do not use any of the patron info
- Handle second Sierra query timeout

## 2023-05-24 -- v0.0.2
### Fixed
- Added retry if Sierra query times out

## 2023-04-14 -- v0.0.1
### Added
- Initial python commit