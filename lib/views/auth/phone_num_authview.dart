import 'package:achiva/exceptions/auth_exceptions.dart';
import 'package:achiva/views/auth/validators.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as devtool show log;
import '../../utilities/show_error_dialog.dart';

class PhoneNumAuthView extends StatefulWidget {
  const PhoneNumAuthView({super.key});

  @override
  State<PhoneNumAuthView> createState() => _PhoneNumAuthViewState();
}

class _PhoneNumAuthViewState extends State<PhoneNumAuthView> {
  late final TextEditingController _phonenumber;
  String _verificationId = '';
  Validators validation = Validators();
  bool isFormSubmitted = false;
  bool isPhonenumTouched = false;
  bool isloading = false;

  @override
  void initState() {
    super.initState();
    _phonenumber = TextEditingController(text: '+9665');
  }

  @override
  void dispose() {
    _phonenumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      onPop: () async {
        setState(() {
          isloading = false;
        });
        resetAuthState();
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 30, 12, 48),
              Color.fromARGB(255, 77, 64, 98),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Image.asset(
              'lib/images/logo-with-name.png',
              fit: BoxFit.contain,
              height: 250,
            ),
            toolbarHeight: 150,
            centerTitle: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 30, 12, 48),
                    Color.fromARGB(255, 77, 64, 98),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 3,
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    width: 450,
                    height: 450,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Welcome to ",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.start,
                        ),
                        const Text(
                          "Achiva,",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          "follow this format:+966[5xxxxxxxx]",
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            color: Color.fromARGB(255, 54, 53, 53),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          maxLength: 13,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(13),
                            FilteringTextInputFormatter.deny(RegExp(r'\s')),
                            // Prevent deleting the prefix
                            TextInputFormatter.withFunction((oldValue, newValue) {
                              if (newValue.text.length < 5) {
                                return oldValue;
                              }
                              if (!newValue.text.startsWith('+9665')) {
                                return oldValue;
                              }
                              return newValue;
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              isPhonenumTouched = true;
                              // Ensure the prefix stays
                              if (!value.startsWith('+9665')) {
                                _phonenumber.text = '+9665${value.substring(5)}';
                                _phonenumber.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _phonenumber.text.length),
                                );
                              }
                            });
                          },
                          autofocus: true,
                          controller: _phonenumber,
                          enableSuggestions: false,
                          autocorrect: false,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            fillColor: Colors.grey.withOpacity(0.1),
                            filled: true,
                            counterText: '',
                            hintText: "+9665xxxxxxxx",
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: (isPhonenumTouched || isFormSubmitted) &&
                                      (validation
                                              .validatePhoneNum(_phonenumber.text)
                                              ?.isNotEmpty ??
                                          false)
                                  ? const BorderSide(
                                      color: Color.fromARGB(255, 195, 24, 12))
                                  : BorderSide.none,
                            ),
                            errorText: (isPhonenumTouched || isFormSubmitted)
                                ? validation.validatePhoneNum(_phonenumber.text)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 15),
                        isloading
                            ? const Align(
                                alignment: Alignment.center,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    backgroundColor: Colors.black,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.grey,
                                    ),
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: () async {
                                  setState(() {
                                    isloading = true;
                                    isFormSubmitted = true;
                                  });

                                  if (validation
                                          .validatePhoneNum(_phonenumber.text)
                                          ?.isEmpty ??
                                      true) {
                                    await verifyPhoneNumber();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please fill phone number field correctly',
                                        ),
                                      ),
                                    );
                                    setState(() {
                                      isloading = false;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color.fromARGB(255, 66, 32, 101),
                                        Color.fromARGB(255, 77, 64, 98),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: double.infinity,
                                      minHeight: 50.0,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Continue',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> verifyPhoneNumber() async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phonenumber.text,
        verificationCompleted: (phoneAuthCredential) async {
          await FirebaseAuth.instance.signInWithCredential(phoneAuthCredential);
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            throw UserNotLoggedInAuthException();
          }
        },
        verificationFailed: (FirebaseAuthException error) async {
          if (!mounted) return;
          await showErrorDialog(
            context,
            'Check your phone number format:\n ${error.message}',
          );
          setState(() {
            isloading = false;
          });
        },
        codeSent: (verificationId, forceResendingToken) async {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            isloading = false;
          });
          final result = await Navigator.pushNamed(
            context,
            '/otp',
            arguments: verificationId,
          );
          if (result == null || result == false) {
            setState(() {
              isloading = false;
            });
          }
        },
        timeout: const Duration(seconds: 30),
        codeAutoRetrievalTimeout: (verificationId) {
          devtool.log("auto retrieval timeout");
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            isloading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'An unexpected error occurred: $e');
      setState(() {
        isloading = false;
      });
    }
  }

  void resetAuthState() {
    setState(() {
      isloading = false;
      isFormSubmitted = false;
      isPhonenumTouched = false;
      _phonenumber.text = '+9665';
    });
  }
}