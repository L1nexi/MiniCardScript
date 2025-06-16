#lang racket

(struct character (name hp max-hp energy max-energy status) #:transparent #:mutable)

; 环境，目前包括玩家和敌人
; 玩家是 character 类型，enemies 是一个 character 列表， cards 是一个 card 列表
(struct env (player enemies cards) #:transparent)

; 分别是卡牌的名称、费用、描述和效果
; 效果是一个效果列表，是动态执行的
(struct card (name cost desc effect) #:transparent)

; intent：卡牌指定的目标 target：effect作用的目标。一张卡牌作用的目标可以与指定的目标不同，如：
; 造成伤害，回复自身血量。指定单个敌军但是target是敌军、自己
; target 始终是列表
(struct ctx (user intent target) #:transparent)

(define (make-ctx-from-intent c intnt)
    (ctx (ctx-user c) intnt (ctx-target c)))

(define (make-ctx-from-target c target)
    (ctx (ctx-user c) (ctx-intent c) target))

(define (make-target char)
    (list char))

(define initial-env (env '() '() '()))

(provide (all-defined-out))



