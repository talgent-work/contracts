# Directory Locators

Storage owns the Directory Locator (`storage.private.v1.DirectoryLocator`) and recognizes only
the `work` condition. Every other condition name and value format is a vocabulary the locating
contexts share, so that each reaches the same Directory by applying the same Locator to the same
facts without depending on the others. This document is that vocabulary.

## Conditions

| Condition | Value |
|---|---|
| `work` | The Work's identity |
| `file_home` | The Work's File Home as `<kind>:<id>`, in the kinds its extension defines |
| `person` | The person the Work represents |
| `starter` | The person who started the Work |
| `work_caller` | The Work's Work Caller as `<kind>:<id>`, such as `project:<project id>` |
| `agent_definition` | The AgentDefinition's identity |

A Directory owner lists its facts ordered by condition name, each condition once.

## Directories located across contexts

| Directory | Locator | Located by |
|---|---|---|
| A File Home's inputs | `[file_home]`, `inputs`, JuiceFS, permanent | The File Home's own context, which writes them; Agent mounts them read-only at `/workspace/inputs` |
| A Work's own inputs | `[work]`, `inputs`, JuiceFS, permanent | Agent, for a Work without a File Home |
| A File Home's Artifacts | `[file_home]`, `artifacts`, JuiceFS, permanent | The File Home's own context; Agent publishes into it |
| A Work's own Artifacts | `[work]`, `artifacts`, JuiceFS, permanent | Agent, for a Work without a File Home |
| A Work Caller's knowledge | `[work_caller]`, `knowledge`, JuiceFS, permanent | The context keeping the Work Caller's knowledge, such as Project Knowledge for `project:<project id>`, which replaces it as a whole; Agent mounts it read-only at `/workspace/knowledge` for a Work Caller of an extension-defined kind, and a Standalone Work mounts none |

Directories only Agent locates, such as a Work's HOME, Session Workspace and Agent Harness state,
are Agent's Work Layout and not listed here.
