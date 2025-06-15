#lang racket

(define (read-s-exprs filename)
  (call-with-input-file filename
    (lambda (in)
      (port->list read in))))

(unless (= (vector-length (current-command-line-arguments)) 1)
  (error "Usage: racket eval.rkt <filename>"))

(define filename (vector-ref (current-command-line-arguments) 0))

(unless (file-exists? filename)
  (error (format "File ~a does not exist" filename)))

(define ast (read-s-exprs filename))

(provide read-s-exprs filename ast)