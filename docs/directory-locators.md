# Directory Locators

Storage owns the Directory Locator (`storage.private.v1.DirectoryLocator`) and recognizes only
the `work` condition. Every other condition name and value format is a vocabulary the locating
contexts share, so that each reaches the same Directory by applying the same Locator to the same
facts without depending on the others. This document is that vocabulary.

## Conditions

| Condition | Value |
|---|---|
| `work` | The Work's identity |
| `subject` | The Work's Subject as `<kind>:<id>`, in the kinds its creating caller defines |
| `person` | The person the Work represents |
| `starter` | The person who started the Work |
| `project` | The Project's identity |
| `agent_definition` | The AgentDefinition's identity |

A Directory owner lists its facts ordered by condition name, each condition once.

## Directories located across contexts

| Directory | Locator | Located by |
|---|---|---|
| A Subject's inputs | `[subject]`, `inputs`, JuiceFS, permanent | The Subject's own context, which writes them; Agent mounts them read-only at `/workspace/inputs` |
| A Work's own inputs | `[work]`, `inputs`, JuiceFS, permanent | Agent, for a Work without a Subject |
| A Subject's Artifacts | `[subject]`, `artifacts`, JuiceFS, permanent | The Subject's own context; Agent publishes into it |
| A Work's own Artifacts | `[work]`, `artifacts`, JuiceFS, permanent | Agent, for a Work without a Subject |
| A Project's knowledge | `[project]`, `knowledge`, JuiceFS, permanent | The context keeping the Project's knowledge, which replaces it as a whole; Agent mounts it read-only at `/workspace/knowledge` |

Directories only Agent locates, such as a Work's HOME, Session Workspace and Agent Harness state,
are Agent's Work Layout and not listed here.
