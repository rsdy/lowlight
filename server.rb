#!/usr/bin/env ruby
#
# controller library for the arduino.
#

require 'socket'
require 'rubygems'
require 'serialport'

#fork do
  server = TCPServer.open 12355

  begin
    serial = SerialPort.open ARGV[0], ARGV[1].to_i, 8, 1, SerialPort::NONE
  rescue
    print 'couldn\'t open serial port!'
    exit
  end

  trap("INT") do
    server.close
  end

  loop do
    begin
      sock = server.accept

      serial.write sock.readpartial(4) if(sock.readpartial(1) == 'w')
      serial.flush
    rescue Errno::EBADF, IOError
      break
    ensure sock.close unless sock.nil?
    end
  end

  serial.close
#end

