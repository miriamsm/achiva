import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CreatePostPage extends StatefulWidget {
  final String userId;
  final String goalId;
  final String taskId;

  CreatePostPage({required this.userId, required this.goalId, required this.taskId});

  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _postContentController = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  int _characterCount = 0;
  final int _characterLimit = 280;

  final Color customPurple = Color(0xFF8E24AA);

  @override
  void initState() {
    super.initState();
    _postContentController.addListener(_updateCharacterCount);
  }

  @override
  void dispose() {
    _postContentController.removeListener(_updateCharacterCount);
    _postContentController.dispose();
    super.dispose();
  }

  void _updateCharacterCount() {
    setState(() {
      _characterCount = _postContentController.text.length;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('posts/${widget.userId}/$fileName');
      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  void _createPost() async {
    String postContent = _postContentController.text;
    if (postContent.isNotEmpty || _imageFile != null) {
      setState(() {
        _isUploading = true;
      });

      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
      }

      try {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(widget.userId)
            .collection('goals')
            .doc(widget.goalId)
            .collection('tasks')
            .doc(widget.taskId)
            .collection('posts')
            .add({
          'content': postContent,
          'postDate': FieldValue.serverTimestamp(),
          'photo': imageUrl ?? '',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(Duration(seconds: 2), () {
          Navigator.of(context).pop();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }

      setState(() {
        _isUploading = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add some content or an image to your post.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isNearLimit = _characterCount > _characterLimit - 10 && _characterCount <= _characterLimit;
    bool isOverLimit = _characterCount > _characterLimit;

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Post', style: TextStyle(color: customPurple)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: customPurple),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          _isUploading
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(customPurple),
                  ),
                )
              : TextButton(
                  onPressed: (_characterCount > 0 && _characterCount <= _characterLimit) || _imageFile != null
                      ? _createPost
                      : null,
                  child: Text(
                    'Post',
                    style: TextStyle(
                      color: (_characterCount > 0 && _characterCount <= _characterLimit) || _imageFile != null
                          ? customPurple
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _postContentController,
                maxLines: null,
                maxLength: _characterLimit,
                decoration: InputDecoration(
                  hintText: "Share your thoughts...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: customPurple, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: customPurple, width: 2),
                  ),
                  counterText: '',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNearLimit
                        ? '${_characterLimit - _characterCount} characters left'
                        : isOverLimit
                            ? 'Character limit exceeded'
                            : '${_characterCount}/${_characterLimit}',
                    style: TextStyle(
                      color: isOverLimit ? Colors.red : (isNearLimit ? Colors.orange : Colors.grey),
                      fontWeight: isNearLimit || isOverLimit ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.photo_library, color: customPurple),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                      IconButton(
                        icon: Icon(Icons.camera_alt, color: customPurple),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_imageFile != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_imageFile!, height: 200, width: double.infinity, fit: BoxFit.cover),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _imageFile = null),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}