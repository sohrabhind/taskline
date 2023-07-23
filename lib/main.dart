import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
      WindowManager.instance.setMinimumSize(const Size(270, 300));
      WindowManager.instance.setSize(const Size(270, 350));
      WindowManager.instance.setAlwaysOnTop(true);
  }
  runApp(const TaskLineApp());
}


const String iconPath = "icon.ico";
const String loginUrl = "https://taskline.hindbyte.com/api/authentication.php";
const String myKeyUrl = "https://taskline.hindbyte.com/api/mykey.php";
const String myTasksUrl = "https://taskline.hindbyte.com/api/mytasks.php";
const String addTaskUrl = "https://taskline.hindbyte.com/api/addtask.php";
const String taskCompletedUrl = "https://taskline.hindbyte.com/api/task-completed.php";
const String completedTasksUrl = "https://taskline.hindbyte.com/api/completed-tasks.php";
const String deleteTaskUrl = "https://taskline.hindbyte.com/api/delete-task.php";

class TaskLineApp extends StatelessWidget {
  const TaskLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task Manager',
      home: LoginScreen(),
    );
  }
}


class ListItem {
  int uniqueNumber;
  String title;
  ListItem(this.uniqueNumber, this.title);
}

class CustomListView extends StatefulWidget {
  final List<ListItem> items;

  const CustomListView({super.key, required this.items});

  @override
  _CustomListViewState createState() => _CustomListViewState();
}


int selectedIndex = -1;

class _CustomListViewState extends State<CustomListView> {

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = widget.items.removeAt(oldIndex);
          widget.items.insert(newIndex, item);
        });
      },
      children: List.generate(
        widget.items.length,
            (index) {
          final item = widget.items[index];
          return ReorderableDragStartListener(
            key: Key(item.uniqueNumber.toString()),
            index: index,
            child: Container(
              color: selectedIndex == item.uniqueNumber ? Colors.blue : null,
              child: InkWell(
                highlightColor: Colors.transparent,
                onTap: () {
                  setState(() {
                    selectedIndex = item.uniqueNumber;
                  });
                },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8.0),
                    child: Text(
                      item.title,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ),
            ),
          );
        },
      ),
    );
  }



  void showUniqueNumber(ListItem item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.title),
          content: Text("Unique Number: ${item.uniqueNumber}"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
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

class _TaskLineScreenState extends State<TaskLineScreen> {
  List<String> tasks = [];
  List<String> completedTasks = [];
  TextEditingController taskController = TextEditingController();
  List<ListItem> myListItems = [];

  @override
  void initState() {
    super.initState();
    retrieveTasks();
    //retrieveCompletedTasks();
  }

  Future<void> retrieveTasks() async {
    final data = {"user_id": widget.userId, "user_private_key": widget.userPrivateKey};
    final response = await http.post(Uri.parse(myTasksUrl), body: data);

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (!result['error']) {
        final tasksData = result["my_tasks"];
        final activeTasks = tasksData
            .where((task) => int.parse(task["task_status"]) == 0)
            .toList();
        setState(() {
          for (var task in activeTasks) {
            myListItems.add(ListItem(int.parse(task["task_id"]), task["task_name"]));
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

  /*
  Future<void> retrieveCompletedTasks() async {
    final data = {"user_id": widget.userId, "user_private_key": widget.userPrivateKey};
    final response = await http.post(Uri.parse(completedTasksUrl), body: data);

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (!result['error']) {
        final tasksData = result["my_tasks"];
        final completed = tasksData
            .where((task) => int.parse(task["task_status"]) == 1)
            .toList();
        setState(() {
          completedTasks = completed.map((task) => task["task_name"]).toList();
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
        builder: (context) => AlertDialog(
          title: Text("Connection Error"),
          content: Text("Could not connect to the server."),
        ),
      );
    }
  }
  */

  Future<void> addTask() async {
    final task = taskController.text;
    if (task.isEmpty) {
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
      "task_title": task,
    };

    final response = await http.post(Uri.parse(addTaskUrl), body: data);
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (!result['error']) {
        setState(() {
          myListItems.add(ListItem(int.parse(result['last_id']), task));
          taskController.clear();
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

  Future<void> deleteTask(int task) async {
    final data = {
      "user_id": widget.userId,
      "user_private_key": widget.userPrivateKey,
      "task_id": task.toString(),
    };
    final response = await http.post(Uri.parse(deleteTaskUrl), body: data);

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (!result['error']) {
        setState(() {
          setState(() {
            myListItems.removeWhere((item) => item.uniqueNumber == task);
          });
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
        builder: (context) => AlertDialog(
          title: Text("Connection Error"),
          content: Text("Could not connect to the server."),
        ),
      );
    }
  }

  Future<void> taskCompleted(int task) async {
    final data = {
      "user_id": widget.userId,
      "user_private_key": widget.userPrivateKey,
      "task_id": task.toString(),
    };
    final response = await http.post(Uri.parse(taskCompletedUrl), body: data);

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (!result['error']) {
        setState(() {
          setState(() {
            myListItems.removeWhere((item) => item.uniqueNumber == task);
          });
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
        builder: (context) => AlertDialog(
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
      appBar: null,
      body: Column(
        children: [
          Expanded(
            child: CustomListView(items: myListItems),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: taskController,
              onSubmitted: (value) => addTask(),
              style: const TextStyle(fontSize: 14), // Optional: You can adjust the font size
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                labelText: "Enter Task",
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: addTask,
                style: ButtonStyle(
                  minimumSize: MaterialStateProperty.all(const Size(100, 48)), // Set the height and width
                  backgroundColor: MaterialStateProperty.all(Colors.blue), // Set button background color
                  foregroundColor: MaterialStateProperty.all(Colors.white), // Set button text color
                ),
                child: const Text("Add Task"),
              ),
              ElevatedButton(
                onPressed: () {
                  taskCompleted(selectedIndex); // Call the taskCompleted function here
                },
                style: ButtonStyle(
                  minimumSize: MaterialStateProperty.all(const Size(100, 48)), // Set the height and width
                  backgroundColor: MaterialStateProperty.all(Colors.blue), // Set button background color
                  foregroundColor: MaterialStateProperty.all(Colors.white), // Set button text color
                ),
                child: const Text("Completed"),
              ),
            ],
          ),
          const SizedBox(height: 16), // Add some padding below the buttons
          const StopwatchWidget(),
          const SizedBox(height: 16), // Add some padding below the buttons
        ],
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
    timer = Timer.periodic(const Duration(milliseconds: 1000), (Timer t) {
      setState(() {
        milliseconds += 1000;
        int hours = milliseconds ~/ (3600 * 1000);
        int remainingMilliseconds = milliseconds % (3600 * 1000);
        int minutes = remainingMilliseconds ~/ (60 * 1000);
        remainingMilliseconds %= (60 * 1000);
        int seconds = remainingMilliseconds ~/ 1000;
        //int centiSeconds = (remainingMilliseconds % 1000) ~/ 10;
        stopwatchText = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';//:${centiSeconds.toString().padLeft(2, '0')}';
      });
    });
  }

  void restartStopwatch() {
    milliseconds = 0;
    startTimer();
  }

  @override
  void initState() {
    super.initState();
    restartStopwatch();
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
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: restartStopwatch,
            style: ButtonStyle(
              minimumSize: MaterialStateProperty.all(const Size(100, 48)), // Set the height and width
              backgroundColor: MaterialStateProperty.all(Colors.blue), // Set button background color
              foregroundColor: MaterialStateProperty.all(Colors.white), // Set button text color
            ),
            child: const Text("Restart"),
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
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Error"),
            content: Text(result['message']),
          ),
        );
      }
    } else {
      showDialog(
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
            title: Text("Login Error"),
            content: Text(result['message']),
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Connection Error"),
          content: Text("Could not connect to the server."),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea (child: Scaffold(
      appBar: null,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: myKey,
              style: ButtonStyle(
                minimumSize: MaterialStateProperty.all(const Size(150, 50)), // Set the height and width
                backgroundColor: MaterialStateProperty.all(Colors.blue), // Set button background color
                foregroundColor: MaterialStateProperty.all(Colors.white), // Set button text color
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
                  backgroundColor: MaterialStateProperty.all(Colors.blue), // Set button background color
                  foregroundColor: MaterialStateProperty.all(Colors.white), // Set button text color
                ),
              child: const Text("Login"),
            ),
          ],
        ),
      ),
    ));
  }
}
