# 领域文档约定（Domain Docs）

说明各工程技能在探索代码库时如何读取与使用本仓库的领域文档。

## 探索代码前先读取

- 仓库根目录的 **`GLOSSARY.md`**，或
- 仓库根目录的 **`GLOSSARY-MAP.md`**（若存在）：它会指向各个上下文独立的 `GLOSSARY.md`，按当前主题读取相关文件。
- **`docs/adr/`**：读取与当前即将修改领域相关的架构决策记录（ADR）。在多上下文仓库中，同时检查对应模块目录下的 `docs/adr/`。

若上述任一文件尚不存在，**静默继续**，不要为此报错或要求预先创建。`/domain-modeling` 技能（通过 `/grill-with-docs` 与 `/improve-codebase-architecture` 触发）会在术语或架构决策真正落定时按需惰性创建它们。

## 目录结构

单上下文仓库（本仓库采用的布局）：

```
/
├── GLOSSARY.md
├── docs/adr/
│   ├── 0001-xxx.md
│   └── 0002-yyy.md
└── Sources/
```

多上下文仓库（根目录存在 `GLOSSARY-MAP.md` 时）：

```
/
├── GLOSSARY-MAP.md
├── docs/adr/                          ← 全局架构决策
└── src/
    ├── ordering/
    │   ├── GLOSSARY.md
    │   └── docs/adr/                  ← 上下文内部架构决策
    └── billing/
        ├── GLOSSARY.md
        └── docs/adr/
```

## 使用术语表（Glossary）中的统一语言

当你的输出命名某个领域概念时（无论是在 Issue 标题、重构提案、排障假设还是测试名称中），必须使用 `GLOSSARY.md` 中定义的标准术语，不要偏离去使用术语表明确排斥的同义词。

如果你需要的概念尚未收录在术语表中，这通常意味着两种情况之一：要么你正在生造项目并不使用的概念（请重新审视），要么术语表存在真实缺口（记录下来交由 `/domain-modeling` 沉淀）。

## 显式标注 ADR 冲突

如果你的输出或方案与现有 ADR 相矛盾，必须显式指出，而不要静默覆盖：

> _与 ADR-0007（xxx）冲突，但值得重新讨论，因为……_
