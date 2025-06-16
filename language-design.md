# MiniCardInterpreter

## 22307130256 李希文

## 选题描述
-   在卡牌游戏的开发中，如何表述一张卡牌的效果始终是一个重要课题。其中一种方式是，利用开发语言对效果逻辑进行描述。这种模式的弊端在于，策划需要时刻与程序员保持沟通，确认效果，无疑增加了时间成本。另一种方式是将卡牌效果逻辑预先定义，策划负责填入数值以及控制流标志。这样的方法一定程度上降低了沟通成本，但也有表达力不足的问题。本解释器提出一种声明式的 DSL，使得策划能够利用 S-Exp 语义化的表示效果逻辑。

## 功能点和设计亮点
-   MiniCardScript 是一个基于 S-表达式的 DSL。它的核心功能聚焦于卡牌效果（effect）的实现。在支持基础效果，如伤害、治疗、获取能量和状态施加之外，MiniCardScript 还支持嵌套效果，支持复杂的效果逻辑；支持目标切换，可以切换目标为自身、意图目标和全体目标；支持控制结构，包括 if, repeat, choice 等控制语句，便于条件触发效果的设置。

-   MiniCardInterpreter 内置了 4 种状态，包含两种增减益状态和两种伤害性状态。MiniCardInterpreter 使用 tick + decay 的机制来统一处理状态触发和状态衰减，统一化状态管理。进一步的开发可以开放状态的自定义实现。

-   实现中，将卡牌列表、玩家、敌人列表封装为世界环境 env ，将使用者、意图目标、当前目标封装为卡牌使用的上下文 ctx。env 和 ctx 分离，全局状态和局部上下文分工明确，便于扩展。

-   利用 foldl 线程式传递上下文，函数式风格且无副作用，逻辑简洁。

## 语法参考
### 角色创建、卡牌创建以及对局控制
```scheme
(card
  (name CardName)
  (cost 1)
  (desc "Text shown to user.")
  (effect <effect>*))

(character
  (name "CharacterName")
  (hp 30)
  (energy 3)
  (status (vulnerable 2)))

(play-card CardName User Intent)
(next-turn)
```
### 效果语法

```bnf
<effect> ::= <action> | <target> | <condition> | <control>

<action> ::= (damage <int>) 
           | (heal <int>) 
           | (inflict <status> <int>) 
           | (gain-energy <int>)

<condition> ::= <if-effect> | <when-effect>
<if-effect> ::= (if <predicate> <effect> <effect>)
<when-effect> ::= (when <predicate> <effect>)

<control> ::= (repeat <int> <effect>) 
            | (choose <effect>+)

<target> ::= (target enemy) 
           | (target self) 
           | (target all)

<predicate> ::= (status-count>= <status> <int>) 
              | (has-status <status>)
              | (hp<= <pct>) 
              | (hp> <pct>) 
              | (energy>= <int>) 
              | (random<= <pct>)

<status> ::= vulnerable | weak | poisoned | fire

```

注释：

- target: target 指定 effect 字句作用的目标。target 默认以意图目标 intent 初始化，且 target 切换后影响后续所有的 effect 字句，直到下一个 target 进行目标切换。

- status: vulnerable 易损，受到伤害增加 50%。weak 虚弱，造成伤害减少 25%。 poisoned 中毒，fire 烧伤，回合结束时受到等同于层数的伤害，层数变为原来的一半。计算是统一向下取整。

## 设计与实现细节
### 设计
设计重点围绕效果进行。我希望效果能够实现多种逻辑，包括条件、目标选择等。为了实现这些，效果本身应该是自包含的，换句话说，我可以把一个效果序列包装为单个效果，单个效果又可以参与构成效果序列。由此得出 effect 的语法设计。

在此基础上，考虑目标选择。使用卡牌时，我们知道使用者以及意图目标，但是意图目标和效果目标并不总是一致。如：“造成6点伤害并回复3点血量。”，后续的效果目标变成了使用者。由此，考虑用医用 ctx 结构来维护出牌所需的上下文。

接下来考虑条件分支。对于条件部分，本项目采用的是预置比较符的方法。诚然，可以实现更为复杂的字段查询比较功能，但考虑到当前项目中的项目与字段总量可以认为并不多，最终选用了预置比较符的做法。

### 实现
- `core.rkt`
提供了 `character` `card` `env` `ctx` 结构体的定义和一部分便利函数。其中，只有 env 设置为了 #:mutable，这是考虑到角色属性需要经常改变。

- `input-util.rkt`
即示例解释器的 util 文件，这里重命名便于区分。提供了读入 S-Exp 的功能

- `mini-card-eval.rkt`
解释器顶层文件。处理角色创建、卡牌创建、执行卡牌、进入下一回合指令的分发。

核心代码：
```scheme
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
        (eval-effect (card-effect card) (ctx user intent (make-target intent)) e)
        e)))

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
     (define new-env (eval-expr expr e))
     (print-env new-env) ; 打印当前环境
     new-env)
   initial-env
   ast))

(void (eval-ast ast))
```

`eval-ast` 采用了线程式上下文的风格实现，初始化全局环境 env 并将其作为参数传递，函数式风格且无副作用。
`eval-expr` 解析 .cdlang 文件中的 S-Exp 表达式并进行指令分派。
`play-card` 初始化效果的局部上下文 ctx 并将其分派给 `eval-effect` 解析。

-   `effect.rkt`
这是整个效果解释的核心。核心代码：

```scheme
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


(define (handle-damage ctx n e)
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

; 根据环境和上下文选择目标
(define (select-target who ctx e) 
    (match who
        ['enemy (make-target (ctx-intent ctx))]
        ['all (env-enemies e)]
        ['self (make-target (ctx-user ctx))]
        [else (error (format "Unknown target: ~a" who))]))

```

效果的解析也采用的是线程式上下文传递的风格。

`eval-effect` 函数处理 effect 列表，形如 ((damage 3) (heal 6))。传入当前上下文 ctx 和环境至 foldl 函数，最终的上下文 ctx 作为返回值，保证 ctx 传递不中断。

`eval-one-effect` 函数负责处理单个 effect 指令。

- 对于基础指令 `damage heal gain-energy inflict`，调用对应的处理函数处理。
- 对于切换目标指令 `target who`，我们需要根据当前上下文和参数 who 来更新上下文，再返回这个上下文用于后续指令。
- 对于嵌套效果指令 `effect`，我们需要将其后的 effect 序列提取处理并调用 `effect-eval` 处理。通过实现嵌套效果，我们可以将由 `(effect )` 包裹的指令序列视为单个效果块。由此，控制流指令的解析也可以统一按单条效果进行。
- 对于控制流指令 `when if repeat choice`，按照其语义拆分 effect 语句并相应调用  `eval-one-effect`处理即可。同上一点所属，嵌套效果的实现使我们可以统一将 body 视为单条效果。

- `select-target`
通过上下文和 who 来选择目标。为了统一处理，我们始终返回一个列表。

- `handle-damage`
以伤害处理的函数举例说明如何实现基础指令。获取使用者，对于每一个目标，按效果计算伤害，并设置环境的相应字段即可。

## 测试用例
解释器的错误处理集中于 `match`。如果有无法匹配的参数，即刻抛出错误并打印提示信息。

- `action-status.cdlang`
```shell
racket mini-card-eval.rkt action-status.cdlang
```

测试了基础动作和状态。预期效果参见注释

- `target-pred.cdlang`
```shell
racket mini-card-eval.rkt target-pred.cdlang
```

测试目标切换和判断谓词。

- `control-branch.cdlang`
```shell
racket mini-card-eval.rkt control-branch.cdlang
```

测试分支和控制流指令。

- `design.cdlang`
```shell
racket mini-card-eval.rkt design.cdlang
```
笔者利用这个 DSL 还原、设计的一些卡牌。

## 运行指南
我当前的环境是 Window11 Racket v8.12。无需任何额外的三方库。
运行程序：
```shell
racket mini-card-eval.rkt your-file.cdlang
```
将 your-file.cdlang 替换为实际 S-Exp 文件即可。