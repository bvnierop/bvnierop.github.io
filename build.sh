#!/bin/sh
set -eu
site-emacs --no-init-file --batch --load publish.el --funcall bvn/publish-site
