#lang racket

(require "util.rkt")


; 角色的名称、生命值、能量和状态
; 状态可有多个。每一个状态都是一个 symbol，持续一轮
; character 需要持续更新状态，设置为 mutable
(struct character (name hp max-hp energy max-energy status) #:transparent #:mutable)

(define (eval-character ast)
    (define name #f)
    (define hp 0)
    (define energy 0)
    (define status '())
    (for ([item ast])
        (match item
            [(list 'name v) (set! name v)]
            [(list 'hp v) (set! hp v)]
            [(list 'energy v) (set! energy v)]
            [(cons 'status statuses) (set! status statuses)]
            [else (error (format "Unknown character attribute: ~a" item))]))
    (character name hp hp energy energy status))

; 环境，目前包括玩家和敌人
; 玩家是 character 类型，enemies 是一个 character 列表， cards 是一个 card 列表
(struct env (player enemies cards) #:transparent)

(define initial-env (env '() '() '()))

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

; 分别是卡牌的名称、费用、描述和效果
; 效果是一个效果列表，是动态执行的
(struct card (name cost desc effect) #:transparent)


(define (eval-card ast)
    (define name #f)
    (define cost 0)
    (define desc #f)
    (define effect '())
    (for ([item ast])
        (match item
            [(list 'name v) (set! name v)]
            [(list 'cost v) (set! cost v)]
            [(list 'desc v) (set! desc v)]
            [(cons 'effect effects) (set! effect effects)]
            [else (error (format "Unknown card attribute: ~a" item))]))
    (card name cost desc effect))

; 效果解释器
(define (eval-effect exprs user e)
    (define current-target '())
    (for ([expr exprs])
        (match expr
            [(list 'target who)
             (set! current-target 
                    (select-target who e))]
            [(list 'damage n) (handle-damage user current-target n e)]
            [(list 'heal n) (handle-heal user current-target n e)]
        ; 嵌套的 effect
            [(cons 'effect eff) (eval-effect eff user e)]
            [else (error (format "Unknown effect: ~a" e))])))


; 根据环境和目标选择目标
(define (select-target who e) 
    (match who
    ; TODO: 当前只支持单个敌人
        ['enemy (first (env-enemies e))]
        ['all (env-enemies e)]
        ['player (env-player e)]
        [else (error (format "Unknown target: ~a" who))]))

(define (handle-damage user target n e)
    ; TODO 目前只处理单个目标
    ; 只处理了易损状态
    (define actual-damage
      (let ([base-damage n])
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

; 检查角色是否有某个状态
(define (has-status? character status)
    (member status (character-status character)))

; 使用卡牌
(define (play-card card user e)
  (define cost (card-cost card))
  ; 检查能量是否足够
  (if (< (character-energy user) cost)
      "Energy not enough to play this card!"
      (begin
        ; 扣除能量
        (printf "Playing card: ~a, cost: ~a\n" (card-name card) cost)
        (set-character-energy! user (- (character-energy user) cost))
        ; 执行效果，传入目标
        (eval-effect (card-effect card) user e)
        e)))

(define (handle-next-turn e)
  (printf "Handling next turn...\n")
  ; 恢复玩家能量
  (define player (env-player e))
  (set-character-energy! player (character-max-energy player))
  ; 恢复敌人能量
  (for ([enemy (env-enemies e)])
    (set-character-energy! enemy (character-max-energy enemy)))
  ; 清除状态
  (set-character-status! player '())
  (for ([enemy (env-enemies e)])
    (set-character-status! enemy '()))
  (printf "Restored energy and cleared status\n")
   e)

; 解析单条 S-Expression
(define (eval-expr ast e)
  (match ast
    [(cons 'character body)
     (define char (eval-character body))
     (if (equal? (character-name char) 'player)
         (env char (env-enemies e) (env-cards e))
         (env (env-player e) (cons char (env-enemies e)) (env-cards e)))]

    [(cons 'card body)
     (define c (eval-card body))
     (env (env-player e) (env-enemies e) (cons c (env-cards e)))]

    [(list 'play-card card-name user-name)
     (define card (lookup-card card-name e))
     (define user (lookup-character user-name e))
     (play-card card user e)]

    [(list 'next-turn)
     (handle-next-turn e)]

    [else
     (error (format "Unknown top-level expression: ~a" ast))]))

(define (eval-ast ast)
  (foldl
   (lambda (expr e)
     (printf "Evaluating: ~a\n" expr)
     (define new-env (eval-expr expr e))
     (printf "Current environment: ~a\n" new-env)
     new-env) ; 返回这个作为新的 accumulator
   initial-env
   ast))

(printf "S-Exp read:\n")
(pretty-print ast) ; just for debug, you can delete these lines
(printf "\n")

(void (eval-ast ast))