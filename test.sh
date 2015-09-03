#!/bin/bash -e

targetfile="dfdf"

if [[ -z "$targetfile" ]]; then
  targetfile=hello
fi

echo $targetfile
  