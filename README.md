## Thorlabs ITC4001 controller
Simple matlab class and gui to control the
[Thorlabs ITC4001 Benchtop Laser Diode/TEC Controller](https://www.thorlabs.de/thorProduct.cfm?partNumber=ITC4001).

## Status
Not done yet, any day now tho =)

## Requirements
This class requires the
[Instrument control toolbox](https://se.mathworks.com/products/instrument.html)
and unfortunately also a VISA driver. While matlab's VISA interface
[reportedly](https://se.mathworks.com/help/releases/R2024b/instrument/troubleshooting-visa-interface.html)
still works on intel-based macs I haven't tried it. So if your using a modern
computer you're stuck with windows.
[Mathworks lists](https://se.mathworks.com/help/releases/R2024b/instrument/troubleshooting-visa-interface.html)
three different VISA drivers but I've only tested the class with the one from
[Rohde & Schwartz](https://www.rohde-schwarz.com/no/applications/r-s-visa-application-note_56280-148812.html),
I would advice against using the NI one since the install process is completely
broken.

## Min matlab version
I *think* R2021a, but I'm not sure. Please send an
[email](mailto:ragnar.seton@uit.no)
or create a
[merge request](https://docs.gitlab.com/ee/user/project/merge_requests/creating_merge_requests.html)
on gitlab if it turns out I'm wrong on this.

## Install
If you have not adjusted your `userpath` you can just download this repo to your
~/Documents/MATLAB folder, unzip it and run
```
addpath([userpath(), filesep(), 'itc4001']);
```

## Basic usage
Connect your ITC4001 with a usb cable, turn it on and run `ITC4001.gui()`.

## Advanced usage
See `help ITC4001`.

## Notes
I want to emphasize *simple class*, you really can't do more than set the
value/range for the TEC and LD and turn them on/off. It shold be fairly easy to
extend tho. All the controlling logic is in the itc4001-class, the gui is just a
static function that creates an object and provides a uifigure-based user
interface to it.
