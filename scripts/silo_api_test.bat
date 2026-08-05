@echo off

 curl -X DELETE http://localhost:5294/api/silos/Silo5

REM curl -X POST http://localhost:5294/api/Silos ^
REM   -H "Content-Type: application/json" ^
REM   -d "{ \"id\": \"Silo7\", \"weight\": 1000, \"level\": 0.6}"

REM curl -X PUT http://localhost:5294/api/Silos/Silo6 ^
REM   -H "Content-Type: application/json" ^
REM   -d "{ \"id\": \"Silo6\", \"weight\": 2000, \"level\": 0.6}"

REM curl -X PATCH http://localhost:5294/api/Silos/Silo6 ^
REM   -H "Content-Type: application/json-patch+json" ^
REM   -d "[{\"op\":\"replace\",\"path\":\"/weight\",\"value\":8000}]"

pause
