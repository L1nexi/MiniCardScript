@echo off
setlocal enabledelayedexpansion

if not exist result (
    mkdir result
)

for %%f in (test\*.cdlang) do (
    echo Running %%f...
    set filename=%%~nxf
    racket mini-card-eval.rkt %%f > result\!filename!.txt
)

echo All tests completed. Results saved in result\ folder.