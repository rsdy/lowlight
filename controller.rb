#!/usr/bin/env ruby
#
# Controller application for the arduino.
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
require 'Qt4'

class MainWindow < Qt::Dialog
  def create_picker led
    Qt::ColorDialog.new self do |d|
      d.setOption Qt::ColorDialog::NoButtons
      d.connect(SIGNAL('currentColorChanged(QColor)')) do |color|
        str = ['w', led, color.red, color.green, color.blue].pack('ACCCC')
        TCPSocket.open('localhost', 12355) { |sock| sock.write str }
      end
    end
  end

  def create_picker_bar
    Qt::GroupBox.new self do |w|
      w.title = 'LED Controls'
      w.layout = Qt::HBoxLayout.new
      w.layout.addWidget create_picker 0
      w.layout.addWidget create_picker 1
      w.minimumWidth = 1035
      w.minimumHeight = 365
    end
  end

  def initialize parent = nil
    super parent

    centralWidget = Qt::Widget.new self do |w|
      w.layout = Qt::VBoxLayout.new
      w.layout.addWidget create_picker_bar
      w.minimumWidth = 1045
      w.minimumHeight = 375
    end
  end
end

app = Qt::Application.new ARGV
window = MainWindow.new
window.show
app.exec

