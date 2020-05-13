#!/bin/bash -e

AMS_PORT=5000

for i in "$@"
do
case $i in
    --ams_port=*)
        AMS_PORT="${i#*=}"
        shift # past argument=value
    ;;
    *)
        exit 0
    ;;
esac
done

. /ie-serving-py/.venv/bin/activate 
cd /ams_wrapper && python -m src.wrapper --port $AMS_PORT