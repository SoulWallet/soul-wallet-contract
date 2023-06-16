#!/bin/bash
forge build
if [[ $1 == "save" ]]; then
    `forge test --gas-report | awk '/-/{p=1} p' > gas-report.txt`
else
    `forge test --gas-report | awk '/-/{p=1} p' > .tmp-gas-report.txt`
    gasReportFile1=$(cat gas-report.txt)
    gasReportFile2=$(cat .tmp-gas-report.txt)
    rm .tmp-gas-report.txt
    if [[ "$gasReportFile1" == "$gasReportFile2" ]]; then
        echo "gas report check success"
    else
        echo "gas report check failed"
        forge test --gas-report
        exit 1
    fi
fi
