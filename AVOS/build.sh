#!/bin/bash

# target_dir = $1 or current pwd if $1 is not present
target_dir=${1:-.}
sh +x build-framework.sh $target_dir
