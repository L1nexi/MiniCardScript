# MiniCardScript (MCS)

> **"Or: How I accidentally built a Turing-complete game engine for my PoPL homework."**

[![Racket](https://img.shields.io/badge/Language-Racket-blue.svg)](https://racket-lang.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Completed_(Toy)-orange.svg)]()

## 📖 简介 (Introduction)

这是一个用 **Racket** 编写的卡牌游戏效果解释器，用于解释自创的卡牌效果 DSL（领域特定语言）。

本来这只是复旦大学《程序设计语言原理》的课程作业，目标是“实现简单的卡牌效果解析”。但写着写着，我玩过的卡牌对战游戏点燃了我的激情（中二之魂）。我不再满足于简单的 `(damage 5)`，而是希望能够复刻一些更加巧妙（神秘）的卡牌机制，于是它变成了一个支持**变量绑定、条件分支、循环递归、副作用结算、甚至能把自己烧死**的**图灵完备**（存疑）的效果引擎。

如果你想看正经的课程报告（包含 BNF 范式、架构设计、状态机模型），请移步：
👉 [**项目设计报告 (DESIGN.md)**](docs/DESIGN.md)

如果你想看我是怎么折磨这个解释器的，请直接看：
👉 [**test/06-mycombo.cdlang**](test/06-mycombo.cdlang)

## ✨ 特性 (Features)

*   **完全的 S-Expression 支持：** 代码即数据，卡牌即逻辑。无需复杂的 Parser，直接享受 Lisp 的括号之美。
*   **复杂的上下文流转 (Context Flow)：** 支持 `user`（使用者）、`intent`（意图）、`target`（实际目标）的动态切换。完美支持“对随机敌人施加基于自身当前烧伤层数一半的中毒”这种诡异特效。
*   **控制流与变量绑定：** 支持 `if`, `when`, `repeat`, `choice` 以及局部变量绑定 `let`。
*   **硬核的状态机制：** 内置了 `tick`（结算）和 `decay`（衰减）模型，支持类似《杀戮尖塔》的毒、火、格挡计算。

## 🔥 灵感来源 (Inspirations)

为了测试这个 DSL 的表达上限，我复刻（缝合）了以下游戏的机制：

*   **Slay the Spire (杀戮尖塔):** 基础的伤害、格挡、能量系统。
*   **Limbus Company (边狱巴士) / Library of Ruina (废墟图书馆):**
    *   烧伤、中毒与流血机制的结算与衰减来自废墟图书馆。
    *   在 [**test/06-mycombo.cdlang**](test/06-mycombo.cdlang) 中，你可以找到我为了致敬传奇三灯人格 **L.C.E. 浮士德** 而创造的 **"自烧伤 (Self-Burn)"** 体系。
*   **其他卡牌游戏：** 炉石传说、邪恶铭刻。

## 🎨 代码赏析 (Showcase)

你以为的 DSL：
```lisp
(effect (damage 5))
```

**实际上的 DSL (选自 `test/06-mycombo.cdlang`):**

```lisp
;; 卡名：炎爆术
;; 描述：引爆主要目标的全部烧伤并造成 3*层数 的伤害，并将引爆的层数随机施加在所有敌人上。
(card
  (name 炎爆术)
  (cost 5)
  (effect 
    (target all)
    (damage 30)
    (inflict fire 10)
    (target enemy)                     ; 目标切换！
    (let ((stacks (get-status fire)))  ; 局部变量绑定！
      (remove-status fire)
      (damage (* 3 stacks))            ; 算术运算！
      (repeat stacks                   ; 动态循环！
        (effect (target random) (inflict fire 1))))
    (target self)
    (inflict fire 14)))
```

## 🛠️ 快速开始 (Quick Start)

环境要求：[Racket](https://racket-lang.org/) (无需依赖库)

### 1. 运行解释器，见证 "数值崩坏"
这是本项目的灵魂文件，请务必运行：
```bash
racket mini-card-eval.rkt test/06-mycombo.cdlang
```

**观察控制台输出**，你会看到为了压榨解释器的极限，我写出的神秘卡组：
*   **炎爆术**：动态计算层数并进行几十次随机状态施加。
*   **因果逆转**：根据己方烧伤层数对敌人造成伤害，同时根据敌人烧伤层数对自己造成伤害。
*   **凤凰契约**：条件苛刻的回光回体卡牌，用于测试条件分支和状态检查
*   **数值过山车**：看着 HP 和状态层数在 Log 里疯狂跳动。

### 2. 运行基础测试
```bash
racket mini-card-eval.rkt test/01-basic-effect.cdlang
```

## 📝 代码结构 (Structures)

*   `core.rkt`: 核心结构体定义 (Environment, Character, Card)。
*   `mini-card-eval.rkt`: 主解释器循环 (Eval Loop)。
*   `effect.rkt`: **魔法发生的地方**。包含所有 `match` 逻辑和效果结算。
*   `parser-util.rkt`: 状态机 (State Machine) 和辅助解析工具。

## 🚧 局限性 (Limitations)

作为一个课程作业，本项目存在以下 ~~局限~~ 特性：

*   **GUI? 不存在的：** 真正的卡牌游戏享受者仅仅看着文字描述就能脑补出激烈的战斗画面
*   **没有抽牌堆/弃牌堆：** `env` 里虽然有卡牌列表，但没有实现洗牌和循环抽卡的逻辑（*因为和DSL解释关系不大*）
*   **缺少事件触发器 (Triggers)：** 无法实现“当受到攻击时”、“回合结束时”的自动触发效果（虽然硬编码了一些状态结算）。
*   **硬核报错：** 遇到语法错误直接抛出 Racket 原生异常并崩溃，你可以在控制台看到挤成一行的多层括号嵌套，所谓 "Fail-Fast" 哲学的极致体现。

## 🤣 幕后花絮 (Behind the Scenes)

如果你查看 `git log --oneline`，你会看到一个开发者的美丽精神状态：

*   `feat: 完成next-turn`: "逻辑很清晰。"
*   `feat: idk`: "我都改了些什么？怎么写消息？算了能跑就行"
*   `refactor: 重构了状态逻辑`: "为了更好的扩展性！"
*   `feat: 1`: "求你了，跑通吧"
*   `refacor: asd`: "？？？"
*   `feat: idk`: "爱咋咋吧，能跑能交报告就行"
