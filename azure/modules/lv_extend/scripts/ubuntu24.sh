#!/bin/bash

set -e
set -x # Enable debug mode to print each command before execution

# Print the current disk usage before extending the logical volume
df -h
