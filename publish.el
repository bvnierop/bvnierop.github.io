;;; publish.el --- Publish bvnierop.github.io -*- lexical-binding: t; -*-

;;; Dependencies
(require 'cl-lib)
(require 'ox-publish)
(require 'subr-x)

;;; Paths and constants
(defconst bvn/project-root (file-name-directory (file-truename (or load-file-name buffer-file-name))))
(defconst bvn/source-root (file-name-as-directory (expand-file-name "site" bvn/project-root)))
(defconst bvn/snippet-root (file-name-as-directory (expand-file-name "snippets" bvn/project-root)))
(defconst bvn/working-root (file-name-as-directory (expand-file-name ".working-copy" bvn/project-root)))
(defconst bvn/publish-root (file-name-as-directory (expand-file-name ".publish" bvn/project-root)))
(defconst bvn/working-post-root (expand-file-name "posts" bvn/working-root))
(defconst bvn/working-talk-root (expand-file-name "talks" bvn/working-root))
(defconst bvn/working-tag-root (expand-file-name "posts/tags" bvn/working-root))
(defconst bvn/post-exclusion-regexp "\\`\\(?:index\\.org\\|last-posts\\.org\\|tags/\\)")
(defconst bvn/talk-exclusion-regexp "\\`index\\.org\\'")
(defvar bvn/content-by-file (make-hash-table :test #'equal))

(defun bvn/normalized-path (path)
  "Return normalized absolute PATH, resolving existing ancestors and symlinks."
  (let ((absolute (expand-file-name path)) missing candidate)
    (setq candidate absolute)
    (while (not (file-exists-p candidate))
      (push (file-name-nondirectory (directory-file-name candidate)) missing)
      (setq candidate (file-name-directory (directory-file-name candidate))))
    (let ((result (file-truename candidate)))
      (dolist (part missing result)
        (setq result (expand-file-name part result))))))

(defun bvn/path-child-p (path root)
  (let ((p (directory-file-name (bvn/normalized-path path)))
        (r (directory-file-name (bvn/normalized-path root))))
    (and (not (equal p r)) (file-in-directory-p p r))))

(defun bvn/guard-working-child (path)
  (unless (bvn/path-child-p path bvn/working-root)
    (error "Refusing path %s: required strict child of %s" path bvn/working-root))
  path)

(defun bvn/guard-disposable-root (path)
  (let ((p (directory-file-name (bvn/normalized-path path)))
        (w (directory-file-name (bvn/normalized-path bvn/working-root)))
        (o (directory-file-name (bvn/normalized-path bvn/publish-root))))
    (unless (or (equal p w) (equal p o))
      (error "Refusing disposable path %s: allowed roots are %s and %s" path w o)))
  path)

(defun bvn/reset-disposable-root (root)
  "Remove children of allow-listed disposable ROOT, preserving ROOT itself."
  (bvn/guard-disposable-root root)
  (make-directory root t)
  (dolist (child (directory-files root t directory-files-no-dot-files-regexp))
    (if (or (file-symlink-p child) (not (file-directory-p child)))
        (delete-file child)
      (delete-directory child t))))

(defun bvn/reset-generated-tag-subtree ()
  (bvn/guard-working-child bvn/working-tag-root)
  (when (file-exists-p bvn/working-tag-root) (delete-directory bvn/working-tag-root t))
  (make-directory bvn/working-tag-root t))

(defun bvn/write-generated-source (file content)
  (bvn/guard-working-child file)
  (make-directory (file-name-directory file) t)
  (with-temp-file file (insert content)))

;;; HTML export backend
(defun bvn/blog-html-link (link contents info)
  (string-replace "/index.html\">" "\">" (org-html-link link contents info)))
(org-export-define-derived-backend 'bvn/blog-html 'html :translate-alist '((link . bvn/blog-html-link)))
(defun bvn/blog-html-publish-to-blog-html (plist filename pub-dir)
  (org-publish-org-to 'bvn/blog-html filename (concat (when (> (length org-html-extension) 0) ".")
                                                      (or (plist-get plist :html-extension) org-html-extension "html")) plist pub-dir))

;;; Metadata and visibility
(defun bvn/parse-tags (raw)
  (let (result)
    (dolist (tag (split-string (or raw "") "[[:space:]]+" t) (nreverse result))
      (unless (member tag result) (push tag result)))))

(defun bvn/keyword-value (keywords name)
  (cadr (assoc-string name keywords t)))

(defun bvn/required-metadata (file field value)
  (setq value (and value (string-trim value)))
  (unless (and value (not (string-empty-p value))) (error "%s %s is missing" file field))
  value)

(defun bvn/read-content-metadata (file kind root build-time)
  "Read all metadata for FILE once and return its content record."
  (let (keywords)
    (with-temp-buffer
      (insert-file-contents file)
      (org-mode)
      (setq keywords (org-collect-keywords '("TITLE" "DATE" "DRAFT" "FILETAGS")))
      (let* ((title (bvn/required-metadata file "TITLE" (bvn/keyword-value keywords "TITLE")))
             (date-text (bvn/required-metadata file "DATE" (bvn/keyword-value keywords "DATE")))
             (date (condition-case err (org-time-string-to-time date-text)
                     (error (error "%s DATE is invalid: %s" file (error-message-string err)))))
             (draft (bvn/keyword-value keywords "DRAFT"))
             (visible (and (not (and draft
                                     (not (string-empty-p (string-trim draft)))))
                           (not (time-less-p build-time date))))
             (source (bvn/normalized-path file)))
        (list :kind kind :source-file source :relative-file (file-relative-name source root)
              :title title :date date :visible visible
              :tags (bvn/parse-tags (bvn/keyword-value keywords "FILETAGS")))))))

(defun bvn/content-sorter (records)
  (sort (copy-sequence records)
        (lambda (a b) (if (equal (plist-get a :date) (plist-get b :date))
                          (string< (plist-get a :relative-file) (plist-get b :relative-file))
                        (time-less-p (plist-get b :date) (plist-get a :date))))))

(defun bvn/collect-content (root kind reserved build-time)
  (let (result)
    (dolist (file (directory-files-recursively root "\\`index\\.org\\'"))
      (let ((relative (file-relative-name file root)))
        (unless (seq-some (lambda (r) (or (string= relative r) (string-prefix-p r relative))) reserved)
          (let ((record (bvn/read-content-metadata file kind root build-time)))
            (puthash (plist-get record :source-file) record bvn/content-by-file)
            (push record result)))))
    result))

(defun bvn/tag-groups (posts)
  (let ((groups (make-hash-table :test #'equal))
        (owners (make-hash-table :test #'equal)))
    (dolist (post posts)
      (dolist (tag (plist-get post :tags))
        (let* ((slug (bvn/tag-slug tag))
               (owner (gethash slug owners)))
          (when (and owner (not (string= owner tag)))
            (error "Tags %S and %S share slug %S" owner tag slug))
          (puthash slug tag owners)
          (let ((group (gethash tag groups)))
            (puthash tag (list :name tag :slug slug
                               :posts (cons post (plist-get group :posts))) groups)))))
    (let (result)
      (maphash (lambda (_name group)
                 (push (plist-put group :posts
                                  (bvn/content-sorter (plist-get group :posts))) result))
               groups)
      (sort result
            (lambda (a b)
              (let ((x (plist-get a :name)) (y (plist-get b :name)))
                (if (string= (downcase x) (downcase y))
                    (string< x y)
                  (string< (downcase x) (downcase y)))))))))

(defun bvn/tag-slug (tag)
  (let ((slug (replace-regexp-in-string "\\`-+\\|-+\\'" ""
                                        (replace-regexp-in-string "[^a-z0-9]+" "-" (downcase tag)))))
    (if (string-empty-p slug) (error "Tag %S has an empty slug" tag) slug)))

(defun bvn/build-content-model ()
  (setq bvn/content-by-file (make-hash-table :test #'equal))
  (let* ((now (current-time))
         (posts (bvn/collect-content bvn/working-post-root 'post '("index.org" "last-posts.org" "tags/") now))
         (talks (bvn/collect-content bvn/working-talk-root 'talk '("index.org" "last-talks.org") now))
         (visible-posts (bvn/content-sorter (cl-remove-if-not (lambda (x) (plist-get x :visible)) posts)))
         (visible-talks (bvn/content-sorter (cl-remove-if-not (lambda (x) (plist-get x :visible)) talks)))
         (groups (bvn/tag-groups visible-posts)))
    (list :posts posts :visible-posts visible-posts :talks talks :visible-talks visible-talks :tag-groups groups)))

(defun bvn/content-record-for-file (file kind)
  (let ((record (gethash (bvn/normalized-path file) bvn/content-by-file)))
    (unless (and record (eq (plist-get record :kind) kind))
      (error "No %s content record for %s" kind file))
    record))

;;; Archive rendering
(defun bvn/render-archive-entry (record generated-file)
  (format "- %s ..... [[file:%s][%s]]" (format-time-string "%Y-%m-%d" (plist-get record :date))
          (file-relative-name (plist-get record :source-file) (file-name-directory generated-file))
          (plist-get record :title)))
(defun bvn/render-list (records generated-file)
  (mapconcat (lambda (r) (bvn/render-archive-entry r generated-file)) records "\n"))
(defun bvn/render-tag-columns (groups)
  (concat "#+ATTR_HTML: :style columns:2\n" (mapconcat (lambda (g) (format "- [[file:tags/%s/index.org][%s]]" (plist-get g :slug) (plist-get g :name))) groups "\n")))

;;; Post tags
;;; Generated working-copy pages
(defun bvn/generate-working-pages (model)
  (let* ((posts-file (expand-file-name "posts/index.org" bvn/working-root))
         (last-file (expand-file-name "posts/last-posts.org" bvn/working-root))
         (talks-file (expand-file-name "talks/index.org" bvn/working-root))
         (groups (plist-get model :tag-groups)))
    (bvn/reset-generated-tag-subtree)
    (bvn/write-generated-source
     last-file (concat (bvn/render-list (plist-get model :visible-posts) last-file) "\n"))
    (bvn/write-generated-source
     posts-file
     (format "#+TITLE: Posts archive\n\n* Tags\n%s\n\n* All posts\n%s\n"
             (bvn/render-tag-columns groups)
             (bvn/render-list (plist-get model :visible-posts) posts-file)))
    (dolist (group groups)
      (let ((file (expand-file-name (format "%s/index.org" (plist-get group :slug))
                                    bvn/working-tag-root)))
        (bvn/write-generated-source
         file
         (format "#+TITLE: Posts tagged: %s\n\n%s\n"
                 (plist-get group :name)
                 (bvn/render-list (plist-get group :posts) file)))))
    (bvn/write-generated-source
     talks-file
     (format "#+TITLE: Talks archive\n\n%s\n"
             (bvn/render-list (plist-get model :visible-talks) talks-file)))))

;;; HTML publishing helpers
(defun bvn/format-post-date (time)
  (let ((date (format-time-string "%b %d, %Y" time))) (concat (upcase (substring date 0 1)) (substring date 1))))
(defun bvn/post-tag-link (record tag)
  (let* ((target (expand-file-name (format "%s/index.org" (bvn/tag-slug tag)) bvn/working-tag-root))
         (relative (file-relative-name target (file-name-directory (plist-get record :source-file)))))
    (format "[[file:%s][%s]]" relative tag)))
(defun bvn/post-subtitle (filename)
  (let* ((record (bvn/content-record-for-file filename 'post)) (date (bvn/format-post-date (plist-get record :date)))
         (text (if (or (not (plist-get record :visible)) (null (plist-get record :tags))) date
                 (concat date " · Tags: " (mapconcat (lambda (tag) (bvn/post-tag-link record tag)) (plist-get record :tags) " | ")))))
    (org-element-parse-secondary-string text (org-element-restriction 'keyword))))
(defun bvn/publish-post-to-html (plist filename pub-dir)
  (let ((copy (copy-sequence plist))) (setq copy (plist-put copy :subtitle (bvn/post-subtitle filename)))
       (bvn/blog-html-publish-to-blog-html copy filename pub-dir)))
(defun bvn/publish-talk-to-html (plist filename pub-dir)
  (let ((copy (copy-sequence plist)) (record (bvn/content-record-for-file filename 'talk)))
    (setq copy (plist-put copy :subtitle (bvn/format-post-date (plist-get record :date))))
    (bvn/blog-html-publish-to-blog-html copy filename pub-dir)))

;;; Org HTML configuration
(setq org-html-htmlize-output-type 'css org-html-doctype "html5" org-html-html5-fancy t
      org-html-head-include-default-style nil org-export-with-sub-superscripts '{}
      org-html-divs '((preamble "header" "preamble") (content "main" "content") (postamble "footer" "postamble"))
      org-html-head "<link rel=\"stylesheet\" href=\"https://use.fontawesome.com/releases/v5.15.4/css/all.css\"> <link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/water.css@2/out/light.css\"> <link rel=\"stylesheet\" href=\"/css/style.css\">")
(defun bvn/html-snippet-format (filename)
  (list (list "en" (with-temp-buffer (insert-file-contents (expand-file-name filename bvn/snippet-root)) (buffer-string)))))
(defun bvn/html-project-options ()
  (list :section-numbers nil :with-toc nil :html-preamble t :html-preamble-format (bvn/html-snippet-format "preamble.html")
        :html-postamble t :html-postamble-format (bvn/html-snippet-format "postamble.html")))

;;; Publishing projects
(setq org-publish-project-alist
      (list
       (list "working-copy"
             :base-directory bvn/source-root
             :publishing-directory bvn/working-root
             :recursive t
             :base-extension ".*"
             :include '("CNAME")
             :publishing-function 'org-publish-attachment)
       (append
        (list "posts"
              :base-directory bvn/working-post-root
              :base-extension "org"
              :publishing-directory (expand-file-name "posts" bvn/publish-root)
              :recursive t
              :publishing-function 'bvn/publish-post-to-html
              :exclude bvn/post-exclusion-regexp)
        (bvn/html-project-options))
       (append
        (list "post-tags"
              :base-directory bvn/working-tag-root
              :base-extension "org"
              :publishing-directory (expand-file-name "posts/tags" bvn/publish-root)
              :recursive t
              :publishing-function 'bvn/blog-html-publish-to-blog-html)
        (bvn/html-project-options))
       (append
        (list "talks" :base-directory bvn/working-talk-root
              :base-extension "org" :publishing-directory (expand-file-name "talks"
                                                                            bvn/publish-root) :recursive t :publishing-function
              'bvn/publish-talk-to-html :exclude bvn/talk-exclusion-regexp)
        (bvn/html-project-options))
       (append
        (list "pages"
              :base-directory bvn/working-root
              :base-extension "org"
              :publishing-directory bvn/publish-root
              :recursive t
              :include '("index.org" "posts/index.org" "talks/index.org")
              :exclude "\\`\\(?:posts/[^/]+/index\\.org\\|posts/last-posts\\.org\\|talks/[^/]+/index\\.org\\|404\\.org\\)"
              :publishing-function 'bvn/blog-html-publish-to-blog-html)
        (bvn/html-project-options))
       (list "assets"
             :base-directory bvn/working-root
             :base-extension "css\\|png\\|jpg\\|pdf"
             :include '("CNAME" "robots.txt")
             :publishing-directory bvn/publish-root
             :recursive t
             :publishing-function 'org-publish-attachment)
       (list "website"
             :components '("posts" "post-tags" "talks" "pages" "assets"))))

;;; Build entry point
(defun bvn/publish-site ()
  (setq bvn/content-by-file (make-hash-table :test #'equal))
  (bvn/reset-disposable-root bvn/working-root)
  (bvn/reset-disposable-root bvn/publish-root)
  (org-publish-remove-all-timestamps)
  (org-publish "working-copy" t)
  (let ((model (bvn/build-content-model)))
    (bvn/generate-working-pages model)
    (org-publish "website" t)
    model))

;;; publish.el ends here
