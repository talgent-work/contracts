# Mapped View Mount

Storage's Mapped View is a read-only tree of Directory Mappings, addressed by path. A caller maps
a Directory at a mapped path with `DirectoryService.MapDirectory`; Storage shows the Directory's
files there as the same files and keeps them current until `UnmapDirectory` or reclamation. A
standing reader mounts one mapped path read-only through a volume fixed at deployment and reads
every mapping beneath it, with no request per file. The mapped path the volume shows is the
reader's scope, chosen when it is deployed.

## Mapping prefixes

Storage's configuration gives a caller token at most one mapping prefix, itself a mapped path.
The caller maps and unmaps only strictly beneath it. Callers choose and interpret their paths
beneath their prefix; Storage never does.

## Volume

| | |
|---|---|
| Claim | PersistentVolumeClaim `talgent-juicefs-view-project-originals`, showing the mapped path `project-originals`, in the namespace the Workbench is deployed to (`talgent`) |
| Access | `ReadOnlyMany`; the volume itself is read-only |
| Shows | The mapped path: the volume's root is the mapped path itself |
| File system | The JuiceFS file system Storage writes, with extended attributes enabled |

The Workbench's deployment owns the volume and the claim. A reader's deployment references the
claim by name from the same namespace, mounts it with `readOnly: true`, and never creates,
changes or writes it.

## Layout

A reader chooses a mount root `<root>` and mounts the claim of mapped path `M` at `<root>/M`. A
mapping at mapped path `P` beneath `M` then lies at `<root>/P`:

```text
<root>/
  <P>/<file path>
```

- `<file path>` is a file's name in the mapped Directory, or, for a Directory whose content is
  replaced as a whole, its relative path in the current content.
- A file's name, content, size and modification time are those of the Directory's file: it is
  the same file, never a copy.
- A mapping whose Directory has no files may have no folder.
- Only regular files are files. Folders are Storage's; anything else is ignored, and links are
  never followed.

## Extended attributes

Each file carries the attributes Storage recorded when it wrote it. Values are UTF-8 text; an
absent attribute means the fact was not recorded.

| Attribute | Value |
|---|---|
| `user.talgent.uploader` | The Account id of the person who uploaded an Attachment |
| `user.talgent.work` | The Work that published an Artifact |
| `user.talgent.content_type` | The media type declared at upload |

Other `user.talgent.*` attributes are Storage's own and not part of this contract.

## Guarantees

- **One writer.** Only Storage writes the Mapped View; every reader mounts it read-only.
- **Same files.** A mapped file is the Directory's file, so the Directory stays the only
  authority and its attributes come along.
- **Complete files only.** A file appears only once complete. A replaced file is a new file at
  the same name; a reader that opened the old one keeps reading it to the end.
- **Fewer, never more.** Every change Storage carries out in a mapped Directory reaches its
  mapped paths. An interrupted change leaves a mapping missing a file, never showing one the
  Directory no longer holds; Storage repairs every mapping at least hourly.
- **No write bypasses Storage.** A mapped Directory is never mounted read-write, and a Directory
  once mounted read-write is never mapped.
- **Mappings never overlap.** No mapping's path is, lies inside or lies above another's.
- **Ending a mapping.** Unmapping, or reclaiming the Directory, removes the mapping's files and
  the folders it emptied.
