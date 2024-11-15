;; Required for source code coloring
(setq org-html-htmlize-output-type 'css)

(require 'package)
(package-initialize)
(unless package-archive-contents
  (add-to-list 'package-archives '("gnu" . "https://elpa.gnu.org/packages/") t)
  (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
  (package-refresh-contents))
(dolist (pkg '(htmlize dash s fsharp-mode))
  (unless (package-installed-p pkg)
    (package-install pkg)))

(require 'ox-publish)
(require 's)
(require 'cl) ; for lexical-let


;;;;;;;;;;;;;;;;;;;;
;; Custom export back-end that removes index.html from links
(defun bvn/blog-html-link (link contents info)
  (let ((html-link (org-html-link link contents info)))
    (s-replace "/index.html\">" "\">" html-link)))

(org-export-define-derived-backend 'bvn/blog-html 'html
  :translate-alist '((link . bvn/blog-html-link)))

(defun bvn/blog-html-publish-to-blog-html (plist filename pub-dir)
  (org-publish-org-to 'bvn/blog-html filename
		      (concat (when (> (length org-html-extension) 0) ".")
			      (or (plist-get plist :html-extension)
				  org-html-extension
				  "html"))
		      plist pub-dir))

;;;;;;;;;;;;;;;;;;;;
(defun bvn/read-metadata-from-org-file (filename tag)
  "Reads metadata from org file FILENAME, specifically the value of TAG"
  (let ((case-fold-search t))
    (with-temp-buffer
      (insert-file-contents filename)
      (goto-char (point-min))
      (ignore-errors
        (progn
          (search-forward-regexp (format "^\\#\\+%s\\:\s+\\(.+\\)$" tag))
          (match-string 1))))))

(defun bvn/post-draft? (filename)
  (bvn/read-metadata-from-org-file filename "DRAFT"))

(defun bvn/post-future? (filename target-date)
  "Check if post in FILENAME has a publish date after TARGET-DATE"
  (let* ((date-string (bvn/read-metadata-from-org-file filename "DATE"))
         (post-date (org-time-string-to-time date-string)))
    (when post-date
      (time-less-p target-date post-date))))

(defun bvn/post-published? (filename)
  "Check if post in FILENAME should be published based on current date"
  (not (bvn/post-future? filename (current-time))))

(defun format-pre/postamble (filename)
  (list (list "en" (with-temp-buffer
                     (insert-file-contents (expand-file-name (format "%s" filename) "./snippets"))
                     (buffer-string)))))

(defun bvn/publish-post-to-html (plist filename pub-dir)
  (let ((project (cons 'blog plist)))
    (plist-put plist :subtitle
               (format-time-string "%b %d, %Y" (org-publish-find-date filename project)))
    (bvn/blog-html-publish-to-blog-html plist filename pub-dir)))

(defun bvn/publish-last-posts-sitemap (title sitemap)
  "Filter sitemap entries to be the last 5 posts"
  (let* ((posts (cdr sitemap))
         (list (cl-remove-if-not (lambda (post) (car post)) posts)))
    (concat (format "#+TITLE: %s\n\n" title)
            (org-list-to-org (cons (car sitemap) list)))))

(defun bvn/sitemap-format-entry (folder)
  "Creates a function that formats an entry to the sitemap.
   ~FOLDER~ is the subfolder where the sitemap should be generated,
   ie \"posts\" or \"talks\""
  (lexical-let ((f folder))
    (lambda (entry style project)
      (let ((file-path (concat "site/" f "/" entry)))
        (when (and (not (bvn/post-draft? file-path))
                   (bvn/post-published? file-path))
          (format "%s ..... [[file:%s][%s]]"
                  (format-time-string "%Y-%m-%d" (org-publish-find-date entry project))
                  entry
                  (org-publish-find-title entry project)))))))

;; html 5
(setq org-html-doctype "html5"
      org-html-html5-fancy t)

;; Don't use default styling
(setq org-html-head-include-default-style nil)
;; Use my own style instead
(setq org-html-divs '((preamble  "header" "preamble")
                      (content   "main"   "content")
                      (postamble "footer" "postamble")))

(setq org-html-head
      "<link rel=\"stylesheet\" href=\"https://use.fontawesome.com/releases/v5.15.4/css/all.css\" integrity=\"sha384-DyZ88mC6Up2uqS4h/KRgHuoeGwBcD4Ng9SiP4dIRy0EXTlnuz47vAwmeGwVChigm\" crossorigin=\"anonymous\"> \
       <link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/water.css@2/out/light.css\"> \
       <link rel=\"stylesheet\" href=\"/css/style.css\"> \
	  \
      <!-- Icons --> \
      <link rel=\"apple-touch-icon\" sizes=\"180x180\" href=\"/img/icons/apple-touch-icon.png\"> \
      <link rel=\"icon\" type=\"image/png\" sizes=\"32x32\" href=\"/img/icons/favicon-32x32.png\"> \
      <link rel=\"icon\" type=\"image/png\" sizes=\"16x16\" href=\"/img/icons/favicon-16x16.png\"> \
      <link rel=\"manifest\" href=\"/img/icons/site.webmanifest\"> \
      <link rel=\"mask-icon\" href=\"/img/icons/safari-pinned-tab.svg\" color=\"#5bbad5\"> \
      <link rel=\"shortcut icon\" href=\"/img/icons/favicon.ico\"> \
      <meta name=\"msapplication-TileColor\" content=\"#da532c\"> \
      <meta name=\"msapplication-config\" content=\"/img/icons/browserconfig.xml\"> \
      <meta name=\"theme-color\" content=\"#ffffff\">"
      )

;; Source coloring

;; Only use subscript and superscripts when the section
;; after an _ or ^ is enclosed in curly braces.
(setq org-export-with-sub-superscripts '{})

(setq org-publish-project-alist
      (list
       (list "working-copy"
             :publishing-function 'org-publish-attachment
             :base-directory "./site"
             :publishing-directory "./.working-copy"
             :recursive t
             :include '("CNAME")
             :base-extension ".*")
             
       (list "posts"									;; name of the project
             :base-directory "./.working-copy/posts"				;; directory to take files from
             :base-extension "org"						;; only take files with this extension
             :publishing-directory "./.publish/posts"	;; output directory
             :recursive t								;; parse recursively, otherwise only index.org would be parsed
             :publishing-function 'bvn/publish-post-to-html ;; publish as html

             :section-numbers nil
             :with-toc nil

             :html-preamble t
             :html-preamble-format (format-pre/postamble "preamble.html")
             :html-postamble t
             :html-postamble-format (format-pre/postamble "postamble.html")

             :auto-sitemap t
             :sitemap-filename "last-posts.org"
             :sitemap-function 'bvn/publish-last-posts-sitemap
             :sitemap-format-entry (bvn/sitemap-format-entry "posts")
             :sitemap-style 'list
             :sitemap-title " "
             :sitemap-sort-files 'anti-chronologically)

       (list "posts-index"
             :base-directory "./.working-copy/posts"
             :base-extension "org"
             :exclude (regexp-opt '("last-posts.org"))
             :publishing-directory "./.publish/posts"
             :recursive t

             :publishing-function 'ignore

             :auto-sitemap t
             :sitemap-filename "index.org"
             :sitemap-style 'list
             :sitemap-title "Posts archive"
             :sitemap-function 'bvn/publish-last-posts-sitemap
             :sitemap-format-entry (bvn/sitemap-format-entry "posts")
             :sitemap-sort-files 'anti-chronologically)

       (list "talks"									;; name of the project
             :base-directory "./.working-copy/talks"				;; directory to take files from
             :base-extension "org"						;; only take files with this extension
             :publishing-directory "./.publish/talks"	;; output directory
             :recursive t								;; parse recursively, otherwise only index.org would be parsed
             :publishing-function 'bvn/publish-post-to-html ;; publish as html

             :section-numbers nil
             :with-toc nil

             :html-preamble t
             :html-preamble-format (format-pre/postamble "preamble.html")
             :html-postamble t
             :html-postamble-format (format-pre/postamble "postamble.html")

             :auto-sitemap t
             :sitemap-filename "last-talks.org"
             :sitemap-function 'bvn/publish-last-posts-sitemap
             :sitemap-format-entry (bvn/sitemap-format-entry "talks")
             :sitemap-style 'list
             :sitemap-title " "
             :sitemap-sort-files 'anti-chronologically)

       (list "talks-index"
             :base-directory "./.working-copy/talks"
             :base-extension "org"
             :exclude (regexp-opt '("last-talks.org"))
             :publishing-directory "./.publish/talks"
             :recursive t

             :publishing-function 'ignore

             :auto-sitemap t
             :sitemap-filename "index.org"
             :sitemap-style 'list
             :sitemap-title "Talks archive"
             :sitemap-function 'bvn/publish-last-posts-sitemap
             :sitemap-format-entry (bvn/sitemap-format-entry "talks")
             :sitemap-sort-files 'anti-chronologically)

       (list "pages"
             :base-directory "./.working-copy"
             :base-extension ""
             :exclude (regexp-opt '(".*"))
             :include '("index.org" "posts/index.org" "talks/index.org")
             :publishing-directory "./.publish"
             :recursive t

             :publishing-function 'bvn/blog-html-publish-to-blog-html

             :section-numbers nil
             :with-toc nil

             :html-preamble t
             :html-preamble-format (format-pre/postamble "preamble.html")
             :html-postamble t
             :html-postamble-format (format-pre/postamble "postamble.html"))

       (list "assets"
             :base-directory "./.working-copy"
             :base-extension "css\\|png\\|jpg"
             :include '("CNAME" "robots.txt")
             :publishing-directory "./.publish"
             :recursive t

             :publishing-function 'org-publish-attachment)
       (list "website" :components (list "working-copy" "posts" "posts-index" "talks" "talks-index" "pages" "assets"))))

(org-publish-remove-all-timestamps)
(org-publish "website" t)
