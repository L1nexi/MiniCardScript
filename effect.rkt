#lang racket

(require "util.rkt")
(require "core.rkt")
(require "parser-util.rkt")

; 效果解释器
(define (eval-effect exprs user target e)
    (define current-target target)
    (for ([expr exprs])
        (match expr
            [(list 'target who)
             (set! current-target 
                    (select-target who user target e))]
            [(list 'damage n) (handle-damage user current-target n e)]
            [(list 'heal n) (handle-heal user current-target n e)]
        ; 嵌套的 effect
            [(cons 'effect eff) (eval-effect eff user target e)]
            [(list 'when predicate (cons 'effect eff))
                (when (eval-pred predicate current-target)
                    (eval-effect eff user target e))] 
            [(list 'if predicate (cons 'effect then-eff) (cons 'effect else-eff))
                (if (eval-pred predicate current-target)
                    (eval-effect then-eff target user e)
                    (eval-effect else-eff target user e))]
            [(list 'gain-energy n) (handle-mod-energy user current-target n e)]
            [(list 'inflict status n) (handle-inflict user current-target status n e)]
            [else (error (format "Unknown effect: ~a" e))])))

; 评估条件表达式
(define (eval-pred pred target)
  (match pred
    [(list 'has-status status)
     (has-status? target status)]
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


(define (handle-mod-energy user target n e)
    (printf "~a gains ~a energy\n"
            (character-name target)
            n)
    
    ; 修改能量
    (set-character-energy! user (+ (character-energy user) n))
    
    ; 输出能量信息
    (printf "New energy for ~a: ~a\n"
           (character-name user)
           (character-energy user))
    e)

(define (handle-inflict user target status n e)
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
           (character-status target))
    e)

(define (handle-damage user target n e)
    ; TODO 目前只处理单个目标
    ; 只处理了易损状态
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
            (character-hp target)))

(define (handle-heal user target n e)
    (let ([new-hp (min (character-max-hp target)
                        (+ (character-hp target) n))])
        (set-character-hp! target new-hp))
    
    (printf "Healed ~a HP to ~a, new HP: ~a\n"
            n
            (character-name target)
            (character-hp target)))


(provide (all-defined-out))