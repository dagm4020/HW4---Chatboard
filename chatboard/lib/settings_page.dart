import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'app_drawer.dart';
import 'package:intl/intl.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKeyPassword = GlobalKey<FormState>();
  DateTime? _dob;
  bool _isLoading = false;
  String _successMessage = '';
  String _errorMessage = '';

  final TextEditingController _passwordController = TextEditingController();

  String _currentUserFirstName = '';
  String _currentUserRole = '';

  Future<void> _selectDOB(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dob) {
      setState(() {
        _dob = picked;
      });
      await _updateDOB();
    }
  }

  Future<void> _loadDOB() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          if (data.containsKey('dob') && data['dob'] != null) {
            setState(() {
              _dob = (data['dob'] as Timestamp).toDate();
            });
          }
        }
      }
    } catch (e) {
      print('Error loading DOB: $e');
      setState(() {
        _errorMessage = 'Failed to load date of birth.';
      });
    }
  }

  Future<void> _fetchCurrentUserDetails() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          setState(() {
            _currentUserFirstName = userDoc['firstName'] ?? 'User';
            _currentUserRole = (userDoc['role'] ?? 'user').toLowerCase();
          });
        }
      }
    } catch (e) {
      print('Error fetching user details: $e');
      setState(() {
        _errorMessage = 'Failed to load user details.';
      });
    }
  }

  Future<void> _updateDOB() async {
    if (_dob == null) {
      setState(() {
        _errorMessage = 'Please select your date of birth.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'dob': Timestamp.fromDate(_dob!),
        });
        setState(() {
          _successMessage = 'Date of birth updated successfully!';
        });
      }
    } catch (e) {
      print('Error updating DOB: $e');
      setState(() {
        _errorMessage = 'Failed to update date of birth.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (_formKeyPassword.currentState!.validate()) {
      _formKeyPassword.currentState!.save();
      String newPassword = _passwordController.text.trim();

      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _successMessage = '';
      });

      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updatePassword(newPassword);
          setState(() {
            _successMessage = 'Password updated successfully!';
            _passwordController.clear();
          });
        }
      } on FirebaseAuthException catch (e) {
        print('FirebaseAuthException during password change: ${e.message}');
        setState(() {
          _errorMessage = e.message ?? 'Failed to update password.';
        });
      } catch (e) {
        print('Unknown error during password change: $e');
        setState(() {
          _errorMessage = 'An unexpected error occurred.';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginPage()),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDOB();
    _fetchCurrentUserDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      drawer: AppDrawer(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: EdgeInsets.symmetric(vertical: 10),
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date of Birth',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () => _selectDOB(context),
                                  child: Row(
                                    children: [
                                      Text(
                                        'DOB: ',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _dob == null
                                              ? 'No DOB selected.'
                                              : DateFormat.yMMMMd()
                                                  .format(_dob!),
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: _dob == null
                                                ? Colors.blue
                                                : Colors.black,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: EdgeInsets.symmetric(vertical: 10),
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Form(
                              key: _formKeyPassword,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Change Password',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  TextFormField(
                                    controller: _passwordController,
                                    decoration: InputDecoration(
                                      labelText: 'New Password',
                                      border: OutlineInputBorder(),
                                    ),
                                    obscureText: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a new password.';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters.';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: _changePassword,
                                      child: Text('Update Password'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_successMessage.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              _successMessage,
                              style:
                                  TextStyle(color: Colors.green, fontSize: 16),
                            ),
                          ),
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.red, fontSize: 16),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 10.0),
                  child: Card(
                    color: Colors.red[50],
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: _logout,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat.yMMMMd().format(timestamp);
  }
}
