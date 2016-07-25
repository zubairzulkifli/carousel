Carousel
========

![Screenshot](screenshot.jpg)

A remote controllable carousel for selecting things. Start
it with:

```
$ INFOBEAMER_TARGET_L=40 info-beamer .
```

The carousel can be control using TCP. So connect to localhost
on port 4444. Once connected skip the info-beamer welcome
message by reading until the first newline. Then "connect"
to the running node by sending

```
*raw/c\n
```

and read the response (it should be 'ok!') by reading until
the next newline. You're now ready to send commands:

```
l\n
```

and

```
r\n
```

swipe left and right one image. You can queue up multiple
swipes. You can stop swiping by sending a

```
s\n
```

command which will slow down movement so it stops on the
next image.

You can query the current image by sending

```
p\n
```

The response is a single line with the basename of the
currently centered image.  

You can hide the complete output by sending

```
o\n
```

and

```
i\n
```

which will fadeout/fadein. Since you can start
info-beamer on layer 40 (see the above arguments in
the provided command line) other programs like
for example omxplayer can run below info-beamer.
Fading out will hide the complete info-beamer output
and omxplayer will become visible.
    
Finally you can switch between
sets of images by sending

```
u\n
{...see below...}\n
```

and

```
d\n
{...see below...}\n
```

which will switch to the given set of images by moving
upwards/downwards. The given json structure must have
the following content. When sending the JSON, make
sure you serialize it into a single line:

```
{
    "title": "Title",
    "images": ["basename1", "basename2", "basename3", ...]
}
```

The provided list in 'images' cannot be empty. 'basename'
specifies the basename of images you want to display. For
each basename you have to provide both basename.jpg and
basename-thumb.jpg. So if you include "example" in the
list of images you have to provide "example.jpg" and
"example-thumb.jpg".

The basename.jpg file should have the full resolution
(something around 500x700 is recommended). The image in
basename-thumb.jpg should have a lower resolution to
enable fast loading times. A maximum resolution of
150x200 is recommended. info-beamer will first load the
low res version while scrolling and then lazy load the
high res versions once scrolling slows down.

A complete communication between info-beamer and
your program might look like this:

```
<<< Info Beamer PI 0.9.6-beta...\n
>>> *raw/c\n
<<< ok!\n
>>> l\n          <- scroll left
>>> u\n{"title":"foo", "images":["0002"]}\n
>>> p\n
<<< 0002\n       <- basename of the centered image
...
```

You can use the example.py program to see the carousel
in action. Also take a look at the top of node.lua for
some options you might want to tweak.
