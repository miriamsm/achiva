import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class FriendsFeedScreen extends StatelessWidget {
  const FriendsFeedScreen({super.key});

  Stream<List<Map<String, dynamic>>> _fetchTaskPosts() async* {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        if (kDebugMode) {
          print('No user is logged in.');
        }
        yield [];
        return;
      }

      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .get();

      if (!userSnapshot.exists) {
        if (kDebugMode) {
          print('User data not found for ID: ${currentUser.uid}');
        }
        yield [];
        return;
      }

      List<dynamic> friendsList =
          (userSnapshot.data() as Map<String, dynamic>)['friends'] ?? [];
      friendsList.add(currentUser.uid);

      List<Map<String, dynamic>> allPosts = [];

      for (String friendId in friendsList) {
        QuerySnapshot goalsSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .doc(friendId)
            .collection('goals')
            .get();

        for (var goalDoc in goalsSnapshot.docs) {
          QuerySnapshot tasksSnapshot =
              await goalDoc.reference.collection('tasks').get();

          for (var taskDoc in tasksSnapshot.docs) {
            QuerySnapshot postsSnapshot = await taskDoc.reference
                .collection('posts')
                .orderBy('postDate', descending: true)
                .get();

            for (var postDoc in postsSnapshot.docs) {
              final postData = postDoc.data() as Map<String, dynamic>;
              if (kDebugMode) {
                print('Raw post data: $postData');
                print('Post ID: ${postDoc.id}'); // Debug print
              }

              if (postData.containsKey('content') &&
                  postData.containsKey('postDate')) {
                String formattedDate = 'Unknown Date';
                try {
                  if (postData['postDate'] is Timestamp) {
                    DateTime dateTime =
                        (postData['postDate'] as Timestamp).toDate();
                    formattedDate =
                        DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
                  } else if (postData['postDate'] is String) {
                    formattedDate = postData['postDate'];
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('Error formatting date: $e');
                  }
                }

                final userInfo = await _fetchUserName(friendId);

                allPosts.add({
                  'id': postDoc.id,
                  'userName': userInfo['fullName'],
                  'profilePic': userInfo['profilePic'],
                  'content': postData['content'].toString(),
                  'photo': postData['photo']?.toString(),
                  'timestamp': formattedDate,
                  'dateTime': (postData['postDate'] as Timestamp).toDate(),
                });
              }
            }
          }
        }
      }

      allPosts.sort((a, b) => b['dateTime'].compareTo(a['dateTime']));

      if (kDebugMode) {
        print('All posts: $allPosts'); // Debug print
      }

      yield allPosts;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error in _fetchTaskPosts: $e');
        print('Stack trace: $stackTrace');
      }
      yield [];
    }
  }

  Future<Map<String, String>> _fetchUserName(String userId) async {
    try {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (userSnapshot.exists) {
        Map<String, dynamic> userData =
            userSnapshot.data() as Map<String, dynamic>;
        String firstName = userData['fname'] ?? 'Unknown';
        String lastName = userData['lname'] ?? 'User';
        String profilePic = userData['photo'] ??
            ''; // Assuming the profile picture URL is stored in 'profilePic'

        return {
          'fullName': '$firstName $lastName',
          'profilePic': profilePic,
        };
      } else {
        return {
          'fullName': 'Unknown User',
          'profilePic': '', // No profile picture
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user name: $e');
      }
      return {
        'fullName': 'Unknown User',
        'profilePic': '', // No profile picture
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: false,
            expandedHeight: 160.0,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildRankingDashboard(),
            ),
            
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Recent Posts",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          _buildPostsFeed(),
        ],
      ),
    );
  }

  // Widget for the ranking dashboard
   Widget _buildRankingDashboard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.deepPurpleAccent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Top Ranked Users",
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10.0),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                _RankingCard(user: 'Alice', score: '🏅 1500'),
                SizedBox(width: 10),
                _RankingCard(user: 'Bob', score: '🥈 1200'),
                SizedBox(width: 10),
                _RankingCard(user: 'Charlie', score: '🥉 1100'),
                SizedBox(width: 10),
                _RankingCard(user: 'David', score: '1000'),
                SizedBox(width: 10),
                _RankingCard(user: 'Eva', score: '950'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget for the feed of posts (fetch posts from tasks)

  Widget _buildPostsFeed() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _fetchTaskPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: Text('No posts available.')),
          );
        }

        final posts = snapshot.data!;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final post = posts[index];
              return _PostCard(
                userName: post['userName'] ?? 'Unknown User',
                content: post['content'] ?? 'No content',
                photoUrl: post['photo'],
                timestamp: post['timestamp'] ?? 'Unknown time',
                profilePicUrl: post['profilePic'],
                postId: post['id'] ?? '',
              );
            },
            childCount: posts.length,
          ),
        );
      },
    );
  }
}



// Widget for each post card (display post content)
class _PostCard extends StatefulWidget {
  final String userName;
  final String content;
  final String? photoUrl;
  final String timestamp;
  final String? profilePicUrl;
  final String? postId; // Add this line to receive the postId

  const _PostCard({
    required this.userName,
    required this.content,
    this.photoUrl,
    required this.timestamp,
    this.profilePicUrl,
    this.postId, // Add this line
  });

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  String? selectedEmoji;
  bool showHeart = false;
  Map<String, dynamic> reactions = {};


  final List<String> emojis = ['❤️', '😀', '😍', '👍', '🎉', '😮', '😢'];

  @override
  void initState() {
    super.initState();
    _fetchReactions();

  }

  void _fetchReactions() async {
    try {
      var postDoc = await _findPostDocument(widget.postId!);
      if (postDoc == null) return;

      setState(() {
        var data = postDoc.data() as Map<String, dynamic>?;
        reactions = data?['reactions'] as Map<String, dynamic>? ?? {};
      });
    } catch (error) {
      print('Failed to fetch reactions: $error');
    }
  }

  
  void _showReactionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reactions'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: emojis.map((emoji) {
                var usersReacted = reactions.entries
                    .where((entry) => entry.value == emoji)
                    .map((entry) => entry.key)
                    .toList();
                return ListTile(
                  leading: Text(emoji, style: const TextStyle(fontSize: 24)),
                  title: Text('${usersReacted.length} ${usersReacted.length == 1 ? 'user' : 'users'}'),
                  onTap: () {
                    // Here you can show the list of users who reacted with this emoji
                    // For simplicity, we're just printing to console
                    print('Users who reacted with $emoji: $usersReacted');
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showEmojiPicker() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Choose a reaction'),
        content: Wrap(
          spacing: 10,
          children: emojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                _updateReaction(emoji);
                Navigator.of(context).pop();
              },
              child: Text(emoji, style: const TextStyle(fontSize: 30)),
            );
          }).toList(),
        ),
      );
    },
  );
}

  void _updateReaction(String emoji) async {
    try {
      var postDoc = await _findPostDocument(widget.postId!);

      if (postDoc == null) {
        throw Exception('Post document not found');
      }

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Update the reaction field in the post document
      await postDoc.reference.update({
        'reactions.${currentUser.uid}': emoji,
      });

      setState(() {
      reactions[currentUser.uid] = emoji;
      selectedEmoji = emoji;
    });
    } catch (error) {
      print('Failed to update reaction: $error');
    }
  }

  Future<DocumentSnapshot?> _findPostDocument(String postId) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    // Search in the user's own posts first
    var userPostsQuery = await FirebaseFirestore.instance
        .collection('Users')
        .doc(currentUser.uid)
        .collection('goals')
        .get();

    for (var goalDoc in userPostsQuery.docs) {
      var tasksQuery = await goalDoc.reference.collection('tasks').get();
      for (var taskDoc in tasksQuery.docs) {
        var postDoc =
            await taskDoc.reference.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          return postDoc;
        }
      }
    }

    // If not found in user's posts, search in friends' posts
    var userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(currentUser.uid)
        .get();
    List<dynamic> friendsList =
        (userDoc.data() as Map<String, dynamic>)['friends'] ?? [];

    for (String friendId in friendsList) {
      var friendPostsQuery = await FirebaseFirestore.instance
          .collection('Users')
          .doc(friendId)
          .collection('goals')
          .get();

      for (var goalDoc in friendPostsQuery.docs) {
        var tasksQuery = await goalDoc.reference.collection('tasks').get();
        for (var taskDoc in tasksQuery.docs) {
          var postDoc =
              await taskDoc.reference.collection('posts').doc(postId).get();
          if (postDoc.exists) {
            return postDoc;
          }
        }
      }
    }

    return null;
  }

  // Handle double tap for heart reaction
  void _handleDoubleTap() {
     _updateReaction('❤️');
  setState(() {
    showHeart = true;
  });

    // Show the heart for a brief moment
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        showHeart = false;
      });
    });
  }

    @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _showEmojiPicker,
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        children: [
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.profilePicUrl != null &&
                          widget.profilePicUrl!.isNotEmpty)
                        CircleAvatar(
                          backgroundImage: NetworkImage(widget.profilePicUrl!),
                          radius: 30.0,
                        )
                      else
                        const CircleAvatar(
                          child: Icon(Icons.person),
                          radius: 30.0,
                        ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Text(
                          widget.userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16.0),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(widget.content, style: const TextStyle(fontSize: 14.0)),
                ),
                const SizedBox(height: 10.0),
                if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: _buildImageWidget(),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.timestamp,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 10.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Wrap(
                            spacing: 8,
                            children: reactions.values.toSet().map((emoji) {
                              return Text(emoji, style: const TextStyle(fontSize: 24));
                            }).toList(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.emoji_emotions_outlined),
                            onPressed: _showReactionsDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showHeart)
            Positioned.fill(
              child: Center(
                child: Icon(Icons.favorite,
                    color: Colors.red.withOpacity(0.8), size: 80),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageWidget() {
    return Image.network(
      widget.photoUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          print('Error loading image: $error');
          print('Image URL: ${widget.photoUrl}');
        }
        return _buildErrorWidget();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 40),
          const SizedBox(height: 10),
          Text('Failed to load image',
              style: TextStyle(color: Colors.red[700])),
          const SizedBox(height: 5),
          if (kDebugMode)
            Text(
              'URL: ${widget.photoUrl}',
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Future<bool> _checkImageAvailability(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking image availability: $e');
      }
      return false;
    }
  }
}

// Widget for the ranking cards
class _RankingCard extends StatelessWidget {
  final String user;
  final String score;

  const _RankingCard({
    required this.user,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 20.0,
            child: Text(user.substring(0, 1)),
          ),
          const SizedBox(height: 5.0),
          Text(
            user,
            style: const TextStyle(color: Colors.white, fontSize: 12.0),
          ),
          Text(
            score,
            style: const TextStyle(color: Colors.white, fontSize: 10.0),
          ),
        ],
      ),
    );
  }
}