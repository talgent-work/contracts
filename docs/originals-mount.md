# Originals Mount

Storage publishes every JuiceFS Directory's files on one standing read-only mount. A trusted
reader, such as Project Knowledge, mounts it and reads originals in place by this layout alone:
no file query and no per-read authorization sit between them. The scope of the mount is the
authorization, chosen when the reader is deployed.

## Volume

| | |
|---|---|
| Claim | PersistentVolumeClaim `talgent-juicefs-originals`, in the namespace the Workbench is deployed to (`talgent`) |
| Access | `ReadOnlyMany`; the volume itself is read-only |
| Mount | `subPath: talgent/assets/directories`, with `readOnly: true` |
| File system | The JuiceFS file system Storage writes, with extended attributes enabled |

The Workbench's deployment owns the volume and the claim. A reader's deployment references the
claim by name from the same namespace and never creates, changes or writes it.

## Layout

```text
<owner>/
  <name>/<path>
```

- `<owner>` is the Directory's owner, the locating caller's facts in condition order, written
  as one path element: each fact as `<condition>=<value>`, facts joined by `,`, and in both
  every byte other than ASCII letters, digits, `-`, `.`, `_`, `:` and `@` written as `%XX`
  (upper-case hex). For example `{project: p1, subject: intent:123}` is
  `project=p1,subject=intent:123`. Storage keeps owners opaque; the reader interprets them and
  selects the Directories it reads.
- `<name>` is the Directory's name: one path element, never starting with `.`.
- A file Storage wrote is identified by its position, its Directory and its path. Its name,
  content, size and modification time are those on the file system.
- A Directory's folder may not exist yet; that Directory has no files. Only regular files are
  files; anything else is ignored, and links are never followed.

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
  new file with the old one at its name, and a rename moves a file to a free name within its
  Directory. A reader sees complete files only and needs no lock.
- **Replaced Directories are read through Storage.** A Directory whose content is replaced as a
  whole shows its current content through links, which a reader of this mount never follows;
  its files are read with the Reference Space Query Contract.
- **Replaced files finish reading.** A reader that opened a file before it was replaced keeps
  reading the old content to the end.
- **Deletion** unlinks the file at its name.
