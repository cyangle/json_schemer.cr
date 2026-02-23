#!/bin/sh

cd $(dirname $0)/../

# Run tests
crystal tool format

./bin/ameba --fix

crystal spec
