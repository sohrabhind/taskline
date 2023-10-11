import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:taskline/database_helper.dart';

Future<void> saveLoginCredentials(String userId, String userPrivateKey) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage();
  // Saving the username using SharedPreferences
  await prefs.setString('user_id', userId);
  // Saving the password using flutter_secure_storage
  await secureStorage.write(key: 'user_private_key', value: userPrivateKey);
}

// Retrieve login credentials
Future<String> getUserId() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('user_id') ?? ''; // Returns empty string if username is not found
}

Future<String> getUserPrivateKey() async {
  const secureStorage = FlutterSecureStorage();
  return await secureStorage.read(key: 'user_private_key') ?? ''; // Returns empty string if password is not found
}

// Clear login credentials
Future<void> clearLoginCredentials() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage();
  // Remove the username using SharedPreferences
  await prefs.remove('user_id');
  // Remove the password using flutter_secure_storage
  await secureStorage.delete(key: 'user_private_key');
}

Future<void> main() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    WidgetsFlutterBinding.ensureInitialized();
    await WindowManager.instance.ensureInitialized();
    WindowManager.instance.setMinimumSize(const Size(240, 300));
    WindowManager.instance.setSize(const Size(240, 350));
    WindowManager.instance.setAlwaysOnTop(true);
    //WindowManager.instance.setBackgroundColor(Colors.transparent);
  }

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const TaskLineApp());

}


const String iconPath = "app_icon.ico";
const String loginUrl = "https://taskline.hindbyte.com/api/authentication.php";
const String myKeyUrl = "https://taskline.hindbyte.com/api/mykey.php";
const String myTasksUrl = "https://taskline.hindbyte.com/api/mytasks.php";
const String addTaskUrl = "https://taskline.hindbyte.com/api/addtask.php";
const String taskCompletedUrl = "https://taskline.hindbyte.com/api/task-completed.php";
const String completedTasksUrl = "https://taskline.hindbyte.com/api/completed-tasks.php";
const String deleteTaskUrl = "https://taskline.hindbyte.com/api/delete-task.php";
const String taskUpdateOrderUrl = "https://taskline.hindbyte.com/api/update-tasks.php";

class TaskLineApp extends StatelessWidget {
  const TaskLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Taskline',
      home: LoginScreen(),
    );
  }
}


class ListItem {
  int taskId;
  int userId;
  String taskTitle;
  int taskStatus;
  int taskPriority;
  int createdAt;
  int updatedAt;
  ListItem(this.taskId, this.userId, this.taskTitle, this.taskStatus, this.taskPriority, this.createdAt, this.updatedAt);
}


class CustomListView extends StatefulWidget {
  final List<ListItem> items;
  final ScrollController scrollController;
  final Function(int oldIndex, int newIndex) onReorder;

  const CustomListView({
    Key? key,
    required this.items,
    required this.scrollController,
    required this.onReorder,
  }) : super(key: key);

  @override
  _CustomListViewState createState() => _CustomListViewState();
}



int selectedIndex = -1;

int getCurrentUnixTimestampInSeconds() {
  // Get the current DateTime
  DateTime now = DateTime.now();

  // Calculate the Unix timestamp in seconds
  int unixTimestamp = now.millisecondsSinceEpoch ~/ 1000;

  return unixTimestamp;
}

class _CustomListViewState extends State<CustomListView> {


  @override
  void dispose() {
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      scrollController: widget.scrollController, // Attach the ScrollController here
      buildDefaultDragHandles: false,
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = widget.items.removeAt(oldIndex);
          widget.items.insert(newIndex, item);
        });
        widget.onReorder(oldIndex, newIndex); // Call the provided onReorder callback
      },

      children: List.generate(
        widget.items.length,
            (index) {
          final item = widget.items[index];
          return ReorderableDragStartListener(
            key: Key(item.taskId.toString()),
            index: index,
            child: Container(
              color: selectedIndex == item.taskId ? const Color(0xff0259f1) : null,
              child: InkWell(
                highlightColor: Colors.transparent,
                onTap: () {
                  setState(() {
                    selectedIndex = item.taskId;
                  });
                },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8.0),
                    child: Text(
                      item.taskTitle,
                      style: TextStyle(fontSize: 12,
                          color: selectedIndex == item.taskId ? const Color(0xffffffff) : null),
                    ),
                  ),
              ),
            ),
          );
        },
      ),
    );
  }

}

class TaskLineScreen extends StatefulWidget {
  final String userId;
  final String userPrivateKey;

  const TaskLineScreen({super.key, required this.userId, required this.userPrivateKey});

  @override
  _TaskLineScreenState createState() => _TaskLineScreenState();

}

class _TaskLineScreenState extends State<TaskLineScreen> with SingleTickerProviderStateMixin {
  List<String> tasks = [];
  List<String> completedTasks = [];
  TextEditingController taskController = TextEditingController();
  List<ListItem> myListItems = [];
  List<ListItem> myCompletedListItems = [];

  DatabaseHelper dbHelper = DatabaseHelper();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    retrieveDatabase();
    retrieveTasks();
    retrieveCompletedTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void addUniqueListItem(int taskId, int userId, String title, int status, int priority, int createdAt, int updatedAt) {
    if (!myListItems.any((item) => item.taskId == taskId)) {
      myListItems.add(ListItem(taskId, userId, title, status, priority, createdAt, updatedAt));
    }
  }

  void addUniqueCompleteListItem(int taskId, int userId, String title, int status, int priority, int createdAt, int updatedAt) {
    if (!myCompletedListItems.any((item) => item.taskId == taskId)) {
      myCompletedListItems.add(ListItem(taskId, userId, title, status, priority, createdAt, updatedAt));
    }
  }

  Future<void> retrieveDatabase() async {
    List<Map<String, dynamic>> dataList = await dbHelper.getData(getUserId(), 0);
    for (var data in dataList) {
      //int id = data['id'];
      int taskId = data['task_id'];
      int userId = data['user_id'];
      String title = data['title'];
      int status = data['status'];
      int priority = data['priority'];
      int createdAt = data['created_at'];
      int updatedAt = data['updated_at'];

      // Process the data as needed
      setState(() {
        addUniqueListItem(taskId, userId, title, status, priority, createdAt, updatedAt);
      });
      //print('id: $id, task_id: $taskId, user_id: $userId, title: $title, priority: $priority, status: $status, created_at: $createdAt, updated_at: $updatedAt');
    }

    List<Map<String, dynamic>> dataListCompleted = await dbHelper.getData(getUserId(), 1);
    for (var data in dataListCompleted) {
      //    int id = data['id'];
      int taskId = data['task_id'];
      int userId = data['user_id'];
      String title = data['title'];
      int priority = data['priority'];
      int status = data['status'];
      int createdAt = data['created_at'];
      int updatedAt = data['updated_at'];

      // Process the data as needed
      setState(() {
        addUniqueCompleteListItem(taskId, userId, title, status, priority, createdAt, updatedAt);
      });
      //print('id: $id, task_id: $taskId, user_id: $userId, title: $title, priority: $priority, status: $status, created_at: $createdAt, updated_at: $updatedAt');
    }

  }


  void insertData(int taskId, int userId, String taskTitle, int taskStatus, int taskPriority, int createdAt, int updatedAt) async {
    Map<String, dynamic> newData = {
      'task_id': taskId,
      'user_id': userId,
      'title': taskTitle,
      'status': taskStatus,
      'priority': taskPriority,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    await dbHelper.insertData(newData, 'tasks');
  }


  Future<void> retrieveTasks() async {
    final data = {"user_id": widget.userId, "user_private_key": widget.userPrivateKey};
    final response = await http.post(Uri.parse(myTasksUrl), body: data);
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (!result['error']) {
        final tasksData = result["my_tasks"];
        final activeTasks = tasksData
            .where((task) => int.parse(task["status"]) == 0)
            .toList();
        setState(() {
          for (var task in activeTasks) {
            int taskId = int.parse(task['task_id']);
            int userId = int.parse(task['user_id']);
            String title = task['title'];
            int status = int.parse(task['status']);
            int priority = int.parse(task['priority']);
            int createdAt = int.parse(task['created_at']);
            int updatedAt = int.parse(task['updated_at']);
            addUniqueListItem(taskId, userId, title, status, priority, createdAt, updatedAt);
            insertData(taskId, userId, title, status, priority, createdAt, updatedAt);
          }
        });
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Login Error"),
            content: Text(result['message']),
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Connection Error"),
          content: Text("Could not connect to the server."),
        ),
      );
    }
  }


  Future<void> retrieveCompletedTasks() async {
    final data = {"user_id": widget.userId, "user_private_key": widget.userPrivateKey};
    final response = await http.post(Uri.parse(completedTasksUrl), body: data);
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (!result['error']) {
        final tasksData = result["my_tasks"];
        final activeTasks = tasksData
            .where((task) => int.parse(task["status"]) == 1)
            .toList();
        setState(() {
          for (var task in activeTasks) {
            int taskId = int.parse(task['task_id']);
            int userId = int.parse(task['user_id']);
            String title = task['title'];
            int status = int.parse(task['status']);
            int priority = int.parse(task['priority']);
            int createdAt = int.parse(task['created_at']);
            int updatedAt = int.parse(task['updated_at']);
            addUniqueCompleteListItem(taskId, userId, title, status, priority, createdAt, updatedAt);
            insertData(taskId, userId, title, status, priority, createdAt, updatedAt);
          }
        });
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Login Error"),
            content: Text(result['message']),
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Connection Error"),
          content: Text("Could not connect to the server."),
        ),
      );
    }
  }

  Future scrollToBottom(ScrollController scrollController) async {
    while (scrollController.position.pixels != scrollController.position.maxScrollExtent) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  Future<void> addTask() async {
    final taskTitle = taskController.text;
    if (taskTitle.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Empty Task"),
          content: Text("Please enter a task."),
        ),
      );
      return;
    }

    final data = {
      "user_id": widget.userId,
      "user_private_key": widget.userPrivateKey,
      "task_title": taskTitle,
    };

    final response = await http.post(Uri.parse(addTaskUrl), body: data);
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (!result['error']) {
        setState(() {
          int taskId = int.parse(result['task_id']);
          int userId = int.parse(result['user_id']);
          String title = result['title'];
          int status = int.parse(result['status']);
          int priority = int.parse(result['priority']);
          int createdAt = int.parse(result['created_at']);
          int updatedAt = int.parse(result['updated_at']);
          addUniqueListItem(taskId, userId, title, status, priority, createdAt, updatedAt);
          taskController.clear();
        });
        scrollToBottom(scrollController);
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Login Error"),
            content: Text(result['message']),
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Connection Error"),
          content: Text("Could not connect to the server."),
        ),
      );
    }
  }

  Future<void> deleteTask(int taskId, int status) async {
    final data = {
      "user_id": widget.userId,
      "user_private_key": widget.userPrivateKey,
      "task_id": taskId.toString(),
    };
    final response = await http.post(Uri.parse(deleteTaskUrl), body: data);
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (!result['error']) {
        debugPrint(result['message']);
        setState(() {
          if (status == 0) {
            ListItem item = myListItems.firstWhere((item) => item.taskId == taskId);
            insertData(taskId, item.userId, item.taskTitle, 2, item.taskPriority, item.createdAt, getCurrentUnixTimestampInSeconds());
            myListItems.removeWhere((element) => element.taskId == taskId);
          } else if (status == 1) {
            ListItem item = myCompletedListItems.firstWhere((item) => item.taskId == taskId);
            insertData(taskId, item.userId, item.taskTitle, 2, item.taskPriority, item.createdAt, getCurrentUnixTimestampInSeconds());
            myCompletedListItems.removeWhere((element) => element.taskId == taskId);
          }
        });
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Login Error"),
            content: Text(result['message']),
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Connection Error"),
          content: Text("Could not connect to the server."),
        ),
      );
    }
  }

  Future<void> taskCompleted(int taskId) async {
    final data = {
      "user_id": widget.userId,
      "user_private_key": widget.userPrivateKey,
      "task_id": taskId.toString(),
    };
    final response = await http.post(Uri.parse(taskCompletedUrl), body: data);
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (!result['error']) {
        setState(() {
          setState(() {
            ListItem item = myListItems.firstWhere((item) => item.taskId == taskId);
            addUniqueCompleteListItem(taskId, item.userId, item.taskTitle, 1, item.taskPriority, item.createdAt, getCurrentUnixTimestampInSeconds());
            insertData(taskId, item.userId, item.taskTitle, 1, item.taskPriority, item.createdAt, getCurrentUnixTimestampInSeconds());
            myListItems.removeWhere((item) => item.taskId == taskId);
          });
        });
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Login Error"),
            content: Text(result['message']),
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Connection Error"),
          content: Text("Could not connect to the server."),
        ),
      );
    }
  }


  Future<void> updateOrder(List<int> taskIds) async {
    final data = {
      "user_id": widget.userId,
      "user_private_key": widget.userPrivateKey,
      "task_ids": jsonEncode(taskIds),
    };
    final response = await http.post(Uri.parse(taskUpdateOrderUrl), body: data);
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (!result['error']) {
        debugPrint(result['message']);
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Login Error"),
            content: Text(result['message']),
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Connection Error"),
          content: Text("Could not connect to the server."),
        ),
      );
    }
  }

  final ScrollController scrollController = ScrollController();
  final ScrollController scrollControllerC = ScrollController();

  @override
  Widget build(BuildContext context) {
    FocusNode focusNode = FocusNode();
    focusNode.requestFocus();
    return SafeArea(
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: null,
      body: RawKeyboardListener(
          focusNode: focusNode,
          onKey: (RawKeyEvent event) {
            if (event.runtimeType == RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.delete) {
              if (_tabController.index == 0 || _tabController.index == 1) {
                debugPrint("Delete");
                deleteTask(selectedIndex, _tabController.index); // Call your deleteTask function here for the first tab
              }
            }
          }, child: Column(
        children: [
          Container(color: const Color(0xFFFFFFFF), // Set the desired background color here
            child: SizedBox(
              height: 36,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  FittedBox(
                    child: Tab(icon: Icon( // <-- Icon
                      Icons.insert_drive_file_outlined,
                    ),),),
                  FittedBox(
                    child: Tab(icon: Icon( // <-- Icon
                      Icons.task_outlined,
                    ),),),
                  FittedBox(
                    child: Tab(icon: Icon( // <-- Icon
                      Icons.settings_rounded,
                    ),),),
                ],
                indicatorWeight: 1.5,
                indicatorColor: Colors.blue,
                labelColor: Colors.blue,
                unselectedLabelColor: const Color(0xFF808080),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Center(
                  child: CustomListView(
                    items: myListItems,
                    scrollController: scrollController,
                    onReorder: (oldIndex, newIndex) {
                      // Handle reordering here if needed
                      List<int> numberArray = [];
                      for (int index = 0; index < myListItems.length; index++) {
                        debugPrint('Reordered: $index');
                        ListItem item = myListItems[index];
                        insertData(item.taskId, item.userId, item.taskTitle, item.taskStatus, index, item.createdAt, getCurrentUnixTimestampInSeconds());
                        numberArray.add(item.taskId);
                      }
                      updateOrder(numberArray);
                    },
                  ),
                ),
                Center(
                  child: CustomListView(items: myCompletedListItems, scrollController: scrollControllerC,
                    onReorder: (oldIndex, newIndex) {
                      // Handle reordering here if needed
                      debugPrint('Reordered: $oldIndex -> $newIndex');
                    },
                  ),
                ),
                const Center(child: Text('Content for Settings')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: taskController,
              onSubmitted: (value) => addTask(),
              style: const TextStyle(fontSize: 13), // Optional: You can adjust the font size
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                labelText: "Type task and press Enter",
                labelStyle: TextStyle(fontSize: 12),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: addTask,
                style: ButtonStyle(
                  minimumSize: MaterialStateProperty.all(const Size(92, 40)), // Set the height and width
                  maximumSize: MaterialStateProperty.all(const Size(92, 40)), // Set the height and width
                  backgroundColor: MaterialStateProperty.all(const Color(0xFF70B3EA)), // Set button background color
                  foregroundColor: MaterialStateProperty.all(Colors.white.withOpacity(1)), // Set button text color
                ),
                child: const Text("Add Task",
                    style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: () {
                  taskCompleted(selectedIndex); // Call the taskCompleted function here
                },
                style: ButtonStyle(
                  minimumSize: MaterialStateProperty.all(const Size(92, 40)), // Set the height and width
                  maximumSize: MaterialStateProperty.all(const Size(92, 40)), // Set the height and width
                  backgroundColor: MaterialStateProperty.all(const Color(0xFF70B3EA)), // Set button background color
                  foregroundColor: MaterialStateProperty.all(Colors.white.withOpacity(1)), // Set button text color
                ),
                child: const Text("Done",
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8), // Add some padding below the buttons
          const StopwatchWidget(),
          const SizedBox(height: 16), // Add some padding below the buttons
        ],
      ),
      ),
    ));
  }
}


class StopwatchWidget extends StatefulWidget {
  const StopwatchWidget({super.key});

  @override
  _StopwatchWidgetState createState() => _StopwatchWidgetState();

}

class _StopwatchWidgetState extends State<StopwatchWidget> {

  String stopwatchText = '00:00:00:00';
  late Timer timer;
  int milliseconds = 0;

  void startTimer() {
    timer = Timer.periodic(const Duration(milliseconds: 44), (Timer t) {
      milliseconds += 44;
      int hours = milliseconds ~/ (3600 * 1000);
      int remainingMilliseconds = milliseconds % (3600 * 1000);
      int minutes = remainingMilliseconds ~/ (60 * 1000);
      remainingMilliseconds %= (60 * 1000);
      int seconds = remainingMilliseconds ~/ 1000;
      int centiSeconds = (remainingMilliseconds % 1000) ~/ 10;
      setState(() {
        stopwatchText = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}:${centiSeconds.toString().padLeft(2, '0')}';
      });
    });
  }

  void restartStopwatch() {
    timer.cancel();
    milliseconds = 0;
    startTimer();
  }

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            stopwatchText,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon( // <-- Icon
              Icons.restart_alt_rounded,
            ),
            splashRadius: 24,
            onPressed: () {
                restartStopwatch();
            },
          ),
        ],
      ),
    );
  }
}


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();

}


class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkSavedCredentials();
  }

  void checkSavedCredentials() async {
    String userId = await getUserId();
    String userPrivateKey = await getUserPrivateKey();
    if (userId.isNotEmpty && userPrivateKey.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskLineScreen(
            userId: userId,
            userPrivateKey: userPrivateKey,
          ),
        ),
      );
    }
  }

  void myKey() async {
    final data = {"app": "taskline"};
    final response = await http.post(Uri.parse(myKeyUrl), body: data);

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (!result['error']) {
        passwordController.text = result['user_private_key'];
      } else {
        showDialog (
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Error"),
            content: Text(result['message']),
          ),
        );
      }
    } else {
      showDialog (
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Connection Error"),
          content: Text("Could not connect to the server."),
        ),
      );
    }
  }

  void login() async {
    var password = passwordController.text;
    final data = {"user_private_key": password};
    final response = await http.post(Uri.parse(loginUrl), body: data);
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (!result['error']) {
        saveLoginCredentials(result['user_id'], result['user_private_key']);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskLineScreen(
              userId: result['user_id'],
              userPrivateKey: result['user_private_key'],
            ),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Login Error"),
            content: Text(result['message']),
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Connection Error"),
          content: Text("Could not connect to the server."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
    child: Scaffold(
          backgroundColor:  Colors.white,
      appBar: null,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:  Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: myKey,
              style: ButtonStyle(
                minimumSize: MaterialStateProperty.all(const Size(150, 50)), // Set the height and width
                backgroundColor: MaterialStateProperty.all(Colors.grey), // Set button background color
                //foregroundColor: MaterialStateProperty.all(Colors.white), // Set button text color
              ),
              child: const Text("Generate Key"),
            ),
            const SizedBox(height: 16.0),
            const Text("Key:"),
            TextField(
              controller: passwordController,
              obscureText: false,
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: login,
                style: ButtonStyle(
                  minimumSize: MaterialStateProperty.all(const Size(150, 50)), // Set the height and width
                  backgroundColor: MaterialStateProperty.all(Colors.grey), // Set button background color
                  //foregroundColor: MaterialStateProperty.all(Colors.white), // Set button text color
                ),
              child: const Text("Login"),
            ),
          ],
        ),
      ),
    ));
  }
}