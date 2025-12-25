# MiniCardScript DSL 语法描述

以下是 MiniCardScript 的完整语法描述，采用 BNF 表示法：

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

## 说明

- **target**：
  - `target` 指定 `effect` 字句作用的目标。
  - 默认以意图目标 `intent` 初始化。
  - `target` 切换后影响后续所有的 `effect` 字句，直到下一个 `target` 进行目标切换。

- **状态**：

| 状态            | 说明              | 衰减            |
|----------------|-----------------|---------------|
| vulnearble 易损 | 受到伤害增加 50%      | 回合结束时 -1      |
| weak 虚弱       | 造成伤害减少 25%      | 回合结束时 -1      |
| block 格挡      | 受到伤害时，相应格挡      | 回合结束时清零       |
| poisoned 中毒   | 回合结束时，受到等同层数的伤害 | 回合结束时减半（向下取整） |
| fire 烧伤       | 回合结束时，受到等同层数的伤害 | 回合结束时减半（向下取整） |

- **控制流语句**：

| 控制结构                   | 说明                                                           |
|------------------------|--------------------------------------------------------------|
| (if pred eff1 eff2)    | 如果 pred 为真，执行 eff1，否则执行 eff2。两者都是单条 effect（可为 effect block） |
| (when pred eff)        | 如果 pred 为真，执行 eff，否则跳过                                       |
| (repeat n eff)         | 重复执行 eff n 次。每次执行使用前一次的上下文结果                                 |
| (choice eff1 eff2 ...) | 从给定效果中随机选择一个执行                                               |
