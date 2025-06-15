#lang racket

(require "util.rkt")
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

; 根据环境和目标选择目标
(define (select-target who user target e) 
    (match who
        ['enemy target]
        ['all (env-enemies e)]
        ['self user]
        [else (error (format "Unknown target: ~a" who))]))

 ; 进行状态的处理：vulnerable、weak 等减少一层。poisoned, fire 造成等同于层数的伤害后，减少一半层数（下取整）
(define (status-calc character)
  (define new-status
    (for/list ([s (character-status character)])
      (match s
        [(list 'vulnerable n)
         (if (> n 1) (list 'vulnerable (- n 1)) #f)]
        [(list 'weak n)
         (if (> n 1) (list 'weak (- n 1)) #f)]
        [(list 'poisoned n)
         (when (> n 0)
           (set-character-hp! character (max 0 (- (character-hp character) n))))
         (if (>= n 2) (list 'poisoned (floor (/ n 2))) #f)]
        [(list 'fire n)
         (when (> n 0)
           (set-character-hp! character (max 0 (- (character-hp character) n))))
         (if (>= n 2) (list 'fire (floor (/ n 2))) #f)]
        [else s])))
  ; 过滤掉 #f（即已移除的状态）
  (set-character-status! character (filter identity new-status)))

(provide (all-defined-out))