import os
import shutil
from datetime import datetime
from sys import argv

if len(argv) > 1:
    notes_dir = argv[1]
else:
    notes_dir = os.path.expanduser("~/Documents/Obsidian")

excluded_keywords = {"attachments", "excalidraw", ".git"}
priority_tags = {"#math", "#urgent"}
todo_note = "01_todo.md"
todo_priority = "00_todo_priority.md"

tasks_to_sync = {}
tagged_tasks = {}
normal_tasks = {}


def modify_completed(filepath, tasks):
    tmp_path = filepath + ".temp"
    with open(filepath, "r", encoding="utf-8", errors="ignore") as file:
        with open(tmp_path, "w", encoding="utf-8") as tmp:
            for line in file:
                if line.startswith("- [ ]"):
                    clean = line.replace("- [ ]", "").strip()
                    if clean in tasks:
                        tmp.write(f"- [x] {clean}\n")
                        continue
                tmp.write(line)
    shutil.move(tmp_path, filepath)


def get_sort_key(filename):
    name = filename.replace(".md", "")
    try:
        return datetime.strptime(name, "%d-%m-%Y").strftime("%Y-%m-%d")
    except ValueError:
        return "9999-99-99" + name


# Leer tareas completadas de los archivos To-Do
for todo_file in [todo_note, todo_priority]:
    path = os.path.join(notes_dir, todo_file)
    if not os.path.exists(path):
        continue

    current_source = None
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith("### From [["):
                current_source = line.split("[[")[1].split("]]")[0]
                if current_source not in tasks_to_sync:
                    tasks_to_sync[current_source] = []
            elif line.startswith("- [x]") and current_source:
                tasks_to_sync[current_source].append(line.replace("- [x]", "").strip())

# Procesar todas las notas en un solo recorrido
for root, _, files in os.walk(notes_dir):
    # No considerar carpetas que contengan las keywords, uso .lower por si decido cambiar el casing
    if any(kw in root.lower() for kw in excluded_keywords):
        continue

    for file in sorted(files, key=get_sort_key):
        if (
            not file.endswith(".md")
            or file in [todo_note, todo_priority]
            or file.startswith(".")
        ):
            continue

        filepath = os.path.join(root, file)
        name = file.replace(".md", "")

        # Sincronizar si hay tareas completadas
        if name in tasks_to_sync and tasks_to_sync[name]:
            modify_completed(filepath, tasks_to_sync[name])

        # Recolectar tareas pendientes actualizadas
        with open(filepath, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("- [ ]"):
                    content = line.strip() + "\n"
                    target_dict = (
                        tagged_tasks
                        if any(tg in line for tg in priority_tags)
                        else normal_tasks
                    )
                    if name not in target_dict:
                        target_dict[name] = []
                    target_dict[name].append(content)


# Escribir archivos finales con links funcionales
def write_to_file(filename, tasks_dict):
    path = os.path.join(notes_dir, filename)
    with open(path, "w", encoding="utf-8") as f:
        f.write(f"---\nid: {filename}\ntags: []\n---\n")
        for source, task_list in tasks_dict.items():
            f.write(f"\n### From [[{source}]]\n")
            f.writelines(task_list)


write_to_file(todo_priority, tagged_tasks)
write_to_file(todo_note, normal_tasks)
