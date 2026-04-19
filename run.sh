#!/bin/bash
# Quick dev run — builds the .app bundle and launches it
cd "$(dirname "$0")"
./build.sh && open "Calendar Timer.app"
