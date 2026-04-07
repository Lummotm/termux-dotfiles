#!/usr/bin/env python3
import os
import re
import sys
import uuid

if len(sys.argv) > 1:
    NOTES_DIR = sys.argv[1]
else:
    NOTES_DIR = os.path.expanduser("~/Documents/Obsidian/")

EXCLUDING_KEYWORDS = {"attachments", "excalidraw", ".git", "books_vault"}

TODO_FOCUS = "00_focus.md"
TODO_BACKLOG = "01_todo.md"
TODO_INBOX = "02_todo_inbox.md"

FOCUS_TAGS = {
    "#urgent",
    "#math",
    "#math/analisis",
    "#math/compleja",
    "#math/diferenciales",
    "#uni",
}

ID_PATTERN = r"\^([a-z0-9]{8})"
TAG_PATTERN = r"(?<!\S)#[a-zA-Z0-9/]+(?!\S)"


def generate_id():
    return f"^{uuid.uuid4().hex[0:8]}"


def is_task(line):
    s = line.strip()

    if not (s.startswith("- [ ]") or s.lower().startswith("- [x]")):
        return False

    content = s[5:].strip()

    return bool(content)


def tag_priority(tag):
    t = tag.lower()
    if "urgent" in t:
        return 0
    if "math" in t:
        return 1
    if "uni" in t:
        return 2
    if "idea" in t:
        return 3
    if "cs" in t:
        return 4
    return 100


def sync_back_tasks():
    updates_by_note = {}
    todo_files = [
        os.path.join(NOTES_DIR, TODO_FOCUS),
        os.path.join(NOTES_DIR, TODO_BACKLOG),
        os.path.join(NOTES_DIR, TODO_INBOX),
    ]

    for todo_path in todo_files:
        if not os.path.exists(todo_path):
            continue
        todo_mtime = os.path.getmtime(todo_path)
        with open(todo_path, "r", encoding="utf-8") as f:
            for line in f:
                if not is_task(line):
                    continue

                status = line.lstrip()[3]
                id_match = re.search(ID_PATTERN, line)
                if not id_match:
                    continue
                task_id = id_match.group(0)

                # Buscamos TODOS los enlaces. El de origen es siempre el ÚLTIMO.
                links = re.findall(r"\[\[(.*?)\]\]", line)
                if not links:
                    continue
                note_name = links[-1]

                # Extraer texto: desde el final del checkbox hasta el inicio del ID
                # pero quitando el link de la nota que está al final.
                text_start_idx = line.find("]") + 2
                text_end_idx = line.find(task_id)
                text = line[text_start_idx:text_end_idx].strip()

                # Eliminar el link de la nota del texto si se coló (por si el ID está después del link)
                text = text.replace(f"[[{note_name}]]", "").strip()

                if note_name not in updates_by_note:
                    updates_by_note[note_name] = {}

                updates_by_note[note_name][task_id] = {
                    "status": status,
                    "text": text,
                    "todo_mtime": todo_mtime,
                }

    if not updates_by_note:
        return

    note_paths = {}
    for root, dirs, files in os.walk(NOTES_DIR):
        dirs[:] = [
            d
            for d in dirs
            if not d.startswith(".")
            and not any(k in d.lower() for k in EXCLUDING_KEYWORDS)
        ]
        for file in files:
            if file.endswith(".md"):
                name = file[:-3]
                if name in updates_by_note:
                    note_paths[name] = os.path.join(root, file)

    for note_name, tasks in updates_by_note.items():
        if note_name not in note_paths:
            continue
        path = note_paths[note_name]
        note_mtime = os.path.getmtime(path)

        with open(path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        changed = False
        new_lines = []
        for line in lines:
            if is_task(line):
                id_match = re.search(ID_PATTERN, line)
                if id_match and id_match.group(0) in tasks:
                    data = tasks[id_match.group(0)]
                    # Sincronizamos si el archivo TODO es más nuevo o igual (por margen de error)
                    if data["todo_mtime"] >= note_mtime:
                        prefix = line[: line.find("-")]
                        new_line = f"{prefix}- [{data['status']}] {data['text']} {id_match.group(0)}\n"
                        if line != new_line:
                            line = new_line
                            changed = True
            new_lines.append(line)

        if changed:
            with open(path, "w", encoding="utf-8") as f:
                f.writelines(new_lines)


def process_line(line):
    if not is_task(line):
        return line

    clean_line = line.rstrip()
    id_match = re.search(ID_PATTERN, clean_line)
    task_id = id_match.group(0) if id_match else generate_id()
    tags = re.findall(TAG_PATTERN, clean_line)

    raw_text = clean_line
    if id_match:
        raw_text = raw_text.replace(id_match.group(0), "")
    for t in tags:
        raw_text = re.sub(rf"(?<!\S){re.escape(t)}(?!\S)", "", raw_text)

    stripped = raw_text.lstrip()
    prefix = raw_text[: len(raw_text) - len(stripped)]
    status = stripped[:5]
    content = " ".join(stripped[5:].strip().split())

    return f"{prefix}{status} {content} {' '.join(tags)} {task_id}\n"


def write_tasks(filename, title, tasks_dict, is_list=False):
    path = os.path.join(NOTES_DIR, filename)
    with open(path, "w", encoding="utf-8") as f:
        f.write(
            f"---\nid: {filename.replace('.md', '')}\naliases: []\ntags: []\n---\n\n# {title}\n\n"
        )
        if is_list:
            for t in tasks_dict:
                f.write(f"{t}\n")
        else:
            sorted_tags = sorted(tasks_dict.keys(), key=lambda t: (tag_priority(t), t))
            for tag in sorted_tags:
                f.write(f"## {tag.replace('#', '')}\n")
                for t in tasks_dict[tag]:
                    f.write(f"{t}\n")
                f.write("\n")


# Sincronizar de TODOs -> Notas originales
sync_back_tasks()

inbox, focus, backlog = [], {}, {}

# Recolectar de Notas -> TODOs (esto incluye los cambios recién guardados)
for root, dirs, files in os.walk(NOTES_DIR):
    dirs[:] = [
        d
        for d in dirs
        if not d.startswith(".") and not any(k in d.lower() for k in EXCLUDING_KEYWORDS)
    ]

    for file in files:
        if not file.endswith(".md") or file in {TODO_FOCUS, TODO_BACKLOG, TODO_INBOX}:
            continue

        path = os.path.join(root, file)
        try:
            with open(path, "r", encoding="utf-8") as f:
                lines = f.readlines()
        except:
            continue

        new_lines, changed = [], False
        for line in lines:
            p_line = process_line(line)
            if p_line != line:
                changed = True
            new_lines.append(p_line)

            # Solo meter en los archivos índice las tareas NO completadas
            if is_task(p_line) and p_line.lstrip().startswith("- [ ]"):
                tags = re.findall(TAG_PATTERN, p_line)
                task_with_link = f"{p_line.rstrip()} [[{file[:-3]}]]"

                if not tags:
                    inbox.append(task_with_link)
                else:
                    target = focus if any(t in FOCUS_TAGS for t in tags) else backlog
                    main_tag = min(tags, key=tag_priority)
                    if main_tag not in target:
                        target[main_tag] = []
                    target[main_tag].append(task_with_link)

        if changed:
            with open(path, "w", encoding="utf-8") as f:
                f.writelines(new_lines)

write_tasks(TODO_FOCUS, "Focus", focus)
write_tasks(TODO_BACKLOG, "Todo", backlog)
write_tasks(TODO_INBOX, "Inbox", inbox, is_list=True)
