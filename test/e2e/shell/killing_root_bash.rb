#!/bin/ruby
# rubocop:disable all

require_relative '../../e2e'

#
# Running the following set of commands caused the Agent to freeze up.
#
#   sleep infinity &
#   exit 1
#
# These are regressions tests that verify that this is no longer a problem.
#

start_job <<-JSON
  {
    "id": "#{$JOB_ID}",

    "env_vars": [],

    "files": [],

    "commands": [
      { "directive": "sleep infinity &" },
      { "directive": "exit 1" }
    ],

    "epilogue_always_commands": [],

    "callbacks": {
      "finished": "#{finished_callback_url}",
      "teardown_finished": "#{teardown_callback_url}"
    },
    "logger": #{$LOGGER}
  }
JSON

wait_for_job_to_finish

assert_job_log <<-LOG
  {"event":"job_started",  "timestamp":"*"}
  {"event":"cmd_started",  "timestamp":"*", "directive":"Exporting environment variables"}
  {"event":"cmd_finished", "timestamp":"*", "directive":"Exporting environment variables","exit_code":0,"finished_at":"*","started_at":"*"}
  {"event":"cmd_started",  "timestamp":"*", "directive":"Injecting Files"}
  {"event":"cmd_finished", "timestamp":"*", "directive":"Injecting Files","exit_code":0,"finished_at":"*","started_at":"*"}
  {"event":"cmd_started",  "timestamp":"*", "directive":"sleep infinity &"}
  {"event":"cmd_finished", "timestamp":"*", "directive":"sleep infinity &","exit_code":0,"finished_at":"*","started_at":"*"}
  {"event":"cmd_started",  "timestamp":"*", "directive":"exit 1"}
  {"event":"cmd_finished", "timestamp":"*", "directive":"exit 1","exit_code":1,"finished_at":"*","started_at":"*"}
  {"event":"cmd_started",  "timestamp":"*", "directive":"export SEMAPHORE_JOB_RESULT=failed"}
  {"event":"cmd_finished", "timestamp":"*", "directive":"export SEMAPHORE_JOB_RESULT=failed","exit_code":1,"started_at":"*","finished_at":"*"}
  {"event":"job_finished", "timestamp":"*", "result":"failed"}
LOG
