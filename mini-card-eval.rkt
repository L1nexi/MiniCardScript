#lang racket

(require "input-util.rkt")
(require "effect.rkt")
(require "core.rkt")
(require "parser-util.rkt")

; 角色的名称、生命值、能量和状态
; 状态可有多个。每一个状态都是一个 symbol，持续一轮
; character 需要持续更新状态，设置为 mutable
; status : ((<status-name> <count>) ...)

; 使用卡牌
(define (play-card card user intent e)
  (define cost (card-cost card))
  ; 检查能量是否足够
  (if (< (character-energy user) cost)
      "Energy not enough to play this card!"
      (begin
        ; 扣除能量
        (printf "Playing card: ~a, cost: ~a\n" (card-name card) cost)
        (set-character-energy! user (- (character-energy user) cost))
        ; 执行效果，传入目标
        (eval-effect (card-effect card) (initial-ctx-from-user-intent user intent) e)
        e)))

(define (handle-next-turn e)
  (printf "Handling next turn...\n")
  ; 恢复玩家能量，计算状态
  (define player (env-player e))
  (set-character-energy! player (character-max-energy player))
  (status-calc player)
  ; 恢复敌人能量，计算状态
  (for ([enemy (env-enemies e)])
    (set-character-energy! enemy (character-max-energy enemy))
    (status-calc enemy))
   e)



; 解析单条 S-Expression
(define (eval-s-expr ast e)
  (match ast
    [(cons 'character body)
     (define char (eval-character body))
     (if (equal? (character-name char) 'player)
         (env char (env-enemies e) (env-cards e))
         (env (env-player e) (cons char (env-enemies e)) (env-cards e)))]

    [(cons 'card body)
     (define c (eval-card body))
     (env (env-player e) (env-enemies e) (cons c (env-cards e)))]

    [(list 'play-card card-name user-name intent-name)
     (define card (lookup-card card-name e))
     (define user (lookup-character user-name e))
     (define intent (lookup-character intent-name e))
     (play-card card user intent e)]

    [(list 'next-turn)
     (handle-next-turn e)]

    [else
     (error (format "Unknown top-level expression: ~a" ast))]))

(define (eval-ast ast)
  (foldl
   (lambda (expr e)
     (printf "Evaluating: ~a\n" expr)
     (define new-env (eval-s-expr expr e))
     (print-env new-env) ; 打印当前环境
     new-env)
   initial-env
   ast))

; (printf "S-Exp read:\n")
; (pretty-print ast) ; just for debug, you can delete these lines
; (printf "\n")

(void (eval-ast ast))