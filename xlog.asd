;;;; xlog.asd
;;;; Copyright (c) 2008-2026 Ciex-Security <wgl@ciex-security.com>
;;;; License: MIT

(asdf:defsystem #:xlog
  :description "Application logger with nested stack support"
  :author "wgl@ciex-security.com"
  :license "MIT"
  :version "1.3.40"
  :serial t
  :components ((:file "xlog-pkg")
               (:file "xlog")))
