import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/stamp_book.dart';
import 'pages/top_reward.dart';
import 'pages/account_info.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Named Routes',
      initialRoute: '/',
      routes: {
        '/': (context) => HomePage(),
        '/StampBook': (context) => StampBook(),
        '/TopReward': (context) => TopReward(),
        '/AccountInfo': (context) => Accountinfo(),
        
      },
    );
  }
}


