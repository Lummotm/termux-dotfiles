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
PRIORITY_TAGS = {"#urgent", "#math"}
TODO_NOTE = "01_todo_inbox.md"
TODO_PRIORITY = "00_todo.md"


ID_PATTERN = re.compile(r"\^[a-z0-9]{8}")
TAG_PATTERN = re.compile(r"#[a-zA-Z0-9/]+")


def generate_id():
    return f" ^{uuid.uuid4().hex[0:8]}"


def process_line(line):
    clean_line = line.rstrip()
    if clean_line.lstrip().startswith("- [ ]") and not ID_PATTERN.search(clean_line):
        return f"{clean_line}{generate_id()}\n"
    return line


inbox_tasks = []
priority_tasks = {}

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

                clean_task = processed_line.rstrip()
                nombre_nota = file.replace(".md", "")
                clean_task = f"{clean_task} [[{nombre_nota}]]"

                if tags:
                    first_tag = tags[0]

                    if first_tag not in priority_tasks:
                        priority_tasks[first_tag] = []

                    priority_tasks[first_tag].append(clean_task)

                else:
                    inbox_tasks.append(clean_task)

        if file_changed:
            with open(file_path, "w", encoding="utf-8") as f:
                f.writelines(new_lines)


def sort_key(tag):
    if "#urgent" in tag:
        return 0, tag
    if "#math" in tag:
        return 1, tag

    return 999, tag


inbox_path = os.path.join(NOTES_DIR, TODO_NOTE)

with open(inbox_path, "w", encoding="utf-8") as f:
    f.write("---\n")
    f.write(f"id: {TODO_NOTE.replace('.md', '')}\n")
    f.write("tags: []\n")
    f.write("aliases: []\n")
    f.write("---\n\n")

    f.write("# 📥 Inbox\n\n")
    if not inbox_tasks:
        f.write("No hay tareas pendientes.\n")
    else:
        for t in inbox_tasks:
            f.write(f"{t}\n")

priority_path = os.path.join(NOTES_DIR, TODO_PRIORITY)
with open(priority_path, "w", encoding="utf-8") as f:
    f.write("---\n")
    f.write(f"id: {TODO_PRIORITY.replace('.md', '')}\n")
    f.write("tags: []\n")
    f.write("aliases: []\n")
    f.write("---\n\n")

    f.write("# 🏷️ Tareas por Tag\n\n")
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
