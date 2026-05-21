# MiniCardScript

> How I accidentally built a Turing-complete effect engine for my PoPL homework.

## 简介

这是一个用 Racket 编写的卡牌游戏效果解释器，用于解释自创的卡牌效果 DSL。

这本是复旦大学《程序设计语言原理》（Principle of Programming Languages.）的课程作业，目标是实现卡牌效果 DSL 的解析。但写着写着，我不再满足于简单的效果解释，而是希望能够复刻一些更加 ~~神秘~~ 强劲的卡牌机制，于是它变成了一个支持变量绑定、条件分支、循环递归、副作用结算的图灵完备（存疑）效果引擎。

正经的课程报告（包含 BNF 范式、架构设计、状态机模型）：
[项目设计报告 (DESIGN.md)](docs/DESIGN.md)

如果你想看我是怎么折磨这个解释器的：
[test/06-mycombo.cdlang](test/06-mycombo.cdlang)

## 特性

- 强大的上下文控制：支持 `user`（使用者）、`intent`（意图）、`target`（实际目标）的动态切换，支持“对随机敌人施加基于自身当前烧伤层数一半的中毒”之类的诡异特效。
- 控制流与变量绑定： 支持 `if`, `when`, `repeat`, `choice` 以及局部变量绑定 `let`。
- 状态机制： 内置了 `tick`（结算）和 `decay`（衰减）模型，支持类似《杀戮尖塔》的毒、火、格挡计算。

## 灵感来源

为了测试这个 DSL 的表达上限，我参考（缝合）了以下游戏的机制：

- Slay the Spire (杀戮尖塔): 基础的伤害、格挡、能量系统。
- Limbus Company (边狱巴士) / Library of Ruina (废墟图书馆):
  - 烧伤、中毒与流血机制的结算与衰减来自废墟图书馆。
  - 在 [test/06-mycombo.cdlang](test/06-mycombo.cdlang) 中，你可以找到我为了致敬传奇三灯人格 L.C.E. 浮士德而创造的自烧伤体系。
- 其他卡牌游戏： 炉石传说、邪恶铭刻等。

## 快速开始

环境要求：[Racket](https://racket-lang.org/) 

### 1. 运行解释器

```bash
racket mini-card-eval.rkt test/06-mycombo.cdlang
```

你会看到为了测试解释器的表达力而写出的神秘卡牌：

- 炎爆术：动态计算层数并进行几十次随机状态施加。
- 因果逆转：根据己方烧伤层数对敌人造成伤害，同时根据敌人烧伤层数对自己造成伤害。
- 凤凰契约：条件苛刻的回光回体卡牌，用于测试条件分支和状态检查

### 2. 运行基础测试

```bash
racket mini-card-eval.rkt test/01-basic-effect.cdlang
```

## 代码结构

- `core.rkt`: 核心结构体定义
- `mini-card-eval.rkt`: 主解释器循环
- `effect.rkt`: 包含所有 `match` 逻辑和效果分发与结算
- `parser-util.rkt`: 状态机和辅助解析工具

## 局限性

作为一个课程作业，本项目存在以下 ~~局限~~ 特性：

- GUI? 不存在的： 卡牌游戏享受者看着文字描述脑补出的战斗画面才是最有表现力的！
- 没有抽牌堆/弃牌堆
- 缺少事件触发器
- 硬核报错
