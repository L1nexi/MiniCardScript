#lang racket

(require "input-util.rkt")
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
        [(list 'damage n) (handle-damage ctx (eval-expr n ctx e) e) ctx]
        [(list 'heal n) (handle-heal ctx (eval-expr n ctx e) e) ctx]
    ; 嵌套的 effect
        [(cons 'effect eff) (eval-effect eff ctx e)]
        [(list 'gain-energy n) (handle-mod-energy ctx (eval-expr n ctx e) e) ctx]
        [(list 'inflict status n) (handle-inflict ctx status (eval-expr n ctx e) e) ctx]
        [(list 'reduce status n) (handle-reduce ctx status (eval-expr n ctx e) e) ctx]
        [(list 'remove-status status) (handle-remove-status ctx status e) ctx]
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
                      ([i (in-range (eval-expr n ctx e))])
                (eval-one-effect eff acc-ctx e))]
        [(cons 'choice choices)
            (define selected (list-ref choices (random (length choices))))
            (eval-one-effect selected ctx e)]
        [(cons 'let (cons bindings body))
            (eval-let bindings body ctx e)]
        [else (error (format "Unknown effect: ~a" expr))]))

(define (eval-let bindings body ctx e)
  (define new-vars
    (map (lambda (b)
           (match b
             [(list var expr)
              (cons var (eval-expr expr ctx e))]))
         bindings))
  (define extended-ctx
    (extend-ctx ctx new-vars))
  (eval-effect body extended-ctx e)
  ; 返回旧的上下文
  ctx)

(define (eval-expr expr ctx e)
  (cond
    [(number? expr) expr]
    [(symbol? expr) (lookup-var expr ctx)]
    [(list? expr) (eval-call expr ctx e)]
    [else (error (format "Unknown expression: ~a" expr))]))

(define (lookup-var name ctx)
  (define val (assoc name (ctx-vars ctx)))
  (if val
      (cdr val)
      (error (format "Unbound variable: ~a" name))))

(define (eval-call expr ctx e)
  (match expr
    [(list '* a b)
     (* (eval-expr a ctx e) (eval-expr b ctx e))]
    [(list '+ a b)
     (+ (eval-expr a ctx e) (eval-expr b ctx e))]
    [(list '- a b)
     (- (eval-expr a ctx e) (eval-expr b ctx e))]
    [(list '/ a b)
     (floor (/ (eval-expr a ctx e) (eval-expr b ctx e)))]
    [(list 'min a b)
     (min (eval-expr a ctx e) (eval-expr b ctx e))]
    [(list 'max a b)
     (max (eval-expr a ctx e) (eval-expr b ctx e))]
    [(list 'get-status status)
     (get-status-count (first (ctx-target ctx)) status)]
    [else (error (format "Unknown function call: ~a" expr))]))

; 评估条件表达式
(define (eval-pred pred targetlist)
  (define target (first targetlist))
  (match pred
    [(cons 'and preds)
     (andmap (lambda (p) (eval-pred p targetlist)) preds)]
    [(cons 'or preds)
     (ormap (lambda (p) (eval-pred p targetlist)) preds)]
    [(list 'not p)
     (not (eval-pred p targetlist))]
    [(list 'has-status status)
     (has-status? target status)]
    [(list 'status-count>= status n)
     (>= (get-status-count target status) n)]
    [(list 'hp<= pct)
     (<= (/ (character-hp target) (character-max-hp target)) (/ pct 100.0))]
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

(define (handle-reduce ctx status n e)
    (for ([target (ctx-target ctx)])
        (define user (ctx-user ctx))
        (printf "~a reduces ~a on ~a with level ~a\n"
                (character-name user)
                status
                (character-name target)
                n)
        
        ; 检查是否已有该状态，且层数大于需减少量
        (define current-count (get-status-count target status))
        (if (> current-count n)
            (set-character-status! target
                (map (lambda (s)
                    (if (equal? (first s) status)
                        (list status (- current-count n))
                        s))
                    (character-status target)))
            ; 否则删除原有状态
            (set-character-status! target
                (filter (lambda (item) (not (equal? (first item) status))))))
        
        ; 输出状态信息
        (printf "New status for ~a: ~a\n"
            (character-name target)
            (character-status target))))

(define (handle-remove-status ctx status e)
    (for ([target (ctx-target ctx)])
        (define user (ctx-user ctx))
        (printf "~a remove ~a on ~a \n"
                (character-name user)
                status
                (character-name target)
                )

        ; 删除对应状态
        (set-character-status! target
            (filter (lambda (item) (not (equal? (first item) status))) (character-status target)))
        
        ; 输出状态信息
        (printf "New status for ~a: ~a\n"
            (character-name target)
            (character-status target))))    

(define (handle-damage ctx n e)
  (for ([target (ctx-target ctx)])
    (define user (ctx-user ctx))
    (define block (get-status-count target 'block))
    (define weakened-damage
      (let ([base-damage n])
        (if (has-status? user 'weak)
            (floor (* base-damage 0.75))
            base-damage)))
    (define actual-damage
      (let ([base-damage weakened-damage])
        (if (has-status? target 'vulnerable)
            (floor (* base-damage 1.5))
            base-damage)))
    (define block-used (min block actual-damage))
    (define hp-damage (max 0 (- actual-damage block)))
    ; 扣除 block
    (when (> block 0)
      (set-character-status! target
        (map (lambda (s)
               (if (equal? (first s) 'block)
                   (list 'block (- (second s) block-used))
                   s))
             (character-status target))))
    ; 扣除 HP
    (let ([new-hp (max 0 (- (character-hp target) hp-damage))])
      (set-character-hp! target new-hp))
    (printf "~a dealt ~a damage to ~a (block ~a), new HP: ~a\n"
            (character-name user)
            actual-damage
            (character-name target)
            block-used
            (character-hp target))))


(define (handle-heal ctx n e)
    (for ([target (ctx-target ctx)])
            (define user (ctx-user ctx))
            (let ([new-hp (min (character-max-hp target)
                    (+ (character-hp target) n))])
            (set-character-hp! target new-hp))
            (printf "~a healed ~a HP to ~a, new HP: ~a\n"
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
        ['random 
         (define enemies (env-enemies e))
         (make-target (list-ref enemies (random (length enemies))))
        ]
        [else (error (format "Unknown target: ~a" who))]))


(provide (all-defined-out))