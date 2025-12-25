# MiniCardInterpreter

L1nex^

## 一、选题描述

在卡牌游戏的开发中，如何表达一张卡牌的效果始终是一个重要课题。传统方式往往通过硬编码实现卡牌效果逻辑，导致策划与程序之间沟通成本高、迭代效率低。而另一种方式是采用参数化的效果模板，仅允许策划填写数值和标志，虽然降低了沟通成本，却严重限制了表达力。

本解释器提出了一种基于 S-Expression（S-表达式）的声明式 DSL —— MiniCardScript，使策划可以直接用结构化、可组合的方式表达卡牌效果，从而在保证表达力的同时降低技术门槛，提高开发效率与灵活性。

## 二、功能亮点与设计理念

- **语言设计理念**  
  MiniCardScript 是一种为非程序人员设计的效果组合语言，采用 Lisp 风格的 S-表达式作为语法基础，具备天然的组合性与嵌套能力。每条 effect 都可以是一个 effect block，从而使得语言支持变量绑定、条件分支、目标切换等控制流程，可以表达复杂的效果逻辑。

- **状态机制统一管理**  
  设计内置五种状态：`vulnerable`, `weak`, `poisoned`, `fire`, `block`。不同状态具有不同的结算机制与衰减机制。解释器统一采用 `tick` 与 `decay` 机制管理状态，支持衰减式状态和持续性伤害，为未来拓展提供通用模型。

- **上下文与环境解耦**  
  使用 `env` 表示全局状态（角色列表与卡牌池），使用 `ctx` 表示局部上下文（使用者、目标、意图）。分离设计便于扩展并实现纯函数式风格的效果执行（无副作用、线程式上下文传递）。

- **函数式解释执行**  
  效果执行基于 `foldl` 实现，每个效果返回一个更新后的上下文。嵌套控制流与目标切换均通过效果块组合实现，函数式风格、无副作用，便于后续扩展。

## 三、DSL 语法描述（BNF）

```
<program>      ::= <top-expr>*
<top-expr>     ::= (character <char-body>) 
                 | (card <card-body>)
                 | (play-card <card-name> <user> <intent>)
                 | (next-turn)

<char-body>    ::= (name <symbol>)
                 (hp <int>)
                 (energy <int>)
                 (status (<status> <int>)*)?

<card-body>    ::= (name <symbol>)
                 (cost <int>)
                 (desc <string>)
                 (effect <effect>*)

<effect>       ::= <action> | <target> | <condition> | <control> | <let-expr> | (effect <effect>*)

<action>       ::= (damage <expr>)
                 | (heal <expr>)
                 | (gain-energy <expr>)
                 | (inflict <status> <expr>)
                 | (reduce <status> <expr>)
                 | (remove-status <status>)

<target>       ::= (target enemy) | (target self) | (target all) | (target random)

<condition>    ::= (when <predicate> <effect>)
                 | (if <predicate> <effect> <effect>)

<control>      ::= (repeat <expr> <effect>)
                 | (choice <effect>+)

<let-expr>     ::= (let (<binding>*) <effect>*)
<binding>      ::= (<symbol> <expr>)

<predicate>    ::= (and <predicate>+)
                 | (or  <predicate>+)
                 | (not <predicate>)
                 | (has-status <status>)
                 | (status-count>= <status> <expr>)
                 | (hp<= <pct>)
                 | (energy>= <expr>)
                 | (random<= <pct>)

<expr>         ::= <int>  | <symbol> | (get-status <status>) | (<operator> <expr> <expr>)
<operator>     ::= * | + | - | / | min | max

<status>       ::= vulnerable | weak | poisoned | fire | block
<pct>          ::= <int>   ; 百分比 0–100

```

注释：

- target: target 指定 effect 字句作用的目标。target 默认以意图目标 intent 初始化。 target 切换后影响后续所有的 effect 字句，直到下一个 target 进行目标切换。

- status:


| 状态            | 说明              | 衰减            |
|---------------|-----------------|---------------|
| vulnearble 易损 | 受到伤害增加 50%      | 回合结束时 -1      |
| weak 虚弱       | 造成伤害减少 25%      | 回合结束时 -1      |
| block 格挡      | 受到伤害时，相应格挡      | 回合结束时清零       |
| poisoned 中毒   | 回合结束时，受到等同层数的伤害 | 回合结束时减半（向下取整） |
| fire 烧伤       | 回合结束时，受到等同层数的伤害 | 回合结束时减半（向下取整） |

- 控制流语句：

| 控制结构                   | 说明                                                           |
|------------------------|--------------------------------------------------------------|
| (if pred eff1 eff2)    | 如果 pred 为真，执行 eff1，否则执行 eff2。两者都是单条 effect（可为 effect block） |
| (when pred eff)        | 如果 pred 为真，执行 eff，否则跳过                                       |
| (repeat n eff)         | 重复执行 eff n 次。每次执行使用前一次的上下文结果                                 |
| (choice eff1 eff2 ...) | 从给定效果中随机选择一个执行                                               |

## 四、设计与实现细节

### 设计

本语言的设计重点围绕“效果”（effect）展开。为了实现诸如变量绑定、条件分支、目标选择等复杂的逻辑操作，效果本身需要具备良好的组合性和封装性。具体而言，我们希望效果既可以是一个原子操作，也可以是由多个子效果构成的复合操作。这一思想直接体现在 effect 的语法设计中：效果序列可以嵌套为单个效果，而单个效果也可以参与构成新的序列。

在此基础上，我们引入了上下文结构 `ctx`，以支持目标选择逻辑。使用卡牌时，我们已知使用者和意图目标，但在某些效果中，其作用目标可能会发生变化。例如，"对敌人造成6点伤害并回复3点生命"，第二个效果的目标应是使用者。为此，`ctx` 用于统一管理出牌时的使用者、意图目标、当前效果目标以及局部绑定变量。

在条件分支方面，我们采用预设谓词（predicate）的方法来实现判断逻辑。尽管可以引入更复杂的字段查询和比较机制，但考虑到本项目中的字段和状态数量有限，预设谓词已足以满足需求。

为了增加语言表达能力，需要引入变量绑定以及表达式求值。具体的实现参考了 racket 中的实现。首先计算 `let` 绑定中的表达式，扩展上下文，再用扩展后的上下文解析后续的 effect 序列。

### 实现

#### core.rkt

本模块定义了核心结构体：`character`、`card`、`env`、`ctx`，并提供部分便捷操作函数。仅 `env` 被声明为可变结构体，便于角色状态的动态更新。

```scheme
(struct character (name hp max-hp energy max-energy status) #:transparent #:mutable)
; enemies 为 character 列表
(struct env (player enemies cards) #:transparent)
(struct card (name cost desc effect) #:transparent)
; target 为 character 列表
(struct ctx (user intent target vars) #:transparent)
```

#### `input-util.rkt`

用于 S-Expression 的读入与解析，基于参考解释器的 `util` 文件改写。

#### `mini-card-eval.rkt`

顶层解释器模块，负责角色和卡牌的构造、卡牌的使用逻辑、以及回合推进机制的调度。

核心逻辑：

```scheme
(define (play-card card user intent e)
    ...
    (eval-effect (card-effect card) (initial-ctx-from-user-intent user intent) e))

; 解析单条 S-Expression
(define (eval-s-expr ast e)
  (match ast
    [(cons 'character body)
     (define char (eval-character body))
     (if (equal? (character-name char) 'player)
         (env char (env-enemies e) (env-cards e))
         (env (env-player e) (cons char (env-enemies e)) (env-cards e)))]
    ...
    [else
     (error (format "eval-s-expr: Unknown top-level expression: ~a" ast))]))

(define (eval-ast ast)
  (foldl eval-s-expr initial-env ast))

```

`eval-ast` 采用了线程式上下文的风格实现，初始化全局环境 env 并将其作为参数传递，此后将 eval-s-expr 返回的新状态以及下一个 S-Exp 传入 eval-s-expr。
`eval-s-expr` 解析 .cdlang 文件中的 S-Exp 表达式并进行指令分派。
`play-card` 初始化效果的局部上下文 ctx 并将其分派给 `eval-effect` 解析。

#### parser-util.rkt

主要处理不含 effect 的基础语句，如角色、卡牌、next-turn 指令的解析和构造。

状态系统亦在此定义，引入了 tick-decay 模型来统一描述状态的触发与衰减：

核心逻辑

```scheme
(define status-tick
  (hash
    'poisoned (lambda (character n) (set-character-hp! character (max 0 (- (character-hp character) n))))
    ...
  ))

(define status-decay
  (hash
    'poisoned (lambda (n) (floor (/ n 2)))
    ...
  ))

(define (status-calc character)
  (define new-status
    (for/list ([s (character-status character)])
    ...
      ; tick
      (define tick-fn (hash-ref status-tick status-name (lambda (c n) (void))))
      (tick-fn character n)
      ; decay
      (define decay-fn (hash-ref status-decay status-name (lambda (n) n)))
      (define new-n (decay-fn n))
      ))
      ...)
```

这一模型有良好的扩展性，便于后续新增或修改状态效果。

#### effect.rkt

这是整个效果解释的重心。核心解析循环：

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
        [else (error (format "eval-one-effect: Unknown effect: ~a" expr))]))
```

`eval-effect` 函数串行处理 effect 列表，形如 ((damage 3) (heal 6))。传入当前上下文 ctx 和环境至 foldl 函数，最终的上下文 ctx 作为返回值，保证 ctx 传递不中断。

`eval-one-effect` 函数负责处理单个 effect 指令。

- 对于基础指令 `damage heal gain-energy inflict`，调用各个字句对应的处理函数处理。在处理函数中进行状态查询、数值计算等具体语义实现。

- 对于切换目标指令 `target who`，我们需要根据当前上下文和参数 who 来更新当前目标，再返回新的上下文用于后续指令。

- 对于嵌套效果指令 `effect`，我们需要将其后的 effect 序列提取处理并调用 `effect-eval` 处理。由此，我们可以将由 `(effect )` 包裹的指令序列视为单个效果块。由此，控制流指令的解析也可以统一按单条效果进行。

- 对于控制流指令 `when if repeat choice`，按照其语义拆分 effect 语句并相应调用  `eval-one-effect`处理即可。同上一点所述，嵌套效果的实现使我们可以统一将 body 视为单条效果。

- 局部变量绑定：`eval-let` 进行上下文扩展，调用处理函数，随后返回旧的上下文。这里天然支持变量 shadowing。`eval-expr` 负责表达式的求值。根据语言设计，这里只需要进行三类的表达式计算。 `eval-call` 负责计算算术函数的调用。

核心逻辑：

```scheme
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
    [else (error (format "eval-expr: Unknown expression: ~a" expr))]))

(define (eval-call expr ctx e)
  (match expr
    [(list '* a b)
     (* (eval-expr a ctx e) (eval-expr b ctx e))]
    ...
    [else (error (format "eval-call: Unknown function call: ~a" expr))]))
```

### 错误处理

当前采用 match 做语法模式匹配，所有未知的顶层指令、未知 effect、未知 target 或 predicate 都会立即抛出处理函数和处理表达式 (error ...)，以便发现配置错误。

<div style="page-break-after: always;"></div>

## 五、测试用例

| 测试用例                  | 说明             |
|-----------------------|----------------|
| 01-basic-effect       | 测试基础动作与状态结算    |
| 02-target-switching   | 测试目标切换         |
| 03-conditions         | 测试条件分支语句 (when if)       |
| 04-control-structures | 测试控制流语句   (repeat choice)        |
| 05-let-and-expr       | 测试局部变量绑定与表达式求值 |
| 06-mycombo            | 测试自创卡牌         |

除 06-mycombo 外，预期输出均在注释中表明。

运行单个测试：Windows 下 `racket mini-card-eval.rkt .\test\01-basic-effect.cdlang`

一次性运行全部测试：Windows 环境下启动 `run-all-tests.bat`

## 六、运行指南

Racket v8.12

无 OS 要求，无需任何依赖库。

运行程序：

```shell
racket mini-card-eval.rkt {{your-file.cdlang}}
```