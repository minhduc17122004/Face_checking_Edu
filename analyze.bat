@echo off
dart analyze lib/common/utils/sync_jobs_util.dart lib/data/local/local_service.dart > analyze_result.txt
type analyze_result.txt
