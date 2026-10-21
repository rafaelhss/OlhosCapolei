#!/bin/bash
cmake -S . -B build
cmake --build build -t clean
cmake --build build
