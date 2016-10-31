## CoCoCaster ##
All rights reserved, Copyright (C) Brett M Gordon, 2016.

A pod cast player for the CoCo2

# Requirements #

CoCo2 or 3 with 32k RAM
Darren Atkinson's CoCoSDC


# Quick Instructions #


1. Download the pod.dsk, install on your CoCoSDC
2. Download a podcast file (*.pdc), install on your CoCoSDC
3. Boot up CoCo and mount pod.dsk as a drive
4. CLOADM"POD":EXEC

After loading the first screen presented to the user is a CoCoSDC file
browser.  An alphabetical sorted list of directories and files (as
present on the CoCoSDC FAT file system) is presented to the user.

# Browser Navigation #

UP/DOWN - Move Cursor through list
SPACE   - Select file/directory
ESC/BRK - Quit program
ALPHA   - Any other key will jump user to first entry starting with this key

After selection of a properly formatted podcast file, the player will
go to the main player screen, presenting a title graphic.

# Player Navigation #

UP/DOWN    - cue forward/backward by 1 minute
LEFT/RIGHT - cue forward/backward by 10 seconds
SPACE      - pause / unpause
ESC        - quit to file browser

At bottom of screen is a progress meter indicating current position in title.


# Notes on .pdc file format #

A .pdc file is a relatively simple format, and shouldn't be too hard for anyone with a Linux box to make there own files.  The basic format is a comprised of two parts: First a graphical image to display to the user, and secondly, the audio data.

The image is a plain UNIX style raw-mode 4 "pbm" format,  256 x 192, monochrome, inverted.

The audio data is in the form of raw samples. 11720 Hz, Mono, 8 bit, unsigned, no headers.

These two components must be sector (256byte) aligned, and the total
file must be an even multiple of 256 bytes.  The UNIX utility 'dd'
does a nice job of smooshing these two components together at the
right places.  Here is an example script:


gimp CoCo-Crew-Logo-small.pbm 
dd if=coco17.pbm of=coco17.1 B=256 conv=sync
mpg123 -w coco17.wav coco17.mp3 
sox coco17.wav -b8 -c1 -r15720 -eunsigned coco17.raw
cat coco17.1 coco17.raw | dd of=coco17.pdc bs=256 conv=sync