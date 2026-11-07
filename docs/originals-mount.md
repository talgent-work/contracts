# Originals Mount

Storage publishes every File Space's files on one standing read-only mount. A trusted reader,
such as Project Knowledge, mounts it and reads originals in place by this layout alone: no
file query and no per-read authorization sit between them. The scope of the mount is the
authorization, chosen when the reader is deployed.

## Volume

| | |
|---|---|
| Claim | PersistentVolumeClaim `talgent-juicefs-originals`, in the namespace the Workbench is deployed to (`talgent`) |
| Access | `ReadOnlyMany`; the volume itself is read-only |
| Mount | `subPath: talgent/assets/spaces`, with `readOnly: true` |
| File system | The JuiceFS file system Storage writes, with extended attributes enabled |

The Workbench's deployment owns the volume and the claim. A reader's deployment references the
claim by name from the same namespace and never creates, changes or writes it.

## Layout

```text
<owner>/
  attachments/<name>
  artifacts/<name>
```

- `<owner>` is the File Space's owner identity, exactly as the caller that opened the space
  named it. Storage keeps it opaque; the reader interprets owner identities and selects the
  ones it reads. An owner is one path element: never empty, never starting with `.`, never
  containing `/`, `\` or NUL.
- `attachments/` holds the owner's input files; `artifacts/` holds the files Work Agents
  published.
- A file is identified by its position: owner, kind directory and name. Its name, content, size
  and modification time are those on the file system.
- A space or kind directory may not exist yet; that space has no files of that kind. Only
  regular files are files of a space; anything else is ignored, and links are never followed.

## Extended attributes

Each file may carry these attributes. Values are UTF-8 text; an absent attribute means the fact
was not recorded.

| Attribute | Value |
|---|---|
| `user.talgent.uploader` | The Account id of the person who uploaded an Attachment |
| `user.talgent.work` | The Work that published an Artifact |
| `user.talgent.content_type` | The media type declared at upload |

Other `user.talgent.*` attributes are Storage's own and not part of this contract.

## Guarantees

- **One writer.** Storage is the only writer of the published layout; every reader mounts it
  read-only.
- **Complete files only.** Every write lands in a staging area outside the published layout and
  becomes visible by one atomic rename: a create renames to a free name, a replace exchanges the
  new file with the old one at its name, a rename moves a file to a free name within its kind
  directory. A reader sees complete files only and needs no lock.
- **Replaced files finish reading.** A reader that opened a file before it was replaced keeps
  reading the old content to the end.
- **Deletion** unlinks the file at its name.
