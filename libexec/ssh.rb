#!/usr/bin/env ruby
require 'resolv'
require 'digest/sha1'

require 'net/ssh'
require 'net/ssh/multi'
require 'net/ssh/gateway'

require 'parallel'
#. }=-

class EssEssHache
  @@dns = Resolv::DNS.open

  def initialize(threads, attempts, timeout)
    @threads  = threads
    @attempts = attempts
    @timeout  = timeout
    @clients  = []
    @sessions = {}
    @gateway  = nil
    @username = nil
    @context  = nil
    @command  = "hostname"
    @sudo     = false
    @sudosec  = nil
    @tries    = 0
  end

  def add_clients(clients)
    @clients += clients
  end

  def set_username(username)
    @username = username
  end

  def set_context(context)
    @context = context
  end

  def set_proxy(host, port)
    @gateway = Net::SSH::Gateway.new(
      host, @username, port: port, :verbose => :fatal,
    )
    return @gateway.active?
  end

  def set_command(cmd)
    @command = cmd
  end

  def set_sudo(duso, secret=nil)
    @sudo = duso
    @sudosec = secret
  end

  def connect(host)
    @sessions[host] = {
      retcode: -1,  stdout: '',
      sigcode: -1,  stderr: '',
      session: nil, except: '',
      success: nil, status: '',
    }

    begin
      #. NOTE on Timeouts -={
      #. the timeout option to net/ssh is not a good measure, at least by
      #. itself.  For instance if the host in questions does respond to port 22,
      #. and say with a valid OpenSSH banner, then this setting does nothing, a
      #. 120s timeout is imposed.  By using Ruby's own timeout, we garantee the
      #. timeout defined by the user to be honored.
      #. }=-
      timeout @timeout do
        if @gateway
          #@sessions[host][:session] = Net::SSH::Gateway.new(
          #  'night.sirca.org.au',
          #  @username,
          #  :port => 222,
          #  :compression => "none",
          #  :auth_methods => [ 'publickey' ],
          #  :verbose => :fatal,
          #).ssh(host, @username,
          #  :timeout => @timeout,
          #  :compression => "none",
          #  :auth_methods => [ 'publickey' ],
          #  :verbose => :fatal,
          #)
          @sessions[host][:status] = "Connecting to #{host} via the gateway #{@gateway}..."
          @sessions[host][:session] = @gateway.ssh(host, @username,
            :timeout => @timeout,
            :compression => "none",
            :auth_methods => [ 'publickey' ],
            :verbose => :fatal,
          )
        else
          @sessions[host][:status] = 'Connecting...'
          #@@dns.getaddress host
          @sessions[host][:session] = Net::SSH.start(host, @username,
            :config => [
              "#{ENV['HOME']}/.simbol/etc/ssh.conf",
              "#{ENV['HOME']}/.ssh/config",
              "/etc/ssh_config"
            ],
            :timeout => @timeout,
            :compression => "none",
            :auth_methods => [ 'publickey' ],
            :verbose => :fatal,
          )
        end
      end

      rescue Resolv::ResolvError => ouch
        @sessions[host][:except] = 'DNS Error'
        @sessions[host][:status] += 'DNS Error'
      rescue Timeout::Error
        @sessions[host][:except] = "Connection Timeout"
        @sessions[host][:status] += 'Connection Failed'
      rescue Errno::EHOSTUNREACH
        @sessions[host][:except] = "Host unreachable"
        @sessions[host][:status] += 'Connection Failed'
      rescue Errno::ECONNREFUSED
        @sessions[host][:except] = "Connection Refused"
        @sessions[host][:status] += 'Connection Failed'
      rescue Net::SSH::AuthenticationFailed
        @sessions[host][:except] = "Authentication Failure"
        @sessions[host][:status] += 'Connection Failed'
      rescue Net::SSH::Disconnect
        @sessions[host][:except] = "SSH Disconnect"
        @sessions[host][:status] += 'Connection Failed'
      rescue
        if @tries < @attempts
          @tries += 1
        else
          retry
        end
      else
        @sessions[host][:status] += 'Connected'
    end
  end

  def exec(host, command)
    command = "sudo -S #{command}" if @sudo
    #. Submit the job, don't wait for it however:

    if not @sessions[host][:session].nil?
      @sessions[host][:success] = false
      begin
        @sessions[host][:status] += "; Executing..."
        @sessions[host][:session].open_channel do |channel|
          @sessions[host][:status] = 'Executing (requesting pty)...'
          channel.request_pty do |ch0, success|
            if success
              @sessions[host][:status] = 'Executing command...'
              channel.exec(command) do |ch1, success|
                if success
                  @sessions[host][:status] = 'Execution submitted'
                  channel.on_data do |ch3, data|
                    if @sudo and @sudosec and data =~ /^\[sudo\] password for/
                      channel.send_data "#{@sudosec}\n"
                    else
                      @sessions[host][:stdout] += data
                    end
                  end
                  channel.on_open_failed do |ch, code, desc|
                    p code, desc
                  end
                  channel.on_extended_data do |ch, data|
                    @sessions[host][:stderr] += "#{data.inspect}"
                  end
                  channel.on_request('exit-status') do |ch, data|
                    @sessions[host][:retcode] = data.read_long
                  end
                  channel.on_request('exit-signal') do |ch, data|
                    @sessions[host][:sigcode] = data.read_long
                  end
                  channel.on_close do |ch|
                    @sessions[host][:success] = true
                  @sessions[host][:status] = 'Execution complete'
                  end
                else
                  @sessions[host][:status] = 'Execution failed'
                  @sessions[host][:except] = "Execution Failure"
                  @sessions[host][:retcode] = -2
                end
              end
            else
              @sessions[host][:status] = 'Execution failed to obtain PTY'
              @sessions[host][:except] = "Failure to obtain PTY"
              @sessions[host][:retcode] = -3
            end
          end
        end
      rescue
        @sessions[host][:status] = 'Execution failed with unknown exception'
        @sessions[host][:except] = "Unhandled exception"
        @sessions[host][:retcode] = -9
      end
    else
      @sessions[host][:status] += '; No session, no execution'
    end
  end

  def harvest
    printf("#. Establishing connectivity to %d hosts...", @clients.length)
    Parallel.map(@clients, :in_threads=>@threads) { |host| self.connect(host) }
    printf("DONE\n")

    printf("#. Submitting commands to %d hosts...", @sessions.length)
    @sessions.map { |host,hostdata| self.exec(host, @command) }
    #Parallel.map(@sessions, :in_threads=>@threads) { |host,hostdata| self.exec(host, @command) }
    printf("DONE\n")

    condition = Proc.new { |ssh| ssh.busy? }
    wait = true
    while wait
     wait = false
     printf "#. Waiting on %d connections...\n", @sessions.length
      @sessions.each do |host,hostdata|
        printf "#. - #{host} #{hostdata[:status]}\n"
        #pp @sessions[host].reject { |k,v| k == :session }
        if hostdata[:session] and hostdata[:session].process(1, &condition)
          wait = true
          break
        end
      end
    end
  end

  def close
    @sessions.each do |host,hostdata|
      hostdata[:session].close unless hostdata[:session].nil?
    end
    @gateway.shutdown! unless @gateway.nil?
  end

  def writeMeABASHScript
    printf("#!/bin/bash\n")
    printf("#. %d threads\n", @threads)
    printf("#. %d attempts\n", @attempts)
    printf("#. %0.1fs timeout\n", @timeout)
    printf("\n")

    printf "local -A %s\n", @context
    printf "local -A %s_o\n", @context
    printf "local -A %s_e\n", @context
    printf "local -A %s_w\n", @context

    @sessions.each do |host, hostdata|
      printf "#. %s...\n", host

      hash = Digest::SHA1.hexdigest host
      printf("%s[%s]=%d\n", @context, hash, hostdata[:retcode])

      stdout = hostdata[:stdout].strip
      stderr = hostdata[:stderr].strip
      except = hostdata[:except].strip

      printf(
        "read -r -d '' %s_o[%s] <<-!\n%s\n!\n",
        @context, hash, stdout
      ) if stdout.length > 0

      if stderr.length > 0
        printf(
          "read -r -d '' %s_e[%s] <<-!\n%s\n!\n",
          @context, hash, stderr
        )
      elsif except.length > 0
        printf(
          "read -r -d '' %s_e[%s] <<-!\nException: %s\n!\n",
          @context, hash, except
        )
      end
    end
  end
end

def secret(sid)
  require 'gpgme'

  encrypted_data = GPGME::Data.new(
    File.open("#{ENV['HOME']}/.simbol/etc/simbol.vault")
  )
  ctx = GPGME::Ctx.new
  decrypted = ctx.decrypt encrypted_data
  decrypted.seek(0)

  secrets = Hash[
    *decrypted.read.split("\n").collect { |v| v.split(/\s+/, 2) }.flatten
  ]

  return secrets[sid]
end

def main
  if ARGV.length >= 4
    threads = ARGV[0].to_i
    attempts = ARGV[1].to_i
    timeout = ARGV[2].to_f

    ssh = EssEssHache.new(threads, attempts, timeout)

    context, remainder = ARGV[3].split('=', 2)
    password = nil

    if ENV.key? 'SUDO' and ENV['SUDO'].length > 0
      password = secret(ENV['SUDO'])
      ssh.set_sudo(true, password)
    end

    clients = remainder.split(',').uniq
    printf("#. %d clients!\n", clients.length)
    cmd = ARGV[4..-1].join(' ')

    ssh.set_command(cmd)
    ssh.set_context(context)

    #ssh_proxy_host = ENV['SSH_PROXY_HOST']
    #if ssh_proxy_host.length > 0
    #  ssh_proxy_port = ENV['SSH_PROXY_PORT'].to_i or 22
    #  ssh.set_proxy(ssh_proxy_host, ssh_proxy_port)
    #end

    ssh.add_clients(clients)
    ssh.harvest
    ssh.writeMeABASHScript
    ssh.close
  end
end

main
