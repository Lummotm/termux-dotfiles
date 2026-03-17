#!/usr/bin/env python3
import os
import re
import sys
import uuid

if len(sys.argv) > 1:
    NOTES_DIR = sys.argv[1]
else:
    NOTES_DIR = os.path.expanduser("~/Documents/Obsidian/")

EXCLUDING_KEYWORDS = {"attachments", "excalidraw", ".git", "books_vault", "seguimiento"}
TODO_NOTE = "01_todo_inbox.md"
TODO_PRIORITY = "00_todo.md"

ID_PATTERN = re.compile(r"\^([a-z0-9]{8})")
# TAG_PATTERN = re.compile(r"#[a-zA-Z0-9/]+") gemini lo mejoro para meter - no se como se lee eso la vd
TAG_PATTERN = re.compile(r"(?<!\S)#[a-zA-Z0-9/\-_]+(?!\S)")


def generate_id():
    return f" ^{uuid.uuid4().hex[0:8]}"


def sync_back_tasks():
    """
    Sincroniza texto y estado desde los TODOs hacia las notas originales.
    Utiliza la fecha de modificación (mtime) para asegurar que solo el
    archivo modificado más recientemente sobrescribe al otro.
    """
    TODO_TASK_PATTERN = re.compile(
        r"^\s*-\s*\[([ xX])\]\s+(.*?)\s+(\^[a-z0-9]{8})\s*\[\[(.*?)\]\]\s*$"
    )

    updates_by_note = {}
    todo_files = [
        os.path.join(NOTES_DIR, TODO_NOTE),
        os.path.join(NOTES_DIR, TODO_PRIORITY),
    ]

    for todo_path in todo_files:
        if not os.path.exists(todo_path):
            continue

        todo_mtime = os.path.getmtime(todo_path)

        with open(todo_path, "r", encoding="utf-8") as f:
            for line in f:
                match = TODO_TASK_PATTERN.match(line)
                if match:
                    status = match.group(1).lower()
                    text = match.group(2).strip()
                    task_id = match.group(3)
                    note_name = match.group(4)

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
            and not any(kw in d.lower() for kw in EXCLUDING_KEYWORDS)
        ]
        for file in files:
            if file.endswith(".md"):
                note_name_without_ext = file[:-3]
                if note_name_without_ext in updates_by_note:
                    note_paths[note_name_without_ext] = os.path.join(root, file)

    ORIGINAL_TASK_PATTERN = re.compile(
        r"^(\s*-\s*\[)[ xX](\]\s+)(.*?)\s+(\^[a-z0-9]{8})\s*$"
    )

    for note_name, tasks_to_update in updates_by_note.items():
        if note_name not in note_paths:
            continue

        file_path = note_paths[note_name]
        note_mtime = os.path.getmtime(file_path)
        changed = False
        updated_lines = []

        try:
            with open(file_path, "r", encoding="utf-8") as f:
                lines = f.readlines()

            for line in lines:
                id_match = ID_PATTERN.search(line)
                if id_match:
                    task_id = f"^{id_match.group(1)}"
                    if task_id in tasks_to_update:
                        task_data = tasks_to_update[task_id]

                        if task_data["todo_mtime"] > note_mtime:
                            orig_match = ORIGINAL_TASK_PATTERN.match(line)
                            if orig_match:
                                prefix = orig_match.group(1)
                                suffix = orig_match.group(2)
                                new_line = f"{prefix}{task_data['status']}{suffix}{task_data['text']} {task_id}\n"

                                if line != new_line:
                                    line = new_line
                                    changed = True
                updated_lines.append(line)

            if changed:
                with open(file_path, "w", encoding="utf-8") as f:
                    f.writelines(updated_lines)
        except Exception as e:
            print(f"Error procesando {file_path}: {e}")


def process_line(line):
    """
    Auto-formatea la línea de la tarea:
    1. Extrae tags e IDs de cualquier parte.
    2. Limpia el texto de espacios extra.
    3. Reconstruye garantizando: Texto -> Tags -> ID.
    """
    # Solo procesa si es una tarea
    if not re.match(r"^\s*-\s*\[[ xX]\]", line):
        return line

    clean_line = line.rstrip()

    # Extraer ID
    id_match = ID_PATTERN.search(clean_line)
    task_id = id_match.group(0) if id_match else ""

    # Si es una tarea pendiente sin ID, generamos uno nuevo
    if not task_id and clean_line.lstrip().startswith("- [ ]"):
        task_id = generate_id().strip()

    # Extraer Tags
    tags = TAG_PATTERN.findall(clean_line)

    # Limpiar la línea base quitando ID y tags
    raw_text = clean_line
    if id_match:
        raw_text = raw_text.replace(id_match.group(0), "")
    for tag in set(tags):
        raw_text = re.sub(rf"(?<!\S){tag}(?!\S)", "", raw_text)

    # Extraemos el prefijo (ej: "  - [ ]") y el texto residual
    prefix_match = re.match(r"^(\s*-\s*\[[ xX]\])(.*)$", raw_text)
    if prefix_match:
        prefix = prefix_match.group(1)
        text_content = prefix_match.group(2)

        # Eliminamos múltiples espacios extraños en el texto
        text_content = re.sub(r"\s+", " ", text_content).strip()

        # Reconstrucción con el orden (tarea + tag + id + [[filename]])
        new_line = prefix
        if text_content:
            new_line += f" {text_content}"

        tags_str = " ".join(tags)
        if tags_str:
            new_line += f" {tags_str}"

        if task_id:
            new_line += f" {task_id}"

        return new_line + "\n"

    return line


# Sincronizar hacia atrás
sync_back_tasks()

inbox_tasks = []
priority_tasks = {}

# Procesar notas (auto-formatear, recolectar tareas)
for root, dirs, files in os.walk(NOTES_DIR):
    dirs[:] = [
        d
        for d in dirs
        if not d.startswith(".")
        and not any(kw in d.lower() for kw in EXCLUDING_KEYWORDS)
    ]

    for file in files:
        if not file.endswith(".md") or file in {TODO_NOTE, TODO_PRIORITY}:
            continue
        file_path = os.path.join(root, file)
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                lines = f.readlines()
        except Exception:
            continue
        file_changed = False

        new_lines = []
        for line in lines:
            processed_line = process_line(line)

            if line != processed_line:
                file_changed = True
            new_lines.append(processed_line)

            if processed_line.lstrip().startswith("- [ ]"):
                tags = TAG_PATTERN.findall(processed_line)
                nombre_nota = file.replace(".md", "")

                clean_task = processed_line.rstrip()
                task_with_link = f"{clean_task} [[{nombre_nota}]]"

                if tags:
                    for tag in tags:
                        if tag not in priority_tasks:
                            priority_tasks[tag] = []
                        # Evita añadir la misma tarea varias veces si duplicaste un tag
                        if task_with_link not in priority_tasks[tag]:
                            priority_tasks[tag].append(task_with_link)
                else:
                    inbox_tasks.append(task_with_link)

        if file_changed:
            with open(file_path, "w", encoding="utf-8") as f:
                f.writelines(new_lines)


def sort_key(tag):
    if "#urgent" in tag:
        return 0, tag
    if "#math" in tag:
        return 1, tag
    return 999, tag


# Escribir archivos TODO
# Inbox
inbox_path = os.path.join(NOTES_DIR, TODO_NOTE)
with open(inbox_path, "w", encoding="utf-8") as f:
    f.write("---\nid: 01_todo_inbox\ntags: []\naliases: []\n---\n\n# 📥 Inbox\n\n")
    if not inbox_tasks:
        f.write("No hay tareas pendientes.\n")
    else:
        for t in inbox_tasks:
            f.write(f"{t}\n")

# Priority
priority_path = os.path.join(NOTES_DIR, TODO_PRIORITY)
with open(priority_path, "w", encoding="utf-8") as f:
    f.write("---\nid: 00_todo\ntags: []\naliases: []\n---\n\n# 🏷️ Tareas por Tag\n\n")
    if not priority_tasks:
        f.write("No hay tareas tageadas.\n")
    else:
        sorted_tags = sorted(priority_tasks.keys(), key=sort_key)
        for tag in sorted_tags:
            tag_str = tag.replace("#", "")
            f.write(f"## {tag_str}\n")
            for t in priority_tasks[tag]:
                f.write(f"{t}\n")
            f.write("\n")
