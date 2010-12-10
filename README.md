Lowlight
========
Copyright (C) 2010 Peter Parkanyi <me@rhapsodhy.hu>

This is the source code for a project I'm really needing for my room :)
Basically, a two-channel RGB lamp, which can be controlled over USB (maybe
Ethernet later on). It can also be set to use data coming from the microphone
to change the colour, which gives a nice dynamic effect.

controller.rb
-------------
This tool has no parameters. The colour pickers set the colour of each bunch of
LEDs. Note that the server has to be started before running the GUI.
	./controller.rb

server.rb
---------
This is a TCP server which by default listens on port 12355. Basically, it's
just a proxy towards the Arduino. There are several reasons why this is a
separate application, though:

* you don't have to keep a GUI open all the time
* Arduino auto-resets by default when initiating serial connection (at least it
does for me when I open /dev/ttyUSB0). This results in several seconds of
darkness.
* it handles processing of the audio sample data and sending it to the device,
so you don't have to keep a GUI open all the time. Yeah, I don't like GUIs most
of the time.

You can get the available parameters and options with the following command:
	./server.rb -h

I think usage is quite self-explanatory from now.

Have fun.

Licence
-------
Distributed under the MIT licence
