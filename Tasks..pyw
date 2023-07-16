import tkinter as tk
from tkinter import messagebox
import time

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


def start_stopwatch():
    global start_time
    start_time = time.time()
    update_stopwatch()

def pause_stopwatch():
    global is_paused
    is_paused = not is_paused

def reset_stopwatch():
    global start_time
    start_time = time.time()
    update_stopwatch()

def update_stopwatch():
    if is_paused:
        return
    elapsed_time = time.time() - start_time
    hours = int(elapsed_time // 3600)
    minutes = int((elapsed_time % 3600) // 60)
    seconds = int(elapsed_time % 60)
    stopwatch_label.config(text=f'{hours:02d}:{minutes:02d}:{seconds:02d}')
    stopwatch_label.after(1000, update_stopwatch)


root = tk.Tk()
root.title('Sticky Task List')
root.attributes('-topmost', True)  # Set the window to be always on top

# Create the task list
task_list = DragDropListbox(root, width=50, activestyle='none')
task_list.pack(padx=(10, 10), pady=(5, 5))


frame = tk.Frame(root, width=50)
frame.pack(padx=(10, 10), pady=(5, 5))

# Create an entry field for new tasks
entry = tk.Entry(frame, width=50)
entry.grid(row=0, column=0, ipadx = 0, ipady=7)

# Bind the Enter key to the entry field
entry.bind('<Return>', add_task)
# Bind the Delete key to the task list
task_list.bind('<Delete>', delete_task)

frame1 = tk.Frame(root)
frame2 = tk.Frame(root)
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
stopwatch_label = tk.Label(frame2, text='00:00:00', font=('Arial', 20))
stopwatch_label.pack(side=tk.LEFT, padx=(10, 10), pady=(0, 5))

reset_button = tk.Button(frame2, text='Restart', command=reset_stopwatch)
reset_button.pack(side=tk.LEFT, padx=(10, 10), pady=(0, 5))

# Retrieve tasks from the file
retrieve_tasks()

# Variables for stopwatch
start_time = 0
is_paused = False

root.mainloop()
