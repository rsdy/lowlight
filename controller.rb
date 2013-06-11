#!/usr/bin/env ruby
#
# Controller application for the arduino.
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
require 'Qt4'

require './lowlight'

module SocketConnection
  def socket &f
    TCPSocket.open('localhost', 12355, &f)
  end

  def send_data data
    socket { |sock| socket.write data }
  end

  def read_data chunks
    socket { |sock| yield data while data = sock.read(chunks) }
  end
end

class MainWindow < Qt::Dialog
  include SocketConnection

  def create_picker led
    Qt::ColorDialog.new self do |d|
      d.setOption Qt::ColorDialog::NoButtons
      d.connect(SIGNAL('currentColorChanged(QColor)')) do |color|
        send_data "#{Lowlight::WriteToArduino}#%02x%02x%02x" % [color.red, color.green, color.blue]
      end
    end
  end

  def create_picker_bar
    Qt::GroupBox.new self do |w|
      w.title = 'LED Controls'
      w.layout = Qt::HBoxLayout.new
      w.layout.addWidget create_picker 0
      w.layout.addWidget create_picker 1
    end
  end

  def create_visualization_bar
    Qt::GroupBox.new self do |w|
      w.title = 'Visualization'
      w.layout = Qt::VBoxLayout.new

      checkbox = Qt::CheckBox.new 'Visualize sounds with LEDs' do |c|
        c.connect(SIGNAL('toggled(bool)')) do |checked|
          send_data case checked
                      when true then Lowlight::SampleControl
                      else Lowlight::DisableSampleControl
                    end
        end
      end

      w.layout.addWidget checkbox
    end
  end

  def initialize parent = nil
    super parent

    centralWidget = Qt::Widget.new self do |w|
      w.layout = Qt::VBoxLayout.new
      w.layout.addWidget create_picker_bar
      w.layout.addWidget create_visualization_bar
      w.minimumWidth = 1045
      w.minimumHeight = 475
    end
  end
end

app = Qt::Application.new ARGV
window = MainWindow.new
window.show
app.exec

