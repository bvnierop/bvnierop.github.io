---
layout: post
title: How I Learned To Let Go And Just Ship
date: 2021-03-26 +0100
categories:
---

In early February I decided that maybe I should start a Jekyll based website,
hosted on GitHub Pages. Almost two months later, this is the first _real_ post.

## Humble beginnings
It starts simple. You think "I know, I'll start a website!" You decide on tech,
hack together or search for a simple theme and publish. "There!" you think,
"We're up!"

This is exactly what I did. The initial one line post is still here. But then it
begins. There a *ton* of stuff I still wanted to do. In the end this resulted in
not doing anything for far too long. Not that I didn't _do_ anything. I did
plenty. But for a long time nobody could see it but me. And I was not producing
any content.

## So much to do
So what did I want to do? I wanted a better theme. I quickly noticed that even
though it's not hard to set up Jekyll locally, things work different between
local and GitHub Pages, so I wanted a staging environment.

I wanted my staging environment to be on a subdomain. But not indexed on
Google. So I had to get `robots.txt` working.

I wanted a workflow that reflected this. A workflow where I'd go from a
`staging` repository to a `main` repository, without affecting the drafts or
posts.

Speaking of drafts, I also wanted drafts to not be in a public GitHub
repository, but still be on GitHub.

I was, and still am, constantly debating if I want only an apex domain, only a
`www` subdomain, or both.

I wanted to develop locally without 'infecting' my system with Ruby. It's not
that I have anything agaist Ruby, but I have a million different little projects
in a million different (versions of) languages. I don't want all these to
clutter my machines.

I want analytics. Nothing fancy. Preferably not Google. Really all I want is
page views. If I were hosting this thing myself then I'd just grep the logs. But
it's on GitHub Pages, so I'm going to have to go with a Javascript based
solution.

I want categories. I want _see also_. I want series of posts. I want comments. I
want an RSS feed. Perhaps I should do something about SEO. 

And I wanted content. I wanted content ready _before_ going live for real. So
that I could schedule that.

That's a lot of things to do while also maintaining a full time job and a
life. Despite COVID-19, I don't have _that_ much free time. And to be fair, it
started to look like work instead of fun. And that's how two months pass.

## So now that all of this is done
It isn't. Not nearly. But we're two months in and I want this thing live. So
here we go. It's shipped.

I'm using a remote theme. It's okay if that breaks during development. I can see
that locally. So I don't need a staging environment or a convoluted workflow.

I no longer really care about drafts. If there are any and someone sees them,
then so be it.

I use [Nix][nix-website]{:target="_blank" rel="nofollow noopener noreferrer"} to
keep my installation clean. I'm not yet sure how happy I am with it, but it's
interesting to play with nonetheless.

And now here we are. It's live. There's still plenty of things to do. Now that
I've shipped, content comes first. And all those other things? They'll
come. Shipping 10% of the things you want is a lot better than never shipping at
all.

  [nix-website]: https://nixos.org
