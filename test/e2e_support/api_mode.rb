# rubocop:disable all

$AGENT_PORT_IN_TESTS = 30000

# based on secret passed to the running server
$TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.gLEycyHdyRRzUpauBxdDFmxT5KoOApFO5MHuvWPgFtY"

class ApiMode
  def boot_up_agent
    system "docker stop $(docker ps -q)"
    system "docker rm $(docker ps -qa)"
    system "docker build -t agent -f Dockerfile.test ."
    system "docker run --privileged --device /dev/ptmx -v /tmp/agent-temp-directory/:/tmp/agent-temp-directory -v /var/run/docker.sock:/var/run/docker.sock -p #{$AGENT_PORT_IN_TESTS}:8000 -p #{$AGENT_SSH_PORT_IN_TESTS}:22 --name agent -tdi agent bash -c \"service ssh restart && nohup ./agent serve --auth-token-secret 'TzRVcspTmxhM9fUkdi1T/0kVXNETCi8UdZ8dLM8va4E' & sleep infinity\""
  end

  def start_job(request)
    r = Tempfile.new
    r.write(request)
    r.close

    puts "============================"
    puts "Sending job request to Agent"

    output = `curl -H "Authorization: Bearer #{$TOKEN}" --fail -X POST -k "https://0.0.0.0:30000/jobs" --data @#{r.path}`

    abort "Failed to send: #{output}" if $?.exitstatus != 0
  end

  def stop_job
    puts "============================"
    puts "Stopping job..."

    output = `curl -H "Authorization: Bearer #{$TOKEN}" --fail -X POST -k "https://0.0.0.0:30000/jobs/terminate"`

    abort "Failed to stob job: #{output}" if $?.exitstatus != 0
  end

  def wait_for_command_to_start(cmd)
    puts "========================="
    puts "Waiting for command to start '#{cmd}'"

    Timeout.timeout(60 * 2) do
      loop do
        `curl -H "Authorization: Bearer #{$TOKEN}" --fail -k "https://0.0.0.0:30000/job_logs" | grep "#{cmd}"`

        if $?.exitstatus == 0
          break
        else
          sleep 1
        end
      end
    end
  end

  def wait_for_job_to_finish
    puts "========================="
    puts "Waiting for job to finish"

    Timeout.timeout(60 * 2) do
      loop do
        `curl -H "Authorization: Bearer #{$TOKEN}" --fail -k "https://0.0.0.0:30000/job_logs" | grep "job_finished"`

        if $?.exitstatus == 0
      	break
        else
      	sleep 1
        end
      end
    end
  end

  def assert_job_log(expected_log)
    puts "========================="
    puts "Asserting Job Logs"

    actual_log = `curl -H "Authorization: Bearer #{$TOKEN}" -k "https://0.0.0.0:30000/jobs/#{$JOB_ID}/log"`

    puts "-----------------------------------"
    puts actual_log
    puts "-----------------------------------"

    abort "Failed to fetch logs: #{actual_log}" if $?.exitstatus != 0

    actual_log   = actual_log.split("\n").map(&:strip).reject(&:empty?)
    expected_log = expected_log.split("\n").map(&:strip).reject(&:empty?)

    index_in_actual_logs = 0
    index_in_expected_logs = 0

    while index_in_actual_logs < actual_log.length && index_in_expected_logs < expected_log.length
      begin
        puts "Comparing log lines Actual=#{index_in_actual_logs} Expected=#{index_in_expected_logs}"

        expected_log_line = expected_log[index_in_expected_logs]
        actual_log_line   = actual_log[index_in_actual_logs]

        puts "  actual:   #{actual_log_line}"
        puts "  expected: #{expected_log_line}"

        actual_log_line_json = Hash[JSON.parse(actual_log_line).sort]

        if expected_log_line =~ /\*\*\* LONG_OUTPUT \*\*\*/
          if actual_log_line_json["event"] == "cmd_output"
            # if we have a *** LONG_OUTPUT *** marker

            # we go to next actual log line
            # but we stay on the same expected log line

            index_in_actual_logs += 1

            next
          else
            # end of the LONG_OUTPUT marker, we increase the expected log line
            # and in the next iteration we will compare regularly again
            index_in_expected_logs += 1

            next
          end
        else
          # if there is no marker, we compare the JSONs
          # we ignore the timestamps because they change every time

          expected_log_line_json = Hash[JSON.parse(expected_log_line).sort]

          if expected_log_line_json.keys != actual_log_line_json.keys
            abort "(fail) JSON keys are different."
          end

          expected_log_line_json.keys.each do |key|
            # Special case when we want to ignore only the output
            # ignore expected entries with '*'

            next if expected_log_line_json[key] == "*"

            if expected_log_line_json[key] != actual_log_line_json[key]
              abort "(fail) Values for '#{key}' are not equal."
            end
          end

          index_in_actual_logs += 1
          index_in_expected_logs += 1
        end

        puts "success"
      rescue
        puts ""
        puts "Line Number: Actual=#{index_in_actual_logs} Expected=#{index_in_expected_logs}"
        puts "Expected: '#{expected_log_line}'"
        puts "Actual:   '#{actual_log_line}'"

        abort "(fail) Failed to parse log line"
      end
    end

    if index_in_actual_logs != actual_log.length
      abort "(fail) There are unchecked log lines from the actual log"
    end

    if index_in_expected_logs != expected_log.length
      abort "(fail) There are unchecked log lines from the expected log"
    end
  end
end
