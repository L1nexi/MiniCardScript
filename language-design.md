# Mini Card Interpreter

## 语言概览
MiniCardScript 是一个基于 S-表达式的 DSL，用于描述卡牌游戏中的效果逻辑。每张卡牌可包含多个效果，每个效果可能包括伤害、治疗、状态施加、条件分支等控制结构。

## 语法参考
### 卡牌相关语法
```scheme
(card
  (name CardName)
  (cost 1)
  (desc "Text shown to user.")
  (effect <effect>))
```

effect 部分可以包含多种类型的效果。
注意，target 是环境切换的效果，它会指定所有后续效果的目标，直到遇到新的 target。


```bnf
<effect> ::= <action> | <target> | <condition> | <next-turn> | <control>

<action> ::= (damage int) 
           | (heal int) 
           | (inflict <status> int) 
           | (gain-energy int)

<condition> ::= (<branch> <predicate> <effect>)
<branch> ::= if | when

<control> ::= (repeat int <effect>) 
            | (choose <effect>+)

<target> ::= (target enemy) 
           | (target self) 
           | (target all)

<next-turn> ::= (next-turn)

<predicate> ::= (has-status <status>) 
              | (hp<= pct) 
              | (hp> pct) 
              | (energy>= int) 
              | (random<= pct)

<status> ::= vulnerable | weak | poisoned | fire

<play-card> ::= (play-card <card-name> <user> <target>)
```

目标指定：卡牌使用时指定主要目标。后续通过 enemy 指定该目标。可以通过 self 指定自身，all 指定所有目标。

vulnerable 和 weak 是两种状态。vulnerable 使自身在收到伤害时额外受到50% 的伤害，而 weak 则使自身在造成伤害时只造成 75% 的伤害。


### 创建人物语法

```scheme
(character
  (name "CharacterName")
  (hp 30)
  (energy 3)
  (status weak))
```
