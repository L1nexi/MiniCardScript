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
