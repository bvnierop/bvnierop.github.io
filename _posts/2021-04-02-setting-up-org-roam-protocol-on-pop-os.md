---
layout: post
title: Setting up org-roam-protocol on Pop!_OS
date: 2021-04-02 +0100
tags: [org-roam, org-protocol, pop!_os]
---

A few weeks ago I started using [org-roam][roam-github]{:target="_blank"
rel="nofollow noopener noreferrer"} for my note taking. Besides being a system
for note taking, it also comes with a workflow. One idea is to take notes of
things you read, as (or just after) you read them.

Already on the first day this turned out to be annoying. In order to create
_any_ note on an article, even just to store it away for future reading,
required too many steps:

1. Create a new roam-note
2. Copy/paste or type the title
3. Add on the second line the tag `#+roam_key`
4. Copy/paste or type the url
5. Start typing notes

This is quite a threshold and it was stopping me from using the system as
intended, so a solution had to be found. Thankfully `org-roam` extends
[org-protocol][org-protocol-website]{:target="_blank" rel="nofollow noopener
noreferrer"} which exists just for this use case.

This post details how I set this up on my Pop!_OS system.

## Enabling org-protocol
Since [org-roam-protocol][org-roam-protocol]{:target="_blank" rel="nofollow
noopener noreferrer"} depends on `org-protocol`, that must first be enabled. In
your config, after loading `org`, add `(require 'org-roam-protocol)`.

## Deskop application
Next we need to create a desktop application for `emacsclient`. This is
different for various platforms. On Pop!_OS, create a file called
`~/local/share/applications/org-protocol.desktop` with the following contents:

```conf
[Desktop Entry]
Name=Org-Protocol
Exec=emacsclient -a "" -c -s "org-protocol" %u
Icon=emacs-icon
Type=Application
Terminal=false
MimeType=x-scheme-handler/org-protocol
```
We're passing some arguments to `emacsclient`:

| argument            | what it does                                                                            |
|:--------------------|:----------------------------------------------------------------------------------------|
| `-a ""`             | -a with an empty string starts a new Emacs daemon if there isn't any.                   |
| `-c`                | Create a new frame.                                                                     |
| `-s "org-protocol"` | Names the socket for the daemon. This ensures that the daemon is for org-protocol only. |

We can technically start the daemon at boot time, but I have not really found
that necessary.

## Associate the protocol
Then we need to associate the desktop application with `org-protocol://`
links. On Pop!_OS we do this with `xdg-mime`. `xdg-mime` is a command line tool
for querying information about file type handling and adding descriptions for
new file types.

The command that matters looks like this:
```bash
xdg-mime default application mimetype(s)
```

Filling in the blanks results in the snippet below:
```bash
xdg-mime default org-protocol.desktop x-scheme-handler/org-protocol
```

## Putting it together
In order to use this, add the following bookmarklet to your browser (Firefox in
my case):

```javascript
javascript:location.href =
    'org-protocol://roam-ref?template=r&ref='
    + encodeURIComponent(location.href)
    + '&title='
    + encodeURIComponent(document.title)
    + '&body='
    + encodeURIComponent(window.getSelection().toString())
```

And then it, mostly, works.

## Finishing touches
In a past post I wrote about [how I learned to let go and ship
it][ship-it]. There are some things about this solution that aren't entirely the
way I'd want them to be. However, this mostly works and significantly lowers the
threshold for taking notes on articles online. So I'll solve the minor issues
later.

### Browser popups
Browser integration is a bit annoying. There's a per-domain popup to ask to
allow `org-protocol://` links. This exists because it's easy to abuse trust in
external protocols.

For now I can continue by pressing `Alt+O`. This is acceptable. For websites
that I end up using a lot I can allow `org-protocol://` links for that domain.

### Body
The bookmarklet contains code to capture selected text. This doesn't end up in
the capture template. Since the goal is to write a note in my own words, that
isn't a big issue.

### File name
In `org-roam` I don't care about the name of the file in which a note is
taken. At all. To reflect that, all my notes have a purely numeric file
name. I'd like to add that to notes captured with `org-roam-protocol` as well.

### Split window
Unfortunately `org-capture`, which is used to capture `org-protocol://` links,
has its own ideas on window management. This idea is to split the frame into two
windows, one of which contains the capture buffer. In this particular workflow
I'd like the capture buffer to occupy the full frame, as it's the only thing I
use the frame for.

However, `org-capture` bypasses `display-buffer` and therefore also
`display-buffer-alist`, making this hard to configure.

### Closing the application
The idea of this workflow is that I activate the bookmarklet, type a few things,
file the note and then close Emacs again. So I'd like to close the desktop
application after that. For now it's no biggie to do that manually.

## Closing thoughts
Since setting this up, the threshold to taking notes of things I read as I read
them has become low enough that I now do it all the time. There's still some
setup to be done, and I'll be sure to write about my solutions as I find them.

  [roam-github]: https://github.com/org-roam/org-roam
  [org-protocol-website]: https://orgmode.org/worg/org-contrib/org-protocol.html
  [org-roam-protocol]: https://www.orgroam.com/manual.html#Roam-Protocol
  [ship-it]: {% post_url 2021-03-26-how-i-learned-to-let-go-and-ship-it %}
