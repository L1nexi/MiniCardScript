#lang racket

(struct character (name hp max-hp energy max-energy status) #:transparent #:mutable)

; 环境，目前包括玩家和敌人
; 玩家是 character 类型，enemies 是一个 character 列表， cards 是一个 card 列表
(struct env (player enemies cards) #:transparent)

; 分别是卡牌的名称、费用、描述和效果
; 效果是一个效果列表，是动态执行的
(struct card (name cost desc effect) #:transparent)

(define initial-env (env '() '() '()))

(provide (all-defined-out))



