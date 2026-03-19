#!/bin/bash

set -e

mkdir code
git clone https://${GH_PAT}@${GH_REPO:-github.com/verantos-dev/verantos-evidence-platform.git} code/
cd code
git fetch
git checkout ${GH_BRANCH:-main}
pnpm install
# Use environment variable for API key\n\
# Run Claude Code with dangerous skip permissions for jailfree mode
exec claude --dangerously-skip-permissions "$@"
