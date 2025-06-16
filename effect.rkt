#lang racket

(require "util.rkt")
(require "core.rkt")
(require "parser-util.rkt")

; exprs 为 S-Exp 列表，解析一连串的effect
(define (eval-effect exprs ctx e)
    (foldl 
        (lambda (expr acc-ctx)
            (eval-one-effect expr acc-ctx e))
        ctx
        exprs))

(define (eval-one-effect expr ctx e)
    (match expr
        [(list 'target who)
            (define new-target (select-target who ctx e))
            (make-ctx-from-target ctx new-target)]
        [(list 'damage n) (handle-damage ctx n e) ctx]
        [(list 'heal n) (handle-heal ctx n e) ctx]
    ; 嵌套的 effect
        [(cons 'effect eff) (eval-effect eff ctx e)]
        [(list 'gain-energy n) (handle-mod-energy ctx n e) ctx]
        [(list 'inflict status n) (handle-inflict ctx status n e) ctx]
        [(list 'when predicate eff)
            (if (eval-pred predicate (ctx-target ctx))
                (eval-one-effect eff ctx e)
                ctx)] 
        [(list 'if predicate then-eff else-eff)
            (if (eval-pred predicate (ctx-target ctx))
                (eval-one-effect then-eff ctx e)
                (eval-one-effect else-eff ctx e))]
        [(list 'repeat n eff)
            (for/fold ([acc-ctx ctx])
                      ([i (in-range n)])
                (eval-one-effect eff acc-ctx e))]
        [(cons 'choice choices)
            (define selected (list-ref choices (random (length choices))))
            (eval-one-effect selected ctx e)]
        [else (error (format "Unknown effect: ~a" expr))]))

; 评估条件表达式
(define (eval-pred pred targetlist)
  (define target (first targetlist))
  (match pred
    [(list 'has-status status)
     (has-status? target status)]
    [(list 'status-count>= status n)
     (>= (get-status-count target status) n)]
    [(list 'hp<= pct)
     (<= (/ (character-hp target) (character-max-hp target)) (/ pct 100.0))]
    [(list 'hp> pct)
     (> (/ (character-hp target) (character-max-hp target)) (/ pct 100.0))]
    [(list 'energy>= n)
     (>= (character-energy target) n)]
    [(list 'random<= pct)
     (<= (random 100) pct)]
    [else
     (error (format "Unknown predicate: ~a" pred))]))


(define (handle-mod-energy ctx n e)
    (for ([target (ctx-target ctx)])
        (define user (ctx-user ctx))
        (printf "~a gains ~a energy\n"
                (character-name target)
                n)
        
        ; 修改能量
        (set-character-energy! user (+ (character-energy user) n))
        
        ; 输出能量信息
        (printf "New energy for ~a: ~a\n"
            (character-name user)
            (character-energy user))
    ))

(define (handle-inflict ctx status n e)
    (for ([target (ctx-target ctx)])
        (define user (ctx-user ctx))
        (printf "~a inflicts ~a on ~a with level ~a\n"
                (character-name user)
                status
                (character-name target)
                n)
        
        ; 检查是否已有该状态，增加层数
        (define current-count (get-status-count target status))
        (if (> current-count 0)
            (set-character-status! target
                (map (lambda (s)
                    (if (equal? (first s) status)
                        (list status (+ n current-count))
                        s))
                    (character-status target)))
            ; 否则添加新状态
            (set-character-status! target
                (cons (list status n) (character-status target))))
        
        ; 输出状态信息
        (printf "New status for ~a: ~a\n"
            (character-name target)
            (character-status target))))

(define (handle-damage ctx n e)
    ; TODO 目前只处理单个目标
    ; 只处理了易损状态
     (for ([target (ctx-target ctx)])

        (define user (ctx-user ctx))
        (define weakened-damage
        (let ([base-damage n])
            (if (has-status? user 'weak)
                (floor (* base-damage 0.75))  ; 0.75倍乘区
                base-damage)))

        (define actual-damage
        (let ([base-damage weakened-damage])
            (if (has-status? target 'vulnerable)
                (floor (* base-damage 1.5))  ; 1.5倍乘区
                base-damage)))

        
        (let ([new-hp (max 0 (- (character-hp target) actual-damage))])
            (set-character-hp! target new-hp))
            
        (printf "~a dealt ~a damage to ~a, new HP: ~a\n"
                (character-name user)
                actual-damage
                (character-name target)
                (character-hp target))))


(define (handle-heal ctx n e)
    (for ([target (ctx-target ctx)])
            (define user (ctx-user ctx))
            (let ([new-hp (min (character-max-hp target)
                    (+ (character-hp target) n))])
            (set-character-hp! target new-hp))
            (printf "~a Healed ~a HP to ~a, new HP: ~a\n"
                    (character-name user)
                    n
                    (character-name target)
                    (character-hp target)))
)

; 根据环境和上下文选择目标
(define (select-target who ctx e) 
    (match who
        ['enemy (make-target (ctx-intent ctx))]
        ['all (env-enemies e)]
        ['self (make-target (ctx-user ctx))]
        [else (error (format "Unknown target: ~a" who))]))


(provide (all-defined-out))