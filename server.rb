#!/usr/bin/env ruby
#
# Controller server for the arduino.
#
# Copyright (c) 2010 Peter Parkanyi <me@rhapsodhy.hu>.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
require 'rubygems'
require 'socket'
require 'serialport'
require 'trollop'

class Server
  def listen
    loop do
      begin
        sock = @server.accept

        case sock.read 1
        when 'w'
          r = sock.read 4
          (0...4).each { |i| puts r[i].to_s }
          $stdout.flush

          @serial.write r
          @serial.flush
        end
      rescue Errno::EBADF, IOError
        break
      ensure
        sock.close unless sock.nil?
      end
    end
  end

  def close
    @server.close
    @serial.close
  end

  def initialize
    @server = TCPServer.open $opts[:port]
    @serial = SerialPort.open $opts[:tty], $opts[:baud].to_i, 8, 1, SerialPort::NONE
  end
end

def start
  trap("INT") do
    @server.close
  end

  begin
    @server = Server.new
  rescue
    print 'couldn\'t open serial port!'
    exit 2
  end
end

$opts = Trollop::options do
  banner <<EOS
Lowlight server application

Usage: ./server.rb

Available options:
EOS

  opt :tty,     'serial port to use', :short => 't', :default => '/dev/ttyUSB0', :type => :string
  opt :baud,    'baud rate',          :short => 'b', :default => 9600,           :type => :int
  opt :port,    'port to listen on',  :short => 'p', :default => 12355
  opt :daemon,  'fork to background', :short => 'd'
  opt :pidfile, 'the pidfile',        :short => 'P', :default => 'pid'
  opt :kill,    'kill already running background process'
end

if $opts[:kill]
  if File.exists? $opts[:pidfile]
    Process.kill :SIGINT, File.open($opts[:pidfile], 'r') { |f| f.read }.to_i
    File.delete $opts[:pidfile]

    print 'server.rb: background process killed successfully!'
    exit 0
  else
    print 'server.rb: no background process!'
    exit 1
  end
end

if $opts[:daemon]
  fork do
    File.open('pid', 'w') { |f| f.print Process.pid }
    start.listen
  end
else
  start.listen
end

