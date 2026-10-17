Hero artwork
============

    hero-devices.png   1920 x 819, PNG with transparency

This is the finished home banner: the pill, the headline, the description,
both buttons, the three trust lines, the device composite and the three
feature cards, all as pixels.

It is drawn edge to edge under the navigation on desktop. Because the text
inside it cannot be read by a screen reader or resized by the browser,
_HeroImageBand lays transparent hotspots over the two buttons and the three
feature cards: those carry the tap targets, the pointer cursor and the
accessibility labels.

Those hotspots are positioned from measurements taken off this exact file:

    Shop all products   x 106..415   y 454..517
    See featured        x 445..654   y 452..515
    Feature cards       x 87..649, 681..1241, 1275..1834   y 660..778

Replacing the artwork means re-measuring them. The numbers live in
_HeroImageBand._hotspots as fractions of the 1920 x 819 frame, and
test/hero_layout_test.dart checks the first of them against the artwork it
covers.

Below the desktop breakpoint the banner is rebuilt from widgets instead, so
the copy stays readable on a phone.
