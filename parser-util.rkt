#lang racket

(require "input-util.rkt")
(require "core.rkt")

(define (eval-character ast)
    (define name #f)
    (define hp 0)
    (define energy 0)
    (define status '())
    (for ([item ast])
        (match item
            [(list 'name v) (set! name v)]
            [(list 'hp v) (set! hp (int-or-error v))]
            [(list 'energy v) (set! energy (int-or-error v))]
            [(cons 'status statuses) (set! status statuses)]
            [else (error (format "Unknown character attribute: ~a" item))]))
    (character name hp hp energy energy status))

(define (lookup-card sym e)
    (define card (findf (lambda (c) (equal? (card-name c) sym)) (env-cards e)))
    (if card
        card
        (error (format "Card not found: ~a" sym))))

(define (lookup-character sym e)
    (define character (findf (lambda (c) (equal? (character-name c) sym)) 
                             (cons (env-player e) (env-enemies e))))
    (if character
        character
        (error (format "Character not found: ~a" sym))))

(define (eval-card ast)
    (define name #f)
    (define cost 0)
    (define desc #f)
    (define effect '())
    (for ([item ast])
        (match item
            [(list 'name v) (set! name v)]
            [(list 'cost v) (set! cost (int-or-error v))]
            [(list 'desc v) (set! desc  v)]
            [(cons 'effect effects) (set! effect effects)]
            [else (error (format "Unknown card attribute: ~a" item))]))
    (card name cost desc effect))

(define (print-env e)
  (printf "—┄┄┄ Environment ┄┄┄—\n")
  (define p (env-player e))
  (printf " Player: ~a (HP: ~a/~a, Energy: ~a/~a, Status: ~a)\n"
          (character-name p)
          (character-hp    p) (character-max-hp    p)
          (character-energy p) (character-max-energy p)
          (character-status p))
  (for ([enemy (env-enemies e)])
    (printf " Enemy:  ~a (HP: ~a/~a, Energy: ~a/~a, Status: ~a)\n"
            (character-name enemy)
            (character-hp    enemy) (character-max-hp    enemy)
            (character-energy enemy) (character-max-energy enemy)
            (character-status enemy)))
  (printf " Cards in env: ~a\n" (map card-name (env-cards e)))
  (printf "—┄┄┄┄┄┄┄┄┄┄┄┄—\n"))

; 判断是否有某个状态
(define (has-status? character status)
  (ormap (lambda (s) (equal? (first s) status)) (character-status character)))

; 获取某个状态的层数
(define (get-status-count character status)
  (define found (findf (lambda (s) (equal? (first s) status)) (character-status character)))
  (if found (second found) 0))



 ; 进行状态的处理：vulnerable、weak 等减少一层。poisoned, fire 造成等同于层数的伤害后，减少一半层数（下取整）
(define status-tick
  (hash
    'poisoned (lambda (character n) (set-character-hp! character (max 0 (- (character-hp character) n))))
    'fire     (lambda (character n) (set-character-hp! character (max 0 (- (character-hp character) n))))
    'vulnerable (lambda (character n) (void))
    'weak       (lambda (character n) (void))
  ))


(define status-decay
  (hash
    'poisoned (lambda (n) (floor (/ n 2)))
    'fire     (lambda (n) (floor (/ n 2)))
    'vulnerable (lambda (n) (max 0 (- n 1)))
    'weak       (lambda (n) (max 0 (- n 1)))
  ))

(define (status-calc character)
  (define new-status
    (for/list ([s (character-status character)])
      (define status-name (first s))
      (define n (second s))
      ; tick
      (define tick-fn (hash-ref status-tick status-name (lambda (c n) (void))))
      (tick-fn character n)
      ; decay
      (define decay-fn (hash-ref status-decay status-name (lambda (n) n)))
      (define new-n (decay-fn n))
      (if (> new-n 0)
          (list status-name new-n)
          #f)))
  (set-character-status! character (filter identity new-status)))

(define (int-or-error n)
  (if (and (number? n) (exact-integer? n))
      n
      (error "Expected an integer, got: " n)))

(provide (all-defined-out))