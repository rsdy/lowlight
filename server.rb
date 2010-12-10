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
require 'narray'
require 'fftw3'
require 'trollop'

class MultiplePopQueue
  # the purpose of this class is to provide a queue which doesn't instantly
  # remove the element which is popped, but lets pop_count number of pops happen
  # before removing the element.
  #
  # it has thread synchronization which is essential for functionality
  # the use case: multiple threads processing the same sequence of inputs
  # without actually knowing of the other threads
  #
  def pop_count; @popmtx.synchronize { @popnum } end

  def clear; @qmtx.synchronize { @que.clear } end

  def empty?; @qmtx.synchronize { @que.size == 0 } end

  def <<(value); push value; end

  def pop_count=(value)
    @popmtx.synchronize { @popnum = value if value > 0 }
  end

  def push(value)
    @qmtx.synchronize do
      @que << value
    end
      @new_item.broadcast
  end

  def pop
    @qmtx.synchronize do
      @new_item.wait(@qmtx) if @que.empty?
      ret = @que[0]

      @popmtx.synchronize do
        if (@cntr += 1) == @popnum
          @que = @que[1..-1]
          @cntr = 0
        end
      end
    end

    return ret
  end

  def initialize
    @qmtx = Mutex.new
    @que = []
    @popnum = 1
    @cntr = 0
    @popmtx = Mutex.new
    @new_item = ConditionVariable.new
  end
end

class Sampler
  def initialize dsp, rate
    @dsp = File.new dsp, 'r'
    # TODO this constant is dumped on a 32bit machine. due to the fact that this
    # is actually a macro in the kernel which depends on the size of int, this
    # might differ on different architectures. should do a c extension which
    # calls the native macro
    #
    @dsp.ioctl 0xc0045002, [rate].pack('I') # SNDCTL_DSP_SPEED
  end

  def window data
    result = []
    data.each_with_index do |x, i|
      result[i] = x * Math::tanh(Math::cos(2*Math::PI*i/(data.length-1)) + Math::cos(Math::PI * data[-i] / (data.length - 1)))
    end
    result
  end

  def sample samples = 4096
    data = window @dsp.read(samples).unpack 'C*' # using 8 bit unsigned DSP
    fft = FFTW3.fft(data)[5...data.length/2] / data.length # first data is DC
  end

  def close
    @dsp.close
  end
end

class Server
  def start_sample_thread
    @sample_queue ||= MultiplePopQueue.new
    sampler = Sampler.new '/dev/dsp', 44100

    Thread.new do
      loop do
        begin
          @sample_queue << sampler.sample 1024
          sleep 0.01
        ensure
          @sample_queue.clear
          sampler.close
        end
      end
    end
  end

  def start_writer_thread
    @writer_queue ||= Queue.new

    Thread.new do
      loop do
        @serial.write @writer_queue.pop
        @serial.flush
      end
    end
  end

  def write_to_arduino sock
    begin
      @writer_queue << sock.read 4
    ensure
      sock.close unless sock.nil?
    end
  end

  def listen
    loop do
      begin
        sock = @server.accept
      rescue Errno::EBADF, IOError
        break
      end

      case sock.read 1
      when 'w'
        write_to_arduino sock
      when 's'
        start_sampler_thread
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
    puts "#{$0}: couldn\'t open serial port!"
    exit 2
  end
end

$opts = Trollop::options do
  banner <<EOS
Lowlight server application

Usage: #{$0}

Available options:
EOS

  opt :tty,     'serial port to use', :short => 't', :default => '/dev/ttyUSB0', :type => :string
  opt :baud,    'baud rate',          :short => 'b', :default => 9600,           :type => :int
  opt :port,    'port to listen on',  :short => 'p', :default => 12355
  opt :daemon,  'fork to background', :short => 'd'
  opt :pidfile, 'the pidfile',        :short => 'P', :default => '/tmp/llserver'
  opt :kill,    'kill already running background process'
end

if $opts[:kill]
  if File.exists? $opts[:pidfile]
    Process.kill :SIGINT, File.read($opts[:pidfile]).to_i
    File.delete $opts[:pidfile]

    puts "#{$0}: background process killed successfully!"
    exit 0
  else
    puts "#{$0}: no background process!"
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

