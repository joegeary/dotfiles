#!/usr/bin/env bash

# Create a new task in Taskwarrior with a given description and optional additional attributes.
# Properly handle special characters in the description and other arguments.
create_task() {
  local description="$1"
  shift # Now $@ contains the rest of the arguments

  # Use an array to hold arguments to prevent word splitting
  local task_args=()
  for arg in "$@"; do
    task_args+=("$arg")
  done

  # Use -- to indicate end of options, and pass the description safely
  local output
  output=$(task add "${task_args[@]}" -- "$description")

  # Extract the UUID from the output using a reliable method
  local task_uuid
  task_uuid=$(echo "$output" | grep -Po '(?<=Created task )[a-z0-9\-]+')

  echo "$task_uuid"
}

# Annotate an existing task
annotate_task() {
  local task_uuid="$1"
  local annotation="$2"
  task "$task_uuid" annotate -- "$annotation"
}
