@echo off
REM Test API Silos

REM --- POST: thêm silo mới ---
curl -X POST http://localhost:5294/api/silos ^
  -H "Content-Type: application/json" ^
  -d "{\"id\":\"SiloTest02\",\"weight\":900,\"level\":0.55,\"indicatorId\":\"IND-004\",\"indicatorPort\":\"COM4\",\"indicatorMaxLoad\":1800,\"controllerIp\":\"192.168.1.20\",\"controllerPort\":\"8083\",\"controllerSn\":\"CTRL-004\"}"

REM --- PUT: cập nhật silo ---
REM curl -X PUT http://localhost:5294/api/silos/Silo1 ^
REM   -H "Content-Type: application/json" ^
REM   -d "{\"id\":\"Silo1\",\"weight\":1500,\"level\":0.8,\"indicatorId\":\"IND-001\",\"indicatorPort\":\"COM1\",\"indicatorMaxLoad\":2000,\"controllerIp\":\"192.168.1.10\",\"controllerPort\":\"8080\",\"controllerSn\":\"CTRL-001\"}"

REM --- DELETE: xoá silo ---
REM curl -X DELETE http://localhost:5294/api/silos/SiloTest02

REM --- GET: lấy danh sách silo ---
REM curl -X GET http://localhost:5294/api/silos

pause
