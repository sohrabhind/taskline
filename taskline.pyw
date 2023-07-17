import tkinter as tk
from tkinter import messagebox
import time
import os

class DragDropListbox(tk.Listbox):
    """ A Tkinter listbox with drag'n'drop reordering of entries. """
    def __init__(self, master, **kw):
        kw['selectmode'] = tk.SINGLE
        tk.Listbox.__init__(self, master, kw)
        self.bind('<Button-1>', self.setCurrent)
        self.bind('<B1-Motion>', self.shiftSelection)
        self.curIndex = None

    def setCurrent(self, event):
        self.curIndex = self.nearest(event.y)

    def shiftSelection(self, event):
        i = self.nearest(event.y)
        if i < self.curIndex:
            x = self.get(i)
            self.delete(i)
            self.insert(i+1, x)
            self.curIndex = i
        elif i > self.curIndex:
            x = self.get(i)
            self.delete(i)
            self.insert(i-1, x)
            self.curIndex = i
        save_tasks()

def add_task(event=None):
    task = entry.get()
    if task:
        task_list.insert(tk.END, task)
        entry.delete(0, tk.END)
        task_list.yview_moveto(1)
        save_tasks()
    else:
        messagebox.showwarning('Empty Task', 'Please enter a task.')

def delete_task(event=None):
    try:
        index = task_list.curselection()
        task_list.delete(index)
        save_tasks()
    except:
        messagebox.showwarning('No Task Selected', 'Please select a task to delete.')

def clear_tasks():
    confirmed = messagebox.askyesno('Clear All', 'Are you sure you want to clear all tasks?')
    if confirmed:
        task_list.delete(0, tk.END)
        save_tasks()

def save_tasks():
    tasks = task_list.get(0, tk.END)
    with open('tasks.txt', 'w') as file:
        for task in tasks:
            file.write(task + '\n')

def retrieve_tasks():
    try:
        with open('tasks.txt', 'r') as file:
            for line in file:
                task = line.strip()
                task_list.insert(tk.END, task)
    except FileNotFoundError:
        pass

def restart_stopwatch():
    global start_time
    start_time = time.time()
    update_stopwatch()

def update_stopwatch():
    elapsed_time = time.time() - start_time
    total_milliseconds = int(elapsed_time * 1000)
    hours = total_milliseconds // (3600 * 1000)
    remaining_milliseconds = total_milliseconds % (3600 * 1000)
    minutes = remaining_milliseconds // (60 * 1000)
    remaining_milliseconds %= (60 * 1000)
    seconds = remaining_milliseconds // 1000
    milliseconds = remaining_milliseconds % 1000

    stopwatch_label.config(text=f'{hours:02d}:{minutes:02d}:{seconds:02d}:{(str(milliseconds)+"00")[:2]}')
    stopwatch_label.after(16, update_stopwatch)


window = tk.Tk()
icon_path = "icon.ico"
if os.path.exists(icon_path):
    window.iconbitmap(default=icon_path)
window.title('Task Manager')
window.attributes('-topmost', True)  # Set the window to be always on top

# Create the listbox_border frame with white background
listbox_border = tk.Frame(window, bg="white")
listbox_border.pack(padx=(10, 10), pady=(5, 5), fill=tk.BOTH, expand=True)

# Create the task_list listbox inside the listbox_border frame
task_list = DragDropListbox(listbox_border, width=50, activestyle='none', borderwidth=0, highlightthickness=0)
task_list.pack(padx=8, pady=8, fill=tk.BOTH, expand=True)

# Create the frame frame with white background
frame = tk.Frame(window, bg="white")
frame.pack(padx=(10, 10), pady=(5, 5), fill=tk.X)

# Create an entry field for new tasks
entry = tk.Entry(frame, width=50, borderwidth=0, highlightthickness=0)
entry.pack(padx=8, pady=8, fill=tk.X)

# Bind the Enter key to the entry field
entry.bind('<Return>', add_task)
# Bind the Delete key to the task list
task_list.bind('<Delete>', delete_task)

frame1 = tk.Frame(window)
frame2 = tk.Frame(window)
frame1.pack()
frame2.pack()

# Create buttons with padding
add_button = tk.Button(frame1, text='Add Task', command=add_task)
add_button.pack(side=tk.LEFT, padx=(10, 10), pady=(5, 5))

delete_button = tk.Button(frame1, text='Remove', command=delete_task)
delete_button.pack(side=tk.LEFT, padx=(10, 10), pady=(5, 5))

clear_button = tk.Button(frame1, text='Clear All', command=clear_tasks)
clear_button.pack(side=tk.LEFT, padx=(10, 10), pady=(5, 5))


# Create stopwatch label
stopwatch_label = tk.Label(frame2, text='00:00:00:00', font=('Arial', 19))
stopwatch_label.pack(side=tk.LEFT, padx=(10, 10), pady=(0, 5))

reset_button = tk.Button(frame2, text='Restart', command=restart_stopwatch)
reset_button.pack(side=tk.LEFT, padx=(10, 10), pady=(0, 5))

# Retrieve tasks from the file
retrieve_tasks()

# Variables for stopwatch
start_time = 0
restart_stopwatch()
window.mainloop()