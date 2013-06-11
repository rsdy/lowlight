#!/usr/bin/env ruby
#
# Controller server for the arduino.
#
# Copyright (c) 2010-2011 Peter Parkanyi <me@rhapsodhy.hu>.
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

require './lowlight'

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

  def sample samples
    data = window @dsp.read(samples).unpack 'C*' # using 8 bit unsigned DSP
    return FFTW3.fft(data)[2...data.length/2] / data.length # first data is DC
  end

  def close
    @dsp.close
  end
end

class Server
  def sample_to_rgb sample
    '#' + (0...3).map { |i|
      starti = i*sample.length/3
      endi = (i+1)*sample.length/3
      num = sample[starti...endi].sum
      '%02x' % (num.real*num.real + num.imag*num.imag).to_i
    }.join
  end

  def sampler_thread
    @sampler_running = true
    sampler = Sampler.new '/dev/dsp', $opts[:rate]

    while @sampler_running
      @writer_queue << sample_to_rgb(sampler.sample($opts[:chunk]))

      @listeners.each do |s|
        begin
          s.write [sample.size] + sample
        rescue IOError
          print '5'
          @listeners.remove s
        end
      end
    end
  end

  def writer_thread
    loop do
      sleep(0.01) until data = @writer_queue.pop

      begin
        @serial.write data
        @serial.flush
      rescue
        # as if nothing happened
      end
    end
  end

  def start_sampler_thread
    @listeners ||= []
    Thread.new { sampler_thread }
  end

  def start_writer_thread
    @writer_queue ||= []
    Thread.new { writer_thread }
  end

  def listen
    loop do
      begin
        sock = @server.accept
      rescue Errno::EBADF, IOError
        break
      end

      case sock.read 1
      when Lowlight::WriteToArduino
        @writer_queue << sock.read(7)
        sock.close

      when Lowlight::StartSampler
        start_sampler_thread unless @sampler_running
        sock.close

      when Lowlight::SampleControl
        @sample_control = true
        start_sampler_thread unless @sampler_running
        sock.close

      when Lowlight::DisableSampleControl
        @sample_control = false
        @sampler_running = false
        sock.close

      when Lowlight::RequestSamples
        @listeners << sock
      end
    end
  end

  def close
    @listeners.each { |s| s.close } unless @listeners.nil?
    @server.close
    @serial.close
  end

  def initialize
    @server = TCPServer.open $opts[:port]
    @serial = SerialPort.open $opts[:tty], $opts[:baud].to_i, 8, 1, SerialPort::NONE
    start_writer_thread
  end
end

def start
  trap("INT") do
    @server.close
  end

  #begin
    @server = Server.new
  #rescue
    #puts "#{$0}: couldn\'t open serial port!"
    #exit 2
  #end
end

$opts = Trollop::options do
  banner <<EOS
Lowlight server application

Usage: #{$0}

Available options:
EOS

  opt :tty,     'serial port to use', :short => 't', :default => '/dev/ttyUSB0', :type => :string
  opt :baud,    'baud rate',          :short => 'b', :default => 9600,           :type => :int
  opt :port,    'port to listen on',  :short => 'p', :default => 12355,          :type => :int
  opt :rate,    'sample rate to use', :short => 'r', :default => 44100,          :type => :int
  opt :chunk,   'samples processed at once', :short => 'c', :default => 4096,    :type => :int
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
    File.open($opts[:pidfile], 'w') { |f| f.print Process.pid }
    start.listen
  end
else
  start.listen
end

