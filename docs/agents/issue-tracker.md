# Issue 追踪器：GitHub

本仓库的 Issue 与规格说明保存在 GitHub Issues（`pcfprio/HiIOS`）中，所有操作统一使用 `gh` CLI。

## 操作约定

- **创建 Issue**：`gh issue create --title "..." --body "..."`。多行正文使用 heredoc。
- **读取 Issue**：`gh issue view <number> --json number,title,body,labels,comments`。
- **列出 Issue**：`gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`，按需配合 `--label` 与 `--state` 过滤。
- **设为父 Issue 的子 Issue（sub-issue）**：创建时使用 `gh issue create --parent <parent> ...`，或创建后执行 `gh issue edit <parent> --add-sub-issue <child>`（需 `gh` 2.94+）。旧版 `gh` 使用：`gh api --method POST repos/<owner>/<repo>/issues/<parent>/sub_issues -F sub_issue_id=<child-db-id>`（使用数值型数据库 ID，见下方 **阻塞关系**）。若未启用 sub-issues，则在子 Issue 正文顶部写入 `Part of #<parent>`。
- **阻塞关系（Blocking）**：使用 GitHub **原生 Issue 依赖关系**作为标准且 UI 可见的表示方式。通过 `gh issue create --blocked-by <n>,<n> ...` 或 `gh issue edit <child> --add-blocked-by <blocker>`（需 `gh` 2.94+）添加依赖边。旧版 `gh` 使用：`gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`，其中 `<blocker-db-id>` 为阻塞方 Issue 的数值型**数据库 ID**（通过 `gh api repos/<owner>/<repo>/issues/<n> --jq .id` 获取，而非 `#number` 或 `node_id`）。若原生依赖不可用，则回退为在子 Issue 正文顶部写入 `Blocked by: #<n>, #<n>`。当所有阻塞项均关闭时，该任务单解除阻塞。
- **统计未关闭的阻塞项数量**：`gh api repos/<owner>/<repo>/issues/<n> --jq .issue_dependencies_summary.blocked_by`（仅统计未关闭的阻塞项；为 `0` 表示可开始）。`gh issue view <n> --json blockedBy` 也会列出已关闭的阻塞项，因此需过滤：`--jq '[.blockedBy.nodes[] | select(.state == "OPEN")] | length'`。
- **评论 Issue**：`gh issue comment <number> --body "..."`。
- **添加／移除标签**：`gh issue edit <number> --add-label "..."` / `--remove-label "..."`。
- **关闭 Issue**：先用 `gh issue comment <number> --body "..."` 发布说明，再执行 `gh issue close <number>`。对已关闭的 Issue 执行 `gh issue close --comment` 会丢弃评论且仍返回退出码 `0`。

目标仓库由 `git remote -v` 自动推断；在克隆目录内运行 `gh` 时会自动识别。

仅向用户自己的仓库（`pcfprio/HiIOS`）提交 Issue，切勿提交到 `mattpocock/skills`（技能来源仓库）。在 fork 仓库中，`gh` 可能默认指向游父仓库，因此在每次会话首次执行 `gh issue create` 前，先用 `gh repo view --json nameWithOwner` 核对目标仓库；若不是用户自己的仓库，需先向用户确认。

## 将 Pull Request 作为分流入口（Triage surface）

**PRs as a request surface: no.** _（若本仓库将外部 PR 视为需求入口，可改为 `yes`；`/triage` 会读取此标记。）_

当设为 `yes` 时，PR 使用与 Issue 相同的标签和状态流转，对应命令替换为 `gh pr`：

- **读取 PR**：先运行 `gh pr view <number>`，再运行 `gh pr view <number> --comments`（非 TTY 环境下 `--comments` 仅输出评论而不含正文），并用 `gh pr diff <number>` 查看变更对比。
- **列出待分流的外部 PR**：`gh api --paginate 'repos/{owner}/{repo}/pulls?state=open' --jq '.[] | select(.author_association | IN("OWNER","MEMBER","COLLABORATOR") | not) | {number, title, author: .user.login, author_association, labels: [.labels[].name]}'`。
- **评论／标签／关闭**：`gh pr comment`、`gh pr edit --add-label`/`--remove-label`、`gh pr close`。

GitHub 的 Issue 与 PR 共用同一套编号空间，因此单独的 `#42` 可能是其中任意一种：先尝试 `gh pr view 42`，失败时回退到 `gh issue view 42`。

## 当技能提及“发布到 Issue 追踪器（publish to the issue tracker）”时

创建一个 GitHub Issue。

## 当技能提及“获取相关任务单（fetch the relevant ticket）”时

按上方 **读取 Issue** 的方式读取。

## 探路操作（Wayfinding operations）

供 `/wayfinder` 使用。**全局图（map）** 是单个父 Issue，各决策任务单作为其**子 Issue（child）**。

- **全局图（Map）**：带有 `wayfinder:map` 标签的单个 Issue，正文维护 Notes／Decisions-so-far／Fog。使用 `gh issue create --label wayfinder:map` 创建。
- **子任务单（Child ticket）**：作为 GitHub sub-issue 关联到全局图的 Issue（见 **设为父 Issue 的子 Issue**）。若未启用 sub-issues，则将该子项加入全局图正文的任务列表，并在子 Issue 正文顶部写入 `Part of #<map>`。标签格式为 `wayfinder:<type>`（`research`／`prototype`／`grilling`／`task`）。认领后，将该任务单指派给当前推进的开发者。
- **阻塞关系（Blocking）**：见上方 **操作约定** 中的 **阻塞关系**。
- **前沿查询（Frontier query）**：列出全局图下所有未关闭的子项（`gh issue list --state open`，限定在全局图的 sub-issues 或任务列表范围内），剔除仍存在未关闭阻塞项（见 **统计未关闭的阻塞项数量**，或 `Blocked by` 行中仍有未关闭 Issue）或已有指派人的条目；按全局图中的顺序取第一个作为当前前沿。
- **认领（Claim）**：`gh issue edit <n> --add-assignee @me`，作为会话的首次写入操作。
- **结项（Resolve）**：先用 `gh issue comment <n> --body "<answer>"` 发布结论，再执行 `gh issue close <n>`，最后在全局图的 Decisions-so-far 中追加一条上下文指针（结论摘要 + 链接）。
