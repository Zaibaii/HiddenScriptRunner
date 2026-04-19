@echo off
setlocal EnableDelayedExpansion

set "sRawArg=%~1"
echo ARG=[!sRawArg!]>>"%cd%\HSR_Test.log"
