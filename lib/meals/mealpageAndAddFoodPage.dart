import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pizza_ordering_app/gemini_utils.dart';
import 'LoggedMeal.dart';
import 'addmeallogpagewidget.dart';

class MealPage2 extends StatefulWidget {
  @override
  State<MealPage2> createState() => _MealPage2State();
}

class _MealPage2State extends State<MealPage2> {
  DateTime _selectedDate = DateTime.now();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late LoggedMeal currentMeal;

  @override
  void initState() {
    super.initState();
    _updateCurrentMeal();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2010),
      lastDate: DateTime(2050),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
    await _updateCurrentMeal();
  }

  Future<void> _updateCurrentMeal() async {
    final meal = await _fetchLoggedMeal();
    if (meal != null) {
      setState(() {
        currentMeal = meal;
      });
    }
  }

  Future<LoggedMeal?> _fetchLoggedMeal() async {
    String userId = _auth.currentUser!.uid;

    DateTime startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
    DateTime endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    QuerySnapshot querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('loggedmeals')
        .where('timeOfLogging', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timeOfLogging', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      Map<String, dynamic> data = querySnapshot.docs.first.data() as Map<String, dynamic>;
      LoggedMeal fetchedData = LoggedMeal.fromMap(data);
      return fetchedData;
    } else {
      return null;
    }
  }

  Future<bool> _deleteMealItem(MealType mealType, MealItem mealItem) async {
    String userId = _auth.currentUser!.uid;
    DateTime startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);

    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('loggedmeals')
          .where('timeOfLogging', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timeOfLogging', isLessThanOrEqualTo: Timestamp.fromDate(startOfDay.add(Duration(days: 1))))
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentReference docRef = querySnapshot.docs.first.reference;

        // Update the meal type
        int mealTypeIndex = currentMeal.mealTypes.indexWhere((mt) => mt.mealTypeName == mealType.mealTypeName);
        if (mealTypeIndex != -1) {
          currentMeal.mealTypes[mealTypeIndex].mealItems.removeWhere((item) => item.id == mealItem.id);
          currentMeal.mealTypes[mealTypeIndex].totalCalories -= mealItem.calories;
        }

        // Update Firestore
        await docRef.update(currentMeal.toMap());

        // Update local state
        setState(() {
          // The currentMeal has already been updated above
        });

        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting meal item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete meal item. Please try again.')),
      );
      return false;
    }
  }
  Future<bool> _showDeleteConfirmationDialog(MealType mealType, MealItem mealItem) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Meal Item'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete this meal item?'),
                Text(mealItem.mealItemName, style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(true);
                _deleteMealItem(mealType, mealItem);
              },
            ),
          ],
        );
      },
    ) ?? false;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calories Remaining'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildDateTimePicker(context),
            _buildCaloriesRemaining(),
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: Icon(Icons.add, color: Colors.blue),
                title: Text('LOG FOOD', style: TextStyle(color: Colors.blue)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddMealLogPage(
                      model: getGeminiInstance(),
                      addMealToLog: addMealToLog,
                    ),
                  ),
                ),
              ),
            ),
            FutureBuilder<LoggedMeal?>(
              future: _fetchLoggedMeal(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                } else if (snapshot.hasData) {
                  LoggedMeal loggedMeal = snapshot.data!;
                  return Column(
                    children: currentMeal.mealTypes
                        .map((mealType) => _buildMealSection(context, mealType))
                        .toList(),
                  );
                } else {
                  return _buildNoMealsLogged(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMealsLogged(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'No meals logged for this date.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void addMealToLog(LoggedMeal meal){
    setState(() {
      currentMeal = meal;
    });
  }

  Widget _buildDateTimePicker(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Center(
        child: InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Log Date',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                SizedBox(width: 5),
                Icon(Icons.calendar_today, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, yyyy').format(_selectedDate),
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaloriesRemaining() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FutureBuilder<LoggedMeal?>(
                future: _fetchLoggedMeal(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  } else if (snapshot.hasData) {
                    LoggedMeal loggedMeal = snapshot.data!;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            child: Text('Total Calories: ${loggedMeal.totalCaloriesLoggedMeal} kCal', style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),)
                        ),
                      ],
                    );
                  } else {
                    return Text('Total Calories: 0 kCal', style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white));
                  }
                },
              ),
            ],
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMealSection(BuildContext context, MealType mealType) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.restaurant, color: Colors.blue),
            title: Text(mealType.mealTypeName,
                style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text('${mealType.totalCalories} kCal',
                style: TextStyle(color: Colors.blue)),
          ),
          ...mealType.mealItems.map((food) => Dismissible(
            key: Key(food.id),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: 20),
              child: Icon(Icons.delete, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              return await _showDeleteConfirmationDialog(mealType, food);
            },
            child: ListTile(
              title: Text(food.mealItemName),
              trailing: Text('${food.calories} kCal',
                  style: TextStyle(color: Colors.grey)),
            ),
          )),
        ],
      ),
    );
  }
}