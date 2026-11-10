require "open3"
require "timeout"

class UploadCommand
  def self.run(*argv, env: {})
    output = +""
    error = +""
    Open3.popen3(env, *argv, pgroup: true) do |stdin, stdout, stderr, process|
      stdin.close
      readers = [Thread.new { output << stdout.read }, Thread.new { error << stderr.read }]
      begin
        Timeout.timeout(Integer(ENV.fetch("UPLOAD_PROCESSING_TIMEOUT_SECONDS", "1800"))) do
          readers.each(&:join)
          raise "Processing command failed: #{error.last(4000)}" unless process.value.success?
        end
      rescue Timeout::Error
        terminate(process.pid, "TERM")
        sleep 1
        terminate(process.pid, "KILL") if process.alive?
        raise "Processing exceeded the configured time limit"
      ensure
        readers.each(&:join)
      end
    end
    output
  end

  def self.terminate(pid, signal)
    Process.kill(signal, -pid)
  rescue Errno::ESRCH
    Rails.logger.debug "[UploadCommand] Process #{pid} already exited"
  end
  private_class_method :terminate
end
