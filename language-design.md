# Mini Card Interpreter

## 语言概览
MiniCardLang 是一门面向卡牌游戏的领域特定语言（DSL），用于定义卡牌在游戏中的行为效果。它允许游戏设计者用简单的 S 表达式描述卡牌的战斗、治疗、增益、减益等逻辑效果。

## 语法参考
### 卡牌相关语法
```scheme
(card
  (name "CardName")
  (cost 1)
  (desc "Text shown to user.")
  (effect <effect>))
```

effect 部分可以包含多种类型的效果。
注意，target 是环境切换的效果，它会指定所有后续效果的目标，直到遇到新的 target。


```bnf
<effect> ::= <action> | <target> | <condition> | <next-turn> ...
<action> ::= (damage int) | (heal int) | (inflict <status>) | (gain-energy int)
<target> ::= (target enemy) | (target player)
<condition> ::= (when <predicate> <effect>)
<predicate> ::= (has-status <status>) | (hp<= percent) | (hp> percent) | (energy>= int)
<next-turn> ::= (next-turn)
<status> ::=  vulnerable | weak
```

vulnerable 和 weak 是两种状态。vulnerable 使自身在收到伤害时额外受到50% 的伤害，而 weak 则使自身在造成伤害时只造成 75% 的伤害。


### 创建人物语法

```scheme
(character
  (name "CharacterName")
  (hp 30)
  (energy 3)
  (status weak))
```
